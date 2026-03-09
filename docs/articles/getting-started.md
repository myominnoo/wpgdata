# Getting Started with wpgdata

## Introduction

`wpgdata` provides a simple R interface to query and download datasets
from the [City of Winnipeg Open Data Portal](https://data.winnipeg.ca)
using the OData V4 API. This vignette walks through the core functions
using the Assessment Parcels dataset (`d4mq-wa44`) as a working example.

``` r
library(wpgdata)
library(dplyr)
```

------------------------------------------------------------------------

## Workflow overview

The typical `wpgdata` workflow follows five steps:

| Function | Purpose |
|----|----|
| [`peg_catalogue()`](https://myominnoo.github.io/wpgdata/reference/peg_catalogue.md) | Browse all available datasets and find IDs |
| [`peg_info()`](https://myominnoo.github.io/wpgdata/reference/peg_info.md) | Explore a specific dataset |
| [`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md) | Find field names before querying |
| [`peg_query()`](https://myominnoo.github.io/wpgdata/reference/peg_query.md) | Filter, select, and sort |
| [`peg_all()`](https://myominnoo.github.io/wpgdata/reference/peg_all.md) | Download all rows |

    peg_catalogue()   →   peg_info()   →   peg_metadata()   →   peg_query()   →   peg_all()
    (find datasets)       (explore)        (find fields)        (filter)          (download all)

------------------------------------------------------------------------

## Step 1 — Find datasets with `peg_catalogue()`

Before working with any dataset, use
[`peg_catalogue()`](https://myominnoo.github.io/wpgdata/reference/peg_catalogue.md)
to browse all available datasets on the portal. This is the best
starting point when you don’t yet know a dataset ID:

``` r
catalogue <- peg_catalogue()
catalogue
#> # A tibble: 216 × 22
#>    id        name     description category license_id created_at rows_updated_at
#>    <chr>     <chr>    <chr>       <chr>    <chr>      <date>     <date>         
#>  1 yg42-q284 WFPS Ca… "The data … Fire an… OGL_CANADA 2020-12-14 2026-03-09     
#>  2 vrzk-mj7v 311 Cal… "Caller wa… Contact… OGL_CANADA 2022-06-17 2026-03-09     
#>  3 tix9-r5tc Plow Zo… "Scheduled… City Pl… NA         2016-10-18 2026-03-09     
#>  4 tgrf-v2zc River W… "Record of… Water a… OGL_CANADA 2018-03-15 2026-03-09     
#>  5 f9mn-vti8 Council… "On Septem… Council… OGL_CANADA 2019-10-01 2026-03-09     
#>  6 u7f6-5326 311 Req… "This data… Contact… OGL_CANADA 2019-08-26 2026-03-09     
#>  7 fxq5-ign2 Accessi… "This data… Streets  OGL_CANADA 2023-01-18 2026-03-09     
#>  8 d4mq-wa44 Assessm… "List of a… Assessm… OGL_CANADA 2017-08-23 2026-03-08     
#>  9 iibp-28fx Burial … "Locations… Cemeter… OGL_CANADA 2016-01-29 2026-03-08     
#> 10 gnxp-9hpt Public … "Public No… Develop… NA         2016-08-08 2026-03-08     
#> # ℹ 206 more rows
#> # ℹ 15 more variables: view_last_modified <date>, publication_date <date>,
#> #   index_updated_at <date>, row_count <int>, col_count <int>,
#> #   download_count <int>, view_count <int>, group <chr>, department <chr>,
#> #   update_frequency <chr>, quality_rank <chr>, license <chr>,
#> #   license_link <chr>, tags <list>, url <chr>
```

Count datasets by category to get an overview of what’s available:

``` r
catalogue |>
  dplyr::count(category, sort = TRUE)
#> # A tibble: 26 × 2
#>    category                                                   n
#>    <chr>                                                  <int>
#>  1 Census                                                    35
#>  2 City Planning                                             27
#>  3 Development Approvals, Building Permits, & Inspections    23
#>  4 Transportation Planning & Traffic Management              18
#>  5 Uncategorized                                             16
#>  6 Council Services                                          15
#>  7 Recreation                                                 9
#>  8 Organizational Support Services                            8
#>  9 Assessment, Taxation, & Corporate                          7
#> 10 Contact Centre - 311                                       7
#> # ℹ 16 more rows
```

Search by name to find a specific dataset and retrieve its ID:

``` r
catalogue |>
  dplyr::filter(grepl("assessment", name, ignore.case = TRUE)) |>
  dplyr::select(name, id, rows_updated_at)
#> # A tibble: 1 × 3
#>   name               id        rows_updated_at
#>   <chr>              <chr>     <date>         
#> 1 Assessment Parcels d4mq-wa44 2026-03-08
```

Use the `id` value in any other `peg_*` function:

``` r
dataset_id <- catalogue |>
  dplyr::filter(name == "Assessment Parcels") |>
  dplyr::pull(id)

dataset_id
#> [1] "d4mq-wa44"
```

------------------------------------------------------------------------

## Step 2 — Explore a dataset with `peg_info()`

Use
[`peg_info()`](https://myominnoo.github.io/wpgdata/reference/peg_info.md)
to understand what a dataset contains — its name, description, category,
update frequency, and row count:

``` r
peg_info("d4mq-wa44")
#> # A tibble: 1 × 11
#>   name        description category created_at rows_updated_at view_last_modified
#>   <chr>       <chr>       <chr>    <date>     <date>          <date>            
#> 1 Assessment… List of al… Assessm… 2017-08-23 2026-03-08      2026-03-08        
#> # ℹ 5 more variables: view_count <int>, download_count <int>, tags <list>,
#> #   license <chr>, provenance <chr>
```

This tells us the dataset was last updated, how many times it has been
downloaded, and what license it is published under — all useful before
committing to a large download.

------------------------------------------------------------------------

## Step 3 — Find field names with `peg_metadata()`

OData queries require exact field names. Use
[`peg_metadata()`](https://myominnoo.github.io/wpgdata/reference/peg_metadata.md)
to look up the available fields and their types before writing any
query:

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
[`peg_query()`](https://myominnoo.github.io/wpgdata/reference/peg_query.md).
The `type` column tells you whether a field is text, number, or another
type — important for writing correct filter expressions.

For example, to find numeric fields only:

``` r
meta |>
  dplyr::filter(type == "number")
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

------------------------------------------------------------------------

## Step 4 — Fetch a quick preview with `peg_get()`

[`peg_get()`](https://myominnoo.github.io/wpgdata/reference/peg_get.md)
fetches the first page of a dataset (up to the server’s default page
size). It is useful for a quick look at the data structure before
writing more targeted queries:

``` r
df <- suppressWarnings(peg_get("d4mq-wa44"))
df
#> # A tibble: 1,000 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <chr>       <lgl>         <lgl>           
#>  1 row-iai… 01000001000          1636 NA          NA            NA              
#>  2 row-u7e… 01000005500          1584 NA          NA            NA              
#>  3 row-rxq… 01000008000          1574 NA          NA            NA              
#>  4 row-7nj… 01000008200          1550 NA          NA            NA              
#>  5 row-pte… 01000008400          1538 NA          NA            NA              
#>  6 row-ehq… 01000008500          1536 NA          NA            NA              
#>  7 row-iyr… 01000013200          1520 NA          NA            NA              
#>  8 row-78v… 01000013300          1510 NA          NA            NA              
#>  9 row-cv3… 01000013600          1500 NA          NA            NA              
#> 10 row-trz… 01000013700          1490 NA          NA            NA              
#> # ℹ 990 more rows
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <int>, …
```

Check column names and types:

``` r
dplyr::glimpse(df)
#> Rows: 1,000
#> Columns: 72
#> $ `__id`                          <chr> "row-iaim.ytxs-dh5m", "row-u7eu_kbti.y…
#> $ roll_number                     <chr> "01000001000", "01000005500", "0100000…
#> $ street_number                   <int> 1636, 1584, 1574, 1550, 1538, 1536, 15…
#> $ unit_number                     <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ street_suffix                   <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ street_direction                <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ street_name                     <chr> "MCCREARY", "MCCREARY", "MCCREARY", "M…
#> $ street_type                     <chr> "ROAD", "ROAD", "ROAD", "ROAD", "ROAD"…
#> $ full_address                    <chr> "1636 MCCREARY ROAD", "1584 MCCREARY R…
#> $ neighbourhood_area              <chr> "WILKES SOUTH", "WILKES SOUTH", "WILKE…
#> $ market_region                   <chr> "6, CHARLESWOOD", "6, CHARLESWOOD", "6…
#> $ total_living_area               <int> 1313, 4007, 1052, 3120, 1510, 4570, 49…
#> $ building_type                   <chr> "ONE STOREY", "TWO STOREY", "ONE STORE…
#> $ basement                        <chr> "Yes", "Yes", "No", "Yes", "Yes", "Yes…
#> $ basement_finish                 <chr> "No", "Yes", "No", "No", "Yes", "Yes",…
#> $ year_built                      <int> 1991, 1991, 2007, 1982, 1970, 1958, 20…
#> $ rooms                           <int> 5, 8, 5, 6, 5, 8, 10, 9, 6, 8, 5, 10, …
#> $ air_conditioning                <chr> "Yes", "Yes", "Yes", "Yes", "Yes", "Ye…
#> $ fire_place                      <chr> "No", "Yes", "No", "No", "Yes", "Yes",…
#> $ attached_garage                 <chr> "No", "Yes", "No", "Yes", "No", "No", …
#> $ detached_garage                 <chr> "Yes", "No", "Yes", "No", "No", "Yes",…
#> $ pool                            <chr> "No", "No", "No", "No", "No", "No", "Y…
#> $ number_floors_condo             <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ property_use_code               <chr> "RESSD - DETACHED SINGLE DWELLING", "R…
#> $ assessed_land_area              <int> 197030, 218155, 43628, 130705, 130718,…
#> $ water_frontage_measurement      <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ sewer_frontage_measurement      <dbl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ property_influences             <chr> "EXTERNAL CORNER,NO SEWER NO WATER", "…
#> $ zoning                          <chr> "A - AGRICULTURAL", "A - AGRICULTURAL"…
#> $ total_assessed_value            <int> 723000, 1619000, 570000, 743000, 57700…
#> $ total_proposed_assessment_value <int> 893000, 1994000, 650000, 968000, 66300…
#> $ assessment_date                 <chr> "2023-04-01T00:00:00.000", "2023-04-01…
#> $ detail_url                      <chr> "Some(http://www.winnipegassessment.co…
#> $ current_assessment_year         <int> 2026, 2026, 2026, 2026, 2026, 2026, 20…
#> $ property_class_1                <chr> "RESIDENTIAL 1", "RESIDENTIAL 1", "RES…
#> $ status_1                        <chr> "TAXABLE", "TAXABLE", "TAXABLE", "TAXA…
#> $ assessed_value_1                <int> 723000, 1619000, 570000, 743000, 57700…
#> $ property_class_2                <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ status_2                        <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ assessed_value_2                <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ property_class_3                <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ status_3                        <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ assessed_value_3                <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ property_class_4                <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ status_4                        <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ assessed_value_4                <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ property_class_5                <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ status_5                        <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ assessed_value_5                <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_assessment_year        <chr> "2027", "2027", "2027", "2027", "2027"…
#> $ proposed_assessment_date        <chr> "2025-04-01T00:00:00.000", "2025-04-01…
#> $ proposed_property_class_1       <chr> "RESIDENTIAL 1", "RESIDENTIAL 1", "RES…
#> $ proposed_status_1               <chr> "TAXABLE", "TAXABLE", "TAXABLE", "TAXA…
#> $ proposed_assessment_value_1     <int> 893000, 1994000, 650000, 968000, 66300…
#> $ proposed_property_class_2       <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_status_2               <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_assessment_value_2     <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_property_class_3       <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_status_3               <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_assessment_value_3     <int> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_property_class_4       <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_status_4               <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_assessment_value_4     <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_property_class_5       <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_status_5               <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ proposed_assessment_value_5     <lgl> NA, NA, NA, NA, NA, NA, NA, NA, NA, NA…
#> $ multiple_residences             <chr> "No", "No", "No", "No", "No", "No", "N…
#> $ geometry                        <df[,2]> <data.frame[26 x 2]>
#> $ dwelling_units                  <chr> "1", "1", "1", "1", "1", "1", "1", …
#> $ centroid_lat                    <dbl> 49.83014, 49.83165, 49.83211, 49.83242…
#> $ centroid_lon                    <dbl> -97.23470, -97.23456, -97.23452, -97.2…
#> $ gisid                           <int> 148170, 148168, 185348, 185347, 185346…
```

------------------------------------------------------------------------

## Step 5 — Query with `peg_query()`

[`peg_query()`](https://myominnoo.github.io/wpgdata/reference/peg_query.md)
supports five OData parameters:

| Argument  | OData parameter | Purpose             |
|-----------|-----------------|---------------------|
| `filter`  | `$filter`       | filter rows         |
| `select`  | `$select`       | choose columns      |
| `top`     | `$top`          | limit rows returned |
| `skip`    | `$skip`         | skip rows (offset)  |
| `orderby` | `$orderby`      | sort results        |

### Filtering rows

Pass R expressions directly — `wpgdata` translates them to OData:

``` r
peg_query("d4mq-wa44",
  filter = total_assessed_value > 1000000,
  top    = 10
)
#> # A tibble: 10 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <lgl>       <lgl>         <lgl>           
#>  1 row-u7e… 01000005500          1584 NA          NA            NA              
#>  2 row-iyr… 01000013200          1520 NA          NA            NA              
#>  3 row-ygb… 01000014500          1450 NA          NA            NA              
#>  4 row-bp9… 01000045500          1290 NA          NA            NA              
#>  5 row-nsk… 01000064000          1820 NA          NA            NA              
#>  6 row-y94… 01000067500          1916 NA          NA            NA              
#>  7 row-s2m… 01000067900          1892 NA          NA            NA              
#>  8 row-fzv… 01000092200          1700 NA          NA            NA              
#>  9 row-4c9… 01000096000          1720 NA          NA            NA              
#> 10 row-44b… 01000306500          2424 NA          NA            NA              
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
peg_query("d4mq-wa44",
  filter = "total_assessed_value gt 1000000",
  top    = 10
)
#> # A tibble: 10 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <lgl>       <lgl>         <lgl>           
#>  1 row-u7e… 01000005500          1584 NA          NA            NA              
#>  2 row-iyr… 01000013200          1520 NA          NA            NA              
#>  3 row-ygb… 01000014500          1450 NA          NA            NA              
#>  4 row-bp9… 01000045500          1290 NA          NA            NA              
#>  5 row-nsk… 01000064000          1820 NA          NA            NA              
#>  6 row-y94… 01000067500          1916 NA          NA            NA              
#>  7 row-s2m… 01000067900          1892 NA          NA            NA              
#>  8 row-fzv… 01000092200          1700 NA          NA            NA              
#>  9 row-4c9… 01000096000          1720 NA          NA            NA              
#> 10 row-44b… 01000306500          2424 NA          NA            NA              
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <lgl>,
#> #   property_use_code <chr>, assessed_land_area <int>, …
```

Both approaches return identical results.

### Compound filters

Combine conditions with `&` (AND) and `|` (OR):

``` r
peg_query("d4mq-wa44",
  filter = total_assessed_value > 1000000 & building_type == "TWO STOREY",
  top    = 10
)
#> # A tibble: 10 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <lgl>       <lgl>         <lgl>           
#>  1 row-u7e… 01000005500          1584 NA          NA            NA              
#>  2 row-iyr… 01000013200          1520 NA          NA            NA              
#>  3 row-ygb… 01000014500          1450 NA          NA            NA              
#>  4 row-nsk… 01000064000          1820 NA          NA            NA              
#>  5 row-3vg… 01000560000          3179 NA          NA            NA              
#>  6 row-mrq… 01000615000             3 NA          NA            NA              
#>  7 row-zir… 01000615400            17 NA          NA            NA              
#>  8 row-uym… 01000615800            31 NA          NA            NA              
#>  9 row-txp… 01000617400            36 NA          NA            NA              
#> 10 row-eh9… 01000718800           400 NA          NA            NA              
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <lgl>,
#> #   property_use_code <chr>, assessed_land_area <int>, …
```

### Selecting columns

Use `select` to return only the columns you need:

``` r
peg_query("d4mq-wa44",
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
peg_query("d4mq-wa44",
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

### Combining everything

``` r
peg_query("d4mq-wa44",
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

Use `skip` and `top` together to paginate manually:

``` r
# rows 1-5
page_1 <- peg_query("d4mq-wa44", top = 5, skip = 0)

# rows 6-10
page_2 <- peg_query("d4mq-wa44", top = 5, skip = 5)
```

------------------------------------------------------------------------

## Step 6 — Download all rows with `peg_all()`

[`peg_all()`](https://myominnoo.github.io/wpgdata/reference/peg_all.md)
automatically paginates through all pages and returns a single tibble.
It shows a progress bar with row counts and percentage:

``` r
# fetch up to 3 pages (safety cap)
peg_all("d4mq-wa44", max_pages = 3)
#> # A tibble: 41,000 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <chr>       <chr>         <chr>           
#>  1 row-iai… 01000001000          1636 NA          NA            NA              
#>  2 row-u7e… 01000005500          1584 NA          NA            NA              
#>  3 row-rxq… 01000008000          1574 NA          NA            NA              
#>  4 row-7nj… 01000008200          1550 NA          NA            NA              
#>  5 row-pte… 01000008400          1538 NA          NA            NA              
#>  6 row-ehq… 01000008500          1536 NA          NA            NA              
#>  7 row-iyr… 01000013200          1520 NA          NA            NA              
#>  8 row-78v… 01000013300          1510 NA          NA            NA              
#>  9 row-cv3… 01000013600          1500 NA          NA            NA              
#> 10 row-trz… 01000013700          1490 NA          NA            NA              
#> # ℹ 40,990 more rows
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <int>, …
```

For large datasets, the default `max_pages = 10` prevents accidental
downloads. Set `max_pages = Inf` to fetch everything:

``` r
# fetch all rows - may take several minutes for large datasets
peg_all("d4mq-wa44", max_pages = Inf)
```

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

------------------------------------------------------------------------

## Finding dataset IDs

The easiest way is to use
[`peg_catalogue()`](https://myominnoo.github.io/wpgdata/reference/peg_catalogue.md)
directly in R:

``` r
peg_catalogue() |>
  dplyr::filter(grepl("your search term", name, ignore.case = TRUE)) |>
  dplyr::select(name, id, category)
```

Alternatively, find IDs on the [City of Winnipeg Open Data
Portal](https://data.winnipeg.ca):

1.  Browse to [data.winnipeg.ca](https://data.winnipeg.ca)
2.  Open any dataset
3.  Click **API** → **OData V4**
4.  Copy the last segment of the URL:

&nbsp;

    https://data.winnipeg.ca/api/odata/v4/d4mq-wa44
                                          ^^^^^^^^^^
                                          dataset ID

------------------------------------------------------------------------

## Further reading

- [City of Winnipeg Open Data Portal](https://data.winnipeg.ca)
- [Socrata Developer Portal](https://dev.socrata.com)
- [OData V4 Query Options](https://www.odata.org/documentation/)
