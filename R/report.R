# report_screening(): the Methods paragraph a screen owes a reader.
#
# Everything the paragraph states is derived from the screen itself, which is
# the point. A number typed into a manuscript by hand goes stale the moment the
# rule above it is edited, and nothing catches it; a number read out of the
# object cannot.

#' Report a screening procedure in prose
#'
#' @description
#' Turns a screen into a paragraph that can go into a Methods section: which
#' rule at which setting, the grouping the criterion was computed within, how
#' much it removed in total and per cell, what it caught, whether it read
#' accuracy, the keep policy, and the references for the criteria used.
#'
#' Every number and every description is derived from the screen, so editing the
#' rule and forgetting to edit the paragraph is not a way to publish a wrong
#' Methods section.
#'
#' @details
#' The counts separate what the rule excluded from what was never screened.
#' Trials with a missing response time, a missing grouping key, or (for a rule
#' that reads accuracy) a missing response, come back with `.keep = FALSE` and
#' `.reason = "missing"`, so `sum(!.keep)` overstates the rule's work. The
#' percentages quoted for the rule are out of the trials it actually saw, and
#' the missing trials get their own sentence.
#'
#' @section Which object to pass:
#' `rt_screen()` attaches the rule and the grouping to its result, so
#' `report_screening(scr)` needs nothing else. Inside
#' `dplyr::mutate(rt_screen(rt, rule), .by = ...)` the four columns are spliced
#' into the data frame and the attributes are lost, so the data frame method
#' asks for the `rule` back and for `groups`, the names of the grouping
#' columns. It recomputes the per-cell counts from `.keep` and those columns,
#' which needs no refitting and gives the same answer.
#'
#' @section What it does not claim:
#' The reference list names the sources for the criteria used and the standard
#' caveats on them, which are not the same thing: `rule_sd()` cites Miller
#' (1991) on sample-size bias, and `rule_mad()` also cites Leys et al. (2013),
#' whose argument is that the mean and standard deviation are the wrong choice.
#' Read the sentence as a pointer to the literature, not as an endorsement.
#' `toBibtex()` on the result gives the entries.
#'
#' @param x A screening result from [rt_screen()], or a data frame carrying its
#'   four columns.
#' @param rule The rule that produced the screen. Optional for an
#'   [rt_screen()] result, which carries it; required for a data frame, where
#'   it cannot be recovered.
#' @param groups Character vector naming the grouping variables, for the
#'   sentence that says what the criterion was computed within. Optional for an
#'   [rt_screen()] result when `.by` was a data frame or a named list, which
#'   supplies them. For a data frame these must be columns of `x`, since their
#'   values are needed to rebuild the cells.
#' @param policy,threshold The exclusion policy the screen was run under. Read
#'   from the object where it carries them; pass them for a data frame if they
#'   were not left at the defaults.
#' @param max_words A guard on the length of the paragraph. Optional clauses
#'   are dropped, lowest priority first, rather than any sentence being
#'   truncated.
#' @param ... Ignored.
#'
#' @return An object of class `rtprep_report`: a list whose `text` element is
#'   the paragraph, carrying alongside it every number the paragraph quotes
#'   (`n_trials`, `n_missing`, `n_screened`, `n_excluded`, `prop_excluded`,
#'   `reasons`, `cells`, `words`), the `fits` table it read them from, the rule,
#'   the reference keys and their `bibliography`, and any `notes`.
#'
#' @seealso [rt_screen()] for the screen, [screen_fits()] for the per-cell table
#'   the counts come from, and [rtprep_report] for the print and BibTeX methods.
#'
#' @examples
#' scr <- rt_screen(rt_example$rt, rule_mad(2.5), .by = rt_example$id)
#' report_screening(scr, groups = "participant")
#'
#' # every number in the paragraph, for a sentence written by hand
#' rep <- report_screening(scr)
#' rep$n_excluded
#' rep$cells
#'
#' @export
report_screening <- function(x, ...) UseMethod("report_screening")

#' @rdname report_screening
#' @export
# nolint start: object_length_linter.
report_screening.rtprep_screen <- function(x, rule = NULL, groups = NULL,
                                           max_words = 300L, ...) {
  fits <- attr(x, "fits")
  # rt_screen() always attaches a fits table, so a missing one means this came
  # out of row subsetting. Reporting anyway would quote counts for rows that
  # are gone and silently lose the per-cell spread, in prose someone pastes
  # into a manuscript. A warning would not survive into the document.
  .stopif(
    is.null(fits),
    paste0(
      "This screen lost its per-group diagnostics to row subsetting, so the ",
      "counts would describe rows that are no longer here. Report the screen ",
      "and filter afterwards: report_screening(scr), then scr[scr$.keep, ]."
    )
  )

  rule <- rule %||% attr(x, "rule")
  .stopif(
    is.null(rule),
    paste0(
      "This screen does not carry its rule, so it cannot be described. Pass ",
      "the rule object that produced it as 'rule'."
    )
  )
  groups <- .resolve_groups(groups, attr(x, "group_names"), nrow(fits))

  .report_core(
    rule = rule, keep = x$.keep, reason = x$.reason, fits = fits,
    prob = x$.prob, groups = groups,
    policy = attr(x, "policy") %||% "threshold",
    threshold = attr(x, "threshold") %||% 0.5,
    max_words = max_words, staged = TRUE
  )
}

#' @rdname report_screening
#' @export
report_screening.data.frame <- function(x, rule, groups = NULL,
                                        policy = c(
                                          "threshold", "probabilistic"
                                        ),
                                        threshold = 0.5,
                                        max_words = 300L, ...) {
  needed <- c(".keep", ".prob", ".rule", ".reason")
  missing_cols <- setdiff(needed, names(x))
  .stopif(
    length(missing_cols) > 0L,
    paste0(
      "'x' is missing the screening column", if (length(missing_cols) > 1L) "s",
      " ", paste0("'", missing_cols, "'", collapse = ", "),
      ". It should be a result of rt_screen(), or a data frame those columns ",
      "were added to."
    )
  )
  # The label in .rule is not the rule: parsing it back into an object would be
  # a second implementation of every constructor, wrong the moment one changes.
  .stopif(
    missing(rule) || is.null(rule),
    paste0(
      "'rule' cannot be recovered from a data frame, whose attributes ",
      "dplyr::mutate() has stripped. Pass the same rule object you passed to ",
      "rt_screen()."
    )
  )
  .stopif(
    !inherits(rule, "rtprep_rule"),
    "'rule' must be a rule object, e.g. from rule_sd()."
  )
  policy <- match.arg(policy)
  .check_scalar(threshold, "threshold", lower = 0, upper = 1)

  if (!is.null(groups)) {
    .stopif(
      !is.character(groups) || anyNA(groups) || !all(nzchar(groups)),
      "'groups' must be a character vector of column names."
    )
    absent <- setdiff(groups, names(x))
    .stopif(
      length(absent) > 0L,
      paste0(
        "'groups' names ", paste0("'", absent, "'", collapse = ", "),
        ", which ", if (length(absent) > 1L) "are" else "is",
        " not a column of 'x'."
      )
    )
  }

  # The cells are rebuilt through the same helpers rt_screen() uses, so they are
  # the same cells in the same order, separator guard included. Nothing is
  # refitted: a per-cell drop rate needs only .keep and the grouping columns.
  key <- .group_key(if (is.null(groups)) NULL else x[groups], nrow(x))
  observed <- is.na(x$.reason) | x$.reason != "missing"
  idx_by_group <- split(
    which(observed),
    factor(key$id[observed], levels = seq_along(key$labels))
  )
  fits <- .assemble_fits(
    key$labels, idx_by_group, x$.keep, vector("list", length(key$labels))
  )

  .report_core(
    rule = rule, keep = x$.keep, reason = x$.reason, fits = fits,
    prob = x$.prob, groups = .resolve_groups(groups, key$names, nrow(fits)),
    policy = policy, threshold = threshold,
    max_words = max_words,
    # the r1_n_flagged columns do not survive mutate(), so a staged rule cannot
    # report its per-stage counts here
    staged = FALSE
  )
}

# nolint end

`%||%` <- function(x, y) if (is.null(x)) y else x

.resolve_groups <- function(groups, stored, n_cells) {
  if (!is.null(groups)) {
    .stopif(
      !is.character(groups) || anyNA(groups) || !all(nzchar(groups)),
      "'groups' must be a character vector of column names."
    )
    if (!is.null(stored) && length(stored) != length(groups)) {
      .stopif(TRUE, paste0(
        "'groups' names ", length(groups), " variable",
        if (length(groups) != 1L) "s", ", but the screen was grouped by ",
        length(stored), "."
      ))
    }
    return(groups)
  }
  if (is.null(stored) || anyNA(stored)) NULL else stored
}

# --- the paragraph -----------------------------------------------------------

.report_core <- function(rule, keep, reason, fits, prob, groups,
                         policy, threshold, max_words, staged) {
  .check_count(max_words, "max_words")
  num <- .report_numbers(keep, reason, fits)
  notes <- character()

  if (.rule_depth(rule) >= 3L) {
    notes <- c(notes, paste0(
      "The rule nests more than two levels deep, so the innermost ",
      "combination is named by its label rather than described. ",
      "See ?rules_compose."
    ))
  }
  if (!.known_rule(rule)) {
    notes <- c(notes, paste0(
      "One rule in this screen is not from rtprep's own roster, so it is ",
      "named by its label and carries no reference."
    ))
  }
  if (!staged && inherits(rule, "rtprep_rule_then")) {
    notes <- c(notes, paste0(
      "Per-stage counts are not available from a data frame, because the ",
      "fits table does not survive dplyr::mutate(). Call screen_fits() for ",
      "them."
    ))
  }

  keys <- .rule_reference(rule)
  clauses <- .report_clauses(
    rule, num, groups, prob, policy, threshold, fits, keys, staged
  )
  text <- .report_assemble(
    clauses, c("cells_empty", "stages", "citations"), max_words
  )

  structure(
    list(
      text = text,
      n_trials = num$n_total,
      n_missing = num$n_missing,
      n_screened = num$n_screened,
      n_excluded = num$n_excluded,
      prop_excluded = num$prop_excluded,
      reasons = num$reasons,
      cells = num$cells,
      fits = fits,
      rule = rule,
      rule_label = rule$label,
      group_names = groups,
      needs_response = .needs_response(rule),
      grouped = .is_grouped_rule(rule),
      policy = policy,
      threshold = threshold,
      references = keys,
      bibliography = if (length(keys) > 0L) {
        do.call(c, lapply(keys, .ref_entry))
      } else {
        utils::bibentry()
      },
      words = .word_count(text),
      notes = notes
    ),
    class = "rtprep_report"
  )
}

# The decomposition the paragraph depends on. n_excluded and n_screened equal
# sum(fits$n_dropped) and sum(fits$n_trials) by construction, so the prose and
# screen_fits() cannot disagree.
.report_numbers <- function(keep, reason, fits) {
  n_total <- length(keep)
  n_missing <- sum(!is.na(reason) & reason == "missing")
  n_screened <- n_total - n_missing
  n_excluded <- sum(!keep) - n_missing

  flagged <- reason[!is.na(reason) & reason != "missing"]
  reasons <- if (length(flagged) > 0L) {
    sort(table(flagged), decreasing = TRUE)
  } else {
    integer()
  }

  ok <- !is.na(fits$prop_dropped)
  cells <- data.frame(
    n = nrow(fits),
    fitted = sum(ok),
    min = if (any(ok)) min(fits$prop_dropped[ok]) else NA_real_,
    max = if (any(ok)) max(fits$prop_dropped[ok]) else NA_real_
  )

  list(
    n_total = n_total, n_missing = n_missing, n_screened = n_screened,
    n_excluded = n_excluded,
    prop_excluded = if (n_screened > 0L) n_excluded / n_screened else NA_real_,
    reasons = reasons, cells = cells
  )
}

.report_clauses <- function(rule, num, groups, prob, policy, threshold,
                            fits, keys, staged) {
  cells <- num$cells
  has_grouping <- .estimates_per_group(rule) && cells$n > 1L
  out <- list()

  out$rule <- paste0(
    .rule_sentence(rule, 1L),
    if (has_grouping) paste0(", ", .grouping_clause(rule, groups, cells$n)),
    "."
  )

  # rule_none() removes nothing by construction, so counting what it removed,
  # naming the reasons it gave and citing its sources would all be noise. Only
  # the missing-data sentence still says something.
  if (inherits(rule, "rtprep_rule_none")) {
    if (num$n_missing > 0L) {
      out$missing <- .missing_clause(num)
    }
    return(out)
  }

  # nothing was screened at all, so there is no drop rate to report and the
  # missing sentence is the whole story
  if (num$n_screened == 0L) {
    out$amount <- paste0(
      "None of the ", num$n_total, " trials had a usable response time and ",
      "grouping key, so the criterion never ran."
    )
    return(out)
  }

  if (staged) {
    out$stages <- .stage_clause(rule, fits)
  }

  out$amount <- .amount_clause(num, has_grouping)

  # only meaningful beside a range, which is the thing the empty cells are not
  # counted in
  if (.has_range(num) && cells$n > cells$fitted) {
    n_empty <- cells$n - cells$fitted
    out$cells_empty <- paste0(
      n_empty, " cell", if (n_empty != 1L) "s",
      " had no usable trials and ", if (n_empty != 1L) "are" else "is",
      " not counted in that range."
    )
  }

  if (length(num$reasons) > 0L) {
    out$reasons <- .reason_clause(num$reasons, num$n_excluded)
  }

  if (num$n_missing > 0L) {
    out$missing <- .missing_clause(num)
  }

  out$accuracy <- .accuracy_clause(rule)

  policy_clause <- .policy_clause(policy, threshold, prob)
  if (!is.null(policy_clause)) {
    out$policy <- policy_clause
  }

  if (length(keys) > 0L) {
    # agreement follows the number of rules applied, not the number of papers
    plural <- .rule_leaves(rule) > 1L
    out$citations <- paste0(
      "The criteri", if (plural) "a are" else "on is", " described by ",
      .join_prose(vapply(keys, .ref_cite, character(1))), "."
    )
  }

  out
}

.missing_clause <- function(num) {
  paste0(
    "A further ", num$n_missing, " of ", num$n_total, " trials (",
    .fmt_pct(num$n_missing / num$n_total),
    ") had a missing response time or grouping key and were excluded before ",
    "screening rather than by the criterion."
  )
}

# A range needs something to have been removed and at least two cells to have
# been fitted; otherwise "between 0% and 0%" is all it can say.
.has_range <- function(num) {
  num$n_excluded > 0L && num$cells$fitted >= 2L
}

.amount_clause <- function(num, has_grouping) {
  cells <- num$cells
  if (num$n_excluded == 0L) {
    return(paste0(
      "It removed none of the ", num$n_screened, " trials it screened."
    ))
  }
  head <- paste0(
    "This removed ", num$n_excluded, " of the ", num$n_screened,
    " trials it screened (", .fmt_pct(num$prop_excluded), ")"
  )
  if (!.has_range(num)) {
    return(paste0(head, "."))
  }
  span <- .fmt_pct_range(cells$min, cells$max)
  where <- if (has_grouping) {
    " per cell"
  } else {
    paste0(" across the ", cells$n, " cells")
  }
  paste0(head, ", ", span, where, ".")
}

.reason_clause <- function(reasons, n_excluded) {
  label <- c(
    too_fast = "fast trials", too_slow = "slow trials",
    contaminant = "trials flagged as contaminants", missing = "missing"
  )
  named <- function(nm) unname(label[nm] %||% nm)

  # One reason accounting for every exclusion is the common case, and the
  # partitive form reads as though something else was going on.
  if (length(reasons) == 1L && identical(sum(reasons), n_excluded)) {
    return(paste0("All the exclusions were ", named(names(reasons)), "."))
  }
  parts <- vapply(
    names(reasons),
    function(nm) paste0(unname(reasons[[nm]]), " were ", named(nm)),
    character(1)
  )
  # partitive: a trial the policy dropped without the rule flagging it carries
  # no reason, so the reasons need not account for every exclusion
  paste0("Of the exclusions, ", .join_prose(parts), ".")
}

.accuracy_clause <- function(rule) {
  if (isTRUE(.needs_response(rule))) {
    paste0(
      "The screen read accuracy, so the exclusions and any accuracy computed ",
      "after them are not independent."
    )
  } else {
    plural <- .rule_leaves(rule) > 1L
    paste0(
      "The criteri", if (plural) "a did" else "on did",
      " not read accuracy, so error trials passed through the screen on ",
      "their response times alone."
    )
  }
}

.policy_clause <- function(policy, threshold, prob) {
  fractional <- any(prob > 0 & prob < 1, na.rm = TRUE)
  if (identical(policy, "probabilistic")) {
    return(paste0(
      "Each trial was kept or dropped by a single draw against its ",
      "probability of being a valid decision trial."
    ))
  }
  # A deterministic rule at the default threshold has nothing to say here: the
  # probabilities are 0 and 1 and any cut between them gives the same answer.
  if (!fractional && isTRUE(all.equal(threshold, 0.5))) {
    return(NULL)
  }
  paste0(
    "Trials were kept where the probability of being a valid decision trial ",
    "exceeded ", .fmt(threshold), "."
  )
}

.stage_clause <- function(rule, fits) {
  if (!inherits(rule, "rtprep_rule_then")) {
    return(NULL)
  }
  n_stages <- length(rule$rules)
  seen <- paste0("r", seq_len(n_stages), "_n_seen")
  flagged <- paste0("r", seq_len(n_stages), "_n_flagged")
  if (!all(c(seen, flagged) %in% names(fits))) {
    return(NULL)
  }
  parts <- vapply(
    seq_len(n_stages),
    function(i) {
      paste0(
        "the ", .ordinal_word(i), " stage flagged ",
        sum(fits[[flagged[i]]], na.rm = TRUE), " of the ",
        sum(fits[[seen[i]]], na.rm = TRUE), " trials it saw"
      )
    },
    character(1)
  )
  clause <- .join_prose(parts)
  paste0(toupper(substring(clause, 1, 1)), substring(clause, 2), ".")
}

.grouping_clause <- function(rule, groups, n_cells) {
  cells <- paste0(n_cells, " cell", if (n_cells != 1L) "s")
  named <- !is.null(groups) && length(groups) > 0L
  # a hierarchical rule pools across the groups to shrink each one, so it is
  # not computed separately within them
  if (isTRUE(.is_grouped_rule(rule))) {
    return(paste0(
      "estimated across all ", n_cells, " ",
      if (named && length(groups) == 1L) paste0(groups, " ") else "",
      "cells together"
    ))
  }
  where <- if (!named) {
    paste0("each of the ", n_cells, " groups")
  } else if (length(groups) == 1L) {
    paste0("each ", groups, " cell (", cells, ")")
  } else {
    paste0("each combination of ", .join_prose(groups), " (", cells, ")")
  }
  paste0("computed separately within ", where)
}

# The grouping sentence is about where a criterion was estimated. An absolute
# cutoff, a pass-through and an oracle estimate nothing, so saying they were
# "computed separately within each participant" would be false.
.estimates_per_group <- function(rule) {
  if (!is.null(rule$rules)) {
    return(any(vapply(rule$rules, .estimates_per_group, logical(1))))
  }
  !inherits(
    rule,
    c("rtprep_rule_none", "rtprep_rule_cutoff", "rtprep_rule_oracle")
  )
}

# The cap is a guard, not a design constraint: a flat rule runs to about 90
# words and the deepest composite in the roster to about 150, so this normally
# does not fire. It exists so that an unusual rule cannot produce a paragraph no
# journal would take. Clauses are dropped whole; no sentence is ever truncated.
.report_assemble <- function(clauses, optional, max_words) {
  clauses <- clauses[!vapply(clauses, is.null, logical(1))]
  text <- paste(unlist(clauses), collapse = " ")
  for (nm in optional) {
    if (.word_count(text) <= max_words) break
    clauses[[nm]] <- NULL
    text <- paste(unlist(clauses), collapse = " ")
  }
  text
}

.word_count <- function(text) {
  if (!nzchar(trimws(text))) {
    return(0L)
  }
  length(strsplit(trimws(text), "[[:space:]]+")[[1]])
}

.fmt_pct <- function(p) {
  if (is.na(p)) {
    return("not defined")
  }
  paste0(format(round(100 * p, 1), trim = TRUE, nsmall = 1), "%")
}

# Widen the precision until the two endpoints read differently, so that a range
# never prints as "between 4% and 4%".
.fmt_pct_range <- function(lo, hi) {
  for (digits in 0:2) {
    a <- format(round(100 * lo, digits), trim = TRUE, nsmall = digits)
    b <- format(round(100 * hi, digits), trim = TRUE, nsmall = digits)
    if (a != b) {
      return(paste0("between ", a, "% and ", b, "%"))
    }
  }
  paste0("the same ", .fmt_pct(lo), " from every cell")
}

.ordinal_word <- function(n) {
  words <- c(
    "first", "second", "third", "fourth", "fifth", "sixth",
    "seventh", "eighth", "ninth", "tenth", "eleventh", "twelfth"
  )
  if (n >= 1L && n <= length(words)) words[n] else paste0(n, "th")
}

# --- methods on the report ---------------------------------------------------

#' Methods for a screening report
#'
#' [report_screening()] returns the paragraph together with every number in it.
#' `print()` wraps the paragraph to the console width and says how long it is;
#' `as.character()` returns it unwrapped, for pasting into a document or an
#' inline `r` chunk.
#'
#' @param x,object A report from [report_screening()].
#' @param width Wrapping width for `print()`.
#' @param ... Ignored.
#'
#' @return `format()` returns the wrapped paragraph as a character vector,
#'   `print()` returns `x` invisibly, `as.character()` returns the paragraph as
#'   a single string, and `toBibtex()` returns the BibTeX entries for the
#'   references cited.
#'
#' @examples
#' scr <- rt_screen(rt_example$rt, rule_mad(2.5), .by = rt_example$id)
#' rep <- report_screening(scr, groups = "participant")
#' rep
#'
#' cat(as.character(rep))
#' utils::toBibtex(rep)
#'
#' @name rtprep_report
NULL

#' @rdname rtprep_report
#' @export
format.rtprep_report <- function(x, width = 0.9 * getOption("width"), ...) {
  strwrap(x$text, width = max(40, width))
}

#' @rdname rtprep_report
#' @export
print.rtprep_report <- function(x, ...) {
  cat(format(x), sep = "\n")
  for (note in x$notes) {
    cat("\n", strwrap(paste("Note:", note), prefix = ""), sep = "\n")
  }
  cat(sprintf(
    "\n[%d words; %d reference%s%s]\n",
    x$words, length(x$references),
    if (length(x$references) != 1L) "s" else "",
    if (length(x$references) > 0L) "; toBibtex(x) for BibTeX" else ""
  ))
  invisible(x)
}

#' @rdname rtprep_report
#' @export
as.character.rtprep_report <- function(x, ...) x$text

#' @rdname rtprep_report
#' @exportS3Method utils::toBibtex
toBibtex.rtprep_report <- function(object, ...) {
  utils::toBibtex(object$bibliography)
}
