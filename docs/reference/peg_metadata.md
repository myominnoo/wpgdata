# Get column names and types for a Winnipeg Open Data dataset

Get column names and types for a Winnipeg Open Data dataset

## Usage

``` r
peg_metadata(dataset_id)
```

## Arguments

- dataset_id:

  A character string of the dataset ID e.g. `"d4mq-wa44"`

## Value

A tibble with columns `name`, `field_name`, `type`, and `description`.
Use `field_name` values in `peg_query()` for filtering and selecting
columns.

## Examples

``` r
if (FALSE) { # \dontrun{
# look up field names before querying
peg_metadata("d4mq-wa44")
} # }
```
