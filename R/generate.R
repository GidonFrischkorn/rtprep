# Layer 5: generation with ground truth. Only r_contaminated() is exported;
# the samplers, the observable-space matching solver, and the contaminant
# machinery are internal (the simulation scripts reach them via rtprep:::).
#
# Two generators produce data -- a diffusion decision model and a two-
# accumulator Wald race -- and both are matched on the observables (mean RT,
# RT variance, accuracy) rather than on parameters, because observables are
# what a researcher can see. (mean_rt, var_rt, accuracy) are exactly the EZ
# sufficient statistics, so on clean data the two matched generators yield
# identical EZ parameters by construction, and any downstream difference is
# attributable to preprocessing interacting with distributional shape.

# ---- samplers ---------------------------------------------------------------

# First-principles diffusion sampler: Euler-Maruyama with a small step.
# Distributional equivalence against rtdists is pinned in the test suite.
# `ndt` is the MEAN non-decision time; `st0 > 0` draws per-trial values from
# U(ndt - st0/2, ndt + st0/2), the centred (Ratcliff) parameterization, so the
# mean RT is invariant in st0 and only the leading edge smears.
.r_ddm <- function(n, drift, bound, ndt, zr = 0.5, st0 = 0, s = 1,
                   dt = 0.001, max_steps = ceiling(20 / dt)) {
  x <- rep(zr * bound, n)
  dec <- numeric(n)
  upper <- logical(n)
  alive <- seq_len(n)
  sd_step <- s * sqrt(dt)
  step <- 0L
  while (length(alive) > 0L && step < max_steps) {
    step <- step + 1L
    x[alive] <- x[alive] + drift * dt +
      stats::rnorm(length(alive), 0, sd_step)
    hit_up <- x[alive] >= bound
    done <- hit_up | x[alive] <= 0
    if (any(done)) {
      idx <- alive[done]
      dec[idx] <- step * dt
      upper[idx] <- hit_up[done]
      alive <- alive[!done]
    }
  }
  # Stragglers past max_steps (20 s of decision time by default) are
  # vanishingly rare for any parameter set this package generates from; they
  # are closed out at the nearer boundary rather than dropped, so nrow stays n.
  if (length(alive) > 0L) {
    dec[alive] <- max_steps * dt
    upper[alive] <- x[alive] >= bound / 2
  }
  ndt_i <- if (st0 > 0) {
    stats::runif(n, ndt - st0 / 2, ndt + st0 / 2)
  } else {
    ndt
  }
  data.frame(rt = dec + ndt_i, response = as.integer(upper))
}

# Racing diffusion: two independent single-boundary Wald accumulators, shared
# bound, winner takes the trial. Exact inverse-Gaussian draws (no time grid):
# the first-passage time of a drift-v diffusion through bound b is
# IG(mu = b/v, lambda = b^2). `drift` is c(correct, error).
.r_rdm <- function(n, drift, bound, ndt, st0 = 0) {
  t_correct <- .rinvgauss(n, bound / drift[1], bound^2)
  t_error <- .rinvgauss(n, bound / drift[2], bound^2)
  upper <- t_correct < t_error
  ndt_i <- if (st0 > 0) {
    stats::runif(n, ndt - st0 / 2, ndt + st0 / 2)
  } else {
    ndt
  }
  data.frame(
    rt = pmin(t_correct, t_error) + ndt_i,
    response = as.integer(upper)
  )
}

# One entry point for both generators, so the contaminant machinery does not
# carry a switch() at every call site.
.r_core <- function(n, generator, par, st0, dt) {
  switch(generator,
    ddm = .r_ddm(
      n, par$drift, par$bound, par$ndt,
      zr = par$zr, st0 = st0, dt = dt
    ),
    rdm = .r_rdm(n, par$drift, par$bound, par$ndt, st0 = st0)
  )
}

# ---- deterministic observables ----------------------------------------------

# The closed-form EZ observables of an unbiased diffusion (Wagenmakers et al.,
# 2007, with s = 1): the exact inverse of ez_ddm(), which the test suite pins.
.ez_forward <- function(drift, bound, ndt, s = 1) {
  y <- exp(-drift * bound / s^2)
  pc <- 1 / (1 + y)
  mdt <- (bound / (2 * drift)) * (1 - y) / (1 + y)
  vdt <- (bound * s^2 / (2 * drift^3)) *
    (1 - 2 * (bound * drift / s^2) * y - y^2) / (1 + y)^2
  c(mean_rt = ndt + mdt, var_rt = vdt, accuracy = pc)
}

# Correct-trial decision-time moments of the Wald race, by numerical
# integration of the winner's defective density -- deterministic, so the
# matching solver optimizes a smooth surface with no common-random-numbers
# machinery needed.
.race_dt_moments <- function(v_correct, v_error, bound) {
  mu_c <- bound / v_correct
  mu_e <- bound / v_error
  lambda <- bound^2
  upper <- max(mu_c + 8 * sqrt(mu_c^3 / lambda), mu_e) * 4 + 5
  win_density <- function(t) {
    .dinvgauss(t, mu_c, lambda) * (1 - .pinvgauss(t, mu_e, lambda))
  }
  moment <- function(fun) {
    stats::integrate(function(t) fun(t) * win_density(t),
      lower = 0, upper = upper, rel.tol = 1e-8,
      stop.on.error = FALSE
    )$value
  }
  pc <- moment(function(t) rep(1, length(t)))
  if (!is.finite(pc) || pc <= 0) {
    return(c(accuracy = NA_real_, mean_dt = NA_real_, sd_dt = NA_real_))
  }
  m1 <- moment(identity) / pc
  m2 <- moment(function(t) t^2) / pc
  c(
    accuracy = pc, mean_dt = m1,
    sd_dt = sqrt(max(m2 - m1^2, 0))
  )
}

# ---- observable-space matching ----------------------------------------------

# Return generator parameters that hit a target (mean_rt, var_rt, accuracy),
# subject to the plausibility constraint that the non-decision time falls in
# `ndt_range` (default: the published Ter range of Matzke & Wagenmakers, 2009).
# The constraint is the point: matching the race to a DDM *without* it drives
# t0 to ~0.02 s -- an exact match on observables that no fitted racing model
# would produce. Cells that cannot be hit under the constraint are refused
# with an error rather than silently approximated.
#
# ddm: closed-form EZ inversion -- (var_rt, accuracy) fix drift and bound
#   uniquely, mean_rt then fixes ndt. Deterministic and exact.
# rdm: the race family is closed under time scaling, so its shape space is
#   two-dimensional -- the drift ratio and the drift-bound product -- and the
#   shape fixes accuracy and the decision-time coefficient of variation. The
#   solver optimizes the shape to hit the target accuracy, matches sd(RT)
#   exactly by scale, and lets the implied ndt fall where the mean demands;
#   a penalty keeps that ndt inside `ndt_range`. Deterministic (integrated
#   moments, fixed starts), no simulation in the loop.
.match_observables <- function(mean_rt, var_rt, accuracy,
                               generator = c("ddm", "rdm"),
                               ndt_range = c(0.206, 0.942)) {
  generator <- match.arg(generator)
  .check_scalar(mean_rt, "mean_rt", lower = 0, incl_lower = FALSE)
  .check_scalar(var_rt, "var_rt", lower = 0, incl_lower = FALSE)
  .check_scalar(accuracy, "accuracy",
    lower = 0.5, upper = 1,
    incl_lower = FALSE, incl_upper = FALSE
  )

  if (generator == "ddm") {
    inv <- ez_ddm(mean_rt, var_rt, accuracy, n_trials = 1e6)
    if (inv$ndt < ndt_range[1] || inv$ndt > ndt_range[2]) {
      stop(
        "The ddm generator can only hit this target with an implied ",
        "non-decision time of ", round(inv$ndt, 3), " s, outside the ",
        "plausible range [", ndt_range[1], ", ", ndt_range[2], "]. ",
        "Pick a target cell inside the jointly attainable region.",
        call. = FALSE
      )
    }
    return(list(
      generator = "ddm",
      par = list(
        drift = inv$drift, bound = inv$bound, ndt = inv$ndt, zr = 0.5
      ),
      observables = .ez_forward(inv$drift, inv$bound, inv$ndt)
    ))
  }

  sd_t <- sqrt(var_rt)
  shape_loss <- function(p) {
    r <- stats::plogis(p[1])
    w <- exp(p[2])
    o <- .race_dt_moments(1, r, w)
    if (!all(is.finite(o))) {
      return(1e6)
    }
    k <- sd_t / o[["sd_dt"]] # time scale that matches sd(RT) exactly
    t0 <- mean_rt - k * o[["mean_dt"]] # ndt then follows from the mean
    outside <- max(0, ndt_range[1] - t0) + max(0, t0 - ndt_range[2])
    ((o[["accuracy"]] - accuracy) / 0.002)^2 + (outside / 0.005)^2
  }
  starts <- expand.grid(
    r = stats::qlogis(c(0.25, 0.55, 0.85)),
    w = log(c(0.5, 2, 8))
  )
  best <- NULL
  for (i in seq_len(nrow(starts))) {
    fit <- stats::optim(
      c(starts$r[i], starts$w[i]), shape_loss,
      method = "Nelder-Mead",
      control = list(maxit = 400, reltol = 1e-10)
    )
    if (is.null(best) || fit$value < best$value) best <- fit
  }
  r <- stats::plogis(best$par[1])
  w <- exp(best$par[2])
  o <- .race_dt_moments(1, r, w)
  k <- sd_t / o[["sd_dt"]]
  t0 <- mean_rt - k * o[["mean_dt"]]
  attained <- abs(o[["accuracy"]] - accuracy) <= 0.005 &&
    t0 >= ndt_range[1] - 1e-8 && t0 <= ndt_range[2] + 1e-8
  if (!attained) {
    stop(
      "The target (mean_rt = ", mean_rt, ", var_rt = ", var_rt,
      ", accuracy = ", accuracy, ") is not attainable for the rdm ",
      "generator with a non-decision time in [", ndt_range[1], ", ",
      ndt_range[2], "]. Pick a target cell inside the jointly ",
      "attainable region.",
      call. = FALSE
    )
  }
  # undo the base parameterization (v_correct = 1, v_error = r, bound = w):
  # scaling time by k multiplies the bound by sqrt(k), divides drifts by it
  par <- list(
    drift = c(1, r) / sqrt(k),
    bound = sqrt(k) * w,
    ndt = min(max(t0, ndt_range[1]), ndt_range[2])
  )
  list(
    generator = "rdm",
    par = par,
    observables = c(
      mean_rt = t0 + k * o[["mean_dt"]],
      var_rt = (k * o[["sd_dt"]])^2,
      accuracy = o[["accuracy"]]
    )
  )
}

# ---- the evidence-quality lapse parameterization ----------------------------

# Degrade the quality of the evidence while holding the speed of processing
# fixed; prop = 1 is the clean process, prop = 0 a complete lapse at chance
# accuracy with finishing times still inside the core's range.
#
# ddm: drift IS the signed evidence difference, so drift -> prop * drift.
#
# rdm: zero drift is NOT the racing analogue of a complete lapse. A Wald
# accumulator's mean finishing time is bound/drift, which diverges as the
# drift goes to 0 -- a zero-drift race never terminates. What chance accuracy
# means in a race is that the two accumulators are equally fast, not that
# nothing accumulates. So scale the evidence DIFFERENCE delta = v1 - v2 while
# holding the total processing rate vbar = (v1 + v2)/2 fixed:
# (v1, v2) -> (vbar + prop * delta/2, vbar - prop * delta/2).
.lapse_pars <- function(par, generator, prop) {
  if (generator == "ddm") {
    par$drift <- prop * par$drift
  } else {
    delta <- par$drift[1] - par$drift[2]
    vbar <- (par$drift[1] + par$drift[2]) / 2
    par$drift <- c(vbar + prop * delta / 2, vbar - prop * delta / 2)
  }
  par
}

# ---- generator parameter validation ----------------------------------------

.check_generator_par <- function(par, generator) {
  .stopif(
    !is.list(par),
    "'par' must be a list of generator parameters."
  )
  defaults <- switch(generator,
    ddm = list(drift = 1.5, bound = 1.2, ndt = 0.30, zr = 0.5),
    rdm = list(drift = c(3, 1.5), bound = 1.5, ndt = 0.30)
  )
  unknown <- setdiff(names(par), names(defaults))
  .stopif(length(unknown) > 0L, paste0(
    "Unknown 'par' component(s) for the ", generator, " generator: ",
    paste(unknown, collapse = ", "), ". Expected: ",
    paste(names(defaults), collapse = ", "), "."
  ))
  par <- utils::modifyList(defaults, par)
  if (generator == "ddm") {
    .check_scalar(par$drift, "par$drift")
    .check_scalar(par$zr, "par$zr",
      lower = 0, upper = 1,
      incl_lower = FALSE, incl_upper = FALSE
    )
  } else {
    .stopif(
      !is.numeric(par$drift) || length(par$drift) != 2L ||
        any(!is.finite(par$drift)) || any(par$drift <= 0),
      paste0(
        "For the rdm generator 'par$drift' must be two positive drifts, ",
        "c(correct, error)."
      )
    )
  }
  .check_scalar(par$bound, "par$bound", lower = 0, incl_lower = FALSE)
  .check_scalar(par$ndt, "par$ndt", lower = 0, incl_lower = FALSE)
  par
}

# ---- r_contaminated() -------------------------------------------------------

#' Generate response time data with contaminants of known type
#'
#' @description
#' Draws trials from an evidence accumulation core and replaces a known subset
#' with contaminants generated by one of three psychologically motivated
#' processes. The ground truth comes back with the data, which is the point:
#' contamination is invisible in real data, so only generated data with known
#' truth lets a preprocessing pipeline be tested rather than trusted.
#'
#' @param n Number of trials.
#' @param generator The clean core. `"ddm"` is a first-principles diffusion
#'   (Euler–Maruyama); `"rdm"` a racing diffusion — two independent
#'   single-boundary Wald accumulators with a shared bound, exact
#'   inverse-Gaussian draws.
#' @param process Which contaminant process replaces the selected trials:
#'
#'   * `"leading_edge"` — anticipations. Uniform in a band around the observed
#'     minimum of the *clean* trials in this call (see
#'     `anticipation_anchor`), responding at chance. Anchoring to an observed
#'     quantity rather than to the generating non-decision time keeps the
#'     construct comparable across generators, whose fitted non-decision
#'     times can differ substantially at identical observables.
#'   * `"delay"` — delayed start-ups. A genuine trial plus a uniform shift of
#'     `delay_min` to `delay_max` seconds; the response — and so the intact
#'     accuracy — is kept.
#'   * `"informationless"` — lapses of evidence quality. The trial is redrawn
#'     from the core with its evidence scaled by `lapse_prop` while the speed
#'     of processing is held fixed: `lapse_prop = 0` is a complete lapse
#'     (chance accuracy, response times still in the core's range),
#'     `lapse_prop = 1` the clean process, and values between are partial
#'     lapses on the same continuum.
#'   * `"mixed"` — each contaminant trial draws its process from `mix`.
#' @param rate Probability that a trial is a contaminant, in `[0, 1)`.
#' @param par Generator parameters as a list. For `"ddm"`: `drift`, `bound`,
#'   `ndt`, `zr` (defaults `1.5, 1.2, 0.30, 0.5`). For `"rdm"`: `drift` as
#'   `c(correct, error)`, `bound`, `ndt` (defaults `c(3, 1.5), 1.5, 0.30`).
#'   The defaults are illustrative, not calibrated; simulation designs should
#'   set parameters from an observable target instead.
#' @param st0 Range of across-trial variability in non-decision time, in
#'   seconds. The per-trial non-decision time is uniform on `ndt ± st0 / 2` —
#'   the centred parameterization, so the mean response time is invariant and
#'   only the leading edge smears.
#' @param anticipation_anchor Observable the anticipation band is centred on:
#'   the minimum (`"min"`) or the 10th percentile (`"q10"`) of the clean
#'   trials generated in this call.
#' @param anticipation_depth Half-width of the anticipation band as a
#'   proportion of the anchor: response times are uniform on
#'   `anchor * (1 ± anticipation_depth)`.
#' @param delay_min,delay_max Bounds of the uniform shift, in seconds, for
#'   `process = "delay"`.
#' @param lapse_prop Evidence-quality proportion for
#'   `process = "informationless"`; see above.
#' @param mix Relative weights of `leading_edge`, `delay`, and
#'   `informationless` for `process = "mixed"`, in that order. Normalized
#'   internally.
#' @param dt Euler–Maruyama step size for the `"ddm"` generator, in seconds.
#'   Smaller steps are slower and more faithful: a discretised first-passage
#'   sampler misses boundary crossings that happen inside a step, which
#'   shifts the response times slightly late. The default of one millisecond
#'   was validated against `rtdists::rdiffusion()` in the package's tests,
#'   where the two agree in accuracy and in the response time quantiles.
#'
#' @return A `data.frame` with `n` rows:
#'
#'   * `rt` — response time in seconds,
#'   * `response` — `1` for a correct (upper-boundary / winning-accumulator)
#'     response, `0` otherwise,
#'   * `contaminant` — logical ground truth,
#'   * `process` — `"clean"` or the generating contaminant process per trial.
#'
#' @details
#' # Reproducibility
#'
#' There is no `set.seed()` anywhere in `rtprep`; reproducibility belongs to
#' the caller (in the simulation scripts, to SimDesign's seed management).
#'
#' # The three processes are clusters, not point definitions
#'
#' Each named process is one implementation of a psychological cluster —
#' premature responding, late starts, disengagement — and the arguments
#' (`anticipation_anchor`, `anticipation_depth`, `delay_min`/`delay_max`,
#' `lapse_prop`) sweep within the cluster. Which implementations a simulation
#' uses, and how many per cluster, is a design decision recorded in the
#' project's `DESIGN.md`, not a package default.
#'
#' @references
#' Ratcliff, R. (1993). Methods for dealing with reaction time outliers.
#' *Psychological Bulletin*, *114*(3), 510–532.
#' \doi{10.1037/0033-2909.114.3.510}
#'
#' Ratcliff, R., & Tuerlinckx, F. (2002). Estimating parameters of the
#' diffusion model: Approaches to dealing with contaminant reaction times and
#' parameter variability. *Psychonomic Bulletin & Review*, *9*(3), 438–481.
#' \doi{10.3758/bf03196302}
#'
#' @seealso [rt_screen()] for what the flags make of these trials,
#'   [rt_summary()] and [ez_ddm()] for what the contamination does to the
#'   parameters.
#'
#' @examples
#' set.seed(1)
#' d <- r_contaminated(
#'   200,
#'   generator = "ddm", process = "leading_edge", rate = 0.1,
#'   par = list(drift = 1.5, bound = 1.2, ndt = 0.30)
#' )
#' table(d$process)
#' # detection scored against ground truth
#' scr <- rt_screen(d$rt, rule = rule_sd(2.5))
#' table(flagged = !scr$.keep, truth = d$contaminant)
#'
#' @export
r_contaminated <- function(n, generator = c("ddm", "rdm"),
                           process = c(
                             "leading_edge", "delay",
                             "informationless", "mixed"
                           ),
                           rate = 0.05, par = list(), st0 = 0,
                           anticipation_anchor = c("min", "q10"),
                           anticipation_depth = 0.3,
                           delay_min = 0, delay_max = 2,
                           lapse_prop = 0,
                           mix = c(
                             leading_edge = 1, delay = 1,
                             informationless = 1
                           ) / 3,
                           dt = 0.001) {
  generator <- match.arg(generator)
  process <- match.arg(process)
  anticipation_anchor <- match.arg(anticipation_anchor)
  .check_count(n, "n")
  .check_scalar(rate, "rate", lower = 0, upper = 1, incl_upper = FALSE)
  .check_scalar(st0, "st0", lower = 0)
  .check_scalar(anticipation_depth, "anticipation_depth",
    lower = 0, upper = 1, incl_lower = FALSE, incl_upper = FALSE
  )
  .check_scalar(delay_min, "delay_min", lower = 0)
  .check_scalar(delay_max, "delay_max", lower = 0)
  .stopif(delay_max <= delay_min, "'delay_max' must exceed 'delay_min'.")
  .check_scalar(lapse_prop, "lapse_prop", lower = 0, upper = 1)
  .check_scalar(dt, "dt", lower = 0, incl_lower = FALSE)
  .stopif(
    !is.numeric(mix) || length(mix) != 3L || any(mix < 0) || sum(mix) <= 0,
    paste0(
      "'mix' must be three non-negative weights for leading_edge, delay, ",
      "and informationless, in that order."
    )
  )
  par <- .check_generator_par(par, generator)

  core <- .r_core(n, generator, par, st0, dt)
  rt <- core$rt
  response <- core$response

  contaminant <- stats::runif(n) < rate
  proc <- rep("clean", n)
  if (any(contaminant)) {
    proc[contaminant] <- if (process == "mixed") {
      sample(
        c("leading_edge", "delay", "informationless"),
        sum(contaminant),
        replace = TRUE, prob = mix / sum(mix)
      )
    } else {
      process
    }
    .stopif(
      any(proc == "leading_edge") && all(contaminant),
      paste0(
        "Every trial came out a contaminant, so there is no clean trial ",
        "to anchor the anticipation band on. Lower 'rate' or raise 'n'."
      )
    )

    is_ant <- proc == "leading_edge"
    if (any(is_ant)) {
      clean_rt <- rt[!contaminant]
      anchor <- switch(anticipation_anchor,
        min = min(clean_rt),
        q10 = unname(stats::quantile(clean_rt, 0.10))
      )
      k <- sum(is_ant)
      rt[is_ant] <- stats::runif(
        k,
        (1 - anticipation_depth) * anchor,
        (1 + anticipation_depth) * anchor
      )
      response[is_ant] <- stats::rbinom(k, 1, 0.5)
    }

    is_delay <- proc == "delay"
    if (any(is_delay)) {
      k <- sum(is_delay)
      # a genuine trial started late: the core draw and its response survive
      rt[is_delay] <- rt[is_delay] + stats::runif(k, delay_min, delay_max)
    }

    is_lapse <- proc == "informationless"
    if (any(is_lapse)) {
      k <- sum(is_lapse)
      redraw <- .r_core(
        k, generator, .lapse_pars(par, generator, lapse_prop), st0, dt
      )
      rt[is_lapse] <- redraw$rt
      response[is_lapse] <- redraw$response
    }
  }

  data.frame(
    rt = rt, response = response,
    contaminant = contaminant, process = proc
  )
}
