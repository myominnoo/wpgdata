# Changelog

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

- [`peg_get()`](https://myominnoo.github.io/wpgdata/reference/peg_get.md)
  — fetch the first page of a dataset
- [`peg_query()`](https://myominnoo.github.io/wpgdata/reference/peg_query.md)
  — filter, select, sort and paginate datasets
- [`peg_all()`](https://myominnoo.github.io/wpgdata/reference/peg_all.md)
  — download all rows with automatic pagination
- [`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md)
  — retrieve column names and types
- [`peg_info()`](https://myominnoo.github.io/wpgdata/reference/peg_info.md)
  — retrieve dataset-level information
- Supports both R expressions and raw OData strings in
  [`peg_query()`](https://myominnoo.github.io/wpgdata/reference/peg_query.md)
- Automatic pagination detection and progress bar in
  [`peg_all()`](https://myominnoo.github.io/wpgdata/reference/peg_all.md)
