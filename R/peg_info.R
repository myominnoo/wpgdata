#' Get dataset-level information from the Winnipeg Open Data Portal
#'
#' @param dataset_id A character string of the dataset ID e.g. `"d4mq-wa44"`
#'
#' @return A tibble with one row containing dataset-level metadata including
#'   name, description, category, timestamps, counts, tags, license,
#'   and provenance.
#' @export
#'
#' @examples
#' \dontrun{
#' peg_info("d4mq-wa44")
#' }
peg_info <- function(dataset_id) {
  if (
    !is.character(dataset_id) ||
      length(dataset_id) != 1L ||
      is.na(dataset_id) ||
      !nzchar(dataset_id)
  ) {
    cli::cli_abort(
      "{.arg dataset_id} must be a single non-empty string, e.g. {.val d4mq-wa44}."
    )
  }

  build_url(dataset_id, api = "views") |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_timeout(.TIMEOUT_SECS) |>
    httr2::req_retry(
      max_tries = .MAX_RETRIES,
      is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L, 503L),
      backoff = \(i) 2^i
    ) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform() |>
    handle_errors() |>
    parse_info()
}


#' @noRd
parse_info <- function(response) {
  parsed <- tryCatch(
    httr2::resp_body_json(response),
    error = \(e) {
      cli::cli_abort(
        "Failed to parse server response as JSON: {e$message}"
      )
    }
  )

  tibble::tibble(
    name = parsed$name %||% NA_character_,
    description = parsed$description %||% NA_character_,
    category = parsed$category %||% NA_character_,
    created_at = .parse_unix(parsed$createdAt),
    rows_updated_at = .parse_unix(parsed$rowsUpdatedAt),
    view_last_modified = .parse_unix(parsed$viewLastModified),
    view_count = parsed$viewCount %||% NA_integer_,
    download_count = parsed$downloadCount %||% NA_integer_,
    tags = list(parsed$tags %||% NA_character_),
    license = parsed$license$name %||% NA_character_,
    provenance = parsed$provenance %||% NA_character_
  )
}
