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
