test_that("peg_query() top limits rows returned", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_query("d4mq-wa44", top = 5))
  expect_equal(nrow(result), 5)
})

test_that("peg_query() select limits columns returned", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_query(
    "d4mq-wa44",
    select = c("roll_number", "total_assessed_value"),
    top = 5
  ))
  expect_named(result, c("roll_number", "total_assessed_value"))
})

test_that("peg_query() skip offsets rows", {
  skip_on_cran()
  skip_if_offline()

  result_a <- suppressWarnings(peg_query("d4mq-wa44", top = 5, skip = 0))
  result_b <- suppressWarnings(peg_query("d4mq-wa44", top = 5, skip = 5))
  expect_false(identical(result_a, result_b))
})

test_that("peg_query() R expression filter returns a tibble", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_query(
    "d4mq-wa44",
    filter = total_assessed_value > 500000,
    top = 5
  ))
  expect_s3_class(result, "tbl_df")
})

test_that("peg_query() raw OData filter returns a tibble", {
  skip_on_cran()
  skip_if_offline()

  result <- suppressWarnings(peg_query(
    "d4mq-wa44",
    filter = "total_assessed_value gt 500000",
    top = 5
  ))
  expect_s3_class(result, "tbl_df")
})

test_that("peg_query() R and raw OData filters return same result", {
  skip_on_cran()
  skip_if_offline()

  result_r <- suppressWarnings(peg_query(
    "d4mq-wa44",
    filter = total_assessed_value > 500000,
    top = 5
  ))
  result_odata <- suppressWarnings(peg_query(
    "d4mq-wa44",
    filter = "total_assessed_value gt 500000",
    top = 5
  ))
  expect_equal(result_r, result_odata)
})
