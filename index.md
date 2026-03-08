# wpgdata

`wpgdata` provides a simple R interface to query and download datasets
from the [City of Winnipeg Open Data Portal](https://data.winnipeg.ca)
using the OData V4 API.

## Installation

Install from CRAN:

``` r
install.packages("wpgdata")
```

Or install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("myominnoo/wpgdata")
```

## Usage

``` r
library(wpgdata)
```

The typical workflow follows these steps:

``` R
peg_catalogue()   →   peg_info()   →   peg_metadata()   →   peg_query()   →   peg_all()
(find datasets)       (explore)        (find fields)        (filter)          (download all)
```

### `peg_catalogue()` — find available datasets

List all datasets on the Winnipeg Open Data Portal with their IDs,
categories, and last updated dates:

``` r
peg_catalogue()
#> # A tibble: 200 × 7
#>    name           id    description category updated_at          row_count url  
#>    <chr>          <chr> <chr>       <chr>    <dttm>                  <int> <chr>
#>  1 WFPS Call Logs yg42… "The data … Fire an… 2026-03-08 16:31:12      1349 http…
#>  2 Plow Zone Sch… tix9… "Scheduled… City Pl… 2026-03-08 16:25:50       630 http…
#>  3 311 Call Wait… vrzk… "Caller wa… Contact… 2026-03-08 16:25:29       701 http…
#>  4 Council Votin… f9mn… "On Septem… Council… 2026-03-08 16:14:49       347 http…
#>  5 River Water L… tgrf… "Record of… Water a… 2026-03-08 16:01:44       731 http…
#>  6 Accessibility… fxq5… "This data… Streets  2026-03-08 16:00:58        67 http…
#>  7 FIPPA Request… pfbi… "The Freed… Organiz… 2026-03-08 11:41:58       484 http…
#>  8 WPA Paystation b85e… "Onstreet … Parking  2026-03-08 10:03:40       385 http…
#>  9 Walkways       jdeq… "This data… City Pl… 2026-03-08 10:03:29       326 http…
#> 10 Daily Adult M… du7c… "The data … Insect … 2026-03-08 10:00:15      1445 http…
#> # ℹ 190 more rows
```

Filter by category or search by name to find a dataset ID:

``` r
library(dplyr)

# count datasets by category
peg_catalogue() |>
  count(category, sort = TRUE)
#> # A tibble: 26 × 2
#>    category                                                   n
#>    <chr>                                                  <int>
#>  1 Census                                                    29
#>  2 City Planning                                             25
#>  3 Development Approvals, Building Permits, & Inspections    23
#>  4 Transportation Planning & Traffic Management              18
#>  5 Uncategorized                                             14
#>  6 Council Services                                          13
#>  7 Organizational Support Services                            8
#>  8 Assessment, Taxation, & Corporate                          7
#>  9 Contact Centre - 311                                       7
#> 10 Water and Waste                                            7
#> # ℹ 16 more rows

# search by name
peg_catalogue() |>
  filter(grepl("assessment", name, ignore.case = TRUE)) |>
  select(name, id, updated_at)
#> # A tibble: 1 × 3
#>   name               id        updated_at         
#>   <chr>              <chr>     <dttm>             
#> 1 Assessment Parcels d4mq-wa44 2026-03-08 09:32:08
```

### `peg_info()` — dataset-level information

Get high-level information about a dataset before downloading it:

``` r
peg_info("d4mq-wa44")
#> # A tibble: 1 × 11
#>   name        description category created_at rows_updated_at view_last_modified
#>   <chr>       <chr>       <chr>    <date>     <date>          <date>            
#> 1 Assessment… List of al… Assessm… 2017-08-23 2026-03-08      2026-03-08        
#> # ℹ 5 more variables: view_count <int>, download_count <int>, tags <list>,
#> #   license <chr>, provenance <chr>
```

### `peg_metadata()` — column names and types

Look up field names and types before querying. Always use `field_name`
values in
[`peg_query()`](https://myominnoo.github.io/wpgdata/reference/peg_query.md):

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

Fetch the first page of a dataset. Warns if more rows are available:

``` r
suppressWarnings(peg_get("d4mq-wa44"))
#> # A tibble: 1,000 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <chr>       <lgl>         <lgl>           
#>  1 row-iai… 01000001000          1636 <NA>        NA            NA              
#>  2 row-u7e… 01000005500          1584 <NA>        NA            NA              
#>  3 row-rxq… 01000008000          1574 <NA>        NA            NA              
#>  4 row-7nj… 01000008200          1550 <NA>        NA            NA              
#>  5 row-pte… 01000008400          1538 <NA>        NA            NA              
#>  6 row-ehq… 01000008500          1536 <NA>        NA            NA              
#>  7 row-iyr… 01000013200          1520 <NA>        NA            NA              
#>  8 row-78v… 01000013300          1510 <NA>        NA            NA              
#>  9 row-cv3… 01000013600          1500 <NA>        NA            NA              
#> 10 row-trz… 01000013700          1490 <NA>        NA            NA              
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
#> 1 row-u7eu… 01000005500          1584 NA          NA            NA              
#> 2 row-iyrb… 01000013200          1520 NA          NA            NA              
#> 3 row-ygb8… 01000014500          1450 NA          NA            NA              
#> 4 row-bp9n… 01000045500          1290 NA          NA            NA              
#> 5 row-nskr… 01000064000          1820 NA          NA            NA              
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

Retrieve all rows across multiple pages with a progress bar:

``` r
peg_all("d4mq-wa44", max_pages = 3)
#> Warning: ! Stopped after 3 pages.
#> ℹ Rows retrieved : 41000 of 245130
#> ℹ Use `max_pages = Inf` to fetch all.
#> # A tibble: 41,000 × 72
#>    `__id`   roll_number street_number unit_number street_suffix street_direction
#>    <chr>    <chr>               <int> <chr>       <chr>         <chr>           
#>  1 row-iai… 01000001000          1636 <NA>        <NA>          <NA>            
#>  2 row-u7e… 01000005500          1584 <NA>        <NA>          <NA>            
#>  3 row-rxq… 01000008000          1574 <NA>        <NA>          <NA>            
#>  4 row-7nj… 01000008200          1550 <NA>        <NA>          <NA>            
#>  5 row-pte… 01000008400          1538 <NA>        <NA>          <NA>            
#>  6 row-ehq… 01000008500          1536 <NA>        <NA>          <NA>            
#>  7 row-iyr… 01000013200          1520 <NA>        <NA>          <NA>            
#>  8 row-78v… 01000013300          1510 <NA>        <NA>          <NA>            
#>  9 row-cv3… 01000013600          1500 <NA>        <NA>          <NA>            
#> 10 row-trz… 01000013700          1490 <NA>        <NA>          <NA>            
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
| `!x`               | `not x`               | NOT                   |

## Finding Dataset IDs

The easiest way is directly in R:

``` r
peg_catalogue() |>
  filter(grepl("your search term", name, ignore.case = TRUE)) |>
  select(name, id, category)
```

Alternatively, browse the [City of Winnipeg Open Data
Portal](https://data.winnipeg.ca) and copy the ID from the OData V4
endpoint URL:

``` R
https://data.winnipeg.ca/api/odata/v4/d4mq-wa44
                                      ^^^^^^^^^^
                                      dataset ID
```

## License

MIT © [Myo Minn Oo](https://github.com/myominnoo)
