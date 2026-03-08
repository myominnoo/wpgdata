# tests/testthat/test-peg_info.R

# Input validation tests --------------------------------------------------

test_that("peg_info() errors on empty dataset_id", {
  expect_error(peg_info(""), "non-empty string")
})

test_that("peg_info() errors on NULL dataset_id", {
  expect_error(peg_info(NULL), "non-empty string")
})

test_that("peg_info() errors on numeric dataset_id", {
  expect_error(peg_info(123), "character string")
})

test_that("peg_info() errors on missing dataset_id", {
  expect_error(peg_info(), "non-empty string")
})


# Output shape tests ------------------------------------------------------

test_that("peg_info() returns a tibble", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_info("d4mq-wa44")
  expect_s3_class(result, "tbl_df")
})

test_that("peg_info() returns one row", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_info("d4mq-wa44")
  expect_equal(nrow(result), 1)
})

test_that("peg_info() returns correct column names", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_info("d4mq-wa44")
  expect_named(
    result,
    c(
      "name",
      "description",
      "category",
      "created_at",
      "rows_updated_at",
      "view_last_modified",
      "view_count",
      "download_count",
      "tags",
      "license",
      "provenance"
    )
  )
})

test_that("peg_info() returns character name", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_info("d4mq-wa44")
  expect_type(result$name, "character")
})

test_that("peg_info() returns date columns", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_info("d4mq-wa44")
  expect_s3_class(result$created_at, "Date")
  expect_s3_class(result$rows_updated_at, "Date")
  expect_s3_class(result$view_last_modified, "Date")
})


# Bad dataset ID tests ----------------------------------------------------

test_that("peg_info() errors on invalid dataset_id", {
  skip_on_cran()
  skip_if_offline()

  expect_error(peg_info("invalid-id-000"), "404")
})
