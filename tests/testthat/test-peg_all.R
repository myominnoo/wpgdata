# tests/testthat/test-peg_all.R

# Input validation tests - dataset_id ------------------------------------

test_that("peg_all() errors on empty dataset_id", {
  expect_error(peg_all(""), "non-empty string")
})

test_that("peg_all() errors on NULL dataset_id", {
  expect_error(peg_all(NULL), "non-empty string")
})

test_that("peg_all() errors on numeric dataset_id", {
  expect_error(peg_all(123), "character string")
})

test_that("peg_all() errors on missing dataset_id", {
  expect_error(peg_all(), "non-empty string")
})


# Input validation tests - max_pages -------------------------------------

test_that("peg_all() errors on non-numeric max_pages", {
  expect_error(peg_all("d4mq-wa44", max_pages = "3"), "positive number")
})

test_that("peg_all() errors on negative max_pages", {
  expect_error(peg_all("d4mq-wa44", max_pages = -1), "positive number")
})

test_that("peg_all() errors on zero max_pages", {
  expect_error(peg_all("d4mq-wa44", max_pages = 0), "positive number")
})


# Output shape tests ------------------------------------------------------

test_that("peg_all() returns a tibble", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_all("d4mq-wa44", max_pages = 1))
  expect_s3_class(result, "tbl_df")
})

test_that("peg_all() returns rows", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_all("d4mq-wa44", max_pages = 1))
  expect_gt(nrow(result), 0)
})

test_that("peg_all() returns columns", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_all("d4mq-wa44", max_pages = 1))
  expect_gt(ncol(result), 0)
})

test_that("peg_all() does not contain @odata.id column", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_all("d4mq-wa44", max_pages = 1))
  expect_false("@odata.id" %in% names(result))
})


# Pagination tests --------------------------------------------------------

test_that("peg_all() returns more rows with more pages", {
  skip_on_cran()
  skip_if_offline()

  result_1 <- suppressWarnings(peg_all("d4mq-wa44", max_pages = 1))
  result_2 <- suppressWarnings(peg_all("d4mq-wa44", max_pages = 2))
  expect_gt(nrow(result_2), nrow(result_1))
})

test_that("peg_all() warns when stopped before all pages fetched", {
  skip_on_cran()
  skip_if_offline()

  expect_warning(peg_all("d4mq-wa44", max_pages = 1), "Stopped after")
})

test_that("peg_all() max_pages = 1 returns rows", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_all("d4mq-wa44", max_pages = 1))
  expect_gt(nrow(result), 0)
})


# Inf max_pages test ------------------------------------------------------

test_that("peg_all() accepts Inf as max_pages without error", {
  skip_on_cran()
  skip_if_offline()

  expect_no_error(suppressWarnings(peg_all("d4mq-wa44", max_pages = 1)))
})


# Bad dataset ID tests ----------------------------------------------------

test_that("peg_all() errors on invalid dataset_id", {
  skip_on_cran()
  skip_if_offline()

  expect_error(peg_all("invalid-id-000"), "404")
})
