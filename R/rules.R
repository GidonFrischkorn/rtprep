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
#' @param maxit Maximum number of EM iterations. The default of 500 is the
#'   setting the companion simulation used throughout; at 100, which
#'   `bmm::flag_contaminant_rts()` uses, the lognormal core left a quarter of
#'   fits unconverged on heavy-tailed data, and an unconverged fit keeps every
#'   trial. Pass `maxit` explicitly when comparing the two packages.
#' @param tol Convergence tolerance on the log-likelihood.
#'
#' @return An object of class `c("rtprep_rule_<name>", "rtprep_rule")`: a list
#'   of validated parameters plus a `label` element used for the `.rule` column
#'   of [rt_screen()].
#'
#' @seealso [rt_screen()] to apply a rule; `screen_compare()` to apply several.
#'   Two further rules that the companion simulation evaluated and did not
#'   recommend are kept unexported and documented in `?rules_experimental`.
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
#' ships their published criteria (their Table 4, tabulated at 4 to 15, 20,
#' 25, 30, 35, 50, and 100 trials), linearly interpolated between the tabulated
#' sample sizes as the table's note instructs and as `trimr` does. Below 4 no
#' criterion exists and nothing is flagged; above 100 the value for 100 is
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

#' Experimental screening rules (not exported)
#'
#' @description
#' Two rules that entered the companion simulation as experimental families
#' and came out tracking no preprocessing on every estimand that matters. They
#' are not exported: a function on the package index reads as a
#' recommendation, and neither is recommended. The code, its tests, and this
#' page stay so that the simulation scripts reproduce from the released source
#' and so that the negative result can be inspected. Reach them with
#' `rtprep:::rule_adaptive_trim()` and `rtprep:::rule_ez_support()`; both
#' return a rule object that [rt_screen()] applies like any other.
#'
#' @param q_cut Lower quantile of the tentative cut, in (0, 0.5). The
#'   validation reference quantile is `2 * q_cut`.
#' @param s_accept Minimum proportional shift of the surviving minimum toward
#'   the reference quantile for the tentative cut to be accepted.
#' @param c_ndt Multiplier on the fitted non-decision time that sets the
#'   support bound, in (0, 1]: no valid response time can undercut
#'   non-decision time, so nothing above 1 has a grounding.
#' @param refit Whether to refit the EZ model once on the survivors and
#'   re-flag against the updated non-decision time. Exactly one refit; the
#'   rule never iterates to convergence.
#'
#' @return An object of class `c("rtprep_rule_<name>", "rtprep_rule")`, as
#'   for the exported constructors in [rules].
#'
#' @details
#' # Adaptive leading-edge trim
#'
#' `rule_adaptive_trim()` cuts at a lower quantile and keeps the cut only if
#' it looks like removed contaminants rather than removed edge. In the
#' simulation it accepted its own cut on nine clean cells in ten at the
#' pre-declared operating point, because a clean leading edge already carries
#' most of the shift the statistic looks for, and its detection of
#' leading-edge anticipations did not exceed the EWMA chart's. It turns an
#' unconditional lower trim into a validated one: cut at
#' the empirical `q_cut` quantile, then measure how far the surviving minimum
#' shifted toward the reference quantile at `2 * q_cut`,
#'
#' \deqn{S = \frac{\min(kept) - \min(all)}{q_{2 q_{cut}}(all) - \min(all)},}
#'
#' and keep the cut only when `S >= s_accept`. Displaced fast contaminants sit
#' in a low block with a gap to the core, so removing them jumps the minimum
#' most of the way to the reference (`S` near 1); a genuinely steep leading
#' edge bunches its fastest trials, so cutting them barely moves the minimum
#' (`S` near 0). When the cut is rejected the rule removes nothing, and the
#' computed `S` and the decision are reported in `attr(x, "fits")` either way.
#'
#' What the statistic actually detects is a *gap* below the leading edge.
#' Across-trial variability in non-decision time smears a clean edge into
#' exactly such a shallow front, which is the rule's documented false-alarm
#' mode. Groups with fewer than 20 trials, and groups whose reference quantile
#' ties the minimum, are left untouched.
#'
#' @examples
#' rtprep:::rule_adaptive_trim()
#'
#' @keywords internal
#' @aliases rules_experimental
#' @rdname rules_experimental
rule_adaptive_trim <- function(q_cut = 0.05, s_accept = 0.5) {
  .check_scalar(q_cut, "q_cut",
    lower = 0, upper = 0.5,
    incl_lower = FALSE, incl_upper = FALSE
  )
  .check_scalar(s_accept, "s_accept", lower = 0, incl_lower = FALSE)

  .new_rule(
    "adaptive_trim",
    label = paste0(
      "adaptive_trim(", .fmt(q_cut), ", ", .fmt(s_accept), ")"
    ),
    q_cut = q_cut, s_accept = s_accept
  )
}

#' @rdname rules_experimental
#'
#' @details
#' # EZ support screen
#'
#' `rule_ez_support()` flags trials the fitted model says are impossible. In
#' the simulation it failed where its own premise predicted: late delayed
#' start-ups drag the fitted non-decision time below zero and the rule reverts
#' to keeping everything, while across-trial variability in non-decision time
#' pushes genuine trials under the bound and the rule removes them. Every
#' evidence accumulation model writes a response time as
#' non-decision time plus a strictly positive decision time, so no valid trial
#' can undercut non-decision time. The rule fits the closed-form EZ model to a
#' group's trials, flags everything below `c_ndt` times the fitted
#' non-decision time, refits once on the survivors (`refit = TRUE`), re-flags
#' against the updated estimate, and stops — never iterating further, because
#' lower-tail removal shrinks the variance and pushes the estimate upward, a
#' one-way ratchet that unlimited iteration would run away with.
#'
#' The catch is the point: fast contaminants drag the fitted non-decision time
#' down, so the rule's premise is poisoned by exactly the trials it hunts.
#' Whether one refit recovers the threshold is an empirical question, not a
#' guarantee. Groups with fewer than ten trials, unusable fits (including a
#' negative fitted non-decision time, which contaminated moments can produce),
#' and fits that would flag more than half the group all remove nothing, with
#' `usable = FALSE` in `attr(x, "fits")`. That last guard is defensive: at
#' `c_ndt <= 1` a first-pass EZ threshold cannot exceed the sample median,
#' because the mean never sits more than one standard deviation above the
#' median while the implied decision-time mean always exceeds it.
#'
#' This rule requires `response`, coded as correct/error.
#'
#' @examples
#' rtprep:::rule_ez_support()
#'
#' @keywords internal
rule_ez_support <- function(c_ndt = 1, refit = TRUE) {
  .check_scalar(c_ndt, "c_ndt", lower = 0, upper = 1, incl_lower = FALSE)
  .check_flag(refit, "refit")

  .new_rule(
    "ez_support",
    label = paste0(
      "ez_support(", .fmt(c_ndt), if (refit) ", refit", ")"
    ),
    c_ndt = c_ndt, refit = refit
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
#' # Accuracy inside the likelihood
#'
#' `use_accuracy = TRUE` is **experimental**. It puts accuracy inside the
#' mixture likelihood rather than using it only afterwards, on the reasoning
#' that a fast trial that is *correct* is less likely to be a guess than a fast
#' trial that is an error — something an RT-only mixture cannot see. With `y`
#' the accuracy indicator, \eqn{\gamma} the chance rate known from the design,
#' and \eqn{p_c} the estimated accuracy of the decision process:
#'
#' \deqn{f(rt, y) = (1 - \pi) f_{RT}(rt \mid \theta)\, p_c^{y}(1-p_c)^{1-y}
#'   + \pi\, U(rt \mid a, b)\, \gamma^{y}(1-\gamma)^{1-y}.}
#'
#' \eqn{\gamma} is fixed, not estimated. The M-step for \eqn{p_c} is the
#' responsibility-weighted mean of `y`, so the extension costs the EM almost
#' nothing; the fitted value comes back as `p_correct` in `attr(x, "fits")`.
#'
#' ## What is known so far, and it is not all good
#'
#' The staging is deliberate, and the reasons are concrete. Three things are
#' already established by the package's own tests, before the simulation has
#' been run:
#'
#' * **It can order overlapping guesses better than response time alone.** Where
#'   contaminants fall inside the valid distribution's range — the case RT-only
#'   detection fails at — the joint posterior ranks them more accurately.
#' * **But the fit tends to collapse.** A contaminant proportion of zero is a
#'   fixed point of this EM, and the accuracy factor widens its basin because it
#'   favours the valid component on every correct trial. On exactly the
#'   overlapping case above, the fit converges cleanly with
#'   \eqn{\pi \approx 10^{-7}} and the rule removes nothing at all: the better
#'   ordering is one the keep policy never gets to act on. Check `collapsed` and
#'   `contaminant_prop` in `attr(x, "fits")` against what you expected.
#' * **It actively hurts when contaminants are as accurate as valid trials.**
#'   A delayed start-up still runs the decision process, so it is usually
#'   correct, and every correct contaminant has its contaminant evidence
#'   attenuated by \eqn{\gamma / p_c}. This is not neutrality: in the package's
#'   own test the joint model loses a large part of the sensitivity the RT-only
#'   model had.
#'
#' The same deflation applies whenever observed accuracy is well above chance,
#' which in most response time paradigms is always. Treat a contaminant
#' proportion below the RT-only estimate as expected rather than as evidence of
#' a cleaner data set.
#'
#' Two things the method cannot enforce for you:
#'
#' * It assumes contaminants respond at `chance`. Get `chance` wrong — screening
#'   a four-alternative task at 0.5 — and detection degrades sharply.
#' * `response` must be coded **correct/error**, not upper/lower boundary. Both
#'   are 0/1, so `rtprep` cannot tell them apart.
#'
#' Nothing forces the valid component to be the accurate one either. When a fit
#' comes back with \eqn{p_c} below `chance` the labels have swapped, which
#' usually means the two components are not separable at that contamination
#' rate. `rtprep` reports rather than constrains: `accuracy_inverted` in
#' `attr(x, "fits")`, plus one warning per call.
#'
#' @references
#' Liu, Y., Cheng, Y., & Liu, H. (2020). Identifying effortful individuals with
#' mixture modeling response accuracy and response time simultaneously to
#' improve item parameter estimation. *Educational and Psychological
#' Measurement*, *80*(4), 775–807. \doi{10.1177/0013164419895068}
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
  maxit = 500, tol = 1e-6
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

.describe_rule.rtprep_rule_adaptive_trim <- function(x) {
  paste0(
    "Cut the fastest ", .fmt(100 * x$q_cut), "% only when the surviving ",
    "minimum shifts at least ", .fmt(x$s_accept), " of the way to the ",
    "q", .fmt(200 * x$q_cut), " quantile (experimental)."
  )
}

.describe_rule.rtprep_rule_ez_support <- function(x) {
  paste0(
    "Exclude trials below ", .fmt(x$c_ndt), " x the closed-form EZ ",
    "non-decision time",
    if (x$refit) ", refitted once on the survivors", " (experimental)."
  )
}

.describe_rule.rtprep_rule_none <- function(x) "Keep every trial."
