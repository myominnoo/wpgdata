# Fetch data from the Winnipeg Open Data Portal

A unified replacement for `peg_get()`, `peg_query()`, and `peg_all()`.
Pages are fetched **in parallel** for maximum throughput.

## Usage

``` r
peg_data(
  dataset_id,
  filter = NULL,
  select = NULL,
  top = NULL,
  skip = NULL,
  orderby = NULL,
  max_connections = NULL
)
```

## Arguments

- dataset_id:

  A character string dataset ID e.g. `"d4mq-wa44"`.

- filter:

  A filter expression — either an R expression such as
  `total_assessed_value > 500000`, or a raw OData string such as
  `"total_assessed_value gt 500000"`. Use
  [`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md)
  to look up valid field names.

- select:

  A character vector of field names to return, e.g.
  `c("roll_number", "total_assessed_value")`.

- top:

  A positive integer — the maximum number of rows to return. When `NULL`
  (the default) every row is fetched.

- skip:

  A non-negative integer — rows to skip before collecting results.

- orderby:

  A character string specifying sort order, e.g.
  `"total_assessed_value desc"`.

- max_connections:

  A positive integer controlling how many HTTP requests are in-flight at
  once. When `NULL` (the default), the value is auto-detected as
  `2 * parallel::detectCores()`, capped at `.MAX_CONNECTIONS` (20) and
  at the number of pages required. Supply an explicit value to override
  — lower if the server rate-limits, higher if you have headroom.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with the requested rows in their original order.

## Details

How it works:

1.  Fires the `$count` request and the first data page
    **simultaneously**, saving one full round trip before the main fetch
    begins.

2.  Pre-computes every remaining page URL from `$skip` offsets — no
    `nextLink` chaining required.

3.  Fires all remaining requests via
    [`httr2::req_perform_parallel()`](https://httr2.r-lib.org/reference/req_perform_parallel.html)
    with `max_active` throttling. curl starts the next request the
    instant any slot frees, avoiding the convoy delay of manual
    batching.

4.  Binds pages in their original order and trims to `top`.

## Examples

``` r
if (FALSE) { # \dontrun{
# fetch every row
peg_data("d4mq-wa44")

# fetch the first 500 rows
peg_data("d4mq-wa44", top = 500)

# filter + select + sort, fetch all matching rows
peg_data(
  "d4mq-wa44",
  filter  = total_assessed_value > 500000,
  select  = c("roll_number", "total_assessed_value"),
  orderby = "total_assessed_value desc"
)

# override connection count
peg_data("d4mq-wa44", max_connections = 4L)
} # }
```
