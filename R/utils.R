# Internal helpers shared across the package.
#
# Everything here is base R plus stats/utils. Validation lives at the public
# boundary (rt_screen(), rt_summary(), the rule constructors); the internal
# apply_rule() methods assume clean input so the per-group inner loop stays
# allocation-light at simulation scale.

.stopif <- function(cond, msg) {
  if (isTRUE(cond)) stop(msg, call. = FALSE)
  invisible(NULL)
}

.warnif <- function(cond, msg) {
  if (isTRUE(cond)) warning(msg, call. = FALSE)
  invisible(NULL)
}

# Single number in a (possibly half-open) interval; finite unless allow_inf.
.check_scalar <- function(x, name, lower = -Inf, upper = Inf,
                          incl_lower = TRUE, incl_upper = TRUE,
                          allow_inf = FALSE) {
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x) &&
    (allow_inf || is.finite(x)) &&
    (if (incl_lower) x >= lower else x > lower) &&
    (if (incl_upper) x <= upper else x < upper)
  # an interval closed at an infinite endpoint only admits Inf when we allow it
  shut_upper <- incl_upper && (allow_inf || is.finite(upper))
  shut_lower <- incl_lower && (allow_inf || is.finite(lower))
  .stopif(!ok, paste0(
    "'", name, "' must be a single number ",
    if (shut_lower) "in [" else "in (", .fmt(lower), ", ", .fmt(upper),
    if (shut_upper) "]." else ")."
  ))
  invisible(NULL)
}

.check_string <- function(x, name) {
  .stopif(
    !is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x),
    paste0("'", name, "' must be a single non-empty string.")
  )
  invisible(NULL)
}

.check_flag <- function(x, name) {
  .stopif(
    !is.logical(x) || length(x) != 1L || is.na(x),
    paste0("'", name, "' must be TRUE or FALSE.")
  )
  invisible(NULL)
}

# Whole numbers of trials or responses, NA allowed, for the functions that
# vectorise over the rows of a summary table. Unlike .check_count() this allows
# zero, because an empty cell is a legitimate thing to summarise; a missing
# count is a missing answer downstream, not an error here.
.check_wholes <- function(x, name) {
  observed <- x[!is.na(x)]
  ok <- (is.numeric(x) || all(is.na(x))) &&
    !any(observed < 0) &&
    !any(abs(observed - round(observed)) > .Machine$double.eps^0.5)
  .stopif(!ok, paste0("'", name, "' must be whole numbers of at least 0."))
  invisible(NULL)
}

.check_count <- function(x, name) {
  .stopif(
    !is.numeric(x) || length(x) != 1L || is.na(x) || x < 1 ||
      abs(x - round(x)) > .Machine$double.eps^0.5,
    paste0("'", name, "' must be a single whole number of at least 1.")
  )
  invisible(NULL)
}

# Compact formatting for rule labels: 0.18 not 0.180000, Inf not Inf.00.
.fmt <- function(x) {
  if (is.character(x)) {
    return(x)
  }
  vapply(x, function(v) format(v, trim = TRUE, digits = 7), character(1))
}

# Recode any of the response codings the package accepts to a logical
# "upper boundary / correct" indicator. Ported from bmm's
# .convert_response_to_upper() so that the two packages accept the same inputs.
.as_upper <- function(x) {
  if (is.numeric(x) || is.logical(x)) {
    # bmm coerces with as.logical(), which silently reads a 1 = error /
    # 2 = correct column as 100% accuracy. Anything outside {0, 1} is far more
    # likely to be a coding mistake than an intent, so refuse it.
    observed <- x[!is.na(x)]
    .stopif(
      is.numeric(x) && !all(observed %in% c(0, 1)),
      paste0(
        "Numeric 'response' must be coded 0/1. Found: ",
        paste(utils::head(sort(unique(observed[!observed %in% c(0, 1)])), 5),
          collapse = ", "
        ), "."
      )
    )
    return(as.logical(x))
  }

  if (is.character(x) || is.factor(x)) {
    x <- tolower(as.character(x))
    upper_patterns <- c("upper", "correct", "acc", "1", "true", "yes", "hit")
    lower_patterns <- c(
      "lower", "error", "err", "incorrect", "0", "false", "no", "miss", "fa"
    )
    is_upper <- x %in% upper_patterns
    is_lower <- x %in% lower_patterns

    unrecognized <- !is_upper & !is_lower & !is.na(x)
    .stopif(any(unrecognized), paste0(
      "Unrecognized response values: ",
      paste(unique(x[unrecognized]), collapse = ", "),
      ". Expected values like 'upper', 'lower', 'correct', 'error', ",
      "1, 0, TRUE, or FALSE."
    ))
    is_upper[is.na(x)] <- NA
    return(is_upper)
  }

  stop(
    "'response' must be numeric, logical, character, or factor, not ",
    class(x)[1], ".",
    call. = FALSE
  )
}

# RTs are in seconds, positive, and possibly missing.
.check_rt <- function(rt) {
  .stopif(
    !is.numeric(rt) || !is.null(dim(rt)),
    paste0("'rt' must be a numeric vector, not ", class(rt)[1], ".")
  )
  .stopif(length(rt) == 0L, "'rt' has length 0.")
  observed <- rt[!is.na(rt)]
  .stopif(any(observed <= 0), "Non-positive RT values found.")
  # an infinite RT would not be caught by the spread guards below: it makes the
  # sd non-finite, the rule bails out, and the offending trial survives
  .stopif(any(is.infinite(observed)), "Infinite RT values found.")
  .warnif(
    any(observed > 10),
    "Some RT values > 10. Ensure RTs are in seconds, not milliseconds."
  )
  invisible(NULL)
}

# Split trials into groups.
#
# Returns list(id, labels): `id` is the integer group index per trial, NA where
# any grouping component is missing; `labels` names the groups in `id` order.
#
# Grouping goes through interaction(), so component order decides group order --
# a numeric participant id sorts 1, 2, 10 rather than "1", "10", "2", and an
# existing factor keeps its levels. The composite key is built with a separator
# that cannot occur in a label, so that .by = list(c("a.b", "a"), c("c", "b.c"))
# stays two groups instead of silently collapsing into one.
#
# `names` carries the grouping variable names where there are any, because the
# labels paste the values together and a report has to say which variables the
# criterion was computed within. A data frame or a named list supplies them; a
# bare vector does not, and gets NA.
.group_key <- function(.by, n) {
  if (is.null(.by)) {
    return(list(id = rep(1L, n), labels = "all", names = NULL))
  }

  components <- if (is.data.frame(.by)) {
    as.list(.by)
  } else if (is.list(.by)) {
    .by
  } else {
    list(.by)
  }

  .stopif(
    length(components) == 0L,
    "'.by' must have at least one grouping component."
  )
  .stopif(
    !all(vapply(components, length, integer(1)) == n),
    "'.by' must have the same length as 'rt'."
  )

  sep <- "\r"
  f <- interaction(components, drop = TRUE, sep = sep, lex.order = TRUE)
  nm <- names(components)
  if (is.null(nm)) {
    nm <- rep(NA_character_, length(components))
  }
  nm[!nzchar(nm)] <- NA_character_
  list(
    id = as.integer(f),
    labels = gsub(sep, ".", levels(f), fixed = TRUE),
    names = nm
  )
}

# Inclusive bounds: a trial is flagged only when strictly outside.
.reason_from_bounds <- function(rt, lower, upper) {
  reason <- rep(NA_character_, length(rt))
  reason[rt < lower] <- "too_fast"
  reason[rt > upper] <- "too_slow"
  reason
}

.prob_from_bounds <- function(rt, lower, upper) {
  as.numeric(rt >= lower & rt <= upper)
}
