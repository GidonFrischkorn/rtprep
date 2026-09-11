# The one rule that cannot be applied one group at a time: it needs every
# group's centre and spread before it can place any group's criterion.

#' Hierarchical screening
#'
#' A location and spread criterion whose centre and spread are shrunk towards
#' the values pooled over all groups, rather than estimated from each group
#' alone.
#'
#' **Experimental.** No published convention exists for it, so it has no
#' conventional setting to cite, and it is not a recommendation.
#'
#' @details
#' A per-participant criterion is estimated from the very data it is meant to
#' clean. A participant with a handful of very slow trials has a mean and a
#' standard deviation pulled outward by exactly those trials, so the criterion
#' widens to admit them: the more contaminated a participant is, the less their
#' own criterion removes. Estimating one criterion for everyone instead trades
#' that for a different error, since participants really do differ in speed and
#' variability.
#'
#' Shrinkage sits between the two. Each group's centre is
#' `w * centre_group + (1 - w) * centre_pooled` with `w = n / (n + n0)`, and its
#' spread is shrunk the same way on the log scale, which keeps it positive.
#' `n0` is the number of trials at which a group is weighted equally between its
#' own estimate and the pooled one: `n0 = 0` gives each group its own criterion,
#' exactly as `rule_sd()` under the same grouping, and `n0 = Inf` gives every
#' group one common criterion. A group whose own spread cannot be computed
#' pools completely, which is the case the method exists for.
#'
#' @section Grouping:
#' `.by` in [rt_screen()] names the units that are shrunk towards each other,
#' normally participants. Everything in one call is pooled, so a `.by` that
#' crosses participants with an experimental condition pools across conditions
#' as well, and a condition that is genuinely slower drags every centre towards
#' it. Screen one condition at a time.
#'
#' @param n_sd Multiplier applied to the shrunk spread.
#' @param n0 Trials at which a group is weighted equally between its own
#'   estimate and the pooled one. Larger values shrink harder. `Inf` gives one
#'   criterion for every group.
#' @param center Location statistic, `"mean"` or `"median"`.
#' @param scale Spread statistic, `"sd"` or `"mad"`.
#'
#' @return An object of class
#'   `c("rtprep_rule_hierarchical", "rtprep_rule")`.
#'
#' @examples
#' rule_hierarchical()
#'
#' # what shrinkage changes, against the same criterion estimated per group
#' screen_compare(
#'   rt_example$rt,
#'   list(
#'     per_group = rule_mad(2.5),
#'     shrunk = rule_hierarchical(
#'       2.5,
#'       n0 = 20, center = "median", scale = "mad"
#'     )
#'   ),
#'   .by = rt_example$id
#' )
#'
#' @seealso [rules] for the criteria estimated within each group.
#' @export
rule_hierarchical <- function(n_sd = 2.5, n0 = 20,
                              center = c("mean", "median"),
                              scale = c("sd", "mad")) {
  .check_scalar(n_sd, "n_sd", lower = 0, incl_lower = FALSE)
  .check_scalar(n0, "n0", lower = 0, allow_inf = TRUE)
  center <- match.arg(center)
  scale <- match.arg(scale)

  new_rule(
    "hierarchical",
    label = paste0(
      "hierarchical(", .fmt(n_sd), ", n0 = ", .fmt(n0), ", ", center, ", ",
      scale, ")"
    ),
    n_sd = n_sd, n0 = n0, center = center, scale = scale,
    grouped = TRUE
  )
}

# nolint start: object_length_linter.
.describe_rule.rtprep_rule_hierarchical <- function(x) {
  # nolint end
  paste0(
    "Exclude trials more than ", .fmt(x$n_sd), " x ", x$scale, " from the ",
    x$center, ", both shrunk towards the pooled value at n0 = ", .fmt(x$n0),
    " (experimental)."
  )
}

#' @exportS3Method
apply_rule_grouped.rtprep_rule_hierarchical <- function(rule, rt,
                                                        response = NULL,
                                                        idx_by_group) {
  n <- length(rt)
  centre_i <- vapply(idx_by_group, function(i) {
    if (rule$center == "mean") mean(rt[i]) else stats::median(rt[i])
  }, numeric(1))
  scale_i <- vapply(idx_by_group, function(i) {
    if (rule$scale == "sd") {
      if (length(i) > 1L) stats::sd(rt[i]) else NA_real_
    } else {
      stats::mad(rt[i])
    }
  }, numeric(1))
  n_i <- lengths(idx_by_group)

  usable <- is.finite(scale_i) & scale_i > 0
  fit_row <- function(g, w, ctr, scl, lower, upper) {
    data.frame(
      center_group = centre_i[g], scale_group = scale_i[g], weight = w,
      center = ctr, scale = scl, lower = lower, upper = upper
    )
  }

  # Nothing anywhere is usable: there is no pooled value to shrink towards, and
  # a rule that cannot be evaluated removes nothing.
  if (!any(usable)) {
    return(list(
      prob = rep(1, n),
      reason = rep(NA_character_, n),
      fit = lapply(seq_along(idx_by_group), function(g) {
        fit_row(g, NA_real_, NA_real_, NA_real_, NA_real_, NA_real_)
      })
    ))
  }

  centre_pooled <- mean(centre_i[usable])
  log_scale_pooled <- mean(log(scale_i[usable]))

  prob <- rep(1, n)
  reason <- rep(NA_character_, n)
  fits <- vector("list", length(idx_by_group))

  for (g in seq_along(idx_by_group)) {
    # a group whose own spread is unusable pools completely; pooling is exactly
    # what rescues it
    w <- if (!usable[g] || is.infinite(rule$n0)) {
      0
    } else {
      n_i[g] / (n_i[g] + rule$n0)
    }
    ctr <- w * centre_i[g] + (1 - w) * centre_pooled
    scl <- if (w == 0) {
      exp(log_scale_pooled)
    } else {
      exp(w * log(scale_i[g]) + (1 - w) * log_scale_pooled)
    }
    lower <- ctr - rule$n_sd * scl
    upper <- ctr + rule$n_sd * scl

    i <- idx_by_group[[g]]
    prob[i] <- .prob_from_bounds(rt[i], lower, upper)
    reason[i] <- .reason_from_bounds(rt[i], lower, upper)
    fits[[g]] <- fit_row(g, w, ctr, scl, lower, upper)
  }

  list(prob = prob, reason = reason, fit = fits)
}
