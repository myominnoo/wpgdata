# =============================================================================
# peg_catalogue.R
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Main function
# -----------------------------------------------------------------------------

#' List all datasets from the Winnipeg Open Data Portal
#'
#' Retrieves a catalogue of all publicly available datasets from
#' data.winnipeg.ca using the Socrata Discovery API. Both catalogue pages and
#' per-dataset metadata are fetched in parallel for maximum throughput.
#'
#' How it works:
#' 1. Fires the catalogue count request and the first catalogue page
#'    **simultaneously** to save one round trip.
#' 2. Pre-computes all remaining page URLs from known offsets and fetches them
#'    in parallel (no sequential `nextLink` chaining).
#' 3. Extracts dataset IDs from all pages, then fires all metadata requests
#'    in a single parallel batch via the `/api/views` endpoint.
#'
#' @param limit A positive integer — the maximum number of datasets to return.
#'   When `NULL` (the default) every available dataset is fetched.
#' @param max_connections A positive integer controlling how many HTTP requests
#'   are in-flight at once. When `NULL` (the default), the value is
#'   auto-detected as `2 * parallel::detectCores()`, capped at
#'   `.MAX_CONNECTIONS` (20) and at the number of requests needed. Supply
#'   an explicit value to override — lower if the portal rate-limits, higher
#'   if you have headroom.
#'
#' @return A tibble with one row per dataset, arranged by most recently updated.
#' @export
peg_catalogue <- function(limit = NULL, max_connections = NULL) {
  # ── 1. Input validation ───────────────────────────────────────────────────

  if (!is.null(limit)) {
    if (
      !is.numeric(limit) || length(limit) != 1L || is.na(limit) || limit < 1
    ) {
      cli::cli_abort(
        "{.arg limit} must be a single positive integer or {.val NULL}."
      )
    }
    limit <- as.integer(limit)
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

  # ── 2. Bootstrap: count + page 0 simultaneously ──────────────────────────
  # Saves one full round trip vs a sequential count-then-fetch approach.

  cli::cli_inform("Connecting to Winnipeg Open Data catalogue...")

  count_req <- httr2::request(.SOCRATA_URL) |>
    httr2::req_url_query(
      domains = "data.winnipeg.ca",
      only = "dataset",
      limit = 1L
    ) |>
    httr2::req_timeout(.TIMEOUT_SECS) |>
    httr2::req_retry(
      max_tries = .MAX_RETRIES,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L, 503L),
      backoff = \(i) 2^i
    ) |>
    httr2::req_error(is_error = \(resp) FALSE)

  page0_req <- build_catalogue_request(offset = 0L, limit = .PAGE_SIZE)

  bootstrap <- tryCatch(
    httr2::req_perform_parallel(
      list(count_req, page0_req),
      max_active = 2L,
      on_error = "continue",
      progress = FALSE
    ),
    error = \(e) {
      cli::cli_abort(c(
        "x" = "Failed to reach the Socrata catalogue API.",
        "i" = "Check your internet connection.",
        "i" = "Details: {e$message}"
      ))
    }
  )

  # parse count
  count_resp <- bootstrap[[1]]
  if (inherits(count_resp, "error")) {
    cli::cli_abort("Catalogue count request failed: {count_resp$message}")
  }
  handle_errors(count_resp)

  if (length(httr2::resp_body_raw(count_resp)) == 0L) {
    cli::cli_abort("Response body is empty fetching catalogue count.")
  }

  total <- httr2::resp_body_json(count_resp) |> purrr::pluck("resultSetSize")

  if (is.null(total) || !is.numeric(total) || total < 0) {
    cli::cli_abort(
      "Unexpected catalogue count value: {.val {total}}. Expected a non-negative integer."
    )
  }
  if (total == 0L) {
    cli::cli_abort(
      "The catalogue API returned 0 datasets for data.winnipeg.ca."
    )
  }

  n_fetch <- if (!is.null(limit)) min(limit, total) else as.integer(total)
  n_pages <- ceiling(n_fetch / .PAGE_SIZE)

  if (is.null(max_connections)) {
    cores <- parallel::detectCores(logical = TRUE) %||% 1L
    # Cap at .MAX_CONNECTIONS (20) to stay polite to the server.
    # Per-stage capping (against n_pages and n_metadata_reqs) is handled
    # naturally: req_perform_parallel never opens more connections than it
    # has requests, so no need to fold request counts into this formula.
    max_connections <- min(cores * 2L, .MAX_CONNECTIONS)
    max_connections <- max(1L, as.integer(max_connections))
    conn_label <- glue::glue("{max_connections} (auto)")
  } else {
    conn_label <- glue::glue("{max_connections} (manual)")
  }

  cli::cli_inform(c(
    "i" = "Total datasets available : {total}",
    "i" = "Datasets to fetch        : {n_fetch}",
    "i" = "Catalogue pages          : {n_pages}",
    "i" = "Connections              : {conn_label}"
  ))

  # ── 4. Stage 1 — catalogue pages ─────────────────────────────────────────
  # Page 0 is already in hand from the bootstrap. Build requests only for
  # pages 1 .. n_pages-1 and fire them in parallel, then parse everything.

  page0_resp <- bootstrap[[2]]
  if (inherits(page0_resp, "error")) {
    cli::cli_abort("First catalogue page request failed: {page0_resp$message}")
  }
  handle_errors(page0_resp)

  if (n_pages == 1L) {
    # All datasets fit in a single page — skip the second parallel call entirely
    all_responses <- list(page0_resp)
  } else {
    remaining_reqs <- lapply(seq_len(n_pages - 1L), \(page_idx) {
      offset <- page_idx * .PAGE_SIZE
      page_top <- min(.PAGE_SIZE, n_fetch - offset)
      build_catalogue_request(offset = offset, limit = page_top)
    })

    remaining_resps <- httr2::req_perform_parallel(
      remaining_reqs,
      max_active = min(max_connections, n_pages - 1L),
      on_error = "continue",
      progress = sprintf("Fetching %d catalogue page(s)", n_pages - 1L)
    )

    all_responses <- c(list(page0_resp), remaining_resps)
  }

  all_ids <- extract_ids_from_pages(all_responses)

  if (length(all_ids) == 0L) {
    cli::cli_abort(c(
      "x" = "No dataset IDs could be retrieved from the catalogue.",
      "i" = "All catalogue page requests may have failed. Try again later."
    ))
  }

  # Honour `limit` exactly — extract_ids_from_pages may return slightly more
  # if the last page was larger than needed.
  if (length(all_ids) > n_fetch) {
    all_ids <- all_ids[seq_len(n_fetch)]
  }

  # ── 5. Stage 2 — metadata ─────────────────────────────────────────────────

  result <- fetch_metadata_parallel(
    all_ids,
    max_connections = max_connections
  ) |>
    dplyr::mutate(
      url = paste0(.WINNIPEG_URL, "/d/", .data$id),
      category = dplyr::coalesce(.data$category, "Uncategorized")
    ) |>
    dplyr::arrange(dplyr::desc(.data$rows_updated_at))

  cli::cli_inform(c(
    "v" = "Done. {nrow(result)} dataset{?s} across {dplyr::n_distinct(result$category)} categor{?y/ies}."
  ))

  result
}


# -----------------------------------------------------------------------------
# 2. Stage 1 helpers — catalogue pages
# -----------------------------------------------------------------------------

#' Build a single httr2 request for one page of the Socrata catalogue API
#'
#' Constructs a request for `limit` datasets starting at `offset` from the
#' Socrata Discovery API for data.winnipeg.ca. Used by `peg_catalogue()` to
#' pre-compute all page requests before firing them in parallel.
#'
#' @param offset Non-negative integer — number of datasets to skip.
#' @param limit Positive integer — number of datasets to return (max 100).
#' @return An httr2 request object.
#' @noRd
build_catalogue_request <- function(offset, limit) {
  if (!is.numeric(offset) || length(offset) != 1L || offset < 0) {
    cli::cli_abort(
      "{.arg offset} must be a non-negative integer, got {.val {offset}}."
    )
  }
  if (!is.numeric(limit) || length(limit) != 1L || limit < 1) {
    cli::cli_abort(
      "{.arg limit} must be a positive integer, got {.val {limit}}."
    )
  }

  httr2::request(.SOCRATA_URL) |>
    httr2::req_url_query(
      domains = "data.winnipeg.ca",
      only = "dataset",
      limit = as.integer(limit),
      offset = as.integer(offset)
    ) |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_timeout(.TIMEOUT_SECS) |>
    httr2::req_retry(
      max_tries = .MAX_RETRIES,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L, 503L),
      backoff = \(i) 2^i
    ) |>
    httr2::req_error(is_error = \(resp) FALSE)
}


#' Extract dataset IDs from a list of catalogue page responses
#'
#' Maps over a list of httr2 response objects (one per catalogue page),
#' handles network-level errors and HTTP errors gracefully with warnings,
#' and collects all non-NA dataset ID strings into a single character vector.
#' Aborts if every page failed, since there would be nothing to return.
#'
#' @param responses A list of httr2 response objects or error conditions.
#' @return A character vector of dataset IDs (e.g. `"d4mq-wa44"`).
#' @noRd
extract_ids_from_pages <- function(responses) {
  ids <- lapply(responses, \(resp) {
    if (inherits(resp, "error")) {
      cli::cli_warn("A catalogue page request failed: {resp$message}")
      return(character(0))
    }

    status <- httr2::resp_status(resp)
    if (status >= 400L) {
      cli::cli_warn("HTTP {status} fetching catalogue page, skipping.")
      return(character(0))
    }

    body <- tryCatch(
      httr2::resp_body_json(resp, simplifyVector = FALSE),
      error = \(e) {
        cli::cli_warn("Failed to parse catalogue page response: {e$message}")
        NULL
      }
    )

    if (is.null(body) || is.null(body$results) || length(body$results) == 0L) {
      cli::cli_warn("Catalogue page returned no results, skipping.")
      return(character(0))
    }

    # lapply + vapply is faster than purrr::map_chr for tight loops
    vapply(body$results, \(x) x$resource$id %||% NA_character_, character(1L))
  })

  # Flatten, drop NAs, deduplicate — guards against overlapping pages
  # returning the same ID twice and firing redundant metadata requests.
  ids <- unique(Filter(\(x) !is.na(x), unlist(ids, use.names = FALSE)))

  # Count failures without calling resp_status() on error objects.
  # inherits(r, "error") must be checked first; if TRUE the status branch
  # is never reached (short-circuit), but using a safe helper is clearer.
  .is_failed <- \(r) {
    inherits(r, "error") ||
      (!inherits(r, "error") && httr2::resp_status(r) >= 400L)
  }
  n_failed <- sum(vapply(responses, .is_failed, logical(1L)))

  if (n_failed == length(responses)) {
    cli::cli_abort(c(
      "x" = "All {length(responses)} catalogue page request{?s} failed.",
      "i" = "The Socrata API may be unavailable. Try again later."
    ))
  }
  if (n_failed > 0L) {
    cli::cli_warn(
      "{n_failed} of {length(responses)} catalogue page{?s} failed. Results may be incomplete."
    )
  }

  ids
}


# -----------------------------------------------------------------------------
# 3. Stage 2 helpers — metadata
# -----------------------------------------------------------------------------

#' Fetch metadata for a vector of dataset IDs in parallel
#'
#' Builds one httr2 request per ID, fires all
#' requests concurrently with `max_connections` slots via
#' [httr2::req_perform_parallel()], and parses each response.
#' Failed responses are skipped with a warning
#' rather than aborting the entire batch, so a single unavailable dataset
#' does not cancel the rest of the catalogue fetch.
#'
#' @param ids A non-empty character vector of dataset IDs.
#' @param max_connections Positive integer — concurrent request slots.
#' @return A tibble with one row per dataset ID. Rows for failed requests
#'   contain the ID and `NA` for all other fields.
#' @noRd
fetch_metadata_parallel <- function(ids, max_connections = .MAX_CONNECTIONS) {
  if (length(ids) == 0L) {
    cli::cli_abort("{.arg ids} must not be empty.")
  }

  # lapply is faster than purrr::map for building simple request lists
  requests <- lapply(ids, fetch_metadata_req)

  responses <- httr2::req_perform_parallel(
    requests,
    max_active = max_connections,
    on_error = "continue",
    progress = sprintf("Fetching metadata for %d datasets", length(ids))
  )

  # Parse in a plain for-loop — avoids purrr::map2 overhead on large vectors.
  # Pre-allocate the output list so R doesn't resize it on every iteration.
  out <- vector("list", length(ids))

  cli::cli_progress_bar(
    name = "Parsing metadata",
    type = "iterator",
    total = length(ids),
    format = "{cli::pb_spin} Parsing {cli::pb_current}/{cli::pb_total} | {cli::pb_percent} | {cli::pb_elapsed} elapsed"
  )

  for (i in seq_along(responses)) {
    resp <- responses[[i]]
    id <- ids[[i]]

    if (inherits(resp, "error")) {
      cli::cli_warn("Request failed for dataset {.val {id}}: {resp$message}")
      out[[i]] <- tibble::tibble(id = id)
    } else {
      status <- httr2::resp_status(resp)
      if (status == 429L) {
        cli::cli_warn("Rate limited (429) for dataset {.val {id}}, skipping.")
        out[[i]] <- tibble::tibble(id = id)
      } else if (status >= 400L) {
        cli::cli_warn("HTTP {status} for dataset {.val {id}}, skipping.")
        out[[i]] <- tibble::tibble(id = id)
      } else {
        out[[i]] <- fetch_metadata_parse(resp, id)
      }
    }

    cli::cli_progress_update()
  }

  cli::cli_progress_done()

  purrr::list_rbind(out)
}


#' Build a single httr2 metadata request for one dataset
#'
#' Constructs a request to the `/api/views/<id>.json` endpoint, which returns
#' rich metadata (schema, dates, engagement stats, custom fields) for a single
#' dataset. Includes retry logic for transient 429/500/503 responses.
#'
#' @param dataset_id A character string dataset ID e.g. `"d4mq-wa44"`.
#' @return An httr2 request object.
#' @noRd
fetch_metadata_req <- function(dataset_id) {
  build_url(dataset_id, api = "views") |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_timeout(.TIMEOUT_SECS) |>
    httr2::req_retry(
      max_tries = .MAX_RETRIES,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L, 503L),
      backoff = \(i) 2^i # 2 s, 4 s, 8 s
    ) |>
    httr2::req_error(is_error = \(resp) FALSE)
}


#' Parse a single `/api/views` metadata response into a one-row tibble
#'
#' Extracts identity, date, structure, engagement, and custom-field columns
#' from the JSON response for one dataset. Malformed or missing fields are
#' handled defensively — each falls back to `NA` rather than aborting — so a
#' single bad dataset does not break the entire catalogue fetch.
#'
#' @param response An httr2 response object with a non-empty JSON body.
#' @param dataset_id The dataset ID string, used in warning messages.
#' @return A one-row tibble, or a minimal stub tibble containing only `id`
#'   if the response body is empty or the JSON cannot be parsed.
#' @noRd
fetch_metadata_parse <- function(response, dataset_id) {
  if (length(httr2::resp_body_raw(response)) == 0L) {
    cli::cli_warn("Empty response for dataset {.val {dataset_id}}, skipping.")
    return(tibble::tibble(id = dataset_id))
  }

  # Wrap JSON parse so a malformed response for one dataset doesn't abort
  # the entire parallel batch.
  v <- tryCatch(
    httr2::resp_body_json(response),
    error = \(e) {
      cli::cli_warn(
        "Failed to parse JSON for dataset {.val {dataset_id}}: {e$message}"
      )
      NULL
    }
  )

  if (is.null(v)) {
    return(tibble::tibble(id = dataset_id))
  }

  # v$columns can be NULL or length-0; guard before subscripting [[1]]
  row_count <- tryCatch(
    as.integer(v$columns[[1]]$cachedContents$count %||% NA_character_),
    error = \(e) NA_integer_
  )

  tibble::tibble(
    # ── identity ────────────────────────────────────────────────────────────
    id = dataset_id,
    name = v$name %||% NA_character_,
    description = v$description %||% NA_character_,
    category = v$category %||% NA_character_,
    license_id = v$licenseId %||% NA_character_,

    # ── dates ────────────────────────────────────────────────────────────────
    created_at = .parse_unix(v$createdAt),
    rows_updated_at = .parse_unix(v$rowsUpdatedAt),
    view_last_modified = .parse_unix(v$viewLastModified),
    publication_date = .parse_unix(v$publicationDate),
    index_updated_at = .parse_unix(v$indexUpdatedAt),

    # ── structure ────────────────────────────────────────────────────────────
    row_count = row_count,
    col_count = length(v$columns %||% list()),

    # ── engagement ───────────────────────────────────────────────────────────
    download_count = v$downloadCount %||% NA_integer_,
    view_count = v$viewCount %||% NA_integer_,

    # ── custom metadata ───────────────────────────────────────────────────────
    group = v$metadata$custom_fields$Department$Group %||% NA_character_,
    department = v$metadata$custom_fields$Department$Department %||%
      NA_character_,
    update_frequency = v$metadata$custom_fields$`Update Frequency`$Interval %||%
      NA_character_,
    quality_rank = v$metadata$custom_fields$Quality$Rank %||% NA_character_,
    license = v$license$name %||% NA_character_,
    license_link = v$license$termsLink %||% NA_character_,

    # ── tags ─────────────────────────────────────────────────────────────────
    tags = list(v$tags %||% NA_character_)
  )
}
