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
  url <- build_url(dataset_id, api = "views")

  url |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform() |>
    handle_errors() |>
    parse_info()
}
