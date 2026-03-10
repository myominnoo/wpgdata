# =============================================================================
# test-peg_catalogue.R
# =============================================================================

# ── Shared helpers ────────────────────────────────────────────────────────────

# Build a minimal httr2 response with a JSON body.
make_resp <- function(body, status = 200L) {
  httr2::response(
    status_code = status,
    headers = list("Content-Type" = "application/json"),
    body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE))
  )
}

# Socrata catalogue count response: {"resultSetSize": n}
count_resp <- function(n) {
  make_resp(list(resultSetSize = n))
}

# One catalogue page with `n` synthetic dataset entries.
# Each entry has a resource.id field as the real API returns.
catalogue_page_resp <- function(ids) {
  results <- lapply(ids, \(id) list(resource = list(id = id)))
  make_resp(list(results = results))
}

# Minimal /api/views metadata response for one dataset.
# All optional fields are included so fetch_metadata_parse() fills every column.
meta_resp <- function(id, name = paste0("Dataset ", id)) {
  make_resp(list(
    name = name,
    description = paste0("Description for ", id),
    category = "Transportation",
    licenseId = "PUBLIC_DOMAIN",
    createdAt = 1609459200L, # 2021-01-01
    rowsUpdatedAt = 1640995200L, # 2022-01-01
    viewLastModified = 1640995200L,
    publicationDate = 1609459200L,
    indexUpdatedAt = 1640995200L,
    downloadCount = 42L,
    viewCount = 100L,
    columns = list(
      list(cachedContents = list(count = "500"))
    ),
    license = list(name = "Public Domain", termsLink = "https://example.com"),
    tags = list("transit", "open-data"),
    metadata = list(
      custom_fields = list(
        Department = list(Group = "Infrastructure", Department = "Transit"),
        `Update Frequency` = list(Interval = "Monthly"),
        Quality = list(Rank = "Gold")
      )
    )
  ))
}

# Network-level error condition (simulates curl timeout / DNS failure).
net_error <- function(msg = "connection refused") {
  structure(simpleError(msg), class = c("error", "condition"))
}

# Convenience: build a full bootstrap list (count + page0) plus optional
# subsequent parallel call responses. `call_n` increments each time
# req_perform_parallel is invoked so tests can return different responses
# for the bootstrap vs later calls.
make_parallel_mock <- function(bootstrap, subsequent = list()) {
  call_count <- 0L
  function(reqs, ...) {
    call_count <<- call_count + 1L
    if (call_count == 1L) bootstrap else subsequent[[call_count - 1L]]
  }
}


# =============================================================================
# peg_catalogue() — input validation
# =============================================================================

test_that("peg_catalogue() rejects invalid `limit`", {
  expect_error(peg_catalogue(limit = 0), class = "rlang_error")
  expect_error(peg_catalogue(limit = -1), class = "rlang_error")
  expect_error(peg_catalogue(limit = "10"), class = "rlang_error")
  expect_error(peg_catalogue(limit = c(1, 2)), class = "rlang_error")
  expect_error(peg_catalogue(limit = NA_real_), class = "rlang_error")
})

test_that("peg_catalogue() rejects invalid `max_connections`", {
  expect_error(peg_catalogue(max_connections = 0), class = "rlang_error")
  expect_error(peg_catalogue(max_connections = -1), class = "rlang_error")
  expect_error(peg_catalogue(max_connections = "5"), class = "rlang_error")
  expect_error(peg_catalogue(max_connections = c(4, 8)), class = "rlang_error")
})

test_that("peg_catalogue() accepts NULL for both args without error", {
  local_mocked_bindings(
    req_perform_parallel = make_parallel_mock(
      bootstrap = list(
        count_resp(3L),
        catalogue_page_resp(c("aa", "bb", "cc"))
      ),
      subsequent = list(list(meta_resp("aa"), meta_resp("bb"), meta_resp("cc")))
    ),
    .package = "httr2"
  )
  expect_no_error(suppressMessages(peg_catalogue()))
})


# =============================================================================
# peg_catalogue() — count / empty catalogue
# =============================================================================

test_that("peg_catalogue() aborts when count request fails at network level", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(net_error("timeout"), make_resp(list()))
    },
    .package = "httr2"
  )
  expect_error(peg_catalogue(), regexp = "Catalogue count request failed")
})

test_that("peg_catalogue() aborts on HTTP 404 for count", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(
        make_resp(list(), status = 404L),
        catalogue_page_resp("aa")
      )
    },
    .package = "httr2"
  )
  expect_error(peg_catalogue(), regexp = "404")
})

test_that("peg_catalogue() aborts when resultSetSize is NULL", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(
        make_resp(list(other = 1L)), # no resultSetSize field
        catalogue_page_resp("aa")
      )
    },
    .package = "httr2"
  )
  expect_error(peg_catalogue(), regexp = "Unexpected catalogue count")
})

test_that("peg_catalogue() aborts when catalogue returns 0 datasets", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(
        count_resp(0L),
        catalogue_page_resp(character(0))
      )
    },
    .package = "httr2"
  )
  expect_error(peg_catalogue(), regexp = "0 datasets")
})

test_that("peg_catalogue() aborts when page0 request fails at network level", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(5L), net_error()),
    .package = "httr2"
  )
  expect_error(peg_catalogue(), regexp = "First catalogue page request failed")
})


# =============================================================================
# peg_catalogue() — single page (≤ 100 datasets)
# =============================================================================

test_that("peg_catalogue() returns a tibble for a single-page catalogue", {
  ids <- c("aa-11", "bb-22", "cc-33")

  call_count <- 0L
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(3L), catalogue_page_resp(ids))
      } else {
        lapply(ids, meta_resp)
      }
    },
    .package = "httr2"
  )

  out <- suppressMessages(peg_catalogue())

  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 3L)
  expect_true("id" %in% names(out))
})

test_that("peg_catalogue() adds `url` column with correct prefix", {
  ids <- c("aa-11")

  call_count <- 0L
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(1L), catalogue_page_resp(ids))
      } else {
        lapply(ids, meta_resp)
      }
    },
    .package = "httr2"
  )

  out <- suppressMessages(peg_catalogue())

  expect_true("url" %in% names(out))
  expect_true(startsWith(out$url[[1]], "https://data.winnipeg.ca/d/"))
  expect_equal(out$url[[1]], "https://data.winnipeg.ca/d/aa-11")
})

test_that("peg_catalogue() fills `category` as 'Uncategorized' when missing", {
  id <- "xx-99"

  call_count <- 0L
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(1L), catalogue_page_resp(id))
      } else {
        # metadata with no category field
        list(make_resp(list(name = "Test", columns = list())))
      }
    },
    .package = "httr2"
  )

  out <- suppressMessages(peg_catalogue())

  expect_equal(out$category[[1]], "Uncategorized")
})

test_that("peg_catalogue() result is arranged by rows_updated_at descending", {
  ids <- c("old-1", "new-2", "mid-3")

  # Unix timestamps must be days apart — .parse_unix() truncates to Date,
  # so values within the same day (e.g. 1000, 2000, 3000 seconds) all
  # produce the same date and arrange() preserves original order.
  call_count <- 0L
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(3L), catalogue_page_resp(ids))
      } else {
        list(
          make_resp(list(
            name = "Old",
            rowsUpdatedAt = 1000000L,
            columns = list()
          )),
          make_resp(list(
            name = "New",
            rowsUpdatedAt = 3000000L,
            columns = list()
          )),
          make_resp(list(
            name = "Mid",
            rowsUpdatedAt = 2000000L,
            columns = list()
          ))
        )
      }
    },
    .package = "httr2"
  )

  out <- suppressMessages(peg_catalogue())

  expect_equal(out$name[[1]], "New")
  expect_equal(out$name[[2]], "Mid")
  expect_equal(out$name[[3]], "Old")
})


# =============================================================================
# peg_catalogue() — `limit` argument
# =============================================================================

test_that("peg_catalogue() respects `limit` smaller than total", {
  ids <- paste0("id-", seq_len(50L))

  call_count <- 0L
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(200L), catalogue_page_resp(ids))
      } else {
        lapply(seq_len(length(reqs)), \(i) meta_resp(paste0("id-", i)))
      }
    },
    .package = "httr2"
  )

  out <- suppressMessages(peg_catalogue(limit = 50L))

  expect_equal(nrow(out), 50L)
})

test_that("peg_catalogue() handles `limit` larger than total gracefully", {
  ids <- c("aa", "bb", "cc")

  call_count <- 0L
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(3L), catalogue_page_resp(ids))
      } else {
        lapply(ids, meta_resp)
      }
    },
    .package = "httr2"
  )

  out <- suppressMessages(peg_catalogue(limit = 9999L))

  expect_equal(nrow(out), 3L)
})


# =============================================================================
# peg_catalogue() — `max_connections` auto-detect
# =============================================================================

test_that("peg_catalogue() auto-detects max_connections capped at .MAX_CONNECTIONS", {
  local_mocked_bindings(
    detectCores = \(...) 32L,
    .package = "parallel"
  )

  ids <- c("aa", "bb")
  call_count <- 0L
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(2L), catalogue_page_resp(ids))
      } else {
        lapply(ids, meta_resp)
      }
    },
    .package = "httr2"
  )

  # 32 cores * 2 = 64, capped at .MAX_CONNECTIONS = 20
  expect_message(peg_catalogue(), regexp = "20 \\(auto\\)")
})

test_that("peg_catalogue() labels manual max_connections correctly", {
  ids <- c("aa", "bb")
  call_count <- 0L
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(2L), catalogue_page_resp(ids))
      } else {
        lapply(ids, meta_resp)
      }
    },
    .package = "httr2"
  )

  expect_message(
    peg_catalogue(max_connections = 5L),
    regexp = "5 \\(manual\\)"
  )
})


# =============================================================================
# extract_ids_from_pages()
# =============================================================================

test_that("extract_ids_from_pages() returns correct IDs from valid responses", {
  resps <- list(
    catalogue_page_resp(c("aa-11", "bb-22")),
    catalogue_page_resp(c("cc-33"))
  )
  ids <- wpgdata:::extract_ids_from_pages(resps)
  expect_equal(sort(ids), sort(c("aa-11", "bb-22", "cc-33")))
})

test_that("extract_ids_from_pages() deduplicates overlapping IDs", {
  resps <- list(
    catalogue_page_resp(c("aa-11", "bb-22")),
    catalogue_page_resp(c("bb-22", "cc-33")) # bb-22 appears in both pages
  )
  ids <- wpgdata:::extract_ids_from_pages(resps)
  expect_equal(length(ids), 3L)
  expect_false(any(duplicated(ids)))
})

test_that("extract_ids_from_pages() warns and skips failed pages", {
  resps <- list(
    catalogue_page_resp(c("aa-11")),
    net_error("timeout")
  )
  # Two warnings fire: per-page ("failed: timeout") + summary ("incomplete").
  # capture_warnings() collects all without suppressing any.
  warns <- testthat::capture_warnings(
    ids <- wpgdata:::extract_ids_from_pages(resps)
  )
  expect_true(any(grepl("failed|incomplete", warns)))
  expect_equal(ids, "aa-11")
})

test_that("extract_ids_from_pages() warns on HTTP error pages", {
  resps <- list(
    catalogue_page_resp(c("aa-11")),
    make_resp(list(), status = 503L)
  )
  warns <- testthat::capture_warnings(
    ids <- wpgdata:::extract_ids_from_pages(resps)
  )
  expect_true(any(grepl("503|incomplete", warns)))
  expect_equal(ids, "aa-11")
})

test_that("extract_ids_from_pages() aborts when all pages fail", {
  resps <- list(net_error(), net_error())
  expect_error(
    suppressWarnings(wpgdata:::extract_ids_from_pages(resps)),
    regexp = "All.*failed"
  )
})

test_that("extract_ids_from_pages() warns and skips pages with empty results", {
  resps <- list(
    catalogue_page_resp(c("aa-11")),
    make_resp(list(results = list()))
  )
  expect_warning(
    ids <- wpgdata:::extract_ids_from_pages(resps),
    regexp = "no results"
  )
  expect_equal(ids, "aa-11")
})

test_that("extract_ids_from_pages() drops NA IDs silently", {
  # Resource entry with no id field returns NA via %||% NA_character_
  resp <- make_resp(list(
    results = list(
      list(resource = list(id = "aa-11")),
      list(resource = list(other = "junk")) # no id → NA
    )
  ))
  ids <- wpgdata:::extract_ids_from_pages(list(resp))
  expect_equal(ids, "aa-11")
})


# =============================================================================
# fetch_metadata_parallel()
# =============================================================================

test_that("fetch_metadata_parallel() aborts on empty ids", {
  expect_error(
    wpgdata:::fetch_metadata_parallel(character(0)),
    class = "rlang_error"
  )
})

test_that("fetch_metadata_parallel() returns one row per ID", {
  ids <- c("aa-11", "bb-22", "cc-33")
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) lapply(ids, meta_resp),
    .package = "httr2"
  )
  out <- suppressMessages(wpgdata:::fetch_metadata_parallel(ids))
  expect_equal(nrow(out), 3L)
})

test_that("fetch_metadata_parallel() returns stub row for network errors", {
  ids <- c("aa-11", "bb-22")
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(meta_resp("aa-11"), net_error()),
    .package = "httr2"
  )
  expect_warning(
    out <- suppressMessages(wpgdata:::fetch_metadata_parallel(ids)),
    regexp = "failed"
  )
  # Both rows present — failed one has stub with only id
  expect_equal(nrow(out), 2L)
  expect_true("id" %in% names(out))
})

test_that("fetch_metadata_parallel() returns stub row for HTTP 404", {
  ids <- c("aa-11", "bb-22")
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(
        meta_resp("aa-11"),
        make_resp(list(), status = 404L)
      )
    },
    .package = "httr2"
  )
  expect_warning(
    out <- suppressMessages(wpgdata:::fetch_metadata_parallel(ids)),
    regexp = "404"
  )
  expect_equal(nrow(out), 2L)
})

test_that("fetch_metadata_parallel() returns stub row for HTTP 429", {
  ids <- c("aa-11")
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(make_resp(list(), status = 429L)),
    .package = "httr2"
  )
  expect_warning(
    out <- suppressMessages(wpgdata:::fetch_metadata_parallel(ids)),
    regexp = "429"
  )
  expect_equal(nrow(out), 1L)
})


# =============================================================================
# fetch_metadata_parse()
# =============================================================================

test_that("fetch_metadata_parse() returns all expected columns", {
  resp <- meta_resp("aa-11")
  out <- wpgdata:::fetch_metadata_parse(resp, "aa-11")

  expected_cols <- c(
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
    "tags"
  )
  expect_true(all(expected_cols %in% names(out)))
})

test_that("fetch_metadata_parse() returns stub on empty body", {
  # httr2::resp_body_raw() throws when the body is truly empty, so mock it
  # to return raw(0) — the value fetch_metadata_parse() checks against.
  local_mocked_bindings(
    resp_body_raw = \(resp) raw(0),
    .package = "httr2"
  )
  expect_warning(
    out <- wpgdata:::fetch_metadata_parse(list(), "aa-11"),
    regexp = "Empty response"
  )
  expect_equal(out$id, "aa-11")
  expect_equal(ncol(out), 1L)
})

test_that("fetch_metadata_parse() returns stub on malformed JSON", {
  bad_resp <- httr2::response(
    status_code = 200L,
    headers = list("Content-Type" = "application/json"),
    body = charToRaw("{not valid json")
  )
  expect_warning(
    out <- wpgdata:::fetch_metadata_parse(bad_resp, "aa-11"),
    regexp = "Failed to parse JSON"
  )
  expect_equal(out$id, "aa-11")
  expect_equal(ncol(out), 1L)
})

test_that("fetch_metadata_parse() handles NULL columns safely", {
  resp <- make_resp(list(name = "Test", columns = NULL))
  out <- wpgdata:::fetch_metadata_parse(resp, "aa-11")
  expect_true(is.na(out$row_count))
  expect_equal(out$col_count, 0L)
})

test_that("fetch_metadata_parse() handles missing optional fields with NA", {
  # Minimal response — only name, no dates, engagement, or custom fields
  resp <- make_resp(list(name = "Minimal", columns = list()))
  out <- wpgdata:::fetch_metadata_parse(resp, "aa-11")

  expect_true(is.na(out$description))
  expect_true(is.na(out$category))
  expect_true(is.na(out$download_count))
  expect_true(is.na(out$group))
  expect_true(is.na(out$department))
})

test_that("fetch_metadata_parse() parses tags as a list column", {
  resp <- meta_resp("aa-11")
  out <- wpgdata:::fetch_metadata_parse(resp, "aa-11")
  expect_true(is.list(out$tags))
  # JSON round-trip returns a list; unlist to compare as character vector
  expect_equal(unlist(out$tags[[1]]), c("transit", "open-data"))
})

test_that("fetch_metadata_parse() returns a one-row tibble", {
  resp <- meta_resp("aa-11")
  out <- wpgdata:::fetch_metadata_parse(resp, "aa-11")
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 1L)
})


# =============================================================================
# build_catalogue_request()
# =============================================================================

test_that("build_catalogue_request() rejects negative offset", {
  expect_error(
    wpgdata:::build_catalogue_request(offset = -1L, limit = 10L),
    class = "rlang_error"
  )
})

test_that("build_catalogue_request() rejects zero limit", {
  expect_error(
    wpgdata:::build_catalogue_request(offset = 0L, limit = 0L),
    class = "rlang_error"
  )
})

test_that("build_catalogue_request() returns an httr2 request object", {
  req <- wpgdata:::build_catalogue_request(offset = 0L, limit = 50L)
  expect_s3_class(req, "httr2_request")
})
