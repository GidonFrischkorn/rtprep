#' Aggregate response times into EZ-diffusion summary statistics
#'
#' @description
#' Screening decides which trials survive; aggregation decides what the
#' survivors are summarised *as*. They fail differently, so `rtprep` keeps them
#' apart and makes both comparable: the same trials summarised three ways can
#' give three different parameter estimates, and that is a preprocessing choice
#' as consequential as the exclusion rule.
#'
#' @param rt Numeric vector of response times **in seconds**.
#' @param response Optional response coding of the same length as `rt`, in any
#'   form [rt_screen()] accepts. Required for `version = "4par"`; without it
#'   `n_upper` is `NA`. A trial whose response is missing belongs to neither
#'   boundary and is left out of both, but still counts towards `n_trials` — as
#'   in `bmm` — so `n_upper / n_trials` understates accuracy when responses are
#'   missing. Drop those trials first if that matters.
#' @param method How the moments are computed.
#'
#'   * `"simple"` — the sample mean and variance. The baseline, and what almost
#'     everyone does.
#'   * `"robust"` — the median, with the variance from the interquartile range
#'     (divided by 1.349) or the median absolute deviation. Statistic-level
#'     robustness, after Chávez De la Peña et al. (2026).
#'   * `"mixture"` — the analytic moments of the response time component of a
#'     fitted contaminant mixture, and its estimated contaminant proportion.
#' @param version `"3par"` pools the two response boundaries; `"4par"`
#'   summarises each separately.
#' @param distribution Core distribution for `method = "mixture"`; see
#'   [rule_mixture()].
#' @param robust_scale Spread statistic for `method = "robust"`.
#' @param weights Optional per-trial weights, typically the `.prob` column of
#'   [rt_screen()]. Defined for `method = "simple"` only.
#' @param min_trials Below this many trials the moments are `NA` rather than
#'   noise; `n_trials` is still reported. With `weights`, the comparison uses
#'   Kish's effective sample size `sum(w)^2 / sum(w^2)`, so two unit weights
#'   among ninety-eight zeros count as two trials rather than a hundred.
#' @param ... Passed to the mixture fit: `bound`, `init`, `max_prop`, `maxit`,
#'   `tol`, as documented in [rule_mixture()] and with the same defaults,
#'   including `maxit = 500` where `bmm::ezdm_summary_stats()` uses 100.
#'
#' @return A one-row `data.frame` — the inputs [ez_ddm()] needs.
#'
#'   `version = "3par"`: `mean_rt`, `var_rt`, `n_upper`, `n_trials`,
#'   `contaminant_prop`.
#'
#'   `version = "4par"`: `mean_rt_upper`, `mean_rt_lower`, `var_rt_upper`,
#'   `var_rt_lower`, `n_upper`, `n_trials`, `contaminant_prop_upper`,
#'   `contaminant_prop_lower`.
#'
#'   `contaminant_prop` is `NA` for every method but `"mixture"`, which is the
#'   only one that estimates it.
#'
#' @details
#' # Two ways of not letting contaminants count
#'
#' `method = "mixture"` reads its moments from the *parametric component*, not
#' from the data, so a trial the uniform component owns contributes nothing at
#' all. `weights` instead computes weighted sample moments, so such a trial
#' contributes a little. They are two models of the same doubt, which is why
#' both are here and why combining them is an error rather than a convenience.
#'
#' Weighted variances use the reliability-weight denominator
#' `sum(w) - sum(w^2) / sum(w)`, which reduces to `n - 1` when the weights are
#' equal. Frequency weights would use `sum(w) - 1` and are the wrong model:
#' `.prob` is a probability, not a count.
#'
#' # Differences from `bmm`
#'
#' `bmm::ezdm_summary_stats()` defaults to `method = "mixture"`; this function
#' defaults to `"simple"`. A package about preprocessing choices should not
#' make one of the choices silently.
#'
#' For `version = "4par"` with `method = "mixture"`, the contaminant bounds are
#' resolved once on the pooled response times before the split. Resolving them
#' per boundary would make the uniform component's density depend on which side
#' happened to have the wider range, so the two halves would be fitted against
#' different models.
#'
#' When the mixture fit fails the moments fall back to `"robust"` with a
#' warning, as in `bmm` — and unlike [rt_screen()], where the analogous failure
#' keeps every trial. The two differ because they answer different questions: a
#' screen that cannot be evaluated should not remove trials, but a summary still
#' has to return a number.
#'
#' @references
#' Wagenmakers, E.-J., van der Maas, H. L. J., Dolan, C. V., & Grasman, R. P. P.
#' P. (2008). EZ does it! Extensions of the EZ-diffusion model. *Psychonomic
#' Bulletin & Review*, *15*(6), 1229–1235. \doi{10.3758/pbr.15.6.1229}
#'
#' Chávez De La Peña, A. F., Shin, E., & Vandekerckhove, J. (2026). Robust
#' Bayesian hypothesis testing with the hierarchical EZ-DDM. *Behavior Research
#' Methods*, *58*(7), 177. \doi{10.3758/s13428-026-03066-1}
#'
#' @seealso [ez_ddm()] to invert these statistics into parameters,
#'   [adjust_accuracy()] to correct the counts for contamination,
#'   [rt_screen()] to decide which trials get here.
#'
#' @examples
#' rt <- c(0.32, 0.35, 0.38, 0.41, 0.44, 0.47, 0.50, 0.55, 0.62, 0.71, 1.90)
#' correct <- c(1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0)
#'
#' rt_summary(rt, correct, min_trials = 5)
#' rt_summary(rt, correct, method = "robust", min_trials = 5)
#'
#' # a probabilistic screen can feed aggregation without a threshold
#' scr <- rt_screen(rt, rule = rule_sd(2))
#' rt_summary(rt, correct, weights = scr$.prob, min_trials = 5)
#'
#' @export
rt_summary <- function(rt, response = NULL,
                       method = c("simple", "robust", "mixture"),
                       version = c("3par", "4par"),
                       distribution = c(
                         "exgaussian", "lognormal", "invgaussian"
                       ),
                       robust_scale = c("iqr", "mad"),
                       weights = NULL, min_trials = 10, ...) {
  method <- match.arg(method)
  version <- match.arg(version)
  distribution <- match.arg(distribution)
  robust_scale <- match.arg(robust_scale)

  .check_rt(rt)
  .check_scalar(min_trials, "min_trials", lower = 1)
  if (!is.null(response)) {
    .stopif(
      length(response) != length(rt),
      "'response' must have the same length as 'rt'."
    )
  }
  .stopif(
    version == "4par" && is.null(response),
    "version = \"4par\" requires 'response'."
  )
  if (!is.null(weights)) {
    .stopif(
      method != "simple",
      paste0(
        "'weights' is defined for method = \"simple\" only. Both \"robust\" ",
        "and \"mixture\" already have their own answer to contamination."
      )
    )
    .stopif(
      length(weights) != length(rt),
      "'weights' must have the same length as 'rt'."
    )
    .stopif(
      !is.numeric(weights) || any(weights < 0, na.rm = TRUE),
      "'weights' must be non-negative."
    )
    .stopif(
      any(is.infinite(weights)),
      "'weights' must be finite."
    )
  }
  mixture_args <- .check_mixture_args(list(...))

  complete <- !is.na(rt)
  rt <- rt[complete]
  if (!is.null(weights)) {
    weights <- weights[complete]
    weights[is.na(weights)] <- 0
    .stopif(
      sum(weights) <= 0,
      "'weights' must include at least one positive value."
    )
  }

  is_upper <- if (is.null(response)) NULL else .as_upper(response[complete])
  n_upper <- if (is.null(is_upper)) {
    NA_integer_
  } else {
    as.integer(sum(is_upper, na.rm = TRUE))
  }
  n_trials <- length(rt)

  # The contaminant bounds are resolved once, on the pooled response times,
  # before any split. Resolving them per boundary would make the uniform
  # component's density depend on which side had the wider range, so the two
  # halves would be fitted against different models. bmm does the same.
  bound <- if (method == "mixture" && n_trials > 0L) {
    .resolve_bounds(mixture_args$bound, rt)$bound
  } else {
    NULL
  }

  moments <- function(x, w) {
    .rt_moments(
      x, w, method, distribution, robust_scale, min_trials, bound, mixture_args
    )
  }

  if (version == "3par") {
    m <- moments(rt, weights)
    return(data.frame(
      mean_rt = m$mean, var_rt = m$var,
      n_upper = n_upper, n_trials = as.integer(n_trials),
      contaminant_prop = m$contaminant_prop
    ))
  }

  # a missing response belongs to neither boundary; indexing with a logical NA
  # would put an NA into both subsets and take down the whole summary
  keep_upper <- !is.na(is_upper) & is_upper
  keep_lower <- !is.na(is_upper) & !is_upper
  upper <- moments(rt[keep_upper], weights[keep_upper])
  lower <- moments(rt[keep_lower], weights[keep_lower])
  data.frame(
    mean_rt_upper = upper$mean, mean_rt_lower = lower$mean,
    var_rt_upper = upper$var, var_rt_lower = lower$var,
    n_upper = n_upper, n_trials = as.integer(n_trials),
    contaminant_prop_upper = upper$contaminant_prop,
    contaminant_prop_lower = lower$contaminant_prop
  )
}

# Mean, variance, and (mixture only) contaminant proportion for one set of
# trials. Below min_trials everything is NA: a summary computed from three
# trials is noise wearing a number's clothes.
.rt_moments <- function(x, w, method, distribution, robust_scale, min_trials,
                        bound, mixture_args) {
  empty <- list(mean = NA_real_, var = NA_real_, contaminant_prop = NA_real_)
  # Weights are counted by Kish's effective sample size, sum(w)^2 / sum(w^2),
  # not by how many rows arrived. Two trials at weight 1 among 98 at weight 0
  # is two trials' worth of information, and min_trials exists precisely to
  # stop that being reported as a number.
  effective_n <- if (is.null(w)) length(x) else .effective_n(w)
  if (length(x) < min_trials || effective_n < min_trials) {
    return(empty)
  }

  simple <- function() {
    if (is.null(w)) {
      list(mean = mean(x), var = stats::var(x), contaminant_prop = NA_real_)
    } else {
      .weighted_moments(x, w)
    }
  }
  robust <- function() {
    scale <- switch(robust_scale,
      iqr = (stats::IQR(x) / 1.349)^2,
      mad = stats::mad(x)^2
    )
    list(mean = stats::median(x), var = scale, contaminant_prop = NA_real_)
  }

  switch(method,
    simple = simple(),
    robust = robust(),
    mixture = {
      fit <- .mixture_moments(x, distribution, bound, mixture_args)
      if (is.null(fit)) {
        warning(
          "The mixture fit did not converge; using robust moments instead.",
          call. = FALSE
        )
        robust()
      } else {
        fit
      }
    }
  )
}

# Kish's effective sample size: how many equally weighted trials carry the same
# information as this weight vector.
.effective_n <- function(w) {
  total <- sum(w)
  if (total <= 0) 0 else total^2 / sum(w^2)
}

# Weighted sample moments. The variance denominator treats the weights as
# reliability weights -- .prob is a probability, not a count -- and reduces to
# n - 1 when they are equal.
.weighted_moments <- function(x, w) {
  total <- sum(w)
  mu <- sum(w * x) / total
  denom <- total - sum(w^2) / total
  variance <- if (denom > 0) sum(w * (x - mu)^2) / denom else NA_real_
  list(mean = mu, var = variance, contaminant_prop = NA_real_)
}

# Analytic moments of the fitted response time component. NULL when the fit
# fails, so the caller can fall back.
.mixture_moments <- function(x, distribution, bound, args) {
  fit <- .fit_rt_mixture(
    x, distribution, bound,
    args$init, args$max_prop, args$maxit, args$tol
  )
  if (!fit$converged) {
    return(NULL)
  }

  m <- .dist_moments(fit$par, distribution)
  list(
    mean = unname(m$mean), var = unname(m$var),
    contaminant_prop = fit$contaminant_prop
  )
}

# Arguments forwarded to the mixture fit. Validated here rather than swallowed:
# `...` reaches the fit only on the mixture branch, so without this a typo like
# `weigths =` would silently produce an unweighted summary and say nothing.
.check_mixture_args <- function(dots) {
  known <- c("bound", "init", "max_prop", "maxit", "tol")
  unknown <- setdiff(names(dots), known)
  unnamed <- length(dots) > 0L && is.null(names(dots))
  .stopif(length(unknown) > 0L || unnamed, paste0(
    "Unknown argument(s): ", paste(unknown, collapse = ", "),
    ". '...' takes only the mixture fit's controls: ",
    paste(known, collapse = ", "), "."
  ))

  args <- utils::modifyList(
    list(
      bound = c("min", "max"), init = 0.05, max_prop = 0.5,
      maxit = 500, tol = 1e-6
    ),
    dots
  )
  # the same checks rule_mixture() runs, so the two entry points agree
  args$bound <- .check_bound(args$bound)
  .check_scalar(args$init, "init",
    lower = 0, upper = 1,
    incl_lower = FALSE, incl_upper = FALSE
  )
  .check_scalar(args$max_prop, "max_prop",
    lower = 0, upper = 1,
    incl_lower = FALSE
  )
  .stopif(args$init >= args$max_prop, "'init' must be less than 'max_prop'.")
  .check_count(args$maxit, "maxit")
  .check_scalar(args$tol, "tol", lower = 0, incl_lower = FALSE)
  args
}

#' Correct accuracy counts for contamination
#'
#' @description
#' Removes the estimated contaminant trials from the accuracy counts, on the
#' assumption that contaminants respond correctly at `guess_rate`. A port of
#' `bmm::adjust_ezdm_accuracy()`.
#'
#' @param n_upper Count of upper-boundary (correct) responses. Vectorised: the
#'   three count and proportion arguments recycle to a common length, one row
#'   per element, so the function takes the columns of a summary table
#'   directly.
#' @param n_trials Total number of trials.
#' @param contaminant_prop Estimated contaminant proportion, typically the
#'   `contaminant_prop` column of [rt_summary()]. `NA` or `<= 0` returns that
#'   row's counts unchanged.
#' @param guess_rate Accuracy assumed for a contaminant response, known from the
#'   design. `0.5` for a two-alternative task. One value for every row.
#'
#' @return A `data.frame` with integer `n_upper_adj` and `n_trials_adj`, one
#'   row per input element. A row whose `n_upper` or `n_trials` is `NA` comes
#'   back `NA`.
#'
#' @details
#' **Stochastic by design.** How many trials were contaminants, and how many of
#' those happened to be correct, are both binomial draws, so repeated calls
#' differ. That is faithful to the uncertainty in a mixture estimate — a point
#' estimate would understate it — and it matches `bmm`. There is no `set.seed()`
#' anywhere in `rtprep`; reproducibility is the caller's.
#'
#' Each row draws independently. For a single row the two draws are made in
#' the same order as `bmm::adjust_ezdm_accuracy()`, so the two functions give
#' the same answer from the same random seed.
#'
#' @seealso [rt_summary()] for the counts and the proportion, [ez_ddm()] for
#'   what to do with them.
#'
#' @examples
#' set.seed(42)
#' adjust_accuracy(n_upper = 80, n_trials = 100, contaminant_prop = 0.1)
#'
#' # one row per cell of a summary table
#' cells <- data.frame(
#'   n_upper = c(80, 45), n_trials = c(100, 50), contaminant_prop = c(0.1, 0.2)
#' )
#' adjust_accuracy(cells$n_upper, cells$n_trials, cells$contaminant_prop)
#'
#' @export
adjust_accuracy <- function(n_upper, n_trials, contaminant_prop,
                            guess_rate = 0.5) {
  .check_wholes(n_upper, "n_upper")
  .check_wholes(n_trials, "n_trials")
  .check_scalar(guess_rate, "guess_rate", lower = 0, upper = 1)
  .stopif(
    !(is.numeric(contaminant_prop) || all(is.na(contaminant_prop))),
    "'contaminant_prop' must be numeric, or NA."
  )
  .stopif(
    any(contaminant_prop > 1, na.rm = TRUE),
    "'contaminant_prop' cannot exceed 1."
  )

  sizes <- lengths(list(n_upper, n_trials, contaminant_prop))
  if (any(sizes == 0L)) {
    return(data.frame(n_upper_adj = integer(0), n_trials_adj = integer(0)))
  }
  n <- max(sizes)
  .warnif(
    any(n %% sizes != 0L),
    "Longer argument is not a multiple of the shorter ones; recycling anyway."
  )
  n_upper <- rep_len(n_upper, n)
  n_trials <- rep_len(n_trials, n)
  contaminant_prop <- rep_len(as.numeric(contaminant_prop), n)
  .stopif(
    any(n_upper > n_trials, na.rm = TRUE),
    "'n_upper' cannot exceed 'n_trials'."
  )

  n_upper_adj <- as.integer(n_upper)
  n_trials_adj <- as.integer(n_trials)
  # a row with a missing count has no answer, whichever count is missing
  no_count <- is.na(n_upper) | is.na(n_trials)
  n_upper_adj[no_count] <- NA_integer_
  n_trials_adj[no_count] <- NA_integer_

  # Only rows with something to adjust touch the random stream. For one such
  # row this is rbinom(1, n_trials, prop) then rbinom(1, n_contam, guess_rate),
  # which is bmm's sequence, so the equivalence holds draw for draw.
  active <- !is.na(contaminant_prop) & contaminant_prop > 0 & !no_count
  if (any(active)) {
    k <- sum(active)
    n_contam <- stats::rbinom(
      k,
      size = n_trials[active], prob = contaminant_prop[active]
    )
    # of those, the ones that came out correct by chance
    n_contam_upper <- stats::rbinom(k, size = n_contam, prob = guess_rate)

    remaining <- n_trials[active] - n_contam
    n_trials_adj[active] <- as.integer(remaining)
    n_upper_adj[active] <- as.integer(
      pmax(0, pmin(n_upper[active] - n_contam_upper, remaining))
    )
  }

  data.frame(n_upper_adj = n_upper_adj, n_trials_adj = n_trials_adj)
}

#' Invert summary statistics into diffusion parameters
#'
#' @description
#' The closed-form EZ-diffusion equations of Wagenmakers, van der Maas and
#' Grasman (2007): mean response time, response time variance, and accuracy in;
#' drift rate, boundary separation, and non-decision time out.
#'
#' Exported so that the whole pipeline-to-parameters check runs with only
#' `rtprep` installed — a reader can screen, aggregate, and estimate without
#' reaching for a model-fitting package.
#'
#' @param mean_rt,var_rt Mean and variance of the response times, in seconds.
#'   Wagenmakers et al. define these on *correct* responses; `version = "3par"`
#'   of [rt_summary()] pools both boundaries, which is equivalent under an
#'   unbiased diffusion and not otherwise. Use `version = "4par"` if the
#'   starting point may be off centre.
#' @param accuracy Proportion of upper-boundary (correct) responses, in
#'   `[0, 1]`.
#' @param n_trials Number of trials the statistics came from. Required: it sets
#'   the size of the edge correction.
#' @param s Scaling constant. `1` here; Wagenmakers et al. use `0.1`. This is a
#'   units convention, not a modelling one — `drift` and `bound` scale linearly
#'   with `s` and `ndt` does not, so a drift of 0.1 at `s = 0.1` and a drift of
#'   1.0 at `s = 1` describe the same process.
#'
#' @return A `data.frame` with `drift`, `bound`, `ndt`, and a logical
#'   `edge_corrected`, one row per input element (inputs recycle to a common
#'   length). `edge_corrected` flags the rows that needed the correction below.
#'
#' @details
#' The equations divide by `logit(accuracy)` and break down at accuracies of 0,
#' 0.5, and 1. Wagenmakers et al.'s edge correction moves the offending value by
#' `1 / (2 * n_trials)`: 1 becomes `1 - 1/(2n)`, 0 becomes `1/(2n)`, and 0.5
#' becomes `0.5 + 1/(2n)`. It is applied silently, because it is the published
#' behaviour and a warning per cell would bury a simulation run — but which
#' cells were corrected comes back in the `edge_corrected` column, so a script
#' can count them. It is a column rather than an attribute so that it survives
#' `[`, `rbind()`, and the dplyr verbs.
#'
#' EZ is fragile under contamination: a handful of fast guesses moves the drift
#' estimate a long way (Ratcliff, 2008). That fragility is the point of the
#' comparison this package exists to support, not a reason to avoid the
#' estimator.
#'
#' @references
#' Wagenmakers, E.-J., van der Maas, H. L. J., & Grasman, R. P. P. P. (2007). An
#' EZ-diffusion model for response time and accuracy. *Psychonomic Bulletin &
#' Review*, *14*(1), 3–22. \doi{10.3758/bf03194023}
#'
#' Ratcliff, R. (2008). The EZ diffusion method: Too EZ? *Psychonomic Bulletin &
#' Review*, *15*(6), 1218–1228. \doi{10.3758/pbr.15.6.1218}
#'
#' @seealso [rt_summary()], which produces exactly the inputs this takes.
#'
#' @examples
#' # the worked example from Wagenmakers et al. (2007)
#' ez_ddm(
#'   mean_rt = 0.723, var_rt = 0.112, accuracy = 0.802,
#'   n_trials = 100, s = 0.1
#' )
#'
#' @export
ez_ddm <- function(mean_rt, var_rt, accuracy, n_trials, s = 1) {
  .check_scalar(s, "s", lower = 0, incl_lower = FALSE)
  for (arg in list(
    list(mean_rt, "mean_rt"), list(var_rt, "var_rt"),
    list(accuracy, "accuracy"), list(n_trials, "n_trials")
  )) {
    .stopif(
      !is.numeric(arg[[1]]),
      paste0("'", arg[[2]], "' must be numeric, not ", class(arg[[1]])[1], ".")
    )
  }
  .stopif(
    any(accuracy < 0 | accuracy > 1, na.rm = TRUE),
    "'accuracy' must be between 0 and 1."
  )
  .stopif(
    any(n_trials < 1, na.rm = TRUE),
    "'n_trials' must be at least 1."
  )

  sizes <- lengths(list(mean_rt, var_rt, accuracy, n_trials))
  if (any(sizes == 0L)) {
    return(data.frame(
      drift = numeric(0), bound = numeric(0), ndt = numeric(0),
      edge_corrected = logical(0)
    ))
  }
  n <- max(sizes)
  .warnif(
    any(n %% sizes != 0L),
    "Longer argument is not a multiple of the shorter ones; recycling anyway."
  )
  mean_rt <- rep_len(mean_rt, n)
  var_rt <- rep_len(var_rt, n)
  accuracy <- rep_len(accuracy, n)
  n_trials <- rep_len(n_trials, n)

  # Wagenmakers et al.'s edge correction: the equations divide by logit(Pc), so
  # 0, 0.5 and 1 all have to be nudged by half a trial
  shift <- 1 / (2 * n_trials)
  pc <- accuracy
  corrected <- !is.na(pc) & pc %in% c(0, 0.5, 1)
  pc[!is.na(pc) & pc == 1] <- 1 - shift[!is.na(pc) & pc == 1]
  pc[!is.na(pc) & pc == 0] <- shift[!is.na(pc) & pc == 0]
  pc[!is.na(pc) & pc == 0.5] <- 0.5 + shift[!is.na(pc) & pc == 0.5]

  s2 <- s^2
  # a single trial leaves no room for the correction: 0 and 1 both land on 0.5,
  # where the equations break down for a different reason
  usable <- !is.na(pc) & !is.na(var_rt) & !is.na(mean_rt) & !is.na(n_trials) &
    var_rt > 0 & !(corrected & n_trials < 2)

  drift <- bound <- ndt <- rep(NA_real_, n)
  if (any(usable)) {
    i <- usable
    logit <- stats::qlogis(pc[i])
    x <- logit * (logit * pc[i]^2 - logit * pc[i] + pc[i] - 0.5) / var_rt[i]
    v <- sign(pc[i] - 0.5) * s * x^(1 / 4)
    a <- s2 * logit / v
    y <- -v * a / s2
    mdt <- (a / (2 * v)) * (1 - exp(y)) / (1 + exp(y))

    drift[i] <- v
    bound[i] <- a
    ndt[i] <- mean_rt[i] - mdt
  }

  data.frame(
    drift = drift, bound = bound, ndt = ndt, edge_corrected = corrected
  )
}
