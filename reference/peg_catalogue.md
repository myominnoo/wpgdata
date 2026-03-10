# List all datasets from the Winnipeg Open Data Portal

Retrieves a catalogue of all publicly available datasets from
data.winnipeg.ca using the Socrata Discovery API. Both catalogue pages
and per-dataset metadata are fetched in parallel for maximum throughput.

## Usage

``` r
peg_catalogue(limit = NULL, max_connections = NULL)
```

## Arguments

- limit:

  A positive integer — the maximum number of datasets to return. When
  `NULL` (the default) every available dataset is fetched.

- max_connections:

  A positive integer controlling how many HTTP requests are in-flight at
  once. When `NULL` (the default), the value is auto-detected as
  `2 * parallel::detectCores()`, capped at `.MAX_CONNECTIONS` (20) and
  at the number of requests needed. Supply an explicit value to override
  — lower if the portal rate-limits, higher if you have headroom.

## Value

A tibble with one row per dataset, arranged by most recently updated.

## Details

How it works:

1.  Fires the catalogue count request and the first catalogue page
    **simultaneously** to save one round trip.

2.  Pre-computes all remaining page URLs from known offsets and fetches
    them in parallel (no sequential `nextLink` chaining).

3.  Extracts dataset IDs from all pages, then fires all metadata
    requests in a single parallel batch via the `/api/views` endpoint.
