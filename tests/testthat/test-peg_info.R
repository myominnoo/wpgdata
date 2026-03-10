# =============================================================================
# test-peg_info.R
# =============================================================================

# ── Shared helpers ────────────────────────────────────────────────────────────

# Reuse make_resp() from test-peg_catalogue.R via testthat's helper loading,
# or redefine locally if this file is run in isolation.
if (!exists("make_resp")) {
  make_resp <- function(body, status = 200L) {
    httr2::response(
      status_code = status,
      headers = list("Content-Type" = "application/json"),
      body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE))
    )
  }
}

# Full /api/views response matching every field parse_info() reads.
full_info_resp <- function(
  name = "Winnipeg Transit Routes",
  description = "All active bus routes.",
  category = "Transportation",
  created_at = 1609459200L, # 2021-01-01 UTC
  updated_at = 1640995200L, # 2022-01-01 UTC
  view_count = 88L,
  dl_count = 12L,
  tags = list("transit", "routes"),
  license = "Public Domain",
  provenance = "official"
) {
  make_resp(list(
    name = name,
    description = description,
    category = category,
    createdAt = created_at,
    rowsUpdatedAt = updated_at,
    viewLastModified = updated_at,
    viewCount = view_count,
    downloadCount = dl_count,
    tags = tags,
    license = list(name = license, termsLink = "https://example.com"),
    provenance = provenance
  ))
}

# Simulate a network-level failure (curl timeout / DNS error).
net_error <- function(msg = "connection refused") {
  structure(simpleError(msg), class = c("error", "condition"))
}


# =============================================================================
# peg_info() — input validation
# =============================================================================

test_that("peg_info() rejects NULL dataset_id", {
  expect_error(peg_info(NULL), class = "rlang_error")
})

test_that("peg_info() rejects NA dataset_id", {
  expect_error(peg_info(NA_character_), class = "rlang_error")
})

test_that("peg_info() rejects empty string dataset_id", {
  expect_error(peg_info(""), class = "rlang_error")
})

test_that("peg_info() rejects non-character dataset_id", {
  expect_error(peg_info(123), class = "rlang_error")
  expect_error(peg_info(TRUE), class = "rlang_error")
  expect_error(peg_info(list("d4mq-wa44")), class = "rlang_error")
})

test_that("peg_info() rejects length > 1 dataset_id", {
  expect_error(peg_info(c("d4mq-wa44", "xxxx-yyyy")), class = "rlang_error")
})

test_that("peg_info() validation error mentions dataset_id argument", {
  expect_error(peg_info(""), regexp = "dataset_id")
})


# =============================================================================
# peg_info() — HTTP error handling
# =============================================================================

test_that("peg_info() aborts on HTTP 404", {
  local_mocked_bindings(
    req_perform = \(req, ...) make_resp(list(), status = 404L),
    .package = "httr2"
  )
  expect_error(peg_info("d4mq-wa44"), regexp = "404")
})

test_that("peg_info() aborts on HTTP 500", {
  local_mocked_bindings(
    req_perform = \(req, ...) make_resp(list(), status = 500L),
    .package = "httr2"
  )
  expect_error(peg_info("d4mq-wa44"), regexp = "500")
})

test_that("peg_info() aborts on HTTP 403", {
  local_mocked_bindings(
    req_perform = \(req, ...) make_resp(list(), status = 403L),
    .package = "httr2"
  )
  expect_error(peg_info("d4mq-wa44"), regexp = "403")
})


# =============================================================================
# peg_info() — happy path
# =============================================================================

test_that("peg_info() returns a one-row tibble", {
  local_mocked_bindings(
    req_perform = \(req, ...) full_info_resp(),
    .package = "httr2"
  )
  out <- peg_info("d4mq-wa44")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
})

test_that("peg_info() returns all expected columns", {
  local_mocked_bindings(
    req_perform = \(req, ...) full_info_resp(),
    .package = "httr2"
  )
  out <- peg_info("d4mq-wa44")

  expected_cols <- c(
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
  expect_true(all(expected_cols %in% names(out)))
})

test_that("peg_info() parses scalar fields correctly", {
  local_mocked_bindings(
    req_perform = \(req, ...) {
      full_info_resp(
        name = "Bus Routes",
        description = "Route data",
        category = "Transportation",
        view_count = 42L,
        dl_count = 7L,
        license = "Public Domain",
        provenance = "official"
      )
    },
    .package = "httr2"
  )
  out <- peg_info("d4mq-wa44")

  expect_equal(out$name, "Bus Routes")
  expect_equal(out$description, "Route data")
  expect_equal(out$category, "Transportation")
  expect_equal(out$view_count, 42L)
  expect_equal(out$download_count, 7L)
  expect_equal(out$license, "Public Domain")
  expect_equal(out$provenance, "official")
})

test_that("peg_info() parses timestamp fields as POSIXct", {
  local_mocked_bindings(
    req_perform = \(req, ...) {
      full_info_resp(
        created_at = 1609459200L,
        updated_at = 1640995200L
      )
    },
    .package = "httr2"
  )
  out <- peg_info("d4mq-wa44")

  expect_s3_class(out$created_at, "Date")
  expect_s3_class(out$rows_updated_at, "Date")
  expect_s3_class(out$view_last_modified, "Date")

  expect_equal(out$created_at, as.Date("2021-01-01"))
  expect_equal(out$rows_updated_at, as.Date("2022-01-01"))
})

test_that("peg_info() parses tags as a list column", {
  local_mocked_bindings(
    req_perform = \(req, ...) full_info_resp(tags = list("transit", "bus")),
    .package = "httr2"
  )
  out <- peg_info("d4mq-wa44")

  expect_true(is.list(out$tags))
  expect_equal(unlist(out$tags[[1]]), c("transit", "bus"))
})


# =============================================================================
# peg_info() — missing / partial fields
# =============================================================================

test_that("peg_info() fills missing optional fields with NA", {
  # Minimal response — only name, no other fields
  local_mocked_bindings(
    req_perform = \(req, ...) make_resp(list(name = "Minimal")),
    .package = "httr2"
  )
  out <- peg_info("d4mq-wa44")

  expect_equal(out$name, "Minimal")
  expect_true(is.na(out$description))
  expect_true(is.na(out$category))
  expect_true(is.na(out$view_count))
  expect_true(is.na(out$download_count))
  expect_true(is.na(out$license))
  expect_true(is.na(out$provenance))
})

test_that("peg_info() uses NA for missing tags", {
  local_mocked_bindings(
    req_perform = \(req, ...) make_resp(list(name = "No tags")),
    .package = "httr2"
  )
  out <- peg_info("d4mq-wa44")

  expect_true(is.list(out$tags))
  expect_true(all(is.na(unlist(out$tags))))
})

test_that("peg_info() handles missing license gracefully", {
  # Response has no license field at all
  local_mocked_bindings(
    req_perform = \(req, ...) make_resp(list(name = "No license")),
    .package = "httr2"
  )
  out <- peg_info("d4mq-wa44")
  expect_true(is.na(out$license))
})

test_that("peg_info() handles license object with no name field", {
  # license present but name sub-field missing
  local_mocked_bindings(
    req_perform = \(req, ...) {
      make_resp(list(
        name = "Test",
        license = list(termsLink = "https://example.com") # no $name
      ))
    },
    .package = "httr2"
  )
  out <- peg_info("d4mq-wa44")
  expect_true(is.na(out$license))
})


# =============================================================================
# parse_info() — unit tests
# =============================================================================

test_that("parse_info() aborts on malformed JSON body", {
  bad_resp <- httr2::response(
    status_code = 200L,
    headers = list("Content-Type" = "application/json"),
    body = charToRaw("{not valid json")
  )
  expect_error(
    wpgdata:::parse_info(bad_resp),
    regexp = "Failed to parse server response as JSON"
  )
})

test_that("parse_info() returns a one-row tibble from a valid response", {
  out <- wpgdata:::parse_info(full_info_resp())
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
})

test_that("parse_info() returns all expected columns", {
  out <- wpgdata:::parse_info(full_info_resp())
  expected_cols <- c(
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
  expect_true(all(expected_cols %in% names(out)))
})

test_that("parse_info() returns exactly 11 columns", {
  out <- wpgdata:::parse_info(full_info_resp())
  expect_equal(ncol(out), 11L)
})
