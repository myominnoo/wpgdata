# HTTP helpers ------------------------------------------------------------

# Not exported - internal helper
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
  if (status == 500) {
    cli::cli_abort("Winnipeg Open Data server error (500). Try again later.")
  }
  if (status >= 400) {
    cli::cli_abort("Request failed with status {status}.")
  }

  invisible(response)
}

#' @noRd
make_request <- function(url) {
  if (is.null(url) || !nzchar(url)) {
    cli::cli_abort("{.arg url} must be a non-empty string.")
  }

  url |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform() |>
    handle_errors() |>
    parse_response()
}


# URL helpers -------------------------------------------------------------

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
    odata = glue::glue("https://data.winnipeg.ca/api/odata/v4/{dataset_id}"),
    views = glue::glue("https://data.winnipeg.ca/api/views/{dataset_id}.json")
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


# Filter helpers ----------------------------------------------------------

#' @noRd
.translate_expr <- function(x) {
  if (is.symbol(x)) {
    return(as.character(x))
  }

  if (!is.call(x)) {
    val <- x
    if (is.character(val)) {
      return(glue::glue("'{val}'"))
    }
    if (is.logical(val)) {
      return(tolower(as.character(val)))
    }
    if (is.numeric(val)) {
      return(format(val, scientific = FALSE))
    }
    cli::cli_abort(
      "Unsupported value type {.cls {class(val)}} in filter expression."
    )
  }

  op <- as.character(x[[1]])

  if (length(x) < 2) {
    cli::cli_abort("Malformed expression: missing operand for {.val {op}}.")
  }

  lhs <- .translate_expr(x[[2]])

  if (op == "!" && length(x) == 2) {
    return(glue::glue("not {lhs}"))
  }

  if (length(x) < 3) {
    cli::cli_abort(
      "Malformed expression: missing right-hand side for {.val {op}}."
    )
  }

  rhs <- .translate_expr(x[[3]])

  switch(
    op,
    "==" = glue::glue("{lhs} eq {rhs}"),
    "!=" = glue::glue("{lhs} ne {rhs}"),
    ">" = glue::glue("{lhs} gt {rhs}"),
    ">=" = glue::glue("{lhs} ge {rhs}"),
    "<" = glue::glue("{lhs} lt {rhs}"),
    "<=" = glue::glue("{lhs} le {rhs}"),
    "&" = ,
    "&&" = glue::glue("({lhs} and {rhs})"),
    "|" = ,
    "||" = glue::glue("({lhs} or {rhs})"),
    cli::cli_abort("Unsupported operator {.val {op}} in filter expression.")
  )
}

#' @noRd
build_filter <- function(expr) {
  if (is.null(expr)) {
    cli::cli_abort("{.arg expr} must not be NULL.")
  }

  if (!is.character(expr) && !is.call(expr) && !is.symbol(expr)) {
    cli::cli_abort(
      "{.arg expr} must be a string or R expression, not {.cls {class(expr)}}."
    )
  }

  if (is.character(expr)) {
    return(expr)
  }
  .translate_expr(expr)
}

# Response parsers --------------------------------------------------------

#' @noRd
parse_response <- function(response) {
  if (httr2::resp_body_raw(response) |> length() == 0) {
    cli::cli_abort("Response body is empty. The server returned no content.")
  }

  parsed <- response |>
    httr2::resp_body_json(simplifyVector = TRUE)

  data <- parsed[["value"]]

  # remove @odata.id column always added by Socrata
  if (!is.null(data) && "@odata.id" %in% names(data)) {
    data[["@odata.id"]] <- NULL
  }

  list(
    data = data,
    next_url = parsed[["@odata.nextLink"]],
    metadata = parsed[["@odata.context"]]
  )
}


#' @noRd
parse_metadata <- function(response) {
  if (httr2::resp_body_raw(response) |> length() == 0) {
    cli::cli_abort(
      "Metadata response body is empty. The server returned no content."
    )
  }

  parsed <- httr2::resp_body_json(response)
  columns <- purrr::pluck(parsed, "columns")

  if (is.null(columns) || length(columns) == 0) {
    cli::cli_abort(
      "No column properties found in metadata. The dataset schema may be empty."
    )
  }

  columns |>
    purrr::map_dfr(\(col) {
      list(
        name = col$name,
        field_name = col$fieldName,
        type = col$dataTypeName,
        description = col$description %||% NA_character_
      )
    })
}

#' @noRd
parse_info <- function(response) {
  if (httr2::resp_body_raw(response) |> length() == 0) {
    cli::cli_abort("Response body is empty. The server returned no content.")
  }

  parsed <- httr2::resp_body_json(response)

  if (is.null(parsed) || !is.list(parsed)) {
    cli::cli_abort("Unexpected response structure from the server.")
  }

  tibble::tibble(
    name = parsed$name %||% NA_character_,
    description = parsed$description %||% NA_character_,
    category = parsed$category %||% NA_character_,
    created_at = .parse_unix(parsed$createdAt),
    rows_updated_at = .parse_unix(parsed$rowsUpdatedAt),
    view_last_modified = .parse_unix(parsed$viewLastModified),
    view_count = parsed$viewCount %||% NA_integer_,
    download_count = parsed$downloadCount %||% NA_integer_,
    tags = list(parsed$tags %||% NA_character_),
    license = parsed$license$name %||% NA_character_,
    provenance = parsed$provenance %||% NA_character_
  )
}


#' @noRd
parse_catalogue <- function(response) {
  if (httr2::resp_body_raw(response) |> length() == 0) {
    cli::cli_abort("Response body is empty. The server returned no content.")
  }

  parsed <- tryCatch(
    httr2::resp_body_json(response),
    error = \(e) {
      cli::cli_abort("Failed to parse catalogue response: {e$message}")
    }
  )

  if (is.null(parsed) || !is.list(parsed)) {
    cli::cli_abort("Unexpected response structure from the catalogue API.")
  }

  results <- purrr::pluck(parsed, "results")

  if (is.null(results) || length(results) == 0) {
    cli::cli_warn("No datasets found in the Winnipeg Open Data catalogue.")
    return(tibble::tibble())
  }

  results |>
    purrr::map(\(x) {
      tibble::tibble(
        name = x$resource$name %||% NA_character_,
        id = x$resource$id %||% NA_character_,
        description = x$resource$description %||% NA_character_,
        category = x$classification$domain_category %||% NA_character_,
        updated_at = x$resource$updatedAt %||% NA_character_,
        row_count = x$resource$download_count %||% NA_integer_
      )
    }) |>
    purrr::list_rbind() |>
    dplyr::mutate(
      updated_at = as.POSIXct(
        .data$updated_at,
        format = "%Y-%m-%dT%H:%M:%S",
        tz = "UTC"
      ),
      url = paste0("https://data.winnipeg.ca/d/", .data$id),
      category = dplyr::coalesce(.data$category, "Uncategorized")
    ) |>
    dplyr::arrange(dplyr::desc(.data$updated_at))
}

#' @noRd
get_catalogue_count <- function() {
  response <- httr2::request("https://api.us.socrata.com/api/catalog/v1") |>
    httr2::req_url_query(
      domains = "data.winnipeg.ca",
      only = "dataset",
      limit = 1L
    ) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform() |>
    handle_errors()

  if (httr2::resp_body_raw(response) |> length() == 0) {
    cli::cli_abort("Response body is empty fetching catalogue count.")
  }

  count <- httr2::resp_body_json(response) |>
    purrr::pluck("resultSetSize")

  if (is.null(count)) {
    cli::cli_abort(
      "Could not retrieve total dataset count from the catalogue API."
    )
  }

  count
}

#' @noRd
fetch_catalogue_page <- function(offset, limit) {
  if (!is.numeric(offset) || offset < 0) {
    cli::cli_abort("{.arg offset} must be a non-negative integer.")
  }

  if (!is.numeric(limit) || limit < 1) {
    cli::cli_abort("{.arg limit} must be a positive integer.")
  }

  httr2::request("https://api.us.socrata.com/api/catalog/v1") |>
    httr2::req_url_query(
      domains = "data.winnipeg.ca",
      only = "dataset",
      limit = as.integer(limit),
      offset = as.integer(offset)
    ) |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform() |>
    handle_errors() |>
    parse_catalogue()
}


#' @noRd
get_total_count <- function(dataset_id) {
  url <- build_url(dataset_id, params = list("count" = "true"))

  response <- url |>
    httr2::request() |>
    httr2::req_headers("Accept" = "application/json") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform() |>
    handle_errors()

  if (httr2::resp_body_raw(response) |> length() == 0) {
    cli::cli_abort(
      "Response body is empty getting row count for {.val {dataset_id}}."
    )
  }

  result <- httr2::resp_body_json(response)
  result[["@odata.count"]] %||% NA_integer_
}


# Date helpers ------------------------------------------------------------

#' @noRd
.parse_unix <- function(x) {
  if (is.null(x)) {
    return(as.Date(NA))
  }
  as.Date(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"))
}


# Operators ---------------------------------------------------------------

#' @noRd
`%||%` <- rlang::`%||%`


# re-export .data pronoun so R CMD check doesn't flag it
#' @importFrom rlang .data
NULL
