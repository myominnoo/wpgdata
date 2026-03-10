# =============================================================================
# test-peg_metadata.R
# =============================================================================

# ── Shared helpers ────────────────────────────────────────────────────────────

if (!exists("make_resp")) {
  make_resp <- function(body, status = 200L) {
    httr2::response(
      status_code = status,
      headers = list("Content-Type" = "application/json"),
      body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE))
    )
  }
}

# Build a /api/views response containing a `columns` array.
# Each entry in `cols` should be a list with name, fieldName, dataTypeName,
# and optionally description — matching the real Socrata schema.
metadata_resp <- function(cols) {
  make_resp(list(columns = cols))
}

# One fully-specified column entry.
make_col <- function(
  name = "Total Assessed Value",
  field_name = "total_assessed_value",
  type = "number",
  description = "The total assessed value of the property."
) {
  list(
    name = name,
    fieldName = field_name,
    dataTypeName = type,
    description = description
  )
}


# =============================================================================
# peg_metadata() — input validation
# =============================================================================

test_that("peg_metadata() rejects NULL dataset_id", {
  expect_error(peg_metadata(NULL), class = "rlang_error")
})

test_that("peg_metadata() rejects NA dataset_id", {
  expect_error(peg_metadata(NA_character_), class = "rlang_error")
})

test_that("peg_metadata() rejects empty string dataset_id", {
  expect_error(peg_metadata(""), class = "rlang_error")
})

test_that("peg_metadata() rejects non-character dataset_id", {
  expect_error(peg_metadata(123), class = "rlang_error")
  expect_error(peg_metadata(TRUE), class = "rlang_error")
  expect_error(peg_metadata(list("abc")), class = "rlang_error")
})

test_that("peg_metadata() rejects length > 1 dataset_id", {
  expect_error(peg_metadata(c("d4mq-wa44", "xxxx-yyyy")), class = "rlang_error")
})

test_that("peg_metadata() validation error mentions dataset_id", {
  expect_error(peg_metadata(""), regexp = "dataset_id")
})


# =============================================================================
# peg_metadata() — HTTP error handling
# =============================================================================

test_that("peg_metadata() aborts on HTTP 404", {
  local_mocked_bindings(
    req_perform = \(req, ...) make_resp(list(), status = 404L),
    .package = "httr2"
  )
  expect_error(peg_metadata("d4mq-wa44"), regexp = "404")
})

test_that("peg_metadata() aborts on HTTP 500", {
  local_mocked_bindings(
    req_perform = \(req, ...) make_resp(list(), status = 500L),
    .package = "httr2"
  )
  expect_error(peg_metadata("d4mq-wa44"), regexp = "500")
})

test_that("peg_metadata() aborts on HTTP 403", {
  local_mocked_bindings(
    req_perform = \(req, ...) make_resp(list(), status = 403L),
    .package = "httr2"
  )
  expect_error(peg_metadata("d4mq-wa44"), regexp = "403")
})


# =============================================================================
# peg_metadata() — happy path
# =============================================================================

test_that("peg_metadata() returns a tibble", {
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(list(make_col())),
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")
  expect_s3_class(out, "tbl_df")
})

test_that("peg_metadata() returns exactly four columns", {
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(list(make_col())),
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")
  expect_equal(names(out), c("name", "field_name", "type", "description"))
})

test_that("peg_metadata() returns one row per column in the schema", {
  cols <- list(
    make_col("Roll Number", "roll_number", "text"),
    make_col("Total Assessed Value", "total_assessed_value", "number"),
    make_col("Assessment Class", "assessment_class", "text")
  )
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(cols),
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")
  expect_equal(nrow(out), 3L)
})

test_that("peg_metadata() parses all fields correctly", {
  local_mocked_bindings(
    req_perform = \(req, ...) {
      metadata_resp(list(
        make_col(
          name = "Roll Number",
          field_name = "roll_number",
          type = "text",
          description = "Unique property roll number."
        )
      ))
    },
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")

  expect_equal(out$name[[1]], "Roll Number")
  expect_equal(out$field_name[[1]], "roll_number")
  expect_equal(out$type[[1]], "text")
  expect_equal(out$description[[1]], "Unique property roll number.")
})

test_that("peg_metadata() preserves row order from the schema", {
  cols <- list(
    make_col("Alpha", "alpha", "text"),
    make_col("Beta", "beta", "number"),
    make_col("Gamma", "gamma", "checkbox")
  )
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(cols),
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")
  expect_equal(out$field_name, c("alpha", "beta", "gamma"))
})


# =============================================================================
# peg_metadata() — missing / partial fields
# =============================================================================

test_that("peg_metadata() fills missing description with NA", {
  col_no_desc <- list(
    name = "Roll Number",
    fieldName = "roll_number",
    dataTypeName = "text"
    # no description field
  )
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(list(col_no_desc)),
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")
  expect_true(is.na(out$description[[1]]))
})

test_that("peg_metadata() fills missing name with NA", {
  col_no_name <- list(fieldName = "roll_number", dataTypeName = "text")
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(list(col_no_name)),
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")
  expect_true(is.na(out$name[[1]]))
})

test_that("peg_metadata() fills missing field_name with NA", {
  col_no_field <- list(name = "Roll Number", dataTypeName = "text")
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(list(col_no_field)),
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")
  expect_true(is.na(out$field_name[[1]]))
})

test_that("peg_metadata() fills missing type with NA", {
  col_no_type <- list(name = "Roll Number", fieldName = "roll_number")
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(list(col_no_type)),
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")
  expect_true(is.na(out$type[[1]]))
})

test_that("peg_metadata() handles mix of complete and partial column entries", {
  cols <- list(
    make_col("Roll Number", "roll_number", "text", "A full entry."),
    list(name = "Incomplete") # missing fieldName, dataTypeName, description
  )
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(cols),
    .package = "httr2"
  )
  out <- peg_metadata("d4mq-wa44")

  expect_equal(nrow(out), 2L)
  expect_equal(out$name[[1]], "Roll Number")
  expect_true(is.na(out$field_name[[2]]))
  expect_true(is.na(out$type[[2]]))
  expect_true(is.na(out$description[[2]]))
})


# =============================================================================
# peg_metadata() — empty / missing columns
# =============================================================================

test_that("peg_metadata() aborts when columns field is absent", {
  local_mocked_bindings(
    req_perform = \(req, ...) {
      make_resp(list(name = "Dataset with no columns key"))
    },
    .package = "httr2"
  )
  expect_error(peg_metadata("d4mq-wa44"), regexp = "No column properties")
})

test_that("peg_metadata() aborts when columns array is empty", {
  local_mocked_bindings(
    req_perform = \(req, ...) metadata_resp(list()),
    .package = "httr2"
  )
  expect_error(peg_metadata("d4mq-wa44"), regexp = "No column properties")
})


# =============================================================================
# parse_metadata() — unit tests
# =============================================================================

test_that("parse_metadata() aborts on malformed JSON", {
  bad_resp <- httr2::response(
    status_code = 200L,
    headers = list("Content-Type" = "application/json"),
    body = charToRaw("{not valid json")
  )
  expect_error(
    wpgdata:::parse_metadata(bad_resp),
    regexp = "Failed to parse metadata response as JSON"
  )
})

test_that("parse_metadata() aborts when columns is NULL", {
  resp <- make_resp(list(name = "No columns"))
  expect_error(
    wpgdata:::parse_metadata(resp),
    regexp = "No column properties"
  )
})

test_that("parse_metadata() returns a tibble with correct columns", {
  resp <- metadata_resp(list(make_col()))
  out <- wpgdata:::parse_metadata(resp)

  expect_s3_class(out, "tbl_df")
  expect_equal(names(out), c("name", "field_name", "type", "description"))
})

test_that("parse_metadata() returns one row per column entry", {
  cols <- list(make_col("A", "a", "text"), make_col("B", "b", "number"))
  resp <- metadata_resp(cols)
  out <- wpgdata:::parse_metadata(resp)
  expect_equal(nrow(out), 2L)
})
