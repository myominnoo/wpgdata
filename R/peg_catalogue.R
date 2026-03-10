# -----------------------------------------------------------------------------
# 1. Main function
# -----------------------------------------------------------------------------

#' List all datasets from the Winnipeg Open Data Portal
#'
#' Retrieves a catalogue of all publicly available datasets from the
#' City of Winnipeg Open Data Portal (data.winnipeg.ca) using the
#' Socrata Discovery API. Metadata is fetched in parallel via the
#' `/api/views` endpoint for each dataset.
#'
#' @param limit An integer specifying the maximum number of datasets to
#'   return. Set to `NULL` to fetch all available datasets.
#' @param max_active An integer controlling how many parallel connections
#'   are open at once during metadata fetching. Defaults to 20. Lower this
#'   if the portal rate-limits aggressively.
#'
#' @return A tibble with one row per dataset.
#' @export
peg_catalogue <- function(limit = NULL, max_active = .MAX_ACTIVE) {
  # [1] input validation
  if (!is.null(limit) && (!is.numeric(limit) || limit < 1)) {
    cli::cli_abort("{.arg limit} must be a positive integer or {.val NULL}.")
  }
  if (!is.numeric(max_active) || max_active < 1) {
    cli::cli_abort("{.arg max_active} must be a positive integer.")
  }

  cli::cli_inform("Fetching Winnipeg Open Data catalogue...")

  total <- get_catalogue_count()
  n_fetch <- if (is.null(limit)) total else min(limit, total)

  cli::cli_inform(c(
    "i" = "Total datasets available: {total}",
    "i" = "Fetching                : {n_fetch}"
  ))

  # stage 1 — fetch all catalogue pages in parallel
  all_ids <- build_catalogue_requests(n_fetch) |>
    httr2::req_perform_parallel(
      on_error = "continue",
      progress = TRUE,
      max_active = max_active # [P6] exposed to caller
    ) |>
    extract_ids_from_pages()

  # [1] abort early if stage 1 yielded nothing — avoids firing 0 metadata reqs
  if (length(all_ids) == 0) {
    cli::cli_abort(c(
      "x" = "No dataset IDs could be retrieved from the catalogue.",
      "i" = "All catalogue page requests may have failed. Try again later."
    ))
  }

  # stage 2 — fetch all metadata in one parallel batch
  result <- fetch_metadata_parallel(all_ids, max_active = max_active) |> # [P4/P6]
    dplyr::mutate(
      url = paste0(.WINNIPEG_URL, "/d/", .data$id),
      category = dplyr::coalesce(.data$category, "Uncategorized")
    ) |>
    dplyr::arrange(dplyr::desc(.data$rows_updated_at))

  cli::cli_inform(c(
    "v" = "Found {nrow(result)} dataset{?s} across {dplyr::n_distinct(result$category)} categor{?y/ies}."
  ))

  result
}
