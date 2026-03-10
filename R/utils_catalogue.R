# =============================================================================
# peg_catalogue() — full call stack
# =============================================================================
#
# Audit changelog:
#
# ERROR HANDLING
#   [1]  peg_catalogue()         — guard against all_ids being empty after
#                                  stage 1 before firing stage 2
#   [2]  get_catalogue_count()   — wrap req_perform() in tryCatch for
#                                  network-level failures (timeout, DNS)
#   [3]  get_catalogue_count()   — validate count is numeric and > 0
#   [4]  build_catalogue_request() — validate offset >= 0 and limit >= 1
#   [5]  extract_ids_from_pages() — guard against NULL/missing `results`
#                                   field in response body before pluck
#   [6]  extract_ids_from_pages() — abort if ALL pages failed, not just warn
#   [7]  fetch_metadata_parallel() — guard against ids being empty
#   [8]  fetch_metadata_parse()  — wrap resp_body_json() in tryCatch to
#                                  catch malformed JSON per dataset
#   [9]  fetch_metadata_parse()  — guard v$columns[[1]] access —
#                                  crashes if columns is NULL or empty list
#   [10] .parse_unix()           — guard against non-numeric input
#
# PERFORMANCE
#   [P1] get_catalogue_count()   — add req_timeout() so a hung count
#                                  request doesn't block indefinitely
#   [P2] build_catalogue_request() — add req_timeout() per page request
#   [P3] fetch_metadata_req()    — add req_timeout() per metadata request
#   [P4] fetch_metadata_parallel() — expose max_active parameter with a
#                                    sensible default (20) instead of
#                                    hardcoded httr2 default of 10
#   [P5] fetch_metadata_parallel() — add req_retry() to each request to
#                                    automatically retry transient 429/503s
#                                    instead of silently skipping datasets
#   [P6] peg_catalogue()         — expose max_active so callers can tune
#                                  concurrency for their network conditions
#
# =============================================================================

# -----------------------------------------------------------------------------
# 2. Stage 1 helpers — catalogue pages
# -----------------------------------------------------------------------------

#' @noRd
get_catalogue_count <- function() {
  # [2] wrap network call in tryCatch — DNS failures, timeouts etc. would
  #     otherwise surface as cryptic httr2 conditions with no context
  response <- tryCatch(
    httr2::request(.SOCRATA_URL) |>
      httr2::req_url_query(
        domains = "data.winnipeg.ca",
        only = "dataset",
        limit = 1L
      ) |>
      httr2::req_timeout(.TIMEOUT_SECS) |> # [P1]
      httr2::req_error(is_error = \(resp) FALSE) |>
      httr2::req_perform() |>
      handle_errors(),
    error = \(e) {
      cli::cli_abort(c(
        "x" = "Failed to reach the Socrata catalogue API.",
        "i" = "Check your internet connection.",
        "i" = "Details: {e$message}"
      ))
    }
  )

  if (length(httr2::resp_body_raw(response)) == 0) {
    cli::cli_abort("Response body is empty fetching catalogue count.")
  }

  count <- httr2::resp_body_json(response) |>
    purrr::pluck("resultSetSize")

  # [3] validate count is usable
  if (is.null(count)) {
    cli::cli_abort(
      "Could not retrieve total dataset count from the catalogue API."
    )
  }
  if (!is.numeric(count) || count < 0) {
    cli::cli_abort(
      "Unexpected catalogue count value: {.val {count}}. Expected a non-negative integer."
    )
  }
  if (count == 0) {
    cli::cli_abort(
      "The catalogue API returned 0 datasets for data.winnipeg.ca."
    )
  }

  count
}


#' @noRd
build_catalogue_requests <- function(n_fetch, page_size = 100L) {
  offsets <- seq(0, n_fetch - 1, by = page_size)

  purrr::map(offsets, \(offset) {
    build_catalogue_request(
      offset = offset,
      limit = min(page_size, n_fetch - offset)
    )
  })
}


#' @noRd
build_catalogue_request <- function(offset, limit) {
  # [4] validate inputs — bad offsets/limits produce silent empty results
  if (!is.numeric(offset) || offset < 0) {
    cli::cli_abort(
      "{.arg offset} must be a non-negative integer, got {.val {offset}}."
    )
  }
  if (!is.numeric(limit) || limit < 1) {
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
    httr2::req_timeout(.TIMEOUT_SECS) |> # [P2]
    httr2::req_error(is_error = \(resp) FALSE)
}


#' @noRd
extract_ids_from_pages <- function(responses) {
  ids <- responses |>
    purrr::map(\(resp) {
      # network-level error (timeout, connection refused)
      if (inherits(resp, "error")) {
        cli::cli_warn("A catalogue page request failed: {resp$message}")
        return(character(0))
      }

      status <- httr2::resp_status(resp)
      if (status >= 400) {
        cli::cli_warn("HTTP {status} fetching catalogue page, skipping.")
        return(character(0))
      }

      # [5] guard against missing/NULL results field before pluck
      body <- tryCatch(
        httr2::resp_body_json(resp),
        error = \(e) {
          cli::cli_warn("Failed to parse catalogue page response: {e$message}")
          return(NULL)
        }
      )

      if (is.null(body) || is.null(body$results) || length(body$results) == 0) {
        cli::cli_warn("Catalogue page returned no results, skipping.")
        return(character(0))
      }

      purrr::map_chr(body$results, \(x) x$resource$id %||% NA_character_)
    }) |>
    purrr::list_c() |>
    purrr::discard(is.na)

  # [6] abort if every page failed — better than returning an empty tibble
  #     downstream with no explanation
  n_failed <- sum(purrr::map_lgl(responses, \(r) {
    inherits(r, "error") || httr2::resp_status(r) >= 400
  }))

  if (n_failed == length(responses)) {
    cli::cli_abort(c(
      "x" = "All {length(responses)} catalogue page request{?s} failed.",
      "i" = "The Socrata API may be unavailable. Try again later."
    ))
  }

  if (n_failed > 0) {
    cli::cli_warn(
      "{n_failed} of {length(responses)} catalogue page{?s} failed. Results may be incomplete."
    )
  }

  ids
}


# -----------------------------------------------------------------------------
# 3. Stage 2 helpers — metadata
# -----------------------------------------------------------------------------

#' @noRd
fetch_metadata_parallel <- function(ids, max_active = .MAX_ACTIVE) {
  # [7] guard against empty ids — req_perform_parallel(list()) is a no-op
  #     but produces a confusing empty result with no warning
  if (length(ids) == 0) {
    cli::cli_abort("{.arg ids} must not be empty.")
  }

  requests <- purrr::map(ids, fetch_metadata_req)

  responses <- httr2::req_perform_parallel(
    requests,
    on_error = "continue",
    progress = TRUE,
    max_active = max_active # [P4]
  )

  purrr::map2(responses, ids, \(resp, id) {
    if (inherits(resp, "error")) {
      cli::cli_warn("Request failed for dataset {.val {id}}: {resp$message}")
      return(tibble::tibble(id = id))
    }

    status <- httr2::resp_status(resp)
    if (status == 429) {
      cli::cli_warn("Rate limited (429) for dataset {.val {id}}, skipping.")
      return(tibble::tibble(id = id))
    }
    if (status >= 400) {
      cli::cli_warn("HTTP {status} for dataset {.val {id}}, skipping.")
      return(tibble::tibble(id = id))
    }

    fetch_metadata_parse(resp, id)
  }) |>
    purrr::list_rbind()
}


#' @noRd
fetch_metadata_req <- function(dataset_id) {
  build_url(dataset_id, api = "views") |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_timeout(.TIMEOUT_SECS) |> # [P3]
    httr2::req_retry(
      # [P5] retry transient failures
      max_tries = .MAX_RETRIES,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L, 503L),
      backoff = \(i) 2^i # exponential: 2s, 4s, 8s
    ) |>
    httr2::req_error(is_error = \(resp) FALSE)
}


#' @noRd
fetch_metadata_parse <- function(response, dataset_id) {
  if (length(httr2::resp_body_raw(response)) == 0) {
    cli::cli_warn("Empty response for dataset {.val {dataset_id}}, skipping.")
    return(tibble::tibble(id = dataset_id))
  }

  # [8] tryCatch around JSON parse — malformed response for one dataset
  #     should not abort the entire catalogue fetch
  v <- tryCatch(
    httr2::resp_body_json(response),
    error = \(e) {
      cli::cli_warn(
        "Failed to parse JSON for dataset {.val {dataset_id}}: {e$message}"
      )
      return(NULL)
    }
  )

  if (is.null(v)) {
    return(tibble::tibble(id = dataset_id))
  }

  # [9] safe row_count extraction — v$columns can be NULL or length-0
  row_count <- tryCatch(
    as.integer(v$columns[[1]]$cachedContents$count %||% NA_character_),
    error = \(e) NA_integer_
  )

  tibble::tibble(
    # identity
    id = dataset_id,
    name = v$name %||% NA_character_,
    description = v$description %||% NA_character_,
    category = v$category %||% NA_character_,
    license_id = v$licenseId %||% NA_character_,

    # dates
    created_at = .parse_unix(v$createdAt),
    rows_updated_at = .parse_unix(v$rowsUpdatedAt),
    view_last_modified = .parse_unix(v$viewLastModified),
    publication_date = .parse_unix(v$publicationDate),
    index_updated_at = .parse_unix(v$indexUpdatedAt),

    # structure
    row_count = row_count, # [9]
    col_count = length(v$columns %||% list()),

    # engagement
    download_count = v$downloadCount %||% NA_integer_,
    view_count = v$viewCount %||% NA_integer_,

    # custom metadata
    group = v$metadata$custom_fields$Department$Group %||% NA_character_,
    department = v$metadata$custom_fields$Department$Department %||%
      NA_character_,
    update_frequency = v$metadata$custom_fields$`Update Frequency`$Interval %||%
      NA_character_,
    quality_rank = v$metadata$custom_fields$Quality$Rank %||% NA_character_,
    license = v$license$name %||% NA_character_,
    license_link = v$license$termsLink %||% NA_character_,

    # tags
    tags = list(v$tags %||% NA_character_)
  )
}
