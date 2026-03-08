# wpgdata 0.1.0

## Initial release

* `peg_get()` — fetch the first page of a dataset
* `peg_query()` — filter, select, sort and paginate datasets
* `peg_all()` — download all rows with automatic pagination
* `peg_metadata()` — retrieve column names and types
* `peg_info()` — retrieve dataset-level information
* Supports both R expressions and raw OData strings in `peg_query()`
* Automatic pagination detection and progress bar in `peg_all()`