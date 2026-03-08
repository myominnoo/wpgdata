#' Get column names and types for a Winnipeg Open Data dataset
#'
#' @param dataset_id A character string of the dataset ID e.g. `"d4mq-wa44"`
#'
#' @return A tibble with columns `name`, `field_name`, `type`, and `description`.
#'   Use `field_name` values in [wpgdata::peg_query()] for filtering and selecting columns.

#' @export
#'
#' @examples
#' \dontrun{
#' # look up field names before querying
#' peg_metadata("d4mq-wa44")
#'
#' # then use field_name in peg_query()
#' peg_query("d4mq-wa44", filter = total_assessed_value > 500000)
#' }
peg_metadata <- function(dataset_id) {
  url <- build_url(dataset_id, api = "views")

  url |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform() |>
    handle_errors() |>
    parse_metadata()
}
