#' List all datasets from the Winnipeg Open Data Portal
#'
#' Retrieves a catalogue of all publicly available datasets from the
#' City of Winnipeg Open Data Portal (data.winnipeg.ca) using the
#' Socrata Discovery API. Metadata is fetched in parallel via the
#' `/api/views` endpoint for each dataset.
#'
#' @param limit An integer specifying the maximum number of datasets to
#'   return. Set to `NULL` to fetch all available datasets.
#'
#' @return A tibble with one row per dataset containing:
#'   \describe{
#'     \item{id}{Dataset ID — use this in [wpgdata::peg_get()],
#'       [wpgdata::peg_query()], [wpgdata::peg_all()],
#'       [wpgdata::peg_metadata()], and [wpgdata::peg_info()]}
#'     \item{name}{Dataset name}
#'     \item{description}{Dataset description}
#'     \item{category}{Dataset category, defaults to `"Uncategorized"` if missing}
#'     \item{license_id}{License identifier (e.g. `"OGL_CANADA"`)}
#'     \item{created_at}{Date the dataset was first created}
#'     \item{rows_updated_at}{Date the data was last updated. Results are
#'       sorted descending by this field}
#'     \item{view_last_modified}{Date the view definition was last modified}
#'     \item{publication_date}{Date the dataset was published}
#'     \item{index_updated_at}{Date the search index was last updated}
#'     \item{row_count}{Number of rows, sourced from cached column statistics}
#'     \item{col_count}{Number of columns}
#'     \item{download_count}{Total number of downloads}
#'     \item{view_count}{Total number of page views}
#'     \item{group}{Departmental group responsible for the dataset}
#'     \item{department}{City department responsible for the dataset}
#'     \item{update_frequency}{How often the dataset is refreshed (e.g. `"Daily"`)}
#'     \item{quality_rank}{Data quality rank assigned by the portal (e.g. `"Gold"`)}
#'     \item{license}{Full license name (e.g. `"Canada Open Government Licence"`)}
#'     \item{license_link}{URL to the full license terms}
#'     \item{tags}{List-column of keyword tags associated with the dataset}
#'     \item{url}{Direct URL to the dataset on data.winnipeg.ca}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # list all available datasets
#' peg_catalogue()
#'
#' # find datasets by category
#' library(dplyr)
#' peg_catalogue() |>
#'   dplyr::filter(category == "Transportation")
#'
#' # search by name
#' peg_catalogue() |>
#'   dplyr::filter(grepl("assessment", name, ignore.case = TRUE))
#'
#' # count datasets by category
#' peg_catalogue() |>
#'   dplyr::count(category, sort = TRUE)
#'
#' # find recently updated datasets
#' peg_catalogue() |>
#'   dplyr::filter(rows_updated_at >= Sys.Date() - 30)
#'
#' # find the largest datasets by row count
#' peg_catalogue() |>
#'   dplyr::arrange(dplyr::desc(row_count))
#'
#' # filter by department
#' peg_catalogue() |>
#'   dplyr::filter(department == "Customer Service & Communications")
#' }
peg_catalogue <- function(limit = NULL) {
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
