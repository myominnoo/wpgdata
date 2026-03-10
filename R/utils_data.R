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

# #' @noRd
# make_request <- function(url) {
#   if (is.null(url) || !nzchar(url)) {
#     cli::cli_abort("{.arg url} must be a non-empty string.")
#   }

#   url |>
#     httr2::request() |>
#     httr2::req_headers("Accept" = "application/json") |>
#     httr2::req_error(is_error = \(resp) FALSE) |>
#     httr2::req_perform() |>
#     handle_errors() |>
#     parse_response()
# }

# #' @noRd
# parse_response <- function(response) {
#   if (httr2::resp_body_raw(response) |> length() == 0) {
#     cli::cli_abort("Response body is empty. The server returned no content.")
#   }

#   parsed <- response |>
#     httr2::resp_body_json(simplifyVector = TRUE)

#   data <- parsed[["value"]]

#   # remove @odata.id column always added by Socrata
#   if (!is.null(data) && "@odata.id" %in% names(data)) {
#     data[["@odata.id"]] <- NULL
#   }

#   list(
#     data = data,
#     next_url = parsed[["@odata.nextLink"]],
#     metadata = parsed[["@odata.context"]]
#   )
# }

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
.parse_page <- function(resp) {
  if (length(httr2::resp_body_raw(resp)) == 0L) {
    cli::cli_abort("A page response returned an empty body.")
  }

  parsed <- httr2::resp_body_json(resp, simplifyVector = TRUE)
  data <- parsed[["value"]]

  # Drop Socrata's internal column present on every response
  if (!is.null(data) && "@odata.id" %in% names(data)) {
    data[["@odata.id"]] <- NULL
  }

  data
}
