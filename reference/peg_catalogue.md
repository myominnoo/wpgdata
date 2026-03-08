# List all datasets from the Winnipeg Open Data Portal

Retrieves a catalogue of all publicly available datasets from the City
of Winnipeg Open Data Portal (data.winnipeg.ca) using the Socrata
Discovery API.

## Usage

``` r
peg_catalogue(limit = 200)
```

## Arguments

- limit:

  An integer specifying the maximum number of datasets to return.
  Defaults to `200`. Set to `NULL` to fetch all available datasets.

## Value

A tibble with one row per dataset containing:

- name:

  Dataset name

- id:

  Dataset ID — use this in
  [`peg_get()`](https://myominnoo.github.io/wpgdata/reference/peg_get.md),
  [`peg_query()`](https://myominnoo.github.io/wpgdata/reference/peg_query.md),
  [`peg_all()`](https://myominnoo.github.io/wpgdata/reference/peg_all.md),
  [`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md),
  and
  [`peg_info()`](https://myominnoo.github.io/wpgdata/reference/peg_info.md)

- description:

  Dataset description

- category:

  Dataset category

- updated_at:

  Date and time of last update

- row_count:

  Number of downloads

- url:

  Direct URL to the dataset on data.winnipeg.ca

## Examples

``` r
if (FALSE) { # \dontrun{
# list all available datasets
peg_catalogue()

# fetch everything
peg_catalogue(limit = NULL)

# find datasets by category
library(dplyr)
peg_catalogue() |>
  filter(category == "Transportation")

# search by name
peg_catalogue() |>
  filter(grepl("assessment", name, ignore.case = TRUE))

# count datasets by category
peg_catalogue() |>
  count(category, sort = TRUE)
} # }
```
