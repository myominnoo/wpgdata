# Changelog

## wpgdata 0.3.0 (development version)

### Breaking changes

- `peg_get()`, `peg_query()`, and `peg_all()` have been removed and
  consolidated into a single
  [`peg_data()`](https://myominnoo.github.io/wpgdata/reference/peg_data.md)
  function. Update existing code:
  - `peg_get("id")` → `peg_data("id")`
  - `peg_query("id", filter = x > 1, select = "col")` →
    `peg_data("id", filter = x > 1, select = "col")`
  - `peg_all("id")` → `peg_data("id")`

### New functions

- [`peg_data()`](https://myominnoo.github.io/wpgdata/reference/peg_data.md)
  — replaces `peg_get()`, `peg_query()`, and `peg_all()` with a unified
  interface for fetching dataset rows. Supports server-side filtering,
  column selection, row ordering, and offset pagination via `top` and
  `skip`. All pages are fetched in parallel using
  [`httr2::req_perform_parallel()`](https://httr2.r-lib.org/reference/req_perform_parallel.html),
  delivering significant throughput improvements over the previous
  sequential approach.

### `peg_catalogue()`

- Catalogue pages and per-dataset metadata are now fetched in parallel
  using
  [`httr2::req_perform_parallel()`](https://httr2.r-lib.org/reference/req_perform_parallel.html),
  with the count request and first page fired simultaneously to save a
  full round trip.
- Metadata is now sourced from the `/api/views/{id}.json` endpoint per
  dataset, replacing the Socrata Discovery API as the sole data source.
- Added new columns: `row_count`, `col_count`, `view_count`, `group`,
  `department`, `update_frequency`, `quality_rank`, `license`,
  `license_link`, `tags`, `license_id`, `rows_updated_at`,
  `view_last_modified`, `publication_date`, `index_updated_at`.
- `row_count` is now sourced from cached column statistics
  (`cachedContents`), making it fast without requiring a separate OData
  count request per dataset.
- Removed the default `limit` of 200 — all available datasets are
  fetched by default.
- Results are sorted by `rows_updated_at` descending.
- HTTP errors and network failures for individual datasets are caught
  and skipped with a warning rather than aborting the entire fetch.

### `peg_info()`

- Added input validation for `dataset_id` (rejects `NULL`, `NA`, empty
  string, non-character, and length \> 1).
- Added
  [`httr2::req_timeout()`](https://httr2.r-lib.org/reference/req_timeout.html)
  and
  [`httr2::req_retry()`](https://httr2.r-lib.org/reference/req_retry.html)
  with exponential backoff for transient 429, 500, and 503 responses.
- Fixed double-read of the response body; the empty-body check is now
  handled by a single `tryCatch` around `resp_body_json()`.

### `peg_metadata()`

- Added input validation for `dataset_id` matching
  [`peg_info()`](https://myominnoo.github.io/wpgdata/reference/peg_info.md).
- Added
  [`httr2::req_timeout()`](https://httr2.r-lib.org/reference/req_timeout.html)
  and
  [`httr2::req_retry()`](https://httr2.r-lib.org/reference/req_retry.html)
  with exponential backoff for transient 429, 500, and 503 responses.
- Fixed double-read of the response body.
- Added `%||% NA_character_` fallbacks for `name`, `field_name`, and
  `type` — previously these would silently insert `NULL` for malformed
  column entries.
- Replaced soft-deprecated
  [`purrr::map_dfr()`](https://purrr.tidyverse.org/reference/map_dfr.html)
  with
  [`purrr::map()`](https://purrr.tidyverse.org/reference/map.html) +
  [`purrr::list_rbind()`](https://purrr.tidyverse.org/reference/list_c.html).

## wpgdata 0.2.0

### New functions

- [`peg_catalogue()`](https://myominnoo.github.io/wpgdata/reference/peg_catalogue.md)
  — list all datasets available on the City of Winnipeg Open Data Portal
  with name, ID, category, and last updated date.

### Internal changes

- Added `get_catalogue_count()`, `fetch_catalogue_page()`, and
  `parse_catalogue()` internal helpers to `utils.R`.
- Imported
  [`rlang::.data`](https://rlang.r-lib.org/reference/dot-data.html)
  pronoun to suppress R CMD check notes in
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
  calls.

## wpgdata 0.1.0

### Initial release

- `peg_get()` — fetch the first page of a dataset.
- `peg_query()` — filter, select, sort, and paginate datasets.
- `peg_all()` — download all rows with automatic pagination.
- [`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md)
  — retrieve column names and types.
- [`peg_info()`](https://myominnoo.github.io/wpgdata/reference/peg_info.md)
  — retrieve dataset-level information.
- Supports both R expressions and raw OData strings in `peg_query()`.
- Automatic pagination detection and progress reporting in `peg_all()`.
