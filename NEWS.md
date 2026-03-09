# wpgdata 0.3.0 (development version)

## `peg_catalogue()`

* Completely overhauled catalogue fetching. Metadata is now sourced from the
  `/api/views/{id}.json` endpoint per dataset, replacing the Socrata Discovery
  API as the sole data source.
* Catalogue pages are now fetched in parallel using `httr2::req_perform_parallel()`.
* Added new columns: `row_count`, `col_count`, `view_count`, `group`,
  `department`, `update_frequency`, `quality_rank`, `license`, `license_link`,
  `tags`, `license_id`, `rows_updated_at`, `view_last_modified`,
  `publication_date`, `index_updated_at`.
* `row_count` is now sourced from cached column statistics (`cachedContents`),
  making it fast without requiring a separate OData count request.
* Removed `limit` default of `200` — function now fetches all datasets by default.
* Results are sorted by `rows_updated_at` descending.
* Improved error handling: HTTP errors and network failures per dataset are
  caught individually and skipped with a warning rather than aborting the full
  fetch.



# wpgdata 0.2.0

## New functions

* `peg_catalogue()` — list all datasets available on the City of Winnipeg
  Open Data Portal with name, ID, category, and last updated date.

## Internal changes

* Added `get_catalogue_count()`, `fetch_catalogue_page()`, and 
  `parse_catalogue()` internal helpers to `utils.R`.
* Imported `rlang::.data` pronoun to suppress R CMD check notes in 
  `dplyr::mutate()` calls.


# wpgdata 0.1.0

## Initial release

* `peg_get()` — fetch the first page of a dataset
* `peg_query()` — filter, select, sort and paginate datasets
* `peg_all()` — download all rows with automatic pagination
* `peg_metadata()` — retrieve column names and types
* `peg_info()` — retrieve dataset-level information
* Supports both R expressions and raw OData strings in `peg_query()`
* Automatic pagination detection and progress bar in `peg_all()`
