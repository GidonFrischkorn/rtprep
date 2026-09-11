#' Compare what several screening rules would remove
#'
#' @description
#' Applies every rule once and reports where they disagree. This is the question
#' the package exists to make askable: *what would a different preprocessing
#' choice have removed?* That is normally unanswerable, because each rule's
#' implementation returns a different shape.
#'
#' @param rt,response,.by,policy,threshold As in [rt_screen()], and forwarded
#'   unchanged.
#' @param rules A `list()` of rule objects; see [rules]. Names become the labels
#'   in the output; unnamed entries take the rule's own label.
#'
#' @return An object of class `rtprep_comparison`: a list with
#'
#'   \describe{
#'     \item{`keep`, `prob`, `reason`}{matrices, `length(rt)` rows by one column
#'       per rule, so downstream analysis needs nothing else.}
#'     \item{`drops`}{one row per rule and group: `n_trials`, `n_dropped`,
#'       `prop_dropped`, and a count column per reason.}
#'     \item{`agreement`}{one row per rule pair: `agree`, `jaccard`, and the
#'       counts behind them.}
#'     \item{`fits`}{the per-group fit diagnostics, stacked, with a `.rule`
#'       column.}
#'   }
#'
#'   `summary()` returns an `rtprep_comparison_summary`: the `drops` and
#'   `agreement` tables, printed by their own method. It is a value, not a side
#'   effect, so `s <- summary(cmp)` is quiet and `s$drops` is the table.
#'   `print()` and `plot()` return their input invisibly. `plot()` draws with
#'   ggplot2 when it is installed and with [graphics::barplot()] when it is not;
#'   the return value is the same either way.
#'
#' @details
#' `agree` and `jaccard` answer different questions and diverge exactly where it
#' matters. Two rules that each drop 2% of trials and never the same one agree
#' on 96% of decisions, and have a Jaccard index of zero. Agreement alone would
#' call them interchangeable. Jaccard is `NA`, not 1, when neither rule dropped
#' anything: no overlap can be computed from two empty sets.
#'
#' @seealso [rt_screen()] for a single rule, [r_contaminated()] to score the
#'   comparison against known ground truth.
#'
#' @examples
#' set.seed(2)
#' d <- r_contaminated(300, process = "mixed", rate = 0.1)
#' cmp <- screen_compare(
#'   d$rt,
#'   list(
#'     cutoff = rule_cutoff(0.18, 3),
#'     sd = rule_sd(2.5),
#'     recursive = rule_recursive("modified")
#'   )
#' )
#' cmp
#' cmp$agreement
#'
#' @export
screen_compare <- function(rt, rules, response = NULL, .by = NULL,
                           policy = c("threshold", "probabilistic"),
                           threshold = 0.5) {
  policy <- match.arg(policy)
  # a rule object is itself a list, so this has to be checked before the
  # is.list() test or a single rule iterates over its own parameters
  .stopif(
    inherits(rules, "rtprep_rule"),
    "'rules' must be a list of rules. Did you mean list(<rule>)?"
  )
  .stopif(
    !is.list(rules) || length(rules) == 0L,
    "'rules' must be a non-empty list of rule objects."
  )
  bad <- !vapply(rules, inherits, logical(1), "rtprep_rule")
  .stopif(any(bad), paste0(
    "Every element of 'rules' must be a rule object. Element(s) ",
    paste(which(bad), collapse = ", "), " are not."
  ))

  labels <- names(rules)
  if (is.null(labels)) labels <- rep("", length(rules))
  auto <- labels == "" | is.na(labels)
  labels[auto] <- vapply(rules[auto], function(r) r$label, character(1))
  .stopif(anyDuplicated(labels) > 0L, paste0(
    "Rule labels must be unique. Duplicated: ",
    paste(unique(labels[duplicated(labels)]), collapse = ", "), "."
  ))

  n <- length(rt)
  screens <- lapply(rules, function(rule) {
    rt_screen(
      rt, rule, response,
      .by = .by, policy = policy, threshold = threshold
    )
  })
  names(screens) <- labels

  as_matrix <- function(column) {
    m <- vapply(screens, function(s) s[[column]], screens[[1]][[column]])
    m <- matrix(m, nrow = n, dimnames = list(NULL, labels))
    m
  }

  structure(
    list(
      keep = as_matrix(".keep"),
      prob = as_matrix(".prob"),
      reason = as_matrix(".reason"),
      drops = .drop_table(screens, labels, .by, n),
      agreement = .agreement_table(as_matrix(".keep"), labels),
      fits = .stack_fits(screens, labels),
      n_trials = n,
      rules = stats::setNames(rules, labels),
      call = match.call()
    ),
    class = "rtprep_comparison"
  )
}

# Drop rates per rule and group, with the reasons broken out.
#
# The group key is recomputed here rather than read back off the screens:
# rt_screen() does not expose it, and reconstructing it from `.by` is exactly
# how it was built in the first place. The reason columns are the union across
# rules, so a rule that never flags anything "too_fast" gets a zero rather than
# a gap.
.drop_table <- function(screens, labels, .by, n) {
  key <- .group_key(.by, n)
  reasons <- sort(unique(unlist(lapply(screens, function(s) {
    s$.reason[!is.na(s$.reason)]
  }))))

  # Same index list as the screening engine builds, for the same reason: the
  # per-group scan this replaces ran once per rule per group over the whole
  # trial vector. Missing trials are keyed here, unlike in rt_screen(), because
  # "missing" is one of the reasons being counted.
  keyed <- which(!is.na(key$id))
  idx_by_group <- split(
    keyed, factor(key$id[keyed], levels = seq_along(key$labels))
  )

  rows <- lapply(seq_along(screens), function(i) {
    s <- screens[[i]]
    fits <- attr(s, "fits")
    if (nrow(fits) == 0L) {
      return(NULL)
    }

    row <- data.frame(
      .rule = labels[i],
      .group = fits$.group,
      n_trials = fits$n_trials,
      n_dropped = fits$n_dropped,
      prop_dropped = fits$prop_dropped,
      stringsAsFactors = FALSE
    )
    for (r in reasons) {
      flagged <- !is.na(s$.reason) & s$.reason == r
      row[[r]] <- vapply(
        idx_by_group, function(idx) sum(flagged[idx]), integer(1),
        USE.NAMES = FALSE
      )
    }
    row
  })

  out <- .rbind_fill(rows)
  row.names(out) <- NULL
  out
}

# Pairwise agreement and Jaccard overlap of the excluded sets.
.agreement_table <- function(keep, labels) {
  n_rules <- ncol(keep)
  if (n_rules < 2L) {
    return(data.frame(
      rule_x = character(0), rule_y = character(0),
      agree = numeric(0), jaccard = numeric(0),
      n_only_x = integer(0), n_only_y = integer(0), n_both = integer(0),
      stringsAsFactors = FALSE
    ))
  }

  pairs <- utils::combn(n_rules, 2)
  rows <- lapply(seq_len(ncol(pairs)), function(p) {
    i <- pairs[1, p]
    j <- pairs[2, p]
    drop_x <- !keep[, i]
    drop_y <- !keep[, j]
    both <- sum(drop_x & drop_y)
    union <- sum(drop_x | drop_y)

    data.frame(
      rule_x = labels[i], rule_y = labels[j],
      agree = mean(keep[, i] == keep[, j]),
      # two rules that drop nothing have no overlap to report; calling that a
      # perfect match would make an empty comparison look like agreement
      jaccard = if (union == 0L) NA_real_ else both / union,
      n_only_x = as.integer(sum(drop_x & !drop_y)),
      n_only_y = as.integer(sum(drop_y & !drop_x)),
      n_both = as.integer(both),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  row.names(out) <- NULL
  out
}

.stack_fits <- function(screens, labels) {
  rows <- lapply(seq_along(screens), function(i) {
    fits <- attr(screens[[i]], "fits")
    if (is.null(fits) || nrow(fits) == 0L) {
      return(NULL)
    }
    cbind(data.frame(.rule = labels[i], stringsAsFactors = FALSE), fits)
  })
  .rbind_fill(rows)
}

#' @param x An `rtprep_comparison`, or for
#'   `print.rtprep_comparison_summary()` an `rtprep_comparison_summary`.
#' @param object An `rtprep_comparison`.
#' @param ... Ignored.
#' @rdname screen_compare
#' @export
print.rtprep_comparison <- function(x, ...) {
  cat(
    "<rtprep comparison>", x$n_trials, "trials,",
    length(x$rules), "rules\n\n"
  )

  overall <- vapply(seq_along(x$rules), function(i) {
    mean(!x$keep[, i])
  }, numeric(1))
  for (i in seq_along(x$rules)) {
    cat(sprintf(
      "  %-28s dropped %5.1f%%\n", colnames(x$keep)[i], 100 * overall[i]
    ))
  }

  if (nrow(x$agreement) > 0L) {
    worst <- x$agreement[which.min(x$agreement$agree), ]
    cat(sprintf(
      "\n  least agreement: %s vs %s, %.1f%% of decisions",
      worst$rule_x, worst$rule_y, 100 * worst$agree
    ))
    if (!is.na(worst$jaccard)) {
      cat(sprintf(" (Jaccard %.2f)", worst$jaccard))
    }
    cat("\n")
  }
  invisible(x)
}

#' @rdname screen_compare
#' @export
summary.rtprep_comparison <- function(object, ...) {
  structure(
    list(drops = object$drops, agreement = object$agreement),
    class = "rtprep_comparison_summary"
  )
}

#' @rdname screen_compare
#' @export
print.rtprep_comparison_summary <- function(x, ...) {
  cat("Drop rates\n\n")
  print(x$drops, row.names = FALSE)
  if (nrow(x$agreement) > 0L) {
    cat("\nPairwise agreement\n\n")
    print(x$agreement, row.names = FALSE)
  }
  invisible(x)
}

#' @rdname screen_compare
#' @export
plot.rtprep_comparison <- function(x, ...) {
  drop_rate <- vapply(seq_along(x$rules), function(i) {
    mean(!x$keep[, i])
  }, numeric(1))
  rule <- colnames(x$keep)

  # ggplot2 is a Suggests, so this has to work without it rather than error:
  # a plot method that stops on a missing optional package is a trap. The
  # ggplot is drawn here rather than returned, so that the return value does
  # not change class with the set of installed packages.
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    dat <- data.frame(rule = rule, drop_rate = drop_rate)
    print(
      ggplot2::ggplot(
        dat,
        ggplot2::aes(
          x = stats::reorder(.data_col(dat, "rule"), drop_rate),
          y = drop_rate
        )
      ) +
        ggplot2::geom_col() +
        ggplot2::coord_flip() +
        ggplot2::labs(x = NULL, y = "proportion of trials dropped")
    )
    return(invisible(x))
  }

  old <- graphics::par(mar = c(4, 12, 2, 2))
  on.exit(graphics::par(old), add = TRUE)
  graphics::barplot(
    rev(drop_rate),
    names.arg = rev(rule), horiz = TRUE, las = 1,
    xlab = "proportion of trials dropped"
  )
  invisible(x)
}

# ggplot2 needs the column, not the value, and rtprep cannot use .data without
# depending on rlang.
.data_col <- function(dat, name) dat[[name]]
