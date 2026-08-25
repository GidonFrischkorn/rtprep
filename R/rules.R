#' Screening rules
#'
#' @description
#' Rule constructors are parameter objects: they validate their arguments and
#' describe themselves, but perform no computation on data. Pass one to
#' [rt_screen()], which applies it and returns the same four per-trial columns
#' whichever rule was used.
#'
#' Rules from incompatible families therefore become directly comparable:
#'
#' * `rule_cutoff()` — fixed absolute bounds.
#' * `rule_sd()` — a location/spread criterion, covering both the SD criterion
#'   and the median absolute deviation criterion.
#' * `rule_mad()` — a thin alias of `rule_sd(center = "median", scale = "mad")`.
#' * `rule_recursive()` — the sample-size-dependent criteria of van Selst and
#'   Jolicoeur (1994).
#' * `rule_ewma()` — the accuracy control chart of Vandekerckhove and
#'   Tuerlinckx (2007).
#' * `rule_mixture()` — a uniform-contaminant mixture fitted by EM.
#' * `rule_none()` — a pass-through baseline.
#'
#' @param min,max Absolute bounds in seconds. Bounds are **inclusive**: a trial
#'   is flagged only when it falls strictly outside. `max = Inf` leaves the
#'   upper tail untouched.
#' @param n_sd,n_mad Multiplier applied to the spread statistic.
#' @param center Location statistic, `"mean"` or `"median"`.
#' @param scale Spread statistic, `"sd"` or `"mad"`. `"mad"` uses [stats::mad()]
#'   and so carries the usual consistency constant of 1.4826.
#' @param type Which recursive criterion to use; see Details.
#' @param include_max Whether the largest response time enters the mean and
#'   standard deviation from which the criterion is built. Applies to
#'   `type = "moving"` only.
#' @param lambda Smoothing weight of the exponentially weighted moving average,
#'   in `(0, 1]`. Smaller values average over more trials.
#' @param L Control-limit multiplier; the chart signals when the average
#'   departs from chance by more than `L` standard errors.
#' @param chance Accuracy expected from a contaminant response, known from the
#'   design (0.5 for a two-alternative task).
#' @param distribution Parametric distribution for the valid response time
#'   component of the mixture.
#' @param bound Length-2 bounds of the uniform contaminant component. Each
#'   element may be a number, or `"min"`/`"max"` for a data-driven bound.
#' @param use_accuracy Whether accuracy enters the mixture likelihood.
#'   **Experimental**; see Details.
#' @param init Starting value for the contaminant proportion.
#' @param max_prop Upper bound on the estimated contaminant proportion.
#' @param maxit Maximum number of EM iterations.
#' @param tol Convergence tolerance on the log-likelihood.
#'
#' @return An object of class `c("rtprep_rule_<name>", "rtprep_rule")`: a list
#'   of validated parameters plus a `label` element used for the `.rule` column
#'   of [rt_screen()].
#'
#' @seealso [rt_screen()] to apply a rule; `screen_compare()` to apply several.
#'
#' @name rules
NULL

.new_rule <- function(subclass, label, ...) {
  structure(
    c(list(...), list(label = label)),
    class = c(paste0("rtprep_rule_", subclass), "rtprep_rule")
  )
}

#' @rdname rules
#'
#' @details
#' # Absolute cutoffs
#'
#' The oldest and still the most common screen: discard anything faster than a
#' plausible minimum or slower than a plausible maximum. Ratcliff (1993) is the
#' standard treatment; Ulrich and Miller (1994) is the counterweight, showing
#' that truncation biases the surviving distribution even when it removes real
#' contaminants.
#'
#' Bounds are inclusive, so `rule_cutoff(min = 0.18)` keeps a response time of
#' exactly 180 ms — 180 ms is not *below* 180 ms. Note that `trimr` uses strict
#' comparisons, so the two implementations can disagree on a trial sitting
#' exactly on a bound.
#'
#' @references
#' Ratcliff, R. (1993). Methods for dealing with reaction time outliers.
#' *Psychological Bulletin*, *114*(3), 510–532.
#' \doi{10.1037/0033-2909.114.3.510}
#'
#' Ulrich, R., & Miller, J. (1994). Effects of truncation on reaction time
#' analysis. *Journal of Experimental Psychology: General*, *123*(1), 34–80.
#' \doi{10.1037/0096-3445.123.1.34}
#'
#' @examples
#' rule_cutoff(0.18, 3)
#'
#' @export
rule_cutoff <- function(min = 0, max = Inf) {
  .check_scalar(min, "min", lower = 0)
  .check_scalar(max, "max", lower = 0, incl_lower = FALSE, allow_inf = TRUE)
  .stopif(min >= max, "'min' must be less than 'max'.")

  .new_rule(
    "cutoff",
    label = paste0("cutoff(", .fmt(min), ", ", .fmt(max), ")"),
    min = min, max = max
  )
}

#' @rdname rules
#'
#' @details
#' # Location and spread criteria
#'
#' `rule_sd()` flags trials further than `n_sd` spread units from a centre,
#' recomputed within each group of [rt_screen()]. `center = "mean", scale =
#' "sd"` is the standard deviation criterion, modal practice in the field;
#' `center = "median", scale = "mad"` is the median absolute deviation
#' criterion recommended by Leys et al. (2013), also available as
#' `rule_mad()`.
#'
#' One constructor covers both because they are one family — the same algorithm
#' with a different location/spread pair. Miller (1991) is the standard warning
#' about the standard deviation criterion: the proportion of a skewed
#' distribution that survives a fixed multiplier depends on sample size, so the
#' criterion silently changes what it removes as trial counts vary. That
#' dependence is what `rule_recursive()` was designed to remove.
#'
#' When the spread statistic cannot be used — fewer than two observed trials in
#' a group, or zero spread — nothing is flagged. A rule that cannot be evaluated
#' must not remove data.
#'
#' @references
#' Leys, C., Ley, C., Klein, O., Bernard, P., & Licata, L. (2013). Detecting
#' outliers: Do not use standard deviation around the mean, use absolute
#' deviation around the median. *Journal of Experimental Social Psychology*,
#' *49*(4), 764–766. \doi{10.1016/j.jesp.2013.03.013}
#'
#' Miller, J. (1991). Reaction time analysis with outlier exclusion: Bias varies
#' with sample size. *The Quarterly Journal of Experimental Psychology Section
#' A*, *43*(4), 907–912. \doi{10.1080/14640749108400962}
#'
#' @examples
#' rule_sd(2.5)
#' rule_mad(3)
#'
#' @export
rule_sd <- function(n_sd = 2.5, center = c("mean", "median"),
                    scale = c("sd", "mad")) {
  .check_scalar(n_sd, "n_sd", lower = 0, incl_lower = FALSE)
  center <- match.arg(center)
  scale <- match.arg(scale)

  .new_rule(
    "sd",
    label = paste0("sd(", .fmt(n_sd), ", ", center, ", ", scale, ")"),
    n_sd = n_sd, center = center, scale = scale
  )
}

#' @rdname rules
#' @export
rule_mad <- function(n_mad = 2.5) {
  rule_sd(n_mad, center = "median", scale = "mad")
}

#' @rdname rules
#'
#' @details
#' # Recursive and moving criteria
#'
#' Van Selst and Jolicoeur (1994) answered Miller's (1991) sample-size problem
#' by making the multiplier itself depend on the number of trials. `rtprep`
#' ships their published criterion table for sample sizes 4 to 100; below 4 no
#' criterion exists and nothing is flagged, and above 100 the value for 100 is
#' used.
#'
#' * `type = "moving"` is their non-recursive moving criterion: one pass, with
#'   the multiplier read off the table for the group's trial count.
#' * `type = "modified"` is the modified recursive procedure: the largest
#'   remaining response time is *temporarily set aside* while the mean and
#'   standard deviation are computed, the most extreme trial at each end is
#'   removed if it falls outside the resulting bounds, and the procedure repeats
#'   until nothing is removed or fewer than five trials remain. The temporary
#'   exclusion is what makes the rule bite, so it applies whatever `include_max`
#'   says — `include_max` governs `type = "moving"` only.
#' * `type = "hybrid"` averages the two. Per trial, `.prob` is the mean of the
#'   two rules' decisions and so takes the value 0, 0.5, or 1; under the default
#'   keep policy a trial survives only if both rules keep it.
#'
#' Note that van Selst and Jolicoeur's published hybrid statistic is the mean of
#' the two *condition means*, which no single per-trial keep vector can
#' reproduce, because the two means have different denominators. To recover the
#' published statistic, summarise the two rules separately and average:
#'
#' ```r
#' keep_moving <- rt_screen(rt, rule = rule_recursive("moving"))$.keep
#' moving <- rt_summary(rt[keep_moving])
#' keep_modif <- rt_screen(rt, rule = rule_recursive("modified"))$.keep
#' modif <- rt_summary(rt[keep_modif])
#' (moving$mean_rt + modif$mean_rt) / 2
#' ```
#'
#' @references
#' Van Selst, M., & Jolicoeur, P. (1994). A solution to the effect of sample
#' size on outlier elimination. *The Quarterly Journal of Experimental
#' Psychology Section A*, *47*(3), 631–650. \doi{10.1080/14640749408401131}
#'
#' Cousineau, D., & Chartier, S. (2010). Outliers detection and treatment: A
#' review. *International Journal of Psychological Research*, *3*(1), 58–67.
#' \doi{10.21500/20112084.844}
#'
#' @examples
#' rule_recursive("modified")
#'
#' @export
rule_recursive <- function(type = c("moving", "modified", "hybrid"),
                           include_max = TRUE) {
  type <- match.arg(type)
  .check_flag(include_max, "include_max")

  .new_rule(
    "recursive",
    label = paste0("recursive(", type, ")"),
    type = type, include_max = include_max
  )
}

#' @rdname rules
#'
#' @details
#' # Accuracy control chart
#'
#' `rule_ewma()` is the exponentially weighted moving average cutoff introduced
#' with DMAT (Vandekerckhove & Tuerlinckx, 2007), and the only *published*
#' screen that uses accuracy rather than response time alone. Trials are ordered
#' from fastest to slowest and an exponentially weighted average of accuracy is
#' accumulated, starting from `chance`. The control limit at trial \eqn{i} is
#'
#' \deqn{\mathrm{UCL}_i = \gamma + L\,\sigma
#'   \sqrt{\frac{\lambda}{2-\lambda}\left(1-(1-\lambda)^{2i}\right)},}
#'
#' with \eqn{\gamma} the chance rate and \eqn{\sigma = \sqrt{\gamma(1-\gamma)}}
#' the standard deviation of a guess. The cutoff is the response time at which
#' the average first rises above the limit: below it, accuracy is
#' indistinguishable from guessing, so those trials are flagged. If the average
#' never crosses, nothing is flagged.
#'
#' The chart lags, and the lag is a cost rather than an implementation detail:
#' the average needs several trials above chance before it clears the limit, so
#' the cutoff lands past the point where accuracy actually rose and valid trials
#' just above it are flagged along with the guesses. Smaller `lambda` averages
#' over more trials and overshoots further. Ratcliff and Kang (2021) note that
#' this rule has not found much use; `rtprep` ships it as the published
#' accuracy-based comparator, not as a recommendation.
#'
#' This rule requires `response`, coded as correct/error rather than as an
#' upper/lower boundary.
#'
#' @references
#' Vandekerckhove, J., & Tuerlinckx, F. (2007). Fitting the Ratcliff diffusion
#' model to experimental data. *Psychonomic Bulletin & Review*, *14*(6),
#' 1011–1026. \doi{10.3758/bf03193087}
#'
#' Ratcliff, R., & Kang, I. (2021). Qualitative speed-accuracy tradeoff effects
#' can be explained by a diffusion/fast-guess mixture model. *Scientific
#' Reports*, *11*, 15169. \doi{10.1038/s41598-021-94451-7}
#'
#' @examples
#' rule_ewma(lambda = 0.05)
#'
#' @export
# `lambda` and `L` keep the notation of the control-chart literature that the
# rule comes from, so the code reads against the paper.
rule_ewma <- function(lambda = 0.01, L = 1.5, chance = 0.5) {
  .check_scalar(lambda, "lambda", lower = 0, upper = 1, incl_lower = FALSE)
  .check_scalar(L, "L", lower = 0, incl_lower = FALSE)
  .check_scalar(chance, "chance",
    lower = 0, upper = 1,
    incl_lower = FALSE, incl_upper = FALSE
  )

  .new_rule(
    "ewma",
    label = paste0("ewma(", .fmt(lambda), ", ", .fmt(L), ")"),
    lambda = lambda, L = L, chance = chance
  )
}

#' @rdname rules
#'
#' @details
#' # Mixture flagging
#'
#' `rule_mixture()` fits, per group, a two-component mixture of a uniform
#' contaminant distribution over `bound` and a parametric response time
#' distribution, by expectation maximisation (Ratcliff & Tuerlinckx, 2002).
#' `.prob` is then the posterior probability that a trial came from the response
#' time component — the one rule in the package that returns something other
#' than 0 and 1, and the reason [rt_screen()] separates the probability from the
#' keep decision at all.
#'
#' The bounds of the uniform component are buffered outward from the observed
#' range by half its width. Without that buffer the uniform's edges sit exactly
#' on data points and the mixture is barely identifiable.
#'
#' Which core distribution you choose matters more than it looks. On a tight
#' block of fast guesses the ex-Gaussian can absorb the block by widening its
#' Gaussian part and driving `tau` to zero, reporting no contamination at all,
#' where the lognormal and inverse Gaussian cores find it. The same thing
#' happens in `bmm`'s implementation, so it is a property of the model rather
#' than of either package — but it is a reason to check
#' `attr(x, "fits")$contaminant_prop` against what you expected rather than
#' trusting the default.
#'
#' When the EM does not converge, or a group has fewer than five trials inside
#' the bounds, **nothing is flagged** and `attr(x, "fits")$converged` is
#' `FALSE`. `rt_screen()` warns once for the whole call, naming how many groups
#' failed, rather than once per group. Note that `bmm` returns `NA`
#' probabilities in this situation; `rtprep` keeps the data, because an `NA`
#' would propagate into `.keep`.
#'
#' `use_accuracy = TRUE` is **experimental** and not yet implemented. It puts
#' accuracy inside the mixture likelihood rather than using it only afterwards,
#' on the reasoning that a fast trial that is *correct* is less likely to be a
#' guess than a fast trial that is an error. It assumes contaminants respond at
#' `chance`, which holds for guessing but not for a delayed start-up, where the
#' decision process still runs and accuracy is intact.
#'
#' @references
#' Ratcliff, R., & Tuerlinckx, F. (2002). Estimating parameters of the diffusion
#' model: Approaches to dealing with contaminant reaction times and parameter
#' variability. *Psychonomic Bulletin & Review*, *9*(3), 438–481.
#' \doi{10.3758/bf03196302}
#'
#' @examples
#' rule_mixture("lognormal")
#'
#' @export
rule_mixture <- function(
  distribution = c("exgaussian", "lognormal", "invgaussian"),
  bound = c("min", "max"), use_accuracy = FALSE,
  chance = 0.5, init = 0.05, max_prop = 0.5,
  maxit = 100, tol = 1e-6
) {
  distribution <- match.arg(distribution)
  bound <- .check_bound(bound)
  .check_flag(use_accuracy, "use_accuracy")
  .check_scalar(chance, "chance",
    lower = 0, upper = 1,
    incl_lower = FALSE, incl_upper = FALSE
  )
  .check_scalar(init, "init",
    lower = 0, upper = 1,
    incl_lower = FALSE, incl_upper = FALSE
  )
  .check_scalar(max_prop, "max_prop", lower = 0, upper = 1, incl_lower = FALSE)
  .stopif(init >= max_prop, "'init' must be less than 'max_prop'.")
  .check_count(maxit, "maxit")
  .check_scalar(tol, "tol", lower = 0, incl_lower = FALSE)

  label <- paste0(
    "mixture(", distribution, if (use_accuracy) ", accuracy", ")"
  )
  .new_rule(
    "mixture",
    label = label,
    distribution = distribution, bound = bound, use_accuracy = use_accuracy,
    chance = chance, init = init, max_prop = max_prop, maxit = maxit, tol = tol
  )
}

# Contaminant bounds are either numbers or the strings "min"/"max", which
# rt_screen() resolves against each group's observed range.
.check_bound <- function(bound) {
  if (is.list(bound)) bound <- unlist(bound)
  .stopif(length(bound) != 2L, "'bound' must have length 2.")

  # c(0.1, "max") is a documented form, and c() has already turned the number
  # into the string "0.1", so a numeric-looking string has to count as numeric
  is_keyword <- vapply(bound, function(b) {
    !is.numeric(b) && tolower(as.character(b)) %in% c("min", "max")
  }, logical(1))
  value <- vapply(bound, function(b) {
    if (is.numeric(b)) {
      return(as.numeric(b))
    }
    suppressWarnings(as.numeric(as.character(b)))
  }, numeric(1))

  ok <- is_keyword | (is.finite(value) & value > 0)
  .stopif(
    !all(ok),
    "'bound' entries must be numeric or one of \"min\", \"max\"."
  )

  reversed <- all(is_keyword) &&
    identical(unname(tolower(as.character(bound))), c("max", "min"))
  .stopif(
    reversed || (all(!is_keyword) && value[1] >= value[2]),
    "'bound' lower bound must be below its upper bound."
  )
  bound
}

#' @rdname rules
#'
#' @details
#' # No screening
#'
#' `rule_none()` keeps every trial. It exists so that "no preprocessing" is an
#' entry in the roster rather than a missing row, and so that pipelines can be
#' compared against it without a special case.
#'
#' @examples
#' rule_none()
#'
#' @export
rule_none <- function() {
  .new_rule("none", label = "none")
}

#' @rdname rules
#' @param x A rule object.
#' @param ... Ignored.
#' @export
print.rtprep_rule <- function(x, ...) {
  cat("<rtprep rule>", x$label, "\n")
  cat(" ", .describe_rule(x), "\n", sep = "")
  invisible(x)
}

.describe_rule <- function(x) UseMethod(".describe_rule")

.describe_rule.default <- function(x) "No description available."

.describe_rule.rtprep_rule_cutoff <- function(x) {
  paste0(
    "Exclude trials outside [", .fmt(x$min), ", ", .fmt(x$max),
    "] seconds (bounds inclusive)."
  )
}

.describe_rule.rtprep_rule_sd <- function(x) {
  paste0(
    "Exclude trials more than ", .fmt(x$n_sd), " x ", x$scale,
    " from the ", x$center, ", computed per group."
  )
}

.describe_rule.rtprep_rule_recursive <- function(x) {
  body <- switch(x$type,
    moving = "moving criterion, one pass",
    modified = "modified recursive criterion, iterated",
    hybrid = "average of the moving and modified recursive criteria"
  )
  paste0("Van Selst & Jolicoeur (1994) ", body, ".")
}

.describe_rule.rtprep_rule_ewma <- function(x) {
  paste0(
    "Exclude trials faster than the response time at which accuracy first ",
    "departs from ", .fmt(x$chance), " (lambda = ", .fmt(x$lambda),
    ", L = ", .fmt(x$L), ")."
  )
}

.describe_rule.rtprep_rule_mixture <- function(x) {
  paste0(
    "Flag trials by their posterior probability under a uniform-contaminant / ",
    x$distribution, " mixture",
    if (x$use_accuracy) ", using accuracy (experimental)", "."
  )
}

.describe_rule.rtprep_rule_none <- function(x) "Keep every trial."
