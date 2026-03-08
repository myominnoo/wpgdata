#' Query a dataset from the Winnipeg Open Data Portal
#'
#' @param dataset_id A character string of the dataset ID e.g. `"d4mq-wa44"`
#' @param filter A filter expression, either a raw OData string
#'   e.g. `"total_assessed_value gt 500000"` or an R expression
#'   e.g. `total_assessed_value > 500000`. Use [wpgdata::peg_metadata()] to find
#'   valid field names.
#' @param select A character vector of field names to return
#'   e.g. `c("roll_number", "total_assessed_value")`
#' @param top An integer specifying the maximum number of rows to return
#' @param skip An integer specifying the number of rows to skip
#' @param orderby A character string specifying the field to sort by
#'   e.g. `"total_assessed_value desc"` or `"total_assessed_value asc"`
#'
#' @return A tibble of the queried dataset
#' @export
#'
#' @examples
#' \dontrun{
#' # use peg_metadata() first to find valid field names
#' peg_metadata("d4mq-wa44")
#'
#' # R expression filter
#' peg_query("d4mq-wa44", filter = total_assessed_value > 500000)
#'
#' # raw OData filter string
#' peg_query("d4mq-wa44", filter = "total_assessed_value gt 500000")
#'
#' # select specific columns
#' peg_query("d4mq-wa44", select = c("roll_number", "total_assessed_value"))
#'
#' # combine filter, select, orderby
#' peg_query("d4mq-wa44",
#'   filter  = total_assessed_value > 500000,
#'   select  = c("roll_number", "total_assessed_value"),
#'   orderby = "total_assessed_value desc",
#'   top     = 100
#' )
#'
#' # skip first 500 rows
#' peg_query("d4mq-wa44", skip = 500, top = 100)
#' }
peg_query <- function(
  dataset_id,
  filter = NULL,
  select = NULL,
  top = NULL,
  skip = NULL,
  orderby = NULL
) {
  params <- list()

  if (!is.null(substitute(filter))) {
    filter_expr <- rlang::enexpr(filter)
    params[["filter"]] <- build_filter(filter_expr)
  }

  if (!is.null(select)) {
    if (!is.character(select)) {
      cli::cli_abort(
        "{.arg select} must be a character vector of column names."
      )
    }
    params[["select"]] <- paste(select, collapse = ",")
  }

  if (!is.null(top)) {
    if (!is.numeric(top) || top < 1) {
      cli::cli_abort("{.arg top} must be a positive integer.")
    }
    params[["top"]] <- as.integer(top)
  }

  if (!is.null(skip)) {
    if (!is.numeric(skip) || skip < 0) {
      cli::cli_abort("{.arg skip} must be a non-negative integer.")
    }
    params[["skip"]] <- as.integer(skip)
  }

  if (!is.null(orderby)) {
    if (!is.character(orderby)) {
      cli::cli_abort(
        "{.arg orderby} must be a character string e.g. {.val total_assessed_value desc}."
      )
    }
    params[["orderby"]] <- orderby
  }

  url <- build_url(dataset_id, params = params)
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
