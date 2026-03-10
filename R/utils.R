# -----------------------------------------------------------------------------
# 4. Shared utilities
# -----------------------------------------------------------------------------

#' @noRd
build_url <- function(dataset_id, api = c("odata", "views"), params = list()) {
  if (missing(dataset_id) || is.null(dataset_id) || !nzchar(dataset_id)) {
    cli::cli_abort(
      "{.arg dataset_id} must be a non-empty string e.g. {.val d4mq-wa44}"
    )
  }
  if (!is.character(dataset_id)) {
    cli::cli_abort(
      "{.arg dataset_id} must be a character string, not {.cls {class(dataset_id)}}"
    )
  }

  api <- match.arg(api)

  base_url <- switch(
    api,
    odata = glue::glue("{.WINNIPEG_URL}/api/odata/v4/{dataset_id}"),
    views = glue::glue("{.WINNIPEG_URL}/api/views/{dataset_id}.json")
  )

  if (length(params) == 0) {
    return(base_url)
  }

  query_string <- params |>
    purrr::imap_chr(\(value, name) {
      glue::glue(
        "${name}={utils::URLencode(as.character(value), reserved = FALSE)}"
      )
    }) |>
    paste(collapse = "&")

  glue::glue("{base_url}?{query_string}")
}


#' @noRd
handle_errors <- function(response) {
  status <- httr2::resp_status(response)

  if (is.null(status)) {
    cli::cli_abort(
      "Could not read response status. The server may be unreachable."
    )
  }
  if (status == 404) {
    cli::cli_abort("Dataset not found (404). Check your dataset ID is correct.")
  }
  if (status == 429) {
    cli::cli_abort("Rate limited (429). Wait a moment before retrying.")
  }
  if (status == 500) {
    cli::cli_abort("Winnipeg Open Data server error (500). Try again later.")
  }
  if (status == 503) {
    cli::cli_abort("Service unavailable (503). Try again later.")
  }
  if (status >= 400) {
    cli::cli_abort("Request failed with status {status}.")
  }

  invisible(response)
}


#' @noRd
.parse_unix <- function(x) {
  if (is.null(x)) {
    return(as.Date(NA))
  }
  # [10] guard against non-numeric — e.g. server returns "" or a string
  if (!is.numeric(x)) {
    cli::cli_warn(
      "Expected a numeric Unix timestamp, got {.cls {class(x)}}. Returning NA."
    )
    return(as.Date(NA))
  }
  as.Date(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"))
}


#' @noRd
`%||%` <- rlang::`%||%`
