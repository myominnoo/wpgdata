#' List all datasets from the Winnipeg Open Data Portal
#'
#' Retrieves a catalogue of all publicly available datasets from the
#' City of Winnipeg Open Data Portal (data.winnipeg.ca) using the
#' Socrata Discovery API.
#'
#' @param limit An integer specifying the maximum number of datasets to
#'   return. Defaults to `200`. Set to `NULL` to fetch all available
#'   datasets.
#'
#' @return A tibble with one row per dataset containing:
#'   \describe{
#'     \item{name}{Dataset name}
#'     \item{id}{Dataset ID — use this in [wpgdata::peg_get()],
#'       [wpgdata::peg_query()], [wpgdata::peg_all()],
#'       [wpgdata::peg_metadata()], and [wpgdata::peg_info()]}
#'     \item{description}{Dataset description}
#'     \item{category}{Dataset category}
#'     \item{updated_at}{Date and time of last update}
#'     \item{row_count}{Number of downloads}
#'     \item{url}{Direct URL to the dataset on data.winnipeg.ca}
#'   }
#' @export
#'
#' @examples
#' \dontrun{
#' # list all available datasets
#' peg_catalogue()
#'
#' # fetch everything
#' peg_catalogue(limit = NULL)
#'
#' # find datasets by category
#' library(dplyr)
#' peg_catalogue() |>
#'   filter(category == "Transportation")
#'
#' # search by name
#' peg_catalogue() |>
#'   filter(grepl("assessment", name, ignore.case = TRUE))
#'
#' # count datasets by category
#' peg_catalogue() |>
#'   count(category, sort = TRUE)
#' }
peg_catalogue <- function(limit = 200) {
  if (!is.null(limit) && (!is.numeric(limit) || limit < 1)) {
    cli::cli_abort(
      "{.arg limit} must be a positive integer or {.val NULL} to fetch all."
    )
  }

  cli::cli_inform("Fetching Winnipeg Open Data catalogue...")

  total <- get_catalogue_count()
  n_fetch <- if (is.null(limit)) total else min(limit, total)

  cli::cli_inform(c(
    "i" = "Total datasets available: {total}",
    "i" = "Fetching              : {n_fetch}"
  ))

  page_size <- 100L
  offsets <- seq(0, n_fetch - 1, by = page_size)

  result <- offsets |>
    purrr::map(\(offset) {
      fetch_catalogue_page(
        offset = offset,
        limit = min(page_size, n_fetch - offset)
      )
    }) |>
    purrr::list_rbind()

  cli::cli_inform(c(
    "v" = "Found {nrow(result)} dataset{?s} across {dplyr::n_distinct(result$category)} categor{?y/ies}."
  ))

  result
}
