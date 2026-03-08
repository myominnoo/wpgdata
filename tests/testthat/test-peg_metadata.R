# tests/testthat/test-peg_metadata.R

# Input validation tests --------------------------------------------------

test_that("peg_metadata() errors on empty dataset_id", {
  expect_error(peg_metadata(""), "non-empty string")
})

test_that("peg_metadata() errors on NULL dataset_id", {
  expect_error(peg_metadata(NULL), "non-empty string")
})

test_that("peg_metadata() errors on numeric dataset_id", {
  expect_error(peg_metadata(123), "character string")
})

test_that("peg_metadata() errors on missing dataset_id", {
  expect_error(peg_metadata(), "non-empty string")
})


# Output shape tests ------------------------------------------------------

test_that("peg_metadata() returns a tibble", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_metadata("d4mq-wa44")
  expect_s3_class(result, "tbl_df")
})

test_that("peg_metadata() returns correct column names", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_metadata("d4mq-wa44")
  expect_named(result, c("name", "field_name", "type", "description"))
})

test_that("peg_metadata() returns rows", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_metadata("d4mq-wa44")
  expect_gt(nrow(result), 0)
})

test_that("peg_metadata() returns character columns", {
  skip_on_cran()
  skip_if_offline()

  result <- peg_metadata("d4mq-wa44")
  expect_type(result$name, "character")
  expect_type(result$field_name, "character")
  expect_type(result$type, "character")
  expect_type(result$description, "character")
})


# Bad dataset ID tests ----------------------------------------------------

test_that("peg_metadata() errors on invalid dataset_id", {
  skip_on_cran()
  skip_if_offline()

  expect_error(peg_metadata("invalid-id-000"), "404")
})
