#' Get column names and types for a Winnipeg Open Data dataset
#'
#' @param dataset_id A character string of the dataset ID e.g. `"d4mq-wa44"`
#'
#' @return A tibble with columns `name`, `field_name`, `type`, and
#'   `description`. Use `field_name` values in [wpgdata::peg_data()] for
#'   filtering and selecting columns.
#' @export
#'
#' @examples
#' \dontrun{
#' # look up field names before querying
#' peg_metadata("d4mq-wa44")
#' }
peg_metadata <- function(dataset_id) {
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
    parse_metadata()
}


#' @noRd
parse_metadata <- function(response) {
  parsed <- tryCatch(
    httr2::resp_body_json(response),
    error = \(e) {
      cli::cli_abort(
        "Failed to parse metadata response as JSON: {e$message}"
      )
    }
  )

  columns <- purrr::pluck(parsed, "columns")

  if (is.null(columns) || length(columns) == 0L) {
    cli::cli_abort(
      "No column properties found in metadata. The dataset schema may be empty."
    )
  }

  columns |>
    purrr::map(\(col) {
      tibble::tibble(
        name = col$name %||% NA_character_,
        field_name = col$fieldName %||% NA_character_,
        type = col$dataTypeName %||% NA_character_,
        description = col$description %||% NA_character_
      )
    }) |>
    purrr::list_rbind()
}
