# tests/testthat/test-peg_get.R

# Input validation tests --------------------------------------------------

test_that("peg_get() errors on empty dataset_id", {
  expect_error(peg_get(""), "non-empty string")
})

test_that("peg_get() errors on NULL dataset_id", {
  expect_error(peg_get(NULL), "non-empty string")
})

test_that("peg_get() errors on numeric dataset_id", {
  expect_error(peg_get(123), "character string")
})

test_that("peg_get() errors on missing dataset_id", {
  expect_error(peg_get(), "non-empty string")
})


# Output shape tests ------------------------------------------------------

test_that("peg_get() returns a tibble", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_get("d4mq-wa44"))
  expect_s3_class(result, "tbl_df")
})

test_that("peg_get() returns rows", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_get("d4mq-wa44"))
  expect_gt(nrow(result), 0)
})

test_that("peg_get() returns columns", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_get("d4mq-wa44"))
  expect_gt(ncol(result), 0)
})

# Pagination warning tests ------------------------------------------------

test_that("peg_get() warns when results are paginated", {
  skip_on_cran()
  skip_if_offline()

  expect_warning(peg_get("d4mq-wa44"), "paginated")
})


# Bad dataset ID tests ----------------------------------------------------

test_that("peg_get() errors on invalid dataset_id", {
  skip_on_cran()
  skip_if_offline()

  expect_error(peg_get("invalid-id-000"), "404")
})
