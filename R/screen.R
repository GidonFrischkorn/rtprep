#' Screen response times with any rule
#'
#' @description
#' Applies a screening rule and returns one row per input trial, whichever rule
#' was used. That uniformity is the package's reason to exist: absolute cutoffs,
#' standard deviation criteria, recursive criteria, and model-based mixtures all
#' come back in the same shape, so a preprocessing choice can be compared rather
#' than assumed.
#'
#' @param rt Numeric vector of response times **in seconds**. `NA` is allowed;
#'   non-positive values are an error.
#' @param response Optional response coding of the same length as `rt`, given as
#'   numeric 0/1, logical, or a character or factor using labels such as
#'   `"correct"`/`"error"` or `"upper"`/`"lower"`. Required by [rule_ewma()] and
#'   by [rule_mixture()] with `use_accuracy = TRUE`.
#' @param rule A rule object; see [rules].
#' @param .by Optional grouping of the same length as `rt` — a vector, factor,
#'   list of vectors, or data frame. Rules are fitted separately within each
#'   group. `NULL` treats all trials as one group.
#' @param keep Exclusion policy. `"threshold"` keeps a trial when its
#'   probability of validity exceeds `threshold`. `"probabilistic"` keeps it
#'   with that probability, drawing once per trial.
#' @param threshold Cut for `keep = "threshold"`, in `[0, 1]`. Ignored under the
#'   probabilistic policy.
#'
#' @return A `data.frame` with one row per element of `rt`, in input order:
#'
#'   \describe{
#'     \item{`.keep`}{logical; keep this trial under the stated policy.}
#'     \item{`.prob`}{numeric; the probability that the trial came from the
#'       decision process, that is **P(valid)**. Deterministic rules return 0 or
#'       1. Note that `bmm::flag_contaminant_rts()` returns the complement.}
#'     \item{`.rule`}{character; the rule's label.}
#'     \item{`.reason`}{character; why the **rule** flagged the trial —
#'       `"too_fast"`, `"too_slow"`, `"contaminant"`, or `"missing"`. `NA`
#'       whenever the rule did not flag it, which includes trials the keep
#'       policy dropped anyway (at `threshold = 1`, or on a probabilistic draw
#'       against a fractional `.prob`). A kept trial never carries a reason.}
#'   }
#'
#'   Per-group fit diagnostics are attached as `attr(x, "fits")`: one row per
#'   group with `.group`, `n_trials`, `n_dropped`, and `prop_dropped`, plus
#'   whatever the rule reports (bounds, iterations, EM convergence).
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
#' Under `keep = "probabilistic"` the decision is stochastic by design. There is
#' no `set.seed()` anywhere in `rtprep`; reproducibility is the caller's, which
#' in the simulation scripts means `SimDesign`'s seed handling.
#'
#' @seealso [rules] for the rules themselves; `screen_compare()` to apply
#'   several at once; `rt_summary()` to aggregate what survives.
#'
#' @examples
#' rt <- c(0.12, 0.31, 0.35, 0.38, 0.42, 0.47, 0.55, 2.90)
#' rt_screen(rt, rule = rule_cutoff(0.18, 2.5))
#'
#' # rules are group-aware without the package depending on dplyr
#' id <- rep(c("a", "b"), each = 4)
#' scr <- rt_screen(rt, rule = rule_sd(2), .by = id)
#' attr(scr, "fits")
#'
#' @export
rt_screen <- function(rt, response = NULL, rule, .by = NULL,
                      keep = c("threshold", "probabilistic"),
                      threshold = 0.5) {
  keep <- match.arg(keep)
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
  # unimplemented rule must fail loudly even when every group is empty
  .stopif(
    is.null(utils::getS3method("apply_rule", class(rule)[1], optional = TRUE)),
    paste0(
      "apply_rule() is not yet implemented for rule class '",
      class(rule)[1], "'."
    )
  )
  unsupported <- .rule_unsupported(rule)
  .stopif(!is.null(unsupported), unsupported)

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

  for (g in seq_along(groups)) {
    idx <- idx_by_group[[g]]
    if (length(idx) == 0L) next
    res <- apply_rule(rule, rt[idx], response[idx])
    prob[idx] <- res$prob
    reason[idx] <- res$reason
    # single-bracket assignment: a rule with no diagnostics returns NULL, and
    # fits[[g]] <- NULL would delete the slot rather than leave it empty
    fits[g] <- list(res$fit)
  }

  .keep <- if (keep == "threshold") {
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
  out
}

# Report failed fits once for the whole call rather than once per group.
# Warning inside the group loop -- which is what bmm does -- would emit one
# warning per subject, and a SimDesign replication has thousands of them. The
# per-group detail stays in attr(x, "fits").
.warn_unconverged <- function(fits) {
  if (is.null(fits) || !"converged" %in% names(fits)) {
    return(invisible(NULL))
  }
  # groups that were never fitted have NA here and belong in neither count
  fitted <- !is.na(fits$converged)
  n_failed <- sum(!fits$converged[fitted])
  .warnif(n_failed > 0L, paste0(
    "The model fit did not converge for ", n_failed, " of ", sum(fitted),
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
  if (is.null(fits) || !"accuracy_inverted" %in% names(fits)) {
    return(invisible(NULL))
  }
  n_inverted <- sum(fits$accuracy_inverted, na.rm = TRUE)
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
  if (is.null(fits) || !"bound_inverted" %in% names(fits)) {
    return(invisible(NULL))
  }
  n_inverted <- sum(fits$bound_inverted, na.rm = TRUE)
  .warnif(n_inverted > 0L, paste0(
    "Contaminant bounds resolved to lower >= upper for ", n_inverted,
    " group(s); the buffered data range was used instead."
  ))

  n_narrow <- sum(fits$bound_excludes_fast | fits$bound_excludes_slow,
    na.rm = TRUE
  )
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

# --- the internal rule engine ----------------------------------------------

# Apply one rule to one group.
#
# Called with `rt` already stripped of missing values and guaranteed non-empty,
# so methods do no validation. Each method returns a list of
#   prob   numeric, length(rt), in [0, 1] -- P(valid)
#   reason character, length(rt), NA where the trial is valid
#   fit    one-row data.frame of diagnostics, or NULL
#
# Adding a rule means one constructor plus one method here; the engine, the
# comparison layer, and the simulation code pick it up unchanged.
apply_rule <- function(rule, rt, response = NULL) UseMethod("apply_rule")

#' @exportS3Method
apply_rule.default <- function(rule, rt, response = NULL) {
  stop(
    "apply_rule() is not yet implemented for rule class '",
    class(rule)[1], "'.",
    call. = FALSE
  )
}

# A rule whose constructor is valid but whose configuration is not yet
# implemented. Returns NULL when the rule can run, otherwise the message.
# Checked before the group loop so it fires even when there is nothing to fit.
.rule_unsupported <- function(rule) UseMethod(".rule_unsupported")

.rule_unsupported.default <- function(rule) NULL

# Which rules cannot run on response times alone.
.needs_response <- function(rule) UseMethod(".needs_response")

.needs_response.default <- function(rule) FALSE

.needs_response.rtprep_rule_ewma <- function(rule) TRUE

.needs_response.rtprep_rule_ez_support <- function(rule) TRUE

.needs_response.rtprep_rule_mixture <- function(rule) isTRUE(rule$use_accuracy)
