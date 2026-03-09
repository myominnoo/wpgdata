# tests/testthat/test-peg_catalogue.R

# Input validation --------------------------------------------------------

test_that("peg_catalogue() errors on non-numeric limit", {
  expect_error(peg_catalogue(limit = "10"), "positive integer")
})

test_that("peg_catalogue() errors on negative limit", {
  expect_error(peg_catalogue(limit = -1), "positive integer")
})

test_that("peg_catalogue() errors on zero limit", {
  expect_error(peg_catalogue(limit = 0), "positive integer")
})


# Live API tests ----------------------------------------------------------
# All live tests share a single API call via a cached fixture to minimise
# network requests during test runs.

get_catalogue_fixture <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      cache <<- peg_catalogue(limit = 5) |> suppressMessages()
    }
    cache
  }
})

test_that("peg_catalogue() returns a tibble with rows", {
  skip_on_cran()
  skip_if_offline()

  result <- get_catalogue_fixture()
  expect_s3_class(result, "tbl_df")
  expect_gt(nrow(result), 0)
})

test_that("peg_catalogue() returns correct column names", {
  skip_on_cran()
  skip_if_offline()

  result <- get_catalogue_fixture()
  expect_named(
    result,
    c(
      "id",
      "name",
      "description",
      "category",
      "license_id",
      "created_at",
      "rows_updated_at",
      "view_last_modified",
      "publication_date",
      "index_updated_at",
      "row_count",
      "col_count",
      "download_count",
      "view_count",
      "group",
      "department",
      "update_frequency",
      "quality_rank",
      "license",
      "license_link",
      "tags",
      "url"
    )
  )
})

test_that("peg_catalogue() returns correct column types", {
  skip_on_cran()
  skip_if_offline()

  result <- get_catalogue_fixture()

  # character
  purrr::walk(
    c(
      "id",
      "name",
      "description",
      "category",
      "license_id",
      "group",
      "department",
      "update_frequency",
      "quality_rank",
      "license",
      "license_link",
      "url"
    ),
    \(col) expect_type(result[[col]], "character")
  )

  # dates
  purrr::walk(
    c(
      "created_at",
      "rows_updated_at",
      "view_last_modified",
      "publication_date",
      "index_updated_at"
    ),
    \(col) expect_s3_class(result[[col]], "Date")
  )

  # integer
  purrr::walk(
    c("row_count", "col_count", "download_count", "view_count"),
    \(col) expect_type(result[[col]], "integer")
  )

  # list-column
  expect_type(result$tags, "list")
})

test_that("peg_catalogue() content is valid", {
  skip_on_cran()
  skip_if_offline()

  result <- get_catalogue_fixture()

  # no missing ids
  expect_false(any(is.na(result$id)))

  # no missing categories
  expect_false(any(is.na(result$category)))

  # url format
  expect_true(all(startsWith(result$url, "https://data.winnipeg.ca/d/")))

  # row_count non-negative where present
  counts <- result$row_count[!is.na(result$row_count)]
  if (length(counts) > 0) {
    expect_true(all(counts >= 0L))
  }

  # col_count positive where present
  counts <- result$col_count[!is.na(result$col_count)]
  if (length(counts) > 0) {
    expect_true(all(counts > 0L))
  }

  # sorted descending by rows_updated_at
  dates <- result$rows_updated_at[!is.na(result$rows_updated_at)]
  if (length(dates) > 1) expect_true(all(diff(as.numeric(dates)) <= 0))
})

test_that("peg_catalogue() respects limit", {
  skip_on_cran()
  skip_if_offline()

  result <- get_catalogue_fixture()
  expect_lte(nrow(result), 5L)
})

test_that("peg_catalogue(limit = NULL) returns all datasets", {
  skip_on_cran()
  skip_if_offline()
  # run separately — this is the expensive call, only run explicitly
  # skip("expensive: run manually to verify full catalogue fetch")

  result <- peg_catalogue() |> suppressMessages()
  expect_gte(nrow(result), 50L)
})
