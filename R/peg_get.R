#' Get a dataset from the Winnipeg Open Data Portal
#'
#' @param dataset_id A character string of the dataset ID e.g. `"d4mq-wa44"`
#'
#' @return A tibble of the dataset
#' @export
#'
#' @examples
#' \dontrun{
#' peg_get("d4mq-wa44")
#' }
peg_get <- function(dataset_id) {
  url <- build_url(dataset_id)
  result <- make_request(url)

  if (!is.null(result$next_url)) {
    cli::cli_warn(c(
      "!" = "Not all rows returned. The dataset is paginated.",
      "i" = "Rows retrieved: {nrow(result$data)}",
      "i" = "Use {.fn peg_all} to retrieve all rows."
    ))
  }

  tibble::as_tibble(result$data)
}
