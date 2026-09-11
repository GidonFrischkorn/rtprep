#' Screen response times with any rule
#'
#' @description
#' Applies a screening rule and returns one row per input trial: the keep
#' decision, the probability behind it, the rule's label, and the reason for a
#' flag. The four columns are the same whichever rule went in, so changing the
#' rule changes one word and nothing around it.
#'
#' @param rt Numeric vector of response times **in seconds**. `NA` is allowed;
#'   non-positive values are an error.
#' @param rule A rule object; see [rules].
#' @param response Optional response coding of the same length as `rt`, given as
#'   numeric 0/1, logical, or a character or factor using labels such as
#'   `"correct"`/`"error"` or `"upper"`/`"lower"`. Required by [rule_ewma()] and
#'   by [rule_mixture()] with `use_accuracy = TRUE`.
#' @param .by Optional grouping of the same length as `rt`: a vector, factor,
#'   list of vectors, or data frame. Rules are fitted separately within each
#'   group. `NULL` treats all trials as one group.
#' @param policy Exclusion policy. `"threshold"` keeps a trial when its
#'   probability of validity exceeds `threshold`. `"probabilistic"` keeps it
#'   with that probability, drawing once per trial.
#' @param threshold Cut for `policy = "threshold"`, in `[0, 1]`. Ignored under
#'   the probabilistic policy.
#'
#' @return A `data.frame` with one row per element of `rt`, in input order:
#'
#'   \describe{
#'     \item{`.keep`}{logical; keep this trial under the stated policy.}
#'     \item{`.prob`}{numeric; the probability that the trial came from the
#'       decision process, that is **P(valid)**. Deterministic rules return 0 or
#'       1. Note that `bmm::flag_contaminant_rts()` returns the complement.}
#'     \item{`.rule`}{character; the rule's label.}
#'     \item{`.reason`}{character; why the **rule** flagged the trial:
#'       `"too_fast"`, `"too_slow"`, `"contaminant"`, or `"missing"`. `NA`
#'       whenever the rule did not flag it, which includes trials the keep
#'       policy dropped anyway (at `threshold = 1`, or on a probabilistic draw
#'       against a fractional `.prob`). A kept trial never carries a reason.}
#'   }
#'
#'   Per-group fit diagnostics are attached as `attr(x, "fits")`: one row per
#'   group with `.group`, `n_trials`, `n_dropped`, and `prop_dropped`, plus
#'   whatever the rule reports (bounds, iterations, EM convergence).
#'   [screen_fits()] returns that table on its own.
#'
#' @details
#' Separating the probability from the decision is deliberate. A mixture rule
#' produces a genuine posterior probability; a cutoff produces a degenerate one.
#' Keeping both in the same object means a probabilistic screen can feed
#' `rt_summary()` as a weight vector without being forced through a threshold
#' first, and that the same comparison machinery covers both families.
#'
#' Trials with a missing response time, or a missing value in any `.by`
#' component, are excluded from every rule's computation and returned with
#' `.keep = FALSE`, `.prob = NA`, and `.reason = "missing"`.
#'
#' Under `policy = "probabilistic"` the decision is stochastic by design. There
#' is no `set.seed()` anywhere in `rtprep`; reproducibility is the caller's.
#'
#' # Inside a data-frame pipeline
#'
#' The function takes vectors and returns a data frame, so it drops into
#' `dplyr::mutate()` unchanged: `mutate(rt_screen(rt, rule_sd(2.5)), .by = id)`
#' splices the four columns in, and `filter(.keep)` then drops the flagged
#' trials. Two things to know. `attr(x, "fits")` does not survive `mutate()`;
#' use [screen_fits()] when the per-group table is what you want. And dplyr
#' reads `.keep =` as its own argument, so assign the column by splicing
#' rather than by name. When only the filter is needed, [rt_keep()] returns
#' the logical vector directly.
#'
#' @seealso [rules] for the rules themselves; [rt_keep()] for the keep vector
#'   alone; [screen_fits()] for the per-group table alone; [screen_compare()]
#'   to apply several rules at once; [rt_summary()] to aggregate what survives.
#'
#' @examples
#' rt <- c(0.12, 0.31, 0.35, 0.38, 0.42, 0.47, 0.55, 2.90)
#' rt_screen(rt, rule_cutoff(0.18, 2.5))
#'
#' # rules are group-aware without the package depending on dplyr
#' id <- rep(c("a", "b"), each = 4)
#' scr <- rt_screen(rt, rule_sd(2), .by = id)
#' attr(scr, "fits")
#'
#' # a rule that reads accuracy takes it by name
#' correct <- c(0, 1, 1, 1, 0, 1, 1, 1)
#' rt_screen(rt, rule_ewma(lambda = 0.1), response = correct)
#'
#' @export
rt_screen <- function(rt, rule, response = NULL, .by = NULL,
                      policy = c("threshold", "probabilistic"),
                      threshold = 0.5) {
  policy <- match.arg(policy)
  .check_rt(rt)
  .stopif(
    !inherits(rule, "rtprep_rule"),
    paste0(
      "'rule' must be a rule object, e.g. from rule_sd(). Got ",
      class(rule)[1], "."
    )
  )
  .stopif(
    !is.numeric(threshold) || length(threshold) != 1L || is.na(threshold) ||
      threshold < 0 || threshold > 1,
    "'threshold' must be a single number between 0 and 1."
  )
  # dispatch is checked up front, not left to apply_rule.default(): an
  # unimplemented rule must fail loudly even when every group is empty. The
  # whole class vector is searched rather than its head, because a rule built
  # with new_rule(fun = ) inherits "rtprep_rule_fun" behind its own subclass and
  # is served by that class's method.
  generic <- if (.is_grouped_rule(rule)) "apply_rule_grouped" else "apply_rule"
  has_method <- any(vapply(
    class(rule),
    function(cl) !is.null(utils::getS3method(generic, cl, optional = TRUE)),
    logical(1)
  ))
  .stopif(
    !has_method,
    paste0(
      generic, "() is not yet implemented for rule class '",
      class(rule)[1], "'."
    )
  )
  unsupported <- .rule_unsupported(rule)
  .stopif(!is.null(unsupported), unsupported)

  # a rule carrying per-trial values must carry exactly as many as there are
  # trials; recycling one silently is the failure mode this check exists for
  carried <- .per_trial_lengths(rule)
  wrong <- carried[carried != length(rt)]
  .stopif(
    length(wrong) > 0L,
    paste0(
      "Rule '", rule$label, "' carries '", names(wrong)[1], "' with ",
      wrong[1], " values, but 'rt' has ", length(rt),
      ". They must be the same length."
    )
  )

  needs_response <- .needs_response(rule)
  if (!is.null(response)) {
    .stopif(
      length(response) != length(rt),
      "'response' must have the same length as 'rt'."
    )
  } else {
    .stopif(
      needs_response,
      paste0("Rule '", rule$label, "' requires 'response'.")
    )
  }

  n <- length(rt)
  key <- .group_key(.by, n)
  observed <- !is.na(rt) & !is.na(key$id)
  # a rule that reads accuracy cannot use a trial whose accuracy is missing; the
  # alternative is a single NA propagating through the EWMA recursion and
  # silently switching the rule off for the whole group
  if (needs_response) {
    # converted once here rather than inside the group loop, so validation
    # stays at the public boundary and the inner loop stays cheap
    response <- as.numeric(.as_upper(response))
    observed <- observed & !is.na(response)
  }

  prob <- rep(NA_real_, n)
  reason <- rep(NA_character_, n)
  reason[!observed] <- "missing"

  groups <- key$labels
  fits <- vector("list", length(groups))

  # Each group's rows are found in one pass rather than by rescanning the whole
  # trial vector per group. The scan version was O(n x groups) -- quadratic in
  # participants at fixed trials each -- which is minutes per call at the scale
  # an online study reaches, and invisible at the 200 subjects the simulations
  # screen.
  obs <- which(observed)
  idx_by_group <- split(obs, factor(key$id[obs], levels = seq_along(groups)))

  if (.is_grouped_rule(rule)) {
    # A rule that pools across groups sees them all at once. It gets only the
    # observed trials, renumbered, so it never has to reason about missingness.
    within <- split(
      seq_along(obs), factor(key$id[obs], levels = seq_along(groups))
    )
    nonempty <- lengths(within) > 0L
    res <- apply_rule_grouped(
      .subset_rule(rule, obs), rt[obs], response[obs], within[nonempty]
    )
    .check_rule_result(res, length(obs), rule, grouped = TRUE)
    .check_rule_fit(res$fit, rule, grouped = TRUE, n_groups = sum(nonempty))
    prob[obs] <- res$prob
    reason[obs] <- res$reason
    fits[which(nonempty)] <- if (is.null(res$fit)) list(NULL) else res$fit
  } else {
    for (g in seq_along(groups)) {
      idx <- idx_by_group[[g]]
      if (length(idx) == 0L) next
      res <- apply_rule(.subset_rule(rule, idx), rt[idx], response[idx])
      .check_rule_result(res, length(idx), rule)
      .check_rule_fit(res$fit, rule)
      prob[idx] <- res$prob
      reason[idx] <- res$reason
      # single-bracket assignment: a rule with no diagnostics returns NULL, and
      # fits[[g]] <- NULL would delete the slot rather than leave it empty
      fits[g] <- list(res$fit)
    }
  }

  .keep <- if (policy == "threshold") {
    prob > threshold
  } else {
    stats::runif(n) < prob
  }
  .keep[!observed] <- FALSE
  # .reason says why the rule flagged a trial, so a kept trial cannot carry one.
  # A trial the rule did not flag but the policy dropped anyway -- at
  # threshold = 1, or on a probabilistic draw against a fractional .prob --
  # keeps .reason = NA.
  reason[.keep] <- NA_character_

  out <- data.frame(
    .keep = .keep,
    .prob = prob,
    .rule = rule$label,
    .reason = reason,
    stringsAsFactors = FALSE
  )
  fits_table <- .assemble_fits(groups, idx_by_group, .keep, fits)
  .warn_bounds(fits_table)
  .warn_inverted(fits_table)
  .warn_unconverged(fits_table)
  attr(out, "fits") <- fits_table
  attr(out, "policy") <- policy
  attr(out, "threshold") <- threshold
  # Neither the rule nor the grouping is recoverable from the four columns:
  # .rule carries a label, not the object, and the fits table carries cell
  # labels with the values pasted together, not the variable names. Both are
  # what report_screening() needs to describe the screen rather than count it.
  attr(out, "rule") <- rule
  attr(out, "group_names") <- key$names
  # a subclass of data.frame: every data-frame idiom still works, and the class
  # buys a print() that reports the screen instead of listing every trial
  class(out) <- c("rtprep_screen", "data.frame")
  out
}

#' Keep vector from a screening rule
#'
#' @description
#' The `.keep` column of [rt_screen()] on its own, for the case where a filter
#' is all that is wanted. It reports how many trials it dropped, once per call,
#' so that the exclusion count is logged next to the exclusion rather than
#' reconstructed afterwards.
#'
#' @inheritParams rt_screen
#' @param quiet If `FALSE` (the default), one message states the rule, the
#'   number of trials dropped, and the proportion. `TRUE` suppresses it.
#'
#' @return A logical vector the length of `rt`: `TRUE` for a trial to keep.
#'   Trials with a missing response time or grouping key are `FALSE`, as in
#'   [rt_screen()].
#'
#' @details
#' Inside a grouped `filter()` the message fires once per group, because the
#' function is called once per group. Pass `.by` to `rt_keep()` instead of to
#' `filter()`: the keep vector is identical either way, and the count then
#' covers the whole data set in one line. Or set `quiet = TRUE`.
#'
#' @seealso [rt_screen()] for the probability and the reason alongside the
#'   decision; [screen_fits()] for the per-group diagnostics.
#'
#' @examples
#' rt <- c(0.12, 0.31, 0.35, 0.38, 0.42, 0.47, 0.55, 2.90)
#' keep <- rt_keep(rt, rule_cutoff(0.18, 2.5))
#' rt[keep]
#'
#' # with dplyr: dat |> filter(rt_keep(rt, rule_sd(2.5), .by = id))
#'
#' @export
rt_keep <- function(rt, rule, response = NULL, .by = NULL,
                    policy = c("threshold", "probabilistic"),
                    threshold = 0.5, quiet = FALSE) {
  .check_flag(quiet, "quiet")
  scr <- rt_screen(
    rt, rule, response,
    .by = .by, policy = policy, threshold = threshold
  )
  keep <- scr$.keep
  if (!quiet) {
    n_dropped <- sum(!keep)
    n_missing <- sum(!is.na(scr$.reason) & scr$.reason == "missing")
    message(sprintf(
      "%s: dropped %d of %d trials (%.1f%%)%s",
      rule$label, n_dropped, length(rt), 100 * n_dropped / length(rt),
      if (n_missing > 0L) sprintf(", %d of them missing", n_missing) else ""
    ))
  }
  keep
}

#' Per-group fit diagnostics from a screening rule
#'
#' @description
#' The `fits` table of [rt_screen()] on its own: one row per group with the
#' bookkeeping columns and whatever the rule reports. It exists because an
#' attribute does not survive `dplyr::mutate()`, so the table is otherwise out
#' of reach inside a pipeline.
#'
#' @inheritParams rt_screen
#'
#' @return A `data.frame` with one row per group, in group order: `.group`,
#'   `n_trials`, `n_dropped`, `prop_dropped`, then the rule's own columns
#'   (bounds, criterion, iterations, EM convergence, and so on; see [rules]).
#'   `n_dropped` and `prop_dropped` count under the stated `policy` and
#'   `threshold`, exactly as `attr(rt_screen(...), "fits")` would.
#'
#' @seealso [rt_screen()], whose per-trial result carries this table as an
#'   attribute; [screen_compare()] for the same table stacked over several
#'   rules.
#'
#' @examples
#' rt <- c(0.12, 0.31, 0.35, 0.38, 0.42, 0.47, 0.55, 2.90)
#' id <- rep(c("a", "b"), each = 4)
#' screen_fits(rt, rule_sd(2), .by = id)
#'
#' # with dplyr: dat |> reframe(screen_fits(rt, rule_sd(2.5)), .by = id)
#'
#' @export
screen_fits <- function(rt, rule, response = NULL, .by = NULL,
                        policy = c("threshold", "probabilistic"),
                        threshold = 0.5) {
  scr <- rt_screen(
    rt, rule, response,
    .by = .by, policy = policy, threshold = threshold
  )
  attr(scr, "fits")
}

# Report failed fits once for the whole call rather than once per group.
# Warning inside the group loop -- which is what bmm does -- would emit one
# warning per subject, and a SimDesign replication has thousands of them. The
# per-group detail stays in attr(x, "fits").
# A composite prefixes each component's diagnostics with its position, so these
# match by suffix: `converged` and `r1_converged` are the same column reported
# by a rule that is on its own and by one inside a combination. Matching the
# bare name only would let a mixture inside a composite fail to converge with
# nothing said.
.fit_cols <- function(fits, name) {
  if (is.null(fits)) {
    return(list())
  }
  hit <- grepl(paste0("(^|_)", name, "$"), names(fits))
  unname(as.list(fits[hit]))
}

.warn_unconverged <- function(fits) {
  cols <- .fit_cols(fits, "converged")
  if (length(cols) == 0L) {
    return(invisible(NULL))
  }
  # groups that were never fitted have NA here and belong in neither count
  fitted <- sum(vapply(cols, function(c) sum(!is.na(c)), integer(1)))
  n_failed <- sum(vapply(cols, function(c) sum(!c, na.rm = TRUE), integer(1)))
  .warnif(n_failed > 0L, paste0(
    "The model fit did not converge for ", n_failed, " of ", fitted,
    " fitted group(s); those trials were all kept. ",
    "See attr(x, \"fits\") for which."
  ))
  invisible(NULL)
}

# An accuracy-informed fit whose valid component came out less accurate than a
# guess has swapped its labels. Reported rather than constrained: it usually
# means the two components are not separable at this contamination rate, which
# is a finding rather than a nuisance.
.warn_inverted <- function(fits) {
  cols <- .fit_cols(fits, "accuracy_inverted")
  if (length(cols) == 0L) {
    return(invisible(NULL))
  }
  n_inverted <- sum(vapply(cols, sum, numeric(1), na.rm = TRUE))
  .warnif(n_inverted > 0L, paste0(
    "In ", n_inverted, " group(s) the fitted decision process came out less ",
    "accurate than chance, which means the mixture labelled its components ",
    "the wrong way round. Treat those fits as uninformative."
  ))
  invisible(NULL)
}

# Bounds are resolved once per group, so a rule that reports them flags the two
# conditions worth mentioning and lets the engine say them once.
.warn_bounds <- function(fits) {
  cols <- .fit_cols(fits, "bound_inverted")
  if (length(cols) == 0L) {
    return(invisible(NULL))
  }
  n_inverted <- sum(vapply(cols, sum, numeric(1), na.rm = TRUE))
  .warnif(n_inverted > 0L, paste0(
    "Contaminant bounds resolved to lower >= upper for ", n_inverted,
    " group(s); the buffered data range was used instead."
  ))

  fast <- .fit_cols(fits, "bound_excludes_fast")
  slow <- .fit_cols(fits, "bound_excludes_slow")
  n_narrow <- sum(vapply(seq_along(fast), function(i) {
    sum(fast[[i]] | slow[[i]], na.rm = TRUE)
  }, numeric(1)))
  .warnif(n_narrow > 0L, paste0(
    "Contaminant bounds exclude observed trials in ", n_narrow,
    " group(s); those trials cannot be classified as contaminants."
  ))
  invisible(NULL)
}

# One row per group, in group-key order, with the shared bookkeeping columns
# first and whatever the rule reported appended.
#
# `idx_by_group` is the index list rt_screen() already built, so the counts come
# from lengths() and one pass per group over that group's own rows -- never over
# the full trial vector.
.assemble_fits <- function(groups, idx_by_group, .keep, fits) {
  n_trials <- unname(lengths(idx_by_group))
  n_dropped <- unname(vapply(
    idx_by_group, function(idx) sum(!.keep[idx]), integer(1)
  ))
  prop_dropped <- n_dropped / n_trials
  # a group with nothing observed has no drop rate, not a rate of zero
  prop_dropped[n_trials == 0L] <- NA_real_

  base <- data.frame(
    .group = groups,
    n_trials = as.integer(n_trials),
    n_dropped = as.integer(n_dropped),
    prop_dropped = prop_dropped,
    stringsAsFactors = FALSE
  )
  # every group key was missing: still a data frame, just an empty one
  if (length(groups) == 0L) {
    return(base)
  }

  rule_cols <- .fill_fits(fits)
  if (is.null(rule_cols)) base else cbind(base, rule_cols)
}

# Stack the rules' one-row fit data frames in group order, column by column.
# Groups the rule never fitted, and columns it did not report for every group,
# are filled with NA -- the same answer as rbind()ing padded rows, without
# building and binding one data frame per group.
.fill_fits <- function(fits) {
  present <- !vapply(fits, is.null, logical(1))
  if (!any(present)) {
    return(NULL)
  }

  all_names <- unique(unlist(lapply(fits[present], names)))
  cols <- lapply(all_names, function(nm) {
    unlist(
      lapply(fits, function(f) if (is.null(f[[nm]])) NA else f[[nm]]),
      use.names = FALSE
    )
  })
  names(cols) <- all_names
  do.call(
    data.frame,
    c(cols, list(check.names = FALSE, stringsAsFactors = FALSE))
  )
}

# rbind() that tolerates rows with different columns, filling the gaps with NA.
# Groups can differ when a rule reports nothing for an empty group.
.rbind_fill <- function(rows) {
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0L) {
    # every group key was missing: still a data frame, just an empty one
    return(data.frame(
      .group = character(0), n_trials = integer(0),
      n_dropped = integer(0), prop_dropped = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  all_names <- unique(unlist(lapply(rows, names)))
  padded <- lapply(rows, function(r) {
    missing_cols <- setdiff(all_names, names(r))
    for (nm in missing_cols) r[[nm]] <- NA
    r[all_names]
  })
  out <- do.call(rbind, padded)
  row.names(out) <- NULL
  out
}

# --- the rule engine --------------------------------------------------------
#
# The apply_rule() generic and its contract live in R/extend.R, because both are
# public: an outside package adds a family with one new_rule() call and one
# method.

# A rule whose constructor is valid but whose configuration is not yet
# implemented. Returns NULL when the rule can run, otherwise the message.
# Checked before the group loop so it fires even when there is nothing to fit.
.rule_unsupported <- function(rule) UseMethod(".rule_unsupported")

.rule_unsupported.default <- function(rule) NULL

# Which rules cannot run on response times alone. The default reads the flag
# new_rule() records, so an outside rule declares this without a method.
.needs_response <- function(rule) UseMethod(".needs_response")

.needs_response.default <- function(rule) {
  isTRUE(attr(rule, "needs_response"))
}

# Which rules have to see every group at once rather than one at a time.
.is_grouped_rule <- function(rule) UseMethod(".is_grouped_rule")

.is_grouped_rule.default <- function(rule) isTRUE(attr(rule, "grouped"))

# Parameters that hold one value per trial and must be cut down to the group
# before dispatch. Recycling them instead is a wrong answer under a warning.
.per_trial_fields <- function(rule) {
  fields <- attr(rule, "per_trial")
  if (is.null(fields)) character() else fields
}

.subset_rule <- function(rule, idx) {
  for (nm in .per_trial_fields(rule)) rule[[nm]] <- rule[[nm]][idx]
  # a composite holds its components in `rules`, and one of them may carry
  # per-trial values of its own
  if (!is.null(rule$rules)) {
    rule$rules <- lapply(rule$rules, .subset_rule, idx)
  }
  rule
}

# Every per-trial field the rule carries, its components included, so the
# length check at the public boundary reaches inside a composite.
.per_trial_lengths <- function(rule) {
  own <- lapply(.per_trial_fields(rule), function(nm) {
    stats::setNames(length(rule[[nm]]), nm)
  })
  nested <- if (is.null(rule$rules)) {
    list()
  } else {
    unlist(lapply(rule$rules, .per_trial_lengths))
  }
  c(unlist(own), nested)
}

.needs_response.rtprep_rule_ewma <- function(rule) TRUE

.needs_response.rtprep_rule_ez_support <- function(rule) TRUE

.needs_response.rtprep_rule_mixture <- function(rule) isTRUE(rule$use_accuracy)
