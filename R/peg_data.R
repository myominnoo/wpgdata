# -----------------------------------------------------------------------------
# peg_data.R — unified fetch / query / paginate with parallel requests
# -----------------------------------------------------------------------------

#' Fetch data from the Winnipeg Open Data Portal
#'
#' A unified replacement for `peg_get()`, `peg_query()`, and `peg_all()`.
#' Pages are fetched **in parallel** for maximum throughput.
#'
#' How it works:
#' 1. Fires the `$count` request and the first data page **simultaneously**,
#'    saving one full round trip before the main fetch begins.
#' 2. Pre-computes every remaining page URL from `$skip` offsets — no
#'    `nextLink` chaining required.
#' 3. Fires all remaining requests via [httr2::req_perform_parallel()] with
#'    `max_active` throttling. curl starts the next request the instant any
#'    slot frees, avoiding the convoy delay of manual batching.
#' 4. Binds pages in their original order and trims to `top`.
#'
#' @param dataset_id A character string dataset ID e.g. `"d4mq-wa44"`.
#' @param filter A filter expression — either an R expression such as
#'   `total_assessed_value > 500000`, or a raw OData string such as
#'   `"total_assessed_value gt 500000"`. Use [peg_metadata()] to look up
#'   valid field names.
#' @param select A character vector of field names to return,
#'   e.g. `c("roll_number", "total_assessed_value")`.
#' @param top A positive integer — the maximum number of rows to return.
#'   When `NULL` (the default) every row is fetched.
#' @param skip A non-negative integer — rows to skip before collecting
#'   results.
#' @param orderby A character string specifying sort order,
#'   e.g. `"total_assessed_value desc"`.
#' @param max_connections A positive integer controlling how many HTTP
#'   requests are in-flight at once. When `NULL` (the default), the value is
#'   auto-detected as `2 * parallel::detectCores()`, capped at 10 and at the
#'   number of pages required. Supply an explicit value to override — lower if
#'   the server rate-limits, higher if you have headroom.
#'
#' @return A [tibble::tibble()] with the requested rows in their original order.
#' @export
#'
#' @examples
#' \dontrun{
#' # fetch every row
#' peg_data("d4mq-wa44")
#'
#' # fetch the first 500 rows
#' peg_data("d4mq-wa44", top = 500)
#'
#' # filter + select + sort, fetch all matching rows
#' peg_data(
#'   "d4mq-wa44",
#'   filter  = total_assessed_value > 500000,
#'   select  = c("roll_number", "total_assessed_value"),
#'   orderby = "total_assessed_value desc"
#' )
#'
#' # override connection count
#' peg_data("d4mq-wa44", max_connections = 4L)
#' }
peg_data <- function(
  dataset_id,
  filter = NULL,
  select = NULL,
  top = NULL,
  skip = NULL,
  orderby = NULL,
  max_connections = NULL
) {
  # ── 1. Input validation ─────────────────────────────────────────────────

  if (!is.null(top)) {
    if (!is.numeric(top) || length(top) != 1L || is.na(top) || top < 1) {
      cli::cli_abort("{.arg top} must be a single positive integer.")
    }
    top <- as.integer(top)
  }

  if (!is.null(skip)) {
    if (!is.numeric(skip) || length(skip) != 1L || is.na(skip) || skip < 0) {
      cli::cli_abort("{.arg skip} must be a single non-negative integer.")
    }
    skip <- as.integer(skip)
  }

  if (!is.null(select) && !is.character(select)) {
    cli::cli_abort("{.arg select} must be a character vector of column names.")
  }

  if (!is.null(orderby) && !is.character(orderby)) {
    cli::cli_abort(
      "{.arg orderby} must be a character string e.g. {.val total_assessed_value desc}."
    )
  }

  if (!is.null(max_connections)) {
    if (
      !is.numeric(max_connections) ||
        length(max_connections) != 1L ||
        max_connections < 1L
    ) {
      cli::cli_abort(
        "{.arg max_connections} must be a single positive integer or {.val NULL}."
      )
    }
    max_connections <- as.integer(max_connections)
  }

  # Capture filter before any calls alter the environment
  filter_expr <- rlang::enexpr(filter)

  # ── 2. Base query params (shared across all page requests) ───────────────

  base_params <- list()

  if (!is.null(filter_expr)) {
    base_params[["filter"]] <- build_filter(filter_expr)
  }
  if (!is.null(select)) {
    base_params[["select"]] <- paste(select, collapse = ",")
  }
  if (!is.null(orderby)) {
    base_params[["orderby"]] <- orderby
  }

  base_skip <- skip %||% 0L

  # ── 3. Bootstrap: fire count + page 0 simultaneously ────────────────────
  # Saves one full round trip compared to a sequential get_total_count() call
  # followed by the first data request.

  count_req <- build_url(dataset_id, params = list("count" = "true")) |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_timeout(seconds = 30L)

  page0_req <- build_url(
    dataset_id,
    params = c(base_params, list(skip = base_skip, top = .PAGE_SIZE))
  ) |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_retry(
      max_tries = 3L,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L, 503L),
      backoff = \(attempt) 2^attempt
    ) |>
    httr2::req_timeout(seconds = 60L)

  bootstrap <- httr2::req_perform_parallel(
    list(count_req, page0_req),
    max_active = 2L,
    on_error = "continue",
    progress = FALSE
  )

  # parse count
  count_resp <- bootstrap[[1]]
  if (inherits(count_resp, "error")) {
    cli::cli_abort("Count request failed: {conditionMessage(count_resp)}")
  }
  handle_errors(count_resp)
  total_available <- httr2::resp_body_json(count_resp)[["@odata.count"]] %||%
    NA_integer_

  if (is.na(total_available)) {
    cli::cli_abort(
      "Could not retrieve row count for {.val {dataset_id}}."
    )
  }
  if (total_available == 0L) {
    cli::cli_warn("Dataset {.val {dataset_id}} has no rows.")
    return(tibble::tibble())
  }

  # parse page 0 data
  page0_resp <- bootstrap[[2]]
  if (inherits(page0_resp, "error")) {
    cli::cli_abort("First page request failed: {conditionMessage(page0_resp)}")
  }
  handle_errors(page0_resp)
  page0_data <- .parse_page(page0_resp)

  # ── 4. Page arithmetic ───────────────────────────────────────────────────

  rows_available <- max(0L, total_available - base_skip)
  rows_to_fetch <- if (!is.null(top)) {
    min(top, rows_available)
  } else {
    rows_available
  }
  n_pages <- ceiling(rows_to_fetch / .PAGE_SIZE)

  if (rows_to_fetch == 0L) {
    cli::cli_warn("No rows remain after applying {.arg skip}.")
    return(tibble::tibble())
  }

  # ── 5. Auto-detect max_connections ──────────────────────────────────────

  if (is.null(max_connections)) {
    cores <- parallel::detectCores(logical = TRUE) %||% 1L
    max_connections <- min(cores * 2L, .MAX_CONNECTIONS, n_pages)
    max_connections <- max(1L, as.integer(max_connections))
    conn_label <- glue::glue("{max_connections} (auto)")
  } else {
    conn_label <- glue::glue("{max_connections} (manual)")
  }

  cli::cli_inform(c(
    "i" = "Rows available : {total_available}",
    "i" = "Rows to fetch  : {rows_to_fetch}",
    "i" = "Pages          : {n_pages}",
    "i" = "Connections    : {conn_label}"
  ))

  # If everything fit in page 0, return immediately — no further requests
  if (n_pages == 1L) {
    out <- tibble::as_tibble(page0_data)
    if (!is.null(top) && nrow(out) > top) {
      out <- out[seq_len(top), ]
    }
    cli::cli_inform(c("v" = "Done. {nrow(out)} row{?s} fetched in 1 page."))
    return(out)
  }

  # ── 6. Build requests for pages 1 .. n_pages-1 ──────────────────────────
  # Page 0 is already done above. Remaining pages are 1-indexed offsets.
  # Using lapply (faster than purrr::map for simple iterations).

  remaining_requests <- lapply(seq_len(n_pages - 1L), \(page_idx) {
    page_skip <- base_skip + page_idx * .PAGE_SIZE
    page_top <- min(.PAGE_SIZE, rows_to_fetch - page_idx * .PAGE_SIZE)

    build_url(
      dataset_id,
      params = c(base_params, list(skip = page_skip, top = page_top))
    ) |>
      httr2::request() |>
      httr2::req_headers("Accept" = "application/json") |>
      httr2::req_error(is_error = \(resp) FALSE) |>
      httr2::req_retry(
        max_tries = 3L,
        is_transient = \(resp) {
          httr2::resp_status(resp) %in% c(429L, 500L, 503L)
        },
        backoff = \(attempt) 2^attempt
      ) |>
      httr2::req_timeout(seconds = 60L)
  })

  # ── 7. Fire all remaining requests — let httr2/curl manage the queue ────
  # Passing all requests at once with max_active is faster than manual
  # batching: curl starts the next request the instant any slot frees,
  # avoiding the convoy delay where a slow page holds up an entire batch.

  responses <- httr2::req_perform_parallel(
    remaining_requests,
    max_active = max_connections,
    on_error = "continue",
    progress = glue::glue("Fetching {n_pages - 1L} pages")
  )

  # ── 8. Parse responses — preserve original page order ───────────────────

  pages <- vector("list", n_pages)
  pages[[1L]] <- page0_data # slot in the already-parsed page 0
  rows_done <- nrow(page0_data)

  cli::cli_progress_bar(
    name = "Parsing pages",
    type = "iterator",
    total = n_pages - 1L,
    format = paste0(
      "{cli::pb_spin} Parsing page {cli::pb_current}/{cli::pb_total} ",
      "| Rows: {rows_done}/{rows_to_fetch} ",
      "| {cli::pb_percent} ",
      "| {cli::pb_elapsed} elapsed"
    )
  )

  for (i in seq_along(responses)) {
    resp <- responses[[i]]
    page_idx <- i + 1L

    if (inherits(resp, "error")) {
      cli::cli_progress_done()
      cli::cli_abort(
        "Page {page_idx} failed with a network error: {conditionMessage(resp)}"
      )
    }

    handle_errors(resp)
    pages[[page_idx]] <- .parse_page(resp)
    rows_done <- rows_done + nrow(pages[[page_idx]])

    cli::cli_progress_update()
  }

  cli::cli_progress_done()

  # ── 9. Bind, trim, return ────────────────────────────────────────────────

  out <- dplyr::bind_rows(pages) |> tibble::as_tibble()

  # Defensive trim — guards against server-side rounding surprises
  if (!is.null(top) && nrow(out) > top) {
    out <- out[seq_len(top), ]
  }

  cli::cli_inform(
    c("v" = "Done. {nrow(out)} row{?s} fetched across {n_pages} page{?s}.")
  )

  out
}


# get_total_count() -------------------------------------------------------

#' Fetch the total row count for a dataset via OData $count
#'
#' Sends a single lightweight request with `$count=true` to the OData endpoint.
#' The server returns a JSON object with an `@odata.count` field rather than
#' any actual row data, making this much cheaper than fetching a full page.
#' Used by `peg_data()` during the bootstrap phase to calculate how many pages
#' need to be requested.
#'
#' @param dataset_id A character string dataset ID e.g. `"d4mq-wa44"`.
#' @return A single integer — the total number of rows in the dataset — or
#'   `NA_integer_` if the server does not return an `@odata.count` field.
#' @noRd
get_total_count <- function(dataset_id) {
  url <- build_url(dataset_id, params = list("count" = "true"))

  response <- url |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    # Disable httr2's default behaviour of throwing on 4xx/5xx so that
    # handle_errors() can produce informative cli messages instead.
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform() |>
    handle_errors()

  if (httr2::resp_body_raw(response) |> length() == 0) {
    cli::cli_abort(
      "Response body is empty getting row count for {.val {dataset_id}}."
    )
  }

  result <- httr2::resp_body_json(response)
  # Return NA if the field is absent rather than throwing, so the caller can
  # decide how to handle a missing count (peg_data() treats NA as fatal).
  result[["@odata.count"]] %||% NA_integer_
}


# build_filter() ----------------------------------------------------------

#' Translate a filter argument into an OData $filter string
#'
#' Accepts two forms:
#' - A **raw OData string** (e.g. `"total_assessed_value gt 500000"`) which is
#'   returned as-is — useful when the caller already knows OData syntax.
#' - An **R expression** (e.g. `total_assessed_value > 500000`) which is
#'   recursively translated to OData syntax.
#'
#' The expression form is captured with `rlang::enexpr()` in the calling
#' function before being passed here, so `expr` arrives as a call object
#' (or symbol for bare column names) rather than an evaluated value.
#'
#' @param expr A character string, a call object, or a symbol.
#' @return A single OData filter string, e.g. `"total_assessed_value gt 500000"`.
#' @noRd
build_filter <- function(expr) {
  if (is.null(expr)) {
    cli::cli_abort("{.arg expr} must not be NULL.")
  }

  if (!is.character(expr) && !is.call(expr) && !is.symbol(expr)) {
    cli::cli_abort(
      "{.arg expr} must be a string or R expression, not {.cls {class(expr)}}."
    )
  }

  # Raw OData strings pass through unchanged.
  if (is.character(expr)) {
    return(expr)
  }

  # R call/symbol objects are recursively translated to OData syntax.
  .translate_expr(expr)
}


# .translate_expr() -------------------------------------------------------

#' Recursively translate an R expression into an OData filter string
#'
#' Walks the abstract syntax tree (AST) of a captured R expression and maps
#' each node to its OData equivalent:
#'
#' - **Symbols** (bare column names) become plain identifier strings.
#' - **Literals** are serialised — character values are single-quoted,
#'   logicals are lowercased (`true`/`false`), numerics use fixed notation.
#' - **Unary `!`** becomes OData `not`.
#' - **Binary comparison operators** (`==`, `!=`, `>`, `>=`, `<`, `<=`) map
#'   to their OData keywords (`eq`, `ne`, `gt`, `ge`, `lt`, `le`).
#' - **Logical connectives** (`&`, `&&`, `|`, `||`) map to `and`/`or` and are
#'   wrapped in parentheses to make precedence explicit.
#'
#' Compound expressions are handled naturally through recursion: each side of
#' a binary operator is translated independently, then joined.
#'
#' @param x A language object (symbol, call, or scalar literal).
#' @return A single OData filter string fragment.
#' @noRd
.translate_expr <- function(x) {
  # ── Leaf: symbol → bare column name ──────────────────────────────────────
  if (is.symbol(x)) {
    return(as.character(x))
  }

  # ── Leaf: literal value → OData-serialised string ────────────────────────
  if (!is.call(x)) {
    val <- x
    if (is.character(val)) {
      # OData string literals must be single-quoted.
      return(glue::glue("'{val}'"))
    }
    if (is.logical(val)) {
      # OData boolean literals are lowercase: true / false.
      return(tolower(as.character(val)))
    }
    if (is.numeric(val)) {
      # Avoid scientific notation (e.g. 1e+05) which OData does not accept.
      return(format(val, scientific = FALSE))
    }
    cli::cli_abort(
      "Unsupported value type {.cls {class(val)}} in filter expression."
    )
  }

  # ── Internal node: operator call ─────────────────────────────────────────
  # x[[1]] is the operator; x[[2]] is the LHS; x[[3]] (if present) is the RHS.
  op <- as.character(x[[1]])

  if (length(x) < 2) {
    cli::cli_abort("Malformed expression: missing operand for {.val {op}}.")
  }

  # Recursively translate the left-hand side.
  lhs <- .translate_expr(x[[2]])

  # ── Unary `!` → OData `not` ──────────────────────────────────────────────
  if (op == "!" && length(x) == 2) {
    return(glue::glue("not {lhs}"))
  }

  if (length(x) < 3) {
    cli::cli_abort(
      "Malformed expression: missing right-hand side for {.val {op}}."
    )
  }

  # Recursively translate the right-hand side.
  rhs <- .translate_expr(x[[3]])

  # ── Binary operators → OData keywords ────────────────────────────────────
  # Fall-through cases (&/&&, |/||) share a single glue expression via
  # consecutive switch arms with no body.
  switch(
    op,
    "==" = glue::glue("{lhs} eq {rhs}"),
    "!=" = glue::glue("{lhs} ne {rhs}"),
    ">" = glue::glue("{lhs} gt {rhs}"),
    ">=" = glue::glue("{lhs} ge {rhs}"),
    "<" = glue::glue("{lhs} lt {rhs}"),
    "<=" = glue::glue("{lhs} le {rhs}"),
    "&" = , # fall-through
    "&&" = glue::glue("({lhs} and {rhs})"),
    "|" = , # fall-through
    "||" = glue::glue("({lhs} or {rhs})"),
    cli::cli_abort("Unsupported operator {.val {op}} in filter expression.")
  )
}


# .parse_page() -----------------------------------------------------------

#' Parse a single OData page response into a data frame
#'
#' Decodes the JSON body of one page response, extracts the `value` array, and
#' strips the `@odata.id` column that Socrata injects into every row. Called
#' in two places inside `peg_data()`: once for the bootstrap page 0 response
#' and once per page inside the parallel parse loop.
#'
#' `simplifyVector = TRUE` in [httr2::resp_body_json()] causes the `value`
#' array to be coerced directly to a data frame when all rows share the same
#' fields, avoiding a slow `purrr::map_dfr()` step.
#'
#' @param resp An httr2 response object with a non-empty JSON body.
#' @return A data frame of rows for this page, or `NULL` if the `value` field
#'   is absent (e.g. a count-only response was passed by mistake).
#' @noRd
.parse_page <- function(resp) {
  if (length(httr2::resp_body_raw(resp)) == 0L) {
    cli::cli_abort("A page response returned an empty body.")
  }

  # simplifyVector coerces the "value" JSON array directly to a data frame —
  # faster than iterating over a list of row objects.
  parsed <- httr2::resp_body_json(resp, simplifyVector = TRUE)
  data <- parsed[["value"]]

  # Socrata adds @odata.id to every row as an internal navigation key.
  # It carries no dataset content and would pollute the returned tibble.
  if (!is.null(data) && "@odata.id" %in% names(data)) {
    data[["@odata.id"]] <- NULL
  }

  data
}
