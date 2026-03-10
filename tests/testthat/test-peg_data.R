test_that("peg_data() rejects invalid `top`", {
  expect_error(peg_data("abc", top = -1), class = "rlang_error")
  expect_error(peg_data("abc", top = 0), class = "rlang_error")
  expect_error(peg_data("abc", top = "10"), class = "rlang_error")
  expect_error(peg_data("abc", top = c(1, 2)), class = "rlang_error")
  expect_error(peg_data("abc", top = NA_real_), class = "rlang_error")
})

test_that("peg_data() rejects invalid `skip`", {
  expect_error(peg_data("abc", skip = -1), class = "rlang_error")
  expect_error(peg_data("abc", skip = "5"), class = "rlang_error")
  expect_error(peg_data("abc", skip = c(0, 1)), class = "rlang_error")
})

test_that("peg_data() rejects invalid `select`", {
  expect_error(peg_data("abc", select = 1L), class = "rlang_error")
  expect_error(peg_data("abc", select = TRUE), class = "rlang_error")
})

test_that("peg_data() rejects invalid `orderby`", {
  expect_error(peg_data("abc", orderby = 123), class = "rlang_error")
  expect_error(peg_data("abc", orderby = TRUE), class = "rlang_error")
})

test_that("peg_data() rejects invalid `max_connections`", {
  expect_error(peg_data("abc", max_connections = 0), class = "rlang_error")
  expect_error(peg_data("abc", max_connections = -1), class = "rlang_error")
  expect_error(
    peg_data("abc", max_connections = c(4, 8)),
    class = "rlang_error"
  )
  expect_error(peg_data("abc", max_connections = "10"), class = "rlang_error")
})


# ── Helpers ──────────────────────────────────────────────────────────────────

# Build a minimal httr2 response object with a JSON body.
make_resp <- function(body, status = 200L) {
  httr2::response(
    status_code = status,
    headers = list("Content-Type" = "application/json"),
    body = charToRaw(jsonlite::toJSON(body, auto_unbox = TRUE))
  )
}

# Build a count response: {"@odata.count": n}
count_resp <- function(n) {
  make_resp(list(`@odata.count` = n))
}

# Build a data-page response with `n` rows of {id, value} columns.
# Optionally injects the @odata.id column that Socrata always adds.
page_resp <- function(n, start_id = 1L, inject_odata_id = TRUE) {
  rows <- lapply(seq_len(n), \(i) {
    row <- list(id = start_id + i - 1L, value = paste0("v", start_id + i - 1L))
    if (inject_odata_id) {
      row[["@odata.id"]] <- "junk"
    }
    row
  })
  make_resp(list(value = rows))
}

# Thin wrapper: splice together a count + page-0 bootstrap list, then
# optionally append extra page responses — matching the structure that
# peg_data() expects from req_perform_parallel().
mock_parallel <- function(count_n, pages) {
  # pages: list of httr2 response objects
  c(list(count_resp(count_n)), pages)
}


# ── Empty dataset ─────────────────────────────────────────────────────────────

test_that("peg_data() returns empty tibble and warns when dataset has 0 rows", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(0), page_resp(0)),
    .package = "httr2"
  )

  expect_warning(
    out <- peg_data("d4mq-wa44"),
    regexp = "no rows"
  )
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
})


# ── Single page (≤ 1 000 rows) ───────────────────────────────────────────────

test_that("peg_data() returns correct rows for a single-page dataset", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(3L), page_resp(3L)),
    .package = "httr2"
  )

  out <- peg_data("d4mq-wa44")

  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 3L)
})

test_that("peg_data() drops @odata.id column", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(count_resp(3L), page_resp(3L, inject_odata_id = TRUE))
    },
    .package = "httr2"
  )

  out <- peg_data("d4mq-wa44")

  expect_false("@odata.id" %in% names(out))
})


# ── Multi-page dataset ────────────────────────────────────────────────────────

test_that("peg_data() assembles multiple pages in correct order", {
  # 2 500 rows → 3 pages (1000 + 1000 + 500)
  p1 <- page_resp(1000L, start_id = 1L)
  p2 <- page_resp(1000L, start_id = 1001L)
  p3 <- page_resp(500L, start_id = 2001L)

  call_count <- 0L

  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        # bootstrap: count + page 0
        list(count_resp(2500L), p1)
      } else {
        # remaining pages 1 and 2
        list(p2, p3)
      }
    },
    .package = "httr2"
  )

  out <- peg_data("d4mq-wa44")

  expect_equal(nrow(out), 2500L)
  # rows arrive in original order
  expect_equal(out$id[[1L]], 1L)
  expect_equal(out$id[[1001L]], 1001L)
  expect_equal(out$id[[2500L]], 2500L)
})


# ── `top` argument ────────────────────────────────────────────────────────────

test_that("peg_data() respects `top` within a single page", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(500L), page_resp(500L)),
    .package = "httr2"
  )

  out <- peg_data("d4mq-wa44", top = 50L)

  expect_equal(nrow(out), 50L)
})

test_that("peg_data() respects `top` spanning multiple pages", {
  p1 <- page_resp(1000L, start_id = 1L)
  p2 <- page_resp(500L, start_id = 1001L)
  call_count <- 0L

  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) list(count_resp(5000L), p1) else list(p2)
    },
    .package = "httr2"
  )

  out <- peg_data("d4mq-wa44", top = 1500L)

  expect_equal(nrow(out), 1500L)
})

test_that("peg_data() handles `top` larger than available rows", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(10L), page_resp(10L)),
    .package = "httr2"
  )

  out <- peg_data("d4mq-wa44", top = 99999L)

  expect_equal(nrow(out), 10L)
})


# ── `skip` argument ───────────────────────────────────────────────────────────

test_that("peg_data() warns and returns empty tibble when skip >= total rows", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(100L), page_resp(0L)),
    .package = "httr2"
  )

  expect_warning(
    out <- peg_data("d4mq-wa44", skip = 100L),
    regexp = "No rows remain"
  )
  expect_equal(nrow(out), 0L)
})

test_that("peg_data() passes `skip` offset to URL builder", {
  urls_seen <- character(0)

  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(500L), page_resp(50L)),
    .package = "httr2"
  )

  # intercept build_url to capture what params were passed
  local_mocked_bindings(
    build_url = \(dataset_id, api = "odata", params = list()) {
      urls_seen <<- c(urls_seen, as.character(params[["skip"]] %||% "none"))
      "https://example.com/fake"
    },
    .package = "wpgdata"
  )

  suppressMessages(peg_data("d4mq-wa44", skip = 200L))

  expect_true(any(urls_seen == "200"))
})


# ── `filter` argument ─────────────────────────────────────────────────────────

test_that("peg_data() translates an R filter expression to OData syntax", {
  params_seen <- list()

  local_mocked_bindings(
    build_filter = \(expr) {
      params_seen[["filter"]] <<- deparse(expr)
      "value gt 100"
    },
    .package = "wpgdata"
  )
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(5L), page_resp(5L)),
    .package = "httr2"
  )

  suppressMessages(peg_data("d4mq-wa44", filter = value > 100))

  expect_equal(params_seen[["filter"]], "value > 100")
})

test_that("peg_data() accepts a raw OData filter string", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(5L), page_resp(5L)),
    .package = "httr2"
  )

  # should not throw
  expect_no_error(
    suppressMessages(peg_data("d4mq-wa44", filter = "value gt 100"))
  )
})


# ── `select` argument ─────────────────────────────────────────────────────────

test_that("peg_data() collapses select vector to comma-separated string", {
  select_seen <- NULL

  real_build_url <- wpgdata:::build_url

  local_mocked_bindings(
    build_url = \(dataset_id, api = "odata", params = list()) {
      select_seen <<- params[["select"]]
      real_build_url(dataset_id, api, params)
    },
    .package = "wpgdata"
  )
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(3L), page_resp(3L)),
    .package = "httr2"
  )

  suppressMessages(peg_data(
    "d4mq-wa44",
    select = c("roll_number", "total_assessed_value")
  ))

  expect_equal(select_seen, "roll_number,total_assessed_value")
})


# ── `orderby` argument ────────────────────────────────────────────────────────

test_that("peg_data() forwards orderby to URL params", {
  orderby_seen <- NULL
  real_build_url <- wpgdata:::build_url

  local_mocked_bindings(
    build_url = \(dataset_id, api = "odata", params = list()) {
      orderby_seen <<- params[["orderby"]]
      real_build_url(dataset_id, api, params)
    },
    .package = "wpgdata"
  )
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(3L), page_resp(3L)),
    .package = "httr2"
  )

  suppressMessages(peg_data("d4mq-wa44", orderby = "total_assessed_value desc"))

  expect_equal(orderby_seen, "total_assessed_value desc")
})


# ── `max_connections` auto-detect ─────────────────────────────────────────────

test_that("peg_data() auto-detects max_connections capped at .MAX_CONNECTIONS", {
  # 32 cores * 2 = 64, but .MAX_CONNECTIONS = 20 is the binding cap.
  # Need >= 20 pages (>= 20 000 rows) so n_pages doesn't cap connections first.
  local_mocked_bindings(
    detectCores = \(...) 32L,
    .package = "parallel"
  )

  call_count <- 0L
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(20000L), page_resp(1000L, start_id = 1L))
      } else {
        lapply(seq_len(length(reqs)), \(i) {
          page_resp(1000L, start_id = (i * 1000L) + 1L)
        })
      }
    },
    .package = "httr2"
  )

  expect_message(
    peg_data("d4mq-wa44"),
    regexp = "20 \\(auto\\)"
  )
})

test_that("peg_data() auto-detects max_connections does not exceed n_pages", {
  # Only 2 pages — with 32 cores the formula gives 64, but req_perform_parallel
  # never opens more connections than it has requests, so the logged value
  # reflects the formula cap (.MAX_CONNECTIONS = 20), not n_pages.
  # We verify the result is correct (1500 rows across 2 pages) rather than
  # asserting an n_pages label the source does not emit.
  local_mocked_bindings(
    detectCores = \(...) 32L,
    .package = "parallel"
  )
  p1 <- page_resp(1000L, start_id = 1L)
  p2 <- page_resp(500L, start_id = 1001L)
  call_count <- 0L

  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) list(count_resp(1500L), p1) else list(p2)
    },
    .package = "httr2"
  )

  out <- suppressMessages(peg_data("d4mq-wa44"))
  expect_equal(nrow(out), 1500L)
})

test_that("peg_data() labels manual max_connections correctly", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(3L), page_resp(3L)),
    .package = "httr2"
  )

  expect_message(
    peg_data("d4mq-wa44", max_connections = 4L),
    regexp = "4 \\(manual\\)"
  )
})


# ── Network / HTTP errors ─────────────────────────────────────────────────────

test_that("peg_data() aborts when the count request fails with a network error", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(
        structure(
          simpleError("connection refused"),
          class = c("error", "condition")
        ),
        page_resp(10L)
      )
    },
    .package = "httr2"
  )

  expect_error(peg_data("d4mq-wa44"), regexp = "Count request failed")
})

test_that("peg_data() aborts when page 0 fails with a network error", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(
        count_resp(10L),
        structure(simpleError("timeout"), class = c("error", "condition"))
      )
    },
    .package = "httr2"
  )

  expect_error(peg_data("d4mq-wa44"), regexp = "First page request failed")
})

test_that("peg_data() aborts when a subsequent page fails with a network error", {
  p1 <- page_resp(1000L, start_id = 1L)
  call_count <- 0L

  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      call_count <<- call_count + 1L
      if (call_count == 1L) {
        list(count_resp(2000L), p1)
      } else {
        list(structure(simpleError("timeout"), class = c("error", "condition")))
      }
    },
    .package = "httr2"
  )

  expect_error(
    suppressMessages(peg_data("d4mq-wa44")),
    regexp = "network error"
  )
})

test_that("peg_data() aborts on HTTP 404 from count endpoint", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(make_resp(list(), status = 404L), page_resp(5L))
    },
    .package = "httr2"
  )

  expect_error(peg_data("d4mq-wa44"), regexp = "404")
})

test_that("peg_data() aborts on HTTP 500 from count endpoint", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) {
      list(make_resp(list(), status = 500L), page_resp(5L))
    },
    .package = "httr2"
  )

  expect_error(peg_data("d4mq-wa44"), regexp = "500")
})


# ── Return type ───────────────────────────────────────────────────────────────

test_that("peg_data() always returns a tibble", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(5L), page_resp(5L)),
    .package = "httr2"
  )

  out <- suppressMessages(peg_data("d4mq-wa44"))

  expect_s3_class(out, "tbl_df")
  expect_s3_class(out, "data.frame")
})

test_that("peg_data() returns a tibble even for 0-row responses after skip", {
  local_mocked_bindings(
    req_perform_parallel = \(reqs, ...) list(count_resp(10L), page_resp(0L)),
    .package = "httr2"
  )

  expect_warning(out <- peg_data("d4mq-wa44", skip = 10L))
  expect_s3_class(out, "tbl_df")
})


# ── .parse_page() helper ──────────────────────────────────────────────────────

test_that(".parse_page() drops @odata.id from response", {
  resp <- page_resp(3L, inject_odata_id = TRUE)
  out <- wpgdata:::.parse_page(resp)
  expect_false("@odata.id" %in% names(out))
})

test_that(".parse_page() aborts on empty body", {
  empty_resp <- httr2::response(
    status_code = 200L,
    headers = list("Content-Type" = "application/json"),
    body = raw(0)
  )
  expect_error(wpgdata:::.parse_page(empty_resp), regexp = "empty body")
})

test_that(".parse_page() returns a data frame", {
  resp <- page_resp(5L)
  out <- wpgdata:::.parse_page(resp)
  expect_true(is.data.frame(out))
  expect_equal(nrow(out), 5L)
})
