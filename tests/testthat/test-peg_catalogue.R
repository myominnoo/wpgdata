# tests/testthat/test-peg_catalogue.R

# Input validation tests - limit -----------------------------------------

test_that("peg_catalogue() errors on non-numeric limit", {
  expect_error(peg_catalogue(limit = "200"), "positive integer")
})

test_that("peg_catalogue() errors on negative limit", {
  expect_error(peg_catalogue(limit = -1), "positive integer")
})

test_that("peg_catalogue() errors on zero limit", {
  expect_error(peg_catalogue(limit = 0), "positive integer")
})

test_that("peg_catalogue() accepts NULL limit", {
  expect_no_error(peg_catalogue(limit = NULL) |> suppressMessages())
})


# Output shape tests ------------------------------------------------------

test_that("peg_catalogue() returns a tibble", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = 10) |> suppressMessages()
  expect_s3_class(result, "tbl_df")
})

test_that("peg_catalogue() returns correct column names", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = 10) |> suppressMessages()
  expect_named(
    result,
    c(
      "name",
      "id",
      "description",
      "category",
      "updated_at",
      "row_count",
      "url"
    )
  )
})

test_that("peg_catalogue() returns rows", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = 10) |> suppressMessages()
  expect_gt(nrow(result), 0)
})

test_that("peg_catalogue() respects limit", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = 10) |> suppressMessages()
  expect_lte(nrow(result), 10)
})


# Column type tests -------------------------------------------------------

test_that("peg_catalogue() returns correct column types", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = 10) |> suppressMessages()
  expect_type(result$name, "character")
  expect_type(result$id, "character")
  expect_type(result$description, "character")
  expect_type(result$category, "character")
  expect_type(result$url, "character")
  expect_s3_class(result$updated_at, "POSIXct")
})


# Content tests -----------------------------------------------------------

test_that("peg_catalogue() url column starts with correct base", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = 10) |> suppressMessages()
  expect_true(all(startsWith(result$url, "https://data.winnipeg.ca/d/")))
})

test_that("peg_catalogue() has no missing ids", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = 10) |> suppressMessages()
  expect_false(any(is.na(result$id)))
})

test_that("peg_catalogue() category has no NAs", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = 10) |> suppressMessages()
  expect_false(any(is.na(result$category)))
})

test_that("peg_catalogue() is sorted by updated_at descending", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = 20) |> suppressMessages()
  expect_true(all(diff(as.numeric(result$updated_at)) <= 0))
})


# Pagination tests --------------------------------------------------------

test_that("peg_catalogue() limit = NULL returns more rows than limit = 100", {
  skip_on_cran()
  skip_if_offline()

  result_100 <- peg_catalogue(limit = 100) |> suppressMessages()
  result_all <- peg_catalogue(limit = NULL) |> suppressMessages()
  expect_gt(nrow(result_all), nrow(result_100))
})

test_that("peg_catalogue() limit = NULL returns all datasets", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_catalogue(limit = NULL) |> suppressMessages()
  expect_gte(nrow(result), 200)
})
