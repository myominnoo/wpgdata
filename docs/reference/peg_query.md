# Query a dataset from the Winnipeg Open Data Portal

Query a dataset from the Winnipeg Open Data Portal

## Usage

``` r
peg_query(
  dataset_id,
  filter = NULL,
  select = NULL,
  top = NULL,
  skip = NULL,
  orderby = NULL
)
```

## Arguments

- dataset_id:

  A character string of the dataset ID e.g. `"d4mq-wa44"`

- filter:

  A filter expression, either a raw OData string e.g.
  `"total_assessed_value gt 500000"` or an R expression e.g.
  `total_assessed_value > 500000`. Use
  [`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md)
  to find valid field names.

- select:

  A character vector of field names to return e.g.
  `c("roll_number", "total_assessed_value")`

- top:

  An integer specifying the maximum number of rows to return

- skip:

  An integer specifying the number of rows to skip

- orderby:

  A character string specifying the field to sort by e.g.
  `"total_assessed_value desc"` or `"total_assessed_value asc"`

## Value

A tibble of the queried dataset

## Examples

``` r
if (FALSE) { # \dontrun{
# use peg_metadata() first to find valid field names
peg_metadata("d4mq-wa44")

# R expression filter
peg_query("d4mq-wa44", filter = total_assessed_value > 500000)

# raw OData filter string
peg_query("d4mq-wa44", filter = "total_assessed_value gt 500000")

# select specific columns
peg_query("d4mq-wa44", select = c("roll_number", "total_assessed_value"))

# combine filter, select, orderby
peg_query("d4mq-wa44",
  filter  = total_assessed_value > 500000,
  select  = c("roll_number", "total_assessed_value"),
  orderby = "total_assessed_value desc",
  top     = 100
)

# skip first 500 rows
peg_query("d4mq-wa44", skip = 500, top = 100)
} # }
```
