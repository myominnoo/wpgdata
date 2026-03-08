
<!-- README.md is generated from README.Rmd. Please edit that file -->

# wpgdata <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![R-CMD-check](https://github.com/myominnoo/wpgdata/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/myominnoo/wpgdata/actions/workflows/R-CMD-check.yaml)
[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

`wpgdata` provides a simple R interface to query and download datasets
from the [City of Winnipeg Open Data Portal](https://data.winnipeg.ca)
using the OData V4 API.

## Installation

Install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("myominnoo/wpgdata")
```

## Quick Start

``` r
library(wpgdata)
```

### `peg_info()` — dataset-level information

Get high-level information about a dataset before downloading it:

``` r
peg_info("d4mq-wa44")
#> # A tibble: 1 × 11
#>   name        description category created_at rows_updated_at view_last_modified
#>   <chr>       <chr>       <chr>    <date>     <date>          <date>            
#> 1 Assessment… List of al… Assessm… 2017-08-23 2026-03-07      2026-03-07        
#> # ℹ 5 more variables: view_count <int>, download_count <int>, tags <list>,
#> #   license <chr>, provenance <chr>
```

### `peg_metadata()` — column names and types

Look up field names and types before querying:

``` r
peg_metadata("d4mq-wa44")
#> # A tibble: 71 × 4
#>    name               field_name         type   description
#>    <chr>              <chr>              <chr>  <chr>      
#>  1 Roll Number        roll_number        text   <NA>       
#>  2 Street Number      street_number      number <NA>       
#>  3 Unit Number        unit_number        text   <NA>       
#>  4 Street Suffix      street_suffix      text   <NA>       
#>  5 Street Direction   street_direction   text   <NA>       
#>  6 Street Name        street_name        text   <NA>       
#>  7 Street Type        street_type        text   <NA>       
#>  8 Full Address       full_address       text   <NA>       
#>  9 Neighbourhood Area neighbourhood_area text   <NA>       
#> 10 Market Region      market_region      text   <NA>       
#> # ℹ 61 more rows
```

### `peg_get()` — fetch the first page

Fetch the first page of a dataset (up to 1000 rows):

``` r
peg_get("d4mq-wa44")
#> Warning: ! Not all rows returned. The dataset is paginated.
#> ℹ Rows retrieved: 1000
#> ℹ Use `peg_all()` to retrieve all rows.
#> # A tibble: 1,000 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <chr>       <lgl>         <lgl>           
#>  1 row-yah… 01000001000          1636 <NA>        NA            NA              
#>  2 row-tuj… 01000005500          1584 <NA>        NA            NA              
#>  3 row-7y8… 01000008000          1574 <NA>        NA            NA              
#>  4 row-vzs… 01000008200          1550 <NA>        NA            NA              
#>  5 row-pq8… 01000008400          1538 <NA>        NA            NA              
#>  6 row-6dw… 01000008500          1536 <NA>        NA            NA              
#>  7 row-ayw… 01000013200          1520 <NA>        NA            NA              
#>  8 row-ji6… 01000013300          1510 <NA>        NA            NA              
#>  9 row-y6a… 01000013600          1500 <NA>        NA            NA              
#> 10 row-82n… 01000013700          1490 <NA>        NA            NA              
#> # ℹ 990 more rows
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <int>, …
```

### `peg_query()` — filter, select, sort

Query a dataset using R expressions or raw OData strings:

``` r
# R expression filter
peg_query("d4mq-wa44",
  filter = total_assessed_value > 1000000,
  top    = 5
)
#> Warning: ! Not all rows returned. The dataset is paginated.
#> ℹ Rows retrieved: 5
#> ℹ Use `peg_all()` to retrieve all rows.
#> # A tibble: 5 × 72
#>   `__id`    roll_number street_number unit_number street_suffix street_direction
#>   <chr>     <chr>               <int> <lgl>       <lgl>         <lgl>           
#> 1 row-tuj9… 01000005500          1584 NA          NA            NA              
#> 2 row-aywk… 01000013200          1520 NA          NA            NA              
#> 3 row-xu56… 01000014500          1450 NA          NA            NA              
#> 4 row-dewr… 01000045500          1290 NA          NA            NA              
#> 5 row-xx9b… 01000064000          1820 NA          NA            NA              
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <lgl>,
#> #   property_use_code <chr>, assessed_land_area <int>, …
```

``` r
# select specific columns
peg_query("d4mq-wa44",
  select = c("roll_number", "full_address", "total_assessed_value"),
  top    = 5
)
#> Warning: ! Not all rows returned. The dataset is paginated.
#> ℹ Rows retrieved: 5
#> ℹ Use `peg_all()` to retrieve all rows.
#> # A tibble: 5 × 3
#>   roll_number full_address       total_assessed_value
#>   <chr>       <chr>                             <int>
#> 1 01000001000 1636 MCCREARY ROAD               723000
#> 2 01000005500 1584 MCCREARY ROAD              1619000
#> 3 01000008000 1574 MCCREARY ROAD               570000
#> 4 01000008200 1550 MCCREARY ROAD               743000
#> 5 01000008400 1538 MCCREARY ROAD               577000
```

``` r
# sort results
peg_query("d4mq-wa44",
  select  = c("roll_number", "full_address", "total_assessed_value"),
  orderby = "total_assessed_value desc",
  top     = 5
)
#> Warning: ! Not all rows returned. The dataset is paginated.
#> ℹ Rows retrieved: 5
#> ℹ Use `peg_all()` to retrieve all rows.
#> # A tibble: 5 × 3
#>   roll_number full_address        total_assessed_value
#>   <chr>       <chr>                              <int>
#> 1 13099071230 1485 PORTAGE AVENUE            651316000
#> 2 03091643600 92 DYSART ROAD                 475244000
#> 3 08020955700 1225 ST MARY'S ROAD            328848000
#> 4 13096152000 700 WILLIAM AVENUE             262782000
#> 5 12092819100 10 KENNEDY STREET              262044000
```

``` r
# combine filter + select + orderby
peg_query("d4mq-wa44",
  filter  = total_assessed_value > 1000000,
  select  = c("roll_number", "full_address", "total_assessed_value"),
  orderby = "total_assessed_value desc",
  top     = 5
)
#> Warning: ! Not all rows returned. The dataset is paginated.
#> ℹ Rows retrieved: 5
#> ℹ Use `peg_all()` to retrieve all rows.
#> # A tibble: 5 × 3
#>   roll_number full_address        total_assessed_value
#>   <chr>       <chr>                              <int>
#> 1 13099071230 1485 PORTAGE AVENUE            651316000
#> 2 03091643600 92 DYSART ROAD                 475244000
#> 3 08020955700 1225 ST MARY'S ROAD            328848000
#> 4 13096152000 700 WILLIAM AVENUE             262782000
#> 5 12092819100 10 KENNEDY STREET              262044000
```

### `peg_all()` — fetch all rows with pagination

Retrieve all rows across multiple pages:

``` r
# fetch up to 3 pages (safety cap)
peg_all("d4mq-wa44", max_pages = 3)
#> Warning: ! Stopped after 3 pages.
#> ℹ Rows retrieved : 41000 of 245130
#> ℹ Use `max_pages = Inf` to fetch all.
#> # A tibble: 41,000 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <chr>       <chr>         <chr>           
#>  1 row-yah… 01000001000          1636 <NA>        <NA>          <NA>            
#>  2 row-tuj… 01000005500          1584 <NA>        <NA>          <NA>            
#>  3 row-7y8… 01000008000          1574 <NA>        <NA>          <NA>            
#>  4 row-vzs… 01000008200          1550 <NA>        <NA>          <NA>            
#>  5 row-pq8… 01000008400          1538 <NA>        <NA>          <NA>            
#>  6 row-6dw… 01000008500          1536 <NA>        <NA>          <NA>            
#>  7 row-ayw… 01000013200          1520 <NA>        <NA>          <NA>            
#>  8 row-ji6… 01000013300          1510 <NA>        <NA>          <NA>            
#>  9 row-y6a… 01000013600          1500 <NA>        <NA>          <NA>            
#> 10 row-82n… 01000013700          1490 <NA>        <NA>          <NA>            
#> # ℹ 40,990 more rows
#> # ℹ 66 more variables: street_name <chr>, street_type <chr>,
#> #   full_address <chr>, neighbourhood_area <chr>, market_region <chr>,
#> #   total_living_area <int>, building_type <chr>, basement <chr>,
#> #   basement_finish <chr>, year_built <int>, rooms <int>,
#> #   air_conditioning <chr>, fire_place <chr>, attached_garage <chr>,
#> #   detached_garage <chr>, pool <chr>, number_floors_condo <int>, …
```

## OData Query Reference

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

## Finding Dataset IDs

Dataset IDs are available on the [City of Winnipeg Open Data
Portal](https://data.winnipeg.ca). Each dataset URL contains the ID, for
example:

    https://data.winnipeg.ca/api/odata/v4/d4mq-wa44
                                          ^^^^^^^^^^
                                          dataset ID

## License

MIT © [Myo Minn Oo](https://github.com/myominnoo)
