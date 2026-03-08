# Get dataset-level information from the Winnipeg Open Data Portal

Get dataset-level information from the Winnipeg Open Data Portal

## Usage

``` r
peg_info(dataset_id)
```

## Arguments

- dataset_id:

  A character string of the dataset ID e.g. `"d4mq-wa44"`

## Value

A tibble with one row containing dataset-level metadata including name,
description, category, timestamps, counts, tags, license, and
provenance.

## Examples

``` r
if (FALSE) { # \dontrun{
peg_info("d4mq-wa44")
} # }
```
