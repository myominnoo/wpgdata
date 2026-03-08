# Get all rows from a Winnipeg Open Data Portal dataset

Automatically paginates through all pages of a dataset using
`@odata.nextLink`. For large datasets, use `max_pages` to cap the number
of pages fetched.

## Usage

``` r
peg_all(dataset_id, max_pages = 10)
```

## Arguments

- dataset_id:

  A character string of the dataset ID e.g. `"d4mq-wa44"`

- max_pages:

  An integer specifying the maximum number of pages to fetch. Defaults
  to `10`. Set to `Inf` to fetch all pages with no limit.

## Value

A tibble of all rows retrieved

## Examples

``` r
if (FALSE) { # \dontrun{
# fetch with default safety cap of 10 pages
peg_all("d4mq-wa44")

# fetch all rows with no limit
peg_all("d4mq-wa44", max_pages = Inf)

# fetch up to 3 pages
peg_all("d4mq-wa44", max_pages = 3)
} # }
```
