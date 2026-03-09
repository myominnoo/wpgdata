# List all datasets from the Winnipeg Open Data Portal

Retrieves a catalogue of all publicly available datasets from the City
of Winnipeg Open Data Portal (data.winnipeg.ca) using the Socrata
Discovery API. Metadata is fetched in parallel via the `/api/views`
endpoint for each dataset.

## Usage

``` r
peg_catalogue(limit = NULL)
```

## Arguments

- limit:

  An integer specifying the maximum number of datasets to return. Set to
  `NULL` to fetch all available datasets.

## Value

A tibble with one row per dataset containing:

- id:

  Dataset ID — use this in
  [`peg_get()`](https://myominnoo.github.io/wpgdata/reference/peg_get.md),
  [`peg_query()`](https://myominnoo.github.io/wpgdata/reference/peg_query.md),
  [`peg_all()`](https://myominnoo.github.io/wpgdata/reference/peg_all.md),
  [`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md),
  and
  [`peg_info()`](https://myominnoo.github.io/wpgdata/reference/peg_info.md)

- name:

  Dataset name

- description:

  Dataset description

- category:

  Dataset category, defaults to `"Uncategorized"` if missing

- license_id:

  License identifier (e.g. `"OGL_CANADA"`)

- created_at:

  Date the dataset was first created

- rows_updated_at:

  Date the data was last updated. Results are sorted descending by this
  field

- view_last_modified:

  Date the view definition was last modified

- publication_date:

  Date the dataset was published

- index_updated_at:

  Date the search index was last updated

- row_count:

  Number of rows, sourced from cached column statistics

- col_count:

  Number of columns

- download_count:

  Total number of downloads

- view_count:

  Total number of page views

- group:

  Departmental group responsible for the dataset

- department:

  City department responsible for the dataset

- update_frequency:

  How often the dataset is refreshed (e.g. `"Daily"`)

- quality_rank:

  Data quality rank assigned by the portal (e.g. `"Gold"`)

- license:

  Full license name (e.g. `"Canada Open Government Licence"`)

- license_link:

  URL to the full license terms

- tags:

  List-column of keyword tags associated with the dataset

- url:

  Direct URL to the dataset on data.winnipeg.ca

## Examples

``` r
if (FALSE) { # \dontrun{
# list all available datasets
peg_catalogue()

# find datasets by category
library(dplyr)
peg_catalogue() |>
  dplyr::filter(category == "Transportation")

# search by name
peg_catalogue() |>
  dplyr::filter(grepl("assessment", name, ignore.case = TRUE))

# count datasets by category
peg_catalogue() |>
  dplyr::count(category, sort = TRUE)

# find recently updated datasets
peg_catalogue() |>
  dplyr::filter(rows_updated_at >= Sys.Date() - 30)

# find the largest datasets by row count
peg_catalogue() |>
  dplyr::arrange(dplyr::desc(row_count))

# filter by department
peg_catalogue() |>
  dplyr::filter(department == "Customer Service & Communications")
} # }
```
