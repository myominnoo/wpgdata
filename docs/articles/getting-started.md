# Getting Started with wpgdata

## Introduction

`wpgdata` provides a tidy R interface to the [City of Winnipeg Open Data
Portal](https://data.winnipeg.ca). Discover available datasets, inspect
their schemas, and download records with automatic parallel pagination —
all via the Socrata OData V4 and Discovery APIs.

This vignette walks through the four core functions using the Assessment
Parcels dataset (`d4mq-wa44`) as the primary working example, with
additional examples using the 311 Service Requests dataset (`u7f6-5326`)
to demonstrate date filtering on large datasets.

``` r
library(wpgdata)
library(dplyr)
```

------------------------------------------------------------------------

## Workflow overview

The typical `wpgdata` workflow follows four steps:

![](README-pipeline.svg)

| Function | Purpose |
|----|----|
| [`peg_catalogue()`](https://myominnoo.github.io/wpgdata/reference/peg_catalogue.md) | Browse all available datasets and find IDs |
| [`peg_info()`](https://myominnoo.github.io/wpgdata/reference/peg_info.md) | Explore a specific dataset |
| [`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md) | Find field names before querying |
| [`peg_data()`](https://myominnoo.github.io/wpgdata/reference/peg_data.md) | Filter, select, sort, and download rows |

------------------------------------------------------------------------

## Step 1 — Find datasets with `peg_catalogue()`

[`peg_catalogue()`](https://myominnoo.github.io/wpgdata/reference/peg_catalogue.md)
retrieves every published dataset from the portal. Both catalogue pages
and per-dataset metadata are fetched in parallel, so the full catalogue
arrives quickly regardless of size.

``` r
catalogue <- peg_catalogue()
catalogue
#> # A tibble: 217 × 22
#>    id        name     description category license_id created_at rows_updated_at
#>    <chr>     <chr>    <chr>       <chr>    <chr>      <date>     <date>         
#>  1 d4mq-wa44 Assessm… "List of a… Assessm… OGL_CANADA 2017-08-23 2026-03-20     
#>  2 yg42-q284 WFPS Ca… "The data … Fire an… OGL_CANADA 2020-12-14 2026-03-20     
#>  3 iibp-28fx Burial … "Locations… Cemeter… OGL_CANADA 2016-01-29 2026-03-20     
#>  4 vrzk-mj7v 311 Cal… "Caller wa… Contact… OGL_CANADA 2022-06-17 2026-03-20     
#>  5 gnxp-9hpt Public … "Public No… Develop… NA         2016-08-08 2026-03-20     
#>  6 tix9-r5tc Plow Zo… "Scheduled… City Pl… NA         2016-10-18 2026-03-20     
#>  7 8xrn-n992 Capital… "The Capit… Assessm… NA         2015-12-01 2026-03-20     
#>  8 du7c-8488 Daily A… "The data … Insect … NA         2016-05-04 2026-03-20     
#>  9 pfbi-rm6v FIPPA R… "The Freed… Organiz… OGL_CANADA 2019-09-10 2026-03-20     
#> 10 tgrf-v2zc River W… "Record of… Water a… OGL_CANADA 2018-03-15 2026-03-20     
#> # ℹ 207 more rows
#> # ℹ 15 more variables: view_last_modified <date>, publication_date <date>,
#> #   index_updated_at <date>, row_count <int>, col_count <int>,
#> #   download_count <int>, view_count <int>, group <chr>, department <chr>,
#> #   update_frequency <chr>, quality_rank <chr>, license <chr>,
#> #   license_link <chr>, tags <list>, url <chr>
```

Count datasets by category to get an overview of what’s available:

``` r
catalogue |>
  count(category, sort = TRUE)
#> # A tibble: 26 × 2
#>    category                                                   n
#>    <chr>                                                  <int>
#>  1 Census                                                    35
#>  2 City Planning                                             27
#>  3 Development Approvals, Building Permits, & Inspections    24
#>  4 Transportation Planning & Traffic Management              18
#>  5 Uncategorized                                             16
#>  6 Council Services                                          15
#>  7 Recreation                                                 9
#>  8 Organizational Support Services                            8
#>  9 Assessment, Taxation, & Corporate                          7
#> 10 Contact Centre - 311                                       7
#> # ℹ 16 more rows
```

Search by name to find a dataset and retrieve its ID:

``` r
catalogue |>
  filter(grepl("assessment", name, ignore.case = TRUE)) |>
  select(name, id, rows_updated_at)
#> # A tibble: 1 × 3
#>   name               id        rows_updated_at
#>   <chr>              <chr>     <date>         
#> 1 Assessment Parcels d4mq-wa44 2026-03-20
```

Use the `id` value in any other `peg_*` function:

``` r
dataset_id <- catalogue |>
  filter(name == "Assessment Parcels") |>
  pull(id)

dataset_id
#> [1] "d4mq-wa44"
```

Use `limit` to cap results while exploring:

``` r
peg_catalogue(limit = 10)
#> # A tibble: 10 × 22
#>    id        name     description category license_id created_at rows_updated_at
#>    <chr>     <chr>    <chr>       <chr>    <chr>      <date>     <date>         
#>  1 d4mq-wa44 Assessm… "List of a… Assessm… OGL_CANADA 2017-08-23 2026-03-20     
#>  2 yg42-q284 WFPS Ca… "The data … Fire an… OGL_CANADA 2020-12-14 2026-03-20     
#>  3 iibp-28fx Burial … "Locations… Cemeter… OGL_CANADA 2016-01-29 2026-03-20     
#>  4 vrzk-mj7v 311 Cal… "Caller wa… Contact… OGL_CANADA 2022-06-17 2026-03-20     
#>  5 gnxp-9hpt Public … "Public No… Develop… NA         2016-08-08 2026-03-20     
#>  6 6rcy-9uik Recycli… "Collectio… Water a… OGL_CANADA 2017-09-08 2026-03-16     
#>  7 hfwk-jp4h Tree In… "Detailed … Parks    OGL_CANADA 2017-08-22 2026-03-16     
#>  8 p5sy-gt7y Aggrega… "Aggregate… Develop… NA         2016-12-21 2026-03-16     
#>  9 it4w-cpf4 Detaile… "City of W… Develop… NA         2016-04-18 2026-03-01     
#> 10 4her-3th5 311 Ser… "This data… Contact… NA         2015-07-22 2025-04-15     
#> # ℹ 15 more variables: view_last_modified <date>, publication_date <date>,
#> #   index_updated_at <date>, row_count <int>, col_count <int>,
#> #   download_count <int>, view_count <int>, group <chr>, department <chr>,
#> #   update_frequency <chr>, quality_rank <chr>, license <chr>,
#> #   license_link <chr>, tags <list>, url <chr>
```

------------------------------------------------------------------------

## Step 2 — Explore a dataset with `peg_info()`

[`peg_info()`](https://myominnoo.github.io/wpgdata/reference/peg_info.md)
returns high-level metadata for a single dataset — name, description,
category, update frequency, row count, and license:

``` r
peg_info("d4mq-wa44")
#> # A tibble: 1 × 11
#>   name        description category created_at rows_updated_at view_last_modified
#>   <chr>       <chr>       <chr>    <date>     <date>          <date>            
#> 1 Assessment… List of al… Assessm… 2017-08-23 2026-03-20      2026-03-20        
#> # ℹ 5 more variables: view_count <int>, download_count <int>, tags <list>,
#> #   license <chr>, provenance <chr>
```

This is useful before committing to a large download: it tells you when
the data was last updated, how many rows to expect, and what license it
is published under.

------------------------------------------------------------------------

## Step 3 — Find field names with `peg_metadata()`

OData queries require exact field names. Use
[`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md)
to look up available fields and their types before writing any query:

``` r
meta <- peg_metadata("d4mq-wa44")
meta
#> # A tibble: 71 × 4
#>    name               field_name         type   description
#>    <chr>              <chr>              <chr>  <chr>      
#>  1 Roll Number        roll_number        text   NA         
#>  2 Street Number      street_number      number NA         
#>  3 Unit Number        unit_number        text   NA         
#>  4 Street Suffix      street_suffix      text   NA         
#>  5 Street Direction   street_direction   text   NA         
#>  6 Street Name        street_name        text   NA         
#>  7 Street Type        street_type        text   NA         
#>  8 Full Address       full_address       text   NA         
#>  9 Neighbourhood Area neighbourhood_area text   NA         
#> 10 Market Region      market_region      text   NA         
#> # ℹ 61 more rows
```

The `field_name` column contains the names to use in
[`peg_data()`](https://myominnoo.github.io/wpgdata/reference/peg_data.md).
The `type` column tells you whether a field is text, number, floating
timestamp, or another type — important for writing correct filter
expressions.

Find numeric fields only:

``` r
meta |>
  filter(type == "number")
#> # A tibble: 24 × 4
#>    name                            field_name                  type  description
#>    <chr>                           <chr>                       <chr> <chr>      
#>  1 Street Number                   street_number               numb… NA         
#>  2 Total Living Area               total_living_area           numb… In Square …
#>  3 Year Built                      year_built                  numb… NA         
#>  4 Rooms                           rooms                       numb… NA         
#>  5 Number Floors (Condo)           number_floors_condo         numb… NA         
#>  6 Assessed Land Area              assessed_land_area          numb… In Square …
#>  7 Water Frontage Measurement      water_frontage_measurement  numb… in Feet    
#>  8 Sewer Frontage Measurement      sewer_frontage_measurement  numb… In Feet    
#>  9 Total Assessed Value            total_assessed_value        numb… NA         
#> 10 Total Proposed Assessment Value total_proposed_assessment_… numb… NA         
#> # ℹ 14 more rows
```

Find timestamp fields (relevant for date filtering):

``` r
meta |>
  filter(type == "calendar_date")
#> # A tibble: 2 × 4
#>   name                     field_name               type          description
#>   <chr>                    <chr>                    <chr>         <chr>      
#> 1 Assessment Date          assessment_date          calendar_date ""         
#> 2 Proposed Assessment Date proposed_assessment_date calendar_date NA
```

------------------------------------------------------------------------

## Step 4 — Fetch data with `peg_data()`

[`peg_data()`](https://myominnoo.github.io/wpgdata/reference/peg_data.md)
is the single function for fetching rows. It supports server-side
filtering, column selection, sorting, and offset pagination. All pages
are fetched in parallel automatically — no manual pagination needed.

### Quick preview

Fetch a small sample to inspect structure before a larger query:

``` r
peg_data("d4mq-wa44", top = 5)
#> # A tibble: 5 × 72
#>   `__id`    roll_number street_number unit_number street_suffix street_direction
#>   <chr>     <chr>               <int> <chr>       <lgl>         <lgl>           
#> 1 row-fhe3… 01000001000          1636 NA          NA            NA              
#> 2 row-b7ye… 01000005500          1584 NA          NA            NA              
#> 3 row-8en9… 01000008000          1574 NA          NA            NA              
#> 4 row-8e6t… 01000008200          1550 NA          NA            NA              
#> 5 row-8j4b… 01000008400          1538 NA          NA            NA              
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <int>,
#> #   property_use_code <chr>, assessed_land_area <int>, …
```

### Filtering rows

Pass R expressions directly — `wpgdata` translates them to OData syntax:

``` r
peg_data("d4mq-wa44",
  filter = total_assessed_value > 1000000,
  top    = 10
)
#> # A tibble: 10 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <chr>       <chr>         <chr>           
#>  1 row-b7y… 01000005500          1584 NA          NA            NA              
#>  2 row-5zx… 01000013200          1520 NA          NA            NA              
#>  3 row-knr… 01000014500          1450 NA          NA            NA              
#>  4 row-vpp… 01000045500          1290 NA          NA            NA              
#>  5 row-8j8… 01000064000          1820 NA          NA            NA              
#>  6 row-mst… 01000067500          1916 NA          NA            NA              
#>  7 row-wq5… 01000067900          1892 NA          NA            NA              
#>  8 row-hfi… 01000092200          1700 NA          NA            NA              
#>  9 row-9rr… 01000096000          1720 NA          NA            NA              
#> 10 row-e9m… 01000306500          2424 NA          NA            NA              
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <lgl>,
#> #   property_use_code <chr>, assessed_land_area <int>, …
```

Or use raw OData strings if you prefer:

``` r
peg_data("d4mq-wa44",
  filter = "total_assessed_value gt 1000000",
  top    = 10
)
#> # A tibble: 10 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <chr>       <chr>         <chr>           
#>  1 row-b7y… 01000005500          1584 NA          NA            NA              
#>  2 row-5zx… 01000013200          1520 NA          NA            NA              
#>  3 row-knr… 01000014500          1450 NA          NA            NA              
#>  4 row-vpp… 01000045500          1290 NA          NA            NA              
#>  5 row-8j8… 01000064000          1820 NA          NA            NA              
#>  6 row-mst… 01000067500          1916 NA          NA            NA              
#>  7 row-wq5… 01000067900          1892 NA          NA            NA              
#>  8 row-hfi… 01000092200          1700 NA          NA            NA              
#>  9 row-9rr… 01000096000          1720 NA          NA            NA              
#> 10 row-e9m… 01000306500          2424 NA          NA            NA              
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <lgl>,
#> #   property_use_code <chr>, assessed_land_area <int>, …
```

Both approaches produce identical results.

### Compound filters

Combine conditions with `&` (AND) and `|` (OR):

``` r
peg_data("d4mq-wa44",
  filter = total_assessed_value > 1000000 & building_type == "TWO STOREY",
  top    = 10
)
#> # A tibble: 10 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <chr>       <lgl>         <chr>           
#>  1 row-b7y… 01000005500          1584 NA          NA            NA              
#>  2 row-5zx… 01000013200          1520 NA          NA            NA              
#>  3 row-knr… 01000014500          1450 NA          NA            NA              
#>  4 row-8j8… 01000064000          1820 NA          NA            NA              
#>  5 row-md5… 01000560000          3179 NA          NA            NA              
#>  6 row-x5m… 01000615000             3 NA          NA            NA              
#>  7 row-hrh… 01000615400            17 NA          NA            NA              
#>  8 row-2x2… 01000615800            31 NA          NA            NA              
#>  9 row-h9d… 01000617400            36 NA          NA            NA              
#> 10 row-fbt… 01000718800           400 NA          NA            NA              
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <lgl>,
#> #   property_use_code <chr>, assessed_land_area <int>, …
```

### Selecting columns

Use `select` to return only the columns you need — reduces transfer size
significantly on wide datasets:

``` r
peg_data("d4mq-wa44",
  select = c("roll_number", "full_address", "total_assessed_value",
             "building_type", "year_built"),
  top    = 10
)
#> # A tibble: 10 × 5
#>    roll_number full_address       building_type  year_built total_assessed_value
#>    <chr>       <chr>              <chr>               <int>                <int>
#>  1 01000001000 1636 MCCREARY ROAD ONE STOREY           1991               723000
#>  2 01000005500 1584 MCCREARY ROAD TWO STOREY           1991              1619000
#>  3 01000008000 1574 MCCREARY ROAD ONE STOREY           2007               570000
#>  4 01000008200 1550 MCCREARY ROAD ONE STOREY           1982               743000
#>  5 01000008400 1538 MCCREARY ROAD ONE STOREY           1970               577000
#>  6 01000008500 1536 MCCREARY ROAD 4 LEVEL SPLIT        1958               979000
#>  7 01000013200 1520 MCCREARY ROAD TWO STOREY           2021              1900000
#>  8 01000013300 1510 MCCREARY ROAD ONE & 1/2 STO…       2000               995000
#>  9 01000013600 1500 MCCREARY ROAD ONE & 1/2 STO…       1994               669000
#> 10 01000013700 1490 MCCREARY ROAD CABOVER              2008               882000
```

### Sorting results

Use `orderby` to sort ascending or descending:

``` r
peg_data("d4mq-wa44",
  select  = c("roll_number", "full_address", "total_assessed_value"),
  orderby = "total_assessed_value desc",
  top     = 10
)
#> # A tibble: 10 × 3
#>    roll_number full_address                total_assessed_value
#>    <chr>       <chr>                                      <int>
#>  1 13099071230 1485 PORTAGE AVENUE                    651316000
#>  2 03091643600 92 DYSART ROAD                         475244000
#>  3 08020955700 1225 ST MARY'S ROAD                    328848000
#>  4 13096152000 700 WILLIAM AVENUE                     262782000
#>  5 12092819100 10 KENNEDY STREET                      262044000
#>  6 12093468100 242 HARGRAVE STREET                    214972000
#>  7 06072082500 409 TACHE AVENUE                       206873000
#>  8 10006776045 555 STERLING LYON PARKWAY              200244000
#>  9 07055050000 T-35-2000 WELLINGTON AVENUE            180099000
#> 10 09010473150 1555 REGENT AVENUE W                   162335000
```

### Combining filter, select, and orderby

``` r
peg_data("d4mq-wa44",
  filter  = total_assessed_value > 1000000 & year_built > 2000,
  select  = c("roll_number", "full_address", "total_assessed_value",
              "building_type", "year_built"),
  orderby = "total_assessed_value desc",
  top     = 10
)
#> # A tibble: 10 × 5
#>    roll_number full_address        building_type year_built total_assessed_value
#>    <chr>       <chr>               <chr>              <int>                <int>
#>  1 10004062400 23 KERSLAKE PLACE   TWO STOREY          2006              4235000
#>  2 10003003000 137 HANDSART BOULE… TWO STOREY          2006              4077000
#>  3 10002999100 214 GRENFELL BOULE… TWO STOREY          2009              4054000
#>  4 10006777080 36 AVONLYNN COURT   ONE STOREY          2022              3905000
#>  5 12040844000 885 WELLINGTON CRE… TWO STOREY          2021              3855000
#>  6 10002760000 135 PARK BOULEVARD… TWO STOREY          2023              3643000
#>  7 01002770500 70 RIDGEDALE CRESC… TWO STOREY          2024              3486000
#>  8 10002884000 130 HANDSART BOULE… TWO STOREY          2020              3386000
#>  9 10006776560 124 GRENFELL BOULE… TWO STOREY          2017              3335000
#> 10 10003006000 123 HANDSART BOULE… TWO STOREY          2005              3304000
```

### Pagination with `skip`

Use `skip` and `top` together to retrieve a specific slice of rows:

``` r
# rows 1–5
page_1 <- peg_data("d4mq-wa44", top = 5, skip = 0)

# rows 6–10
page_2 <- peg_data("d4mq-wa44", top = 5, skip = 5)
```

### Fetching all rows

Omit `top` to fetch every matching row across all pages:

``` r
# fetches all rows — may take several minutes for large datasets
peg_data("d4mq-wa44")
```

------------------------------------------------------------------------

## Date filtering

Datasets with timestamp columns (type `calendar_date` or
`floating_timestamp` in
[`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md))
support date range filters via raw OData strings. Socrata floating
timestamps use ISO 8601 format with milliseconds:
`YYYY-MM-DDTHH:MM:SS.mmm`.

Build cutoff strings with a small helper to avoid repeating the format:

``` r
# helper — format a Date as a Socrata floating timestamp string
ts <- function(date) format(date, "%Y-%m-%dT00:00:00.000")
```

The examples below use the 311 Service Requests dataset (`u7f6-5326`),
which has 18+ million rows and is updated continuously — date filters
are essential to avoid downloading the entire dataset.

### Records closed in the last 4 days

``` r
filter_str <- paste0("closed_date ge '", ts(Sys.Date() - 4), "'")

peg_data(
  "u7f6-5326",
  filter = filter_str,
  select = c("case_id", "channel_type", "subject", "reason",
             "type", "open_date", "closed_date", "case_status",
             "neighbourhood", "ward"),
  top    = 100L
)
#> # A tibble: 100 × 10
#>    case_id   channel_type subject reason type  open_date closed_date case_status
#>    <chr>     <chr>        <chr>   <chr>  <chr> <chr>     <chr>       <chr>      
#>  1 00e17bc8… Voice In     Servic… Water… Wate… 2014-09-… 2026-03-18… Closed     
#>  2 0130e8c6… Voice In     Servic… City … Indi… 2018-11-… 2026-03-17… Closed     
#>  3 0145e387… Voice In     Servic… Water… Wate… 2014-06-… 2026-03-18… Closed     
#>  4 016c4370… Voice In     Servic… Water… Wate… 2014-02-… 2026-03-18… Closed     
#>  5 01d35870… Voice In     Servic… Water… Wate… 2014-09-… 2026-03-18… Closed     
#>  6 029fed7e… Voice In     Servic… City … Indi… 2019-03-… 2026-03-17… Closed     
#>  7 042218b5… Voice In     Servic… Water… Valv… 2014-03-… 2026-03-18… Closed     
#>  8 04d029f1… Voice In     Servic… Water… Valv… 2014-05-… 2026-03-18… Closed     
#>  9 05d0fc55… Voice In     Servic… Plann… City… 2015-10-… 2026-03-17… Closed     
#> 10 05d0fc55… Self Service Servic… Plann… City… 2015-10-… 2026-03-17… Closed     
#> # ℹ 90 more rows
#> # ℹ 2 more variables: neighbourhood <chr>, ward <chr>
```

### Records closed within a specific date range

``` r
filter_str <- paste0(
  "closed_date ge '", ts(as.Date("2026-03-01")), "'",
  " and ",
  "closed_date lt '", ts(as.Date("2026-03-07")), "'"
)

peg_data(
  "u7f6-5326",
  filter = filter_str,
  select = c("case_id", "subject", "open_date", "closed_date", "case_status"),
  top    = 100L
)
#> # A tibble: 100 × 5
#>    case_id                             subject open_date closed_date case_status
#>    <chr>                               <chr>   <chr>     <chr>       <chr>      
#>  1 925ba9824f63b6e105eb00dc8f069b56e4… Servic… 2018-04-… 2026-03-06… Closed     
#>  2 ef9eb1f31d08f9c23314e28c86c4cdc66a… Servic… 2023-02-… 2026-03-04… Closed     
#>  3 e17ba4e93b31b085f5f102113833ecc3b8… Servic… 2023-06-… 2026-03-05… Closed     
#>  4 e17ba4e93b31b085f5f102113833ecc3b8… Servic… 2023-06-… 2026-03-05… Closed     
#>  5 c54dfa99aa65b99836b03401b63f7576f8… Servic… 2023-08-… 2026-03-04… Closed     
#>  6 b6bd446227ce1aef7480f1aec1e60d97cc… Servic… 2023-09-… 2026-03-04… Closed     
#>  7 d81f9c3026c55e7b9fd049c13cb825f03f… Servic… 2023-12-… 2026-03-06… Closed     
#>  8 5b52f3b44ddc0fdaffe18f93c7529579b9… Servic… 2023-12-… 2026-03-06… Closed     
#>  9 71c5dea21dbeba15537e1b26084bc6b908… Servic… 2023-12-… 2026-03-06… Closed     
#> 10 c48b7cd13abf00d7de74c92cf918efc15b… Servic… 2023-12-… 2026-03-06… Closed     
#> # ℹ 90 more rows
```

### Open cases from the last 7 days

``` r
filter_str <- paste0(
  "open_date ge '", ts(Sys.Date() - 7), "'",
  " and ",
  "case_status eq 'Open'"
)

peg_data(
  "u7f6-5326",
  filter  = filter_str,
  select  = c("case_id", "subject", "reason", "open_date",
              "case_status", "neighbourhood", "ward"),
  top     = 100L
)
#> # A tibble: 100 × 7
#>    case_id              subject reason open_date case_status neighbourhood ward 
#>    <chr>                <chr>   <chr>  <chr>     <chr>       <chr>         <chr>
#>  1 85737cf8aed019baf1b… Servic… Asses… 2026-03-… Open        NA            NA   
#>  2 a5f641c1fefc70ff811… Servic… Water… 2026-03-… Open        King Edward   St. …
#>  3 14413d52546953d2bf9… Servic… Water… 2026-03-… Open        Pulberry      St. …
#>  4 def3469b275f18e5096… Servic… Trans… 2026-03-… Open        NA            NA   
#>  5 959b3538554dd6e8524… Servic… Asses… 2026-03-… Open        River East    Nort…
#>  6 0d00b3abc5db0f1caea… Servic… Publi… 2026-03-… Open        NA            NA   
#>  7 0a8da3ffeea5d452f8a… Servic… Publi… 2026-03-… Open        NA            NA   
#>  8 ba23f5972a6c8736651… Servic… Water… 2026-03-… Open        NA            NA   
#>  9 62a617b57be61a7df4f… Servic… Water… 2026-03-… Open        Holden        St. …
#> 10 4e767e8dc87d00cb621… Servic… Water… 2026-03-… Open        Silver Heigh… St. …
#> # ℹ 90 more rows
```

### Cases closed yesterday, sorted by most recently closed

``` r
filter_str <- paste0(
  "closed_date ge '", ts(Sys.Date() - 1), "'",
  " and ",
  "closed_date lt '", ts(Sys.Date()), "'"
)

peg_data(
  "u7f6-5326",
  filter  = filter_str,
  select  = c("case_id", "subject", "channel_type",
              "open_date", "closed_date", "neighbourhood"),
  orderby = "closed_date desc",
  top     = 100L
)
#> # A tibble: 7 × 6
#>   case_id               channel_type subject open_date closed_date neighbourhood
#>   <chr>                 <chr>        <chr>   <chr>     <chr>       <chr>        
#> 1 5290205807c2d82aa351… Voice In     Servic… 2026-03-… 2026-03-19… Tyndall Park 
#> 2 86dac5efdb20f2cec795… VOF          Servic… 2026-03-… 2026-03-19… NA           
#> 3 e904e530d8d53c6ad88b… Voice In     Inform… 2026-03-… 2026-03-19… NA           
#> 4 3887658d92e0ebd73e6d… Voice In     Servic… 2026-03-… 2026-03-19… Munroe East  
#> 5 6ced2002c49a11832772… Voice In     Servic… 2026-03-… 2026-03-19… NA           
#> 6 0be9a18a56d20852ff76… Voice In     Servic… 2026-03-… 2026-03-19… NA           
#> 7 cdbcadd803817f39dbe0… Voice In     Inform… 2026-03-… 2026-03-19… NA
```

> **Note:** The `top` argument is included in all date filter examples
> to keep live API calls lightweight during development. Remove it to
> retrieve the full result set.

------------------------------------------------------------------------

## OData filter reference

| R expression       | OData equivalent      | Meaning               |
|--------------------|-----------------------|-----------------------|
| `x == 1`           | `x eq 1`              | equal                 |
| `x != 1`           | `x ne 1`              | not equal             |
| `x > 1`            | `x gt 1`              | greater than          |
| `x >= 1`           | `x ge 1`              | greater than or equal |
| `x < 1`            | `x lt 1`              | less than             |
| `x <= 1`           | `x le 1`              | less than or equal    |
| `x == 1 & y == 2`  | `(x eq 1 and y eq 2)` | AND                   |
| `x == 1 \| y == 2` | `(x eq 1 or y eq 2)`  | OR                    |
| `!x`               | `not x`               | NOT                   |

> **Tip:** R expression syntax works for numeric and string comparisons.
> For date comparisons, use raw OData strings as shown in the date
> filtering section above.

------------------------------------------------------------------------

## Finding dataset IDs

The easiest way is to search directly in R:

``` r
peg_catalogue() |>
  filter(grepl("your search term", name, ignore.case = TRUE)) |>
  select(name, id, category)
```

Alternatively, browse the [City of Winnipeg Open Data
Portal](https://data.winnipeg.ca), open any dataset, click **API → OData
V4**, and copy the last segment of the URL:

    https://data.winnipeg.ca/api/odata/v4/d4mq-wa44
                                          ^^^^^^^^^^
                                          dataset ID

------------------------------------------------------------------------

## Further reading

- [City of Winnipeg Open Data Portal](https://data.winnipeg.ca)
- [Socrata Developer Portal](https://dev.socrata.com)
- [OData V4 Query Options](https://www.odata.org/documentation/)
