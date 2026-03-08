#' Get all rows from a Winnipeg Open Data Portal dataset
#'
#' Automatically paginates through all pages of a dataset using
#' `@odata.nextLink`. For large datasets, use `max_pages` to cap
#' the number of pages fetched.
#'
#' @param dataset_id A character string of the dataset ID e.g. `"d4mq-wa44"`
#' @param max_pages An integer specifying the maximum number of pages to fetch.
#'   Defaults to `10`. Set to `Inf` to fetch all pages with no limit.
#'
#' @return A tibble of all rows retrieved
#' @export
#'
#' @examples
#' \dontrun{
#' # fetch with default safety cap of 10 pages
#' peg_all("d4mq-wa44")
#'
#' # fetch all rows with no limit
#' peg_all("d4mq-wa44", max_pages = Inf)
#'
#' # fetch up to 3 pages
#' peg_all("d4mq-wa44", max_pages = 3)
#' }
peg_all <- function(dataset_id, max_pages = 10) {
  # input validation
  if (!is.numeric(max_pages) || max_pages < 1) {
    cli::cli_abort(
      "{.arg max_pages} must be a positive number or {.val Inf}."
    )
  }

  # get total rows upfront for progress bar
  total_rows_available <- get_total_count(dataset_id)

  if (is.na(total_rows_available)) {
    cli::cli_abort(
      "Could not retrieve total row count for {.val {dataset_id}}. The dataset may be unavailable."
    )
  }

  if (total_rows_available == 0) {
    cli::cli_warn("Dataset {.val {dataset_id}} has no rows.")
    return(tibble::tibble())
  }

  total_pages <- NA_integer_
  pages_to_fetch <- max_pages

  cli::cli_inform(c(
    "i" = "Total rows available : {total_rows_available}",
    "i" = "Pages to fetch       : {pages_to_fetch}"
  ))

  # initialise
  url <- build_url(dataset_id)
  all_data <- list()
  page <- 1
  total_rows <- 0

  cli::cli_progress_bar(
    name = "Fetching data",
    type = "iterator",
    total = if (is.finite(max_pages)) max_pages else NA,
    format = paste0(
      "{cli::pb_spin} Page {page} | ",
      "Rows: {total_rows}/{total_rows_available} | ",
      "{cli::pb_percent} | {cli::pb_elapsed}"
    )
  )

  repeat {
    result <- make_request(url)
    all_data <- c(all_data, list(result$data))
    total_rows <- total_rows + nrow(result$data)

    cli::cli_progress_update(set = page)

    if (is.null(result$next_url) || page >= max_pages) {
      break
    }

    url <- result$next_url
    page <- page + 1
  }

  cli::cli_progress_done()

  # final message
  if (!is.null(result$next_url) && page >= max_pages) {
    cli::cli_warn(c(
      "!" = "Stopped after {page} page{?s}.",
      "i" = "Rows retrieved : {total_rows} of {total_rows_available}",
      "i" = "Use {.code max_pages = Inf} to fetch all."
    ))
  } else {
    cli::cli_inform(c(
      "v" = "Done. {total_rows} of {total_rows_available} rows retrieved in {page} page{?s}."
    ))
  }

  dplyr::bind_rows(all_data) |>
    tibble::as_tibble()
}
