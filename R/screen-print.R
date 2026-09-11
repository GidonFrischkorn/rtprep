# Methods for the rt_screen() return.
#
# The object is a data.frame with one row per trial, so at the console it used
# to print every trial and say nothing about the screen. These report the screen
# first and then the rows, and keep the `fits` attribute honest when subset.

#' Methods for a screening result
#'
#' [rt_screen()] returns one row per trial with the per-group diagnostics
#' attached as an attribute. `print()` reports what was removed and why before
#' the rows, because the count is usually the answer wanted and the rows are
#' usually too many to read.
#'
#' @details
#' The `fits` attribute describes the screen, so it survives column subsetting
#' and is dropped by row subsetting: after `scr[scr$.keep, ]` its `n_dropped`
#' and `prop_dropped` count rows that are no longer there, and carrying it along
#' would attach a table that quietly disagrees with the object. The class
#' survives for as long as the four columns do.
#'
#' The `rule` and `group_names` attributes, which [report_screening()] reads,
#' name the screen rather than count it, so they survive row subsetting too.
#'
#' `as.data.frame()` strips the class and the attributes, for when a plain frame
#' is wanted.
#'
#' @param x A screening result from [rt_screen()].
#' @param n Number of trials to show. `print()` shows the screen summary in
#'   full whatever this is.
#' @param row.names,optional Passed to [base::as.data.frame()].
#' @param ... Ignored.
#'
#' @return `print()` returns `x` invisibly. `format()` returns the summary as a
#'   character vector. `as.data.frame()` returns a plain `data.frame`.
#'
#' @examples
#' scr <- rt_screen(rt_example$rt, rule_mad(2.5), .by = rt_example$id)
#' scr
#'
#' # the per-group diagnostics the summary points at
#' head(attr(scr, "fits"))
#'
#' @name rtprep_screen
NULL

#' @rdname rtprep_screen
#' @export
format.rtprep_screen <- function(x, ...) {
  fits <- attr(x, "fits")
  n <- nrow(x)
  dropped <- sum(!x$.keep)
  rule <- if (n > 0L) x$.rule[1] else "?"
  groups <- if (is.null(fits)) NA_integer_ else nrow(fits)

  head_line <- paste0(
    "<rtprep screen> ", n, " trials, ", rule,
    if (!is.na(groups)) paste0(", ", groups, " group", if (groups != 1) "s")
  )
  kept_line <- sprintf(
    "  kept %d (%.1f%%), dropped %d (%.1f%%)",
    n - dropped, 100 * (n - dropped) / max(n, 1L),
    dropped, 100 * dropped / max(n, 1L)
  )

  out <- c(head_line, kept_line)

  reasons <- x$.reason[!is.na(x$.reason)]
  if (length(reasons) > 0L) {
    tab <- sort(table(reasons), decreasing = TRUE)
    out <- c(out, paste0(
      "  reasons: ",
      paste(names(tab), unname(tab), sep = " ", collapse = ", ")
    ))
  }

  policy <- attr(x, "policy")
  threshold <- attr(x, "threshold")
  if (!is.null(policy)) {
    out <- c(out, if (identical(policy, "threshold")) {
      paste0("  policy: keep where .prob > ", .fmt(threshold))
    } else {
      "  policy: probabilistic, one draw per trial against .prob"
    })
  }

  out <- c(out, if (is.null(fits)) {
    "  per-group diagnostics: dropped by subsetting; screen_fits() to refit"
  } else {
    paste0(
      "  per-group diagnostics: screen_fits(), or attr(x, \"fits\") -- ",
      nrow(fits), " row", if (nrow(fits) != 1) "s"
    )
  })
  out
}

#' @rdname rtprep_screen
#' @export
print.rtprep_screen <- function(x, n = 6L, ...) {
  cat(format(x), sep = "\n")
  if (nrow(x) == 0L) {
    return(invisible(x))
  }
  cat("\n")
  shown <- min(n, nrow(x))
  # stripped before printing: head() keeps the class, so print()ing it would
  # come straight back here
  rows <- as.data.frame(x[seq_len(shown), , drop = FALSE])
  print(rows)
  if (nrow(x) > shown) {
    cat(
      "# ", nrow(x) - shown, " more trials; as.data.frame(x) for all of them\n",
      sep = ""
    )
  }
  invisible(x)
}

#' @rdname rtprep_screen
#' @export
as.data.frame.rtprep_screen <- function(x, row.names = NULL, optional = FALSE,
                                        ...) {
  attr(x, "fits") <- NULL
  attr(x, "policy") <- NULL
  attr(x, "threshold") <- NULL
  attr(x, "rule") <- NULL
  attr(x, "group_names") <- NULL
  class(x) <- "data.frame"
  x
}

#' @rdname rtprep_screen
#' @param i,j Row and column indices.
#' @param drop Whether to drop to a vector when one column is selected.
#' @export
`[.rtprep_screen` <- function(x, i, j, drop = TRUE) {
  kept <- attributes(x)[c(
    "fits", "policy", "threshold", "rule", "group_names"
  )]
  out <- NextMethod()
  if (!is.data.frame(out)) {
    return(out)
  }
  # NextMethod() carries these through, so dropping one takes an explicit NULL
  attr(out, "fits") <- NULL
  attr(out, "policy") <- NULL
  attr(out, "threshold") <- NULL
  attr(out, "rule") <- NULL
  attr(out, "group_names") <- NULL

  if (all(c(".keep", ".prob", ".rule", ".reason") %in% names(out))) {
    attr(out, "policy") <- kept$policy
    attr(out, "threshold") <- kept$threshold
    # the rule and the grouping name the screen rather than count it, so unlike
    # the fits table they stay true of any subset of the rows
    attr(out, "rule") <- kept$rule
    attr(out, "group_names") <- kept$group_names
    # the fits table describes the screen, and a row subset is no longer the
    # screen it was computed for
    if (missing(i)) {
      attr(out, "fits") <- kept$fits
    }
    class(out) <- c("rtprep_screen", "data.frame")
  } else {
    class(out) <- "data.frame"
  }
  out
}
