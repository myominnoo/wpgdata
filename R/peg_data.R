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
#'   auto-detected as `2 * parallel::detectCores()`, capped at
#'   `.MAX_CONNECTIONS` (20) and at the number of pages required. Supply an
#'   explicit value to override — lower if the server rate-limits, higher if
#'   you have headroom.
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

  # Capture filter before any calls alter the environment.
  # If the user passed a pre-built variable, evaluate it to get the string.
  filter_expr <- rlang::enexpr(filter)
  if (is.symbol(filter_expr)) {
    filter_expr <- rlang::eval_tidy(filter_expr, env = rlang::caller_env())
  }

  # ── 2. Base query params (shared across count + all page requests) ───────

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
  # The count request includes base_params (especially filter) so the count
  # reflects the filtered row total, not the full dataset size.
  # Saves one full round trip vs sequential count-then-fetch.

  count_req <- build_url(
    dataset_id,
    params = c(base_params, list("count" = "true"))
  ) |>
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

  # ── parse count ──────────────────────────────────────────────────────────

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

  # ── parse page 0 ─────────────────────────────────────────────────────────

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

  # ── 7. Fire all remaining requests ──────────────────────────────────────

  responses <- httr2::req_perform_parallel(
    remaining_requests,
    max_active = max_connections,
    on_error = "continue",
    progress = sprintf(
      "Fetching %d page%s",
      n_pages - 1L,
      if (n_pages - 1L == 1L) "" else "s"
    )
  )

  # ── 8. Parse responses — preserve original page order ───────────────────

  pages <- vector("list", n_pages)
  pages[[1L]] <- page0_data

  cli::cli_progress_bar(
    name = "Parsing pages",
    type = "iterator",
    total = n_pages - 1L,
    format = paste0(
      "{cli::pb_spin} Parsing page {cli::pb_current}/{cli::pb_total}",
      " | {cli::pb_percent}",
      " | {cli::pb_elapsed} elapsed"
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
    cli::cli_progress_update()
  }

  cli::cli_progress_done()

  # ── 9. Bind, trim, return ────────────────────────────────────────────────

  out <- dplyr::bind_rows(pages) |> tibble::as_tibble()

  if (!is.null(top) && nrow(out) > top) {
    out <- out[seq_len(top), ]
  }

  cli::cli_inform(
    c("v" = "Done. {nrow(out)} row{?s} fetched across {n_pages} page{?s}.")
  )

  out
}


# build_filter() ----------------------------------------------------------

#' Translate a filter argument into an OData $filter string
#'
#' Accepts two forms:
#' - A **raw OData string** (e.g. `"total_assessed_value gt 500000"`) which is
#'   returned as-is.
#' - An **R expression** (e.g. `total_assessed_value > 500000`) which is
#'   recursively translated to OData syntax by `.translate_expr()`.
#'
#' @param expr A character string, a call object, or a symbol.
#' @return A single OData filter string.
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

  if (is.character(expr)) {
    return(expr)
  }

  .translate_expr(expr)
}


# .translate_expr() -------------------------------------------------------

#' Recursively translate an R expression into an OData filter string
#'
#' Walks the AST of a captured R expression and maps each node to its OData
#' equivalent. Symbols become bare identifiers; literals are serialised with
#' appropriate quoting; binary and unary operators are mapped to OData keywords.
#'
#' @param x A language object (symbol, call, or scalar literal).
#' @return A single OData filter string fragment.
#' @noRd
.translate_expr <- function(x) {
  if (is.symbol(x)) {
    return(as.character(x))
  }

  if (!is.call(x)) {
    val <- x
    if (is.character(val)) {
      return(glue::glue("'{val}'"))
    }
    if (is.logical(val)) {
      return(tolower(as.character(val)))
    }
    if (is.numeric(val)) {
      return(format(val, scientific = FALSE))
    }
    cli::cli_abort(
      "Unsupported value type {.cls {class(val)}} in filter expression."
    )
  }

  op <- as.character(x[[1]])

  if (length(x) < 2) {
    cli::cli_abort("Malformed expression: missing operand for {.val {op}}.")
  }

  lhs <- .translate_expr(x[[2]])

  if (op == "!" && length(x) == 2) {
    return(glue::glue("not {lhs}"))
  }

  if (length(x) < 3) {
    cli::cli_abort(
      "Malformed expression: missing right-hand side for {.val {op}}."
    )
  }

  rhs <- .translate_expr(x[[3]])

  switch(
    op,
    "==" = glue::glue("{lhs} eq {rhs}"),
    "!=" = glue::glue("{lhs} ne {rhs}"),
    ">" = glue::glue("{lhs} gt {rhs}"),
    ">=" = glue::glue("{lhs} ge {rhs}"),
    "<" = glue::glue("{lhs} lt {rhs}"),
    "<=" = glue::glue("{lhs} le {rhs}"),
    "&" = ,
    "&&" = glue::glue("({lhs} and {rhs})"),
    "|" = ,
    "||" = glue::glue("({lhs} or {rhs})"),
    cli::cli_abort("Unsupported operator {.val {op}} in filter expression.")
  )
}


# .parse_page() -----------------------------------------------------------

#' Parse a single OData page response into a data frame
#'
#' Decodes the JSON body, extracts the `value` array, and strips the
#' `@odata.id` column Socrata injects into every row.
#' `simplifyVector = TRUE` coerces the array directly to a data frame,
#' avoiding a slow row-by-row iteration.
#'
#' @param resp An httr2 response object with a non-empty JSON body.
#' @return A data frame of rows for this page.
#' @noRd
.parse_page <- function(resp) {
  if (length(httr2::resp_body_raw(resp)) == 0L) {
    cli::cli_abort("A page response returned an empty body.")
  }

  parsed <- httr2::resp_body_json(resp, simplifyVector = TRUE)
  data <- parsed[["value"]]

  if (!is.null(data) && "@odata.id" %in% names(data)) {
    data[["@odata.id"]] <- NULL
  }

  data
}
