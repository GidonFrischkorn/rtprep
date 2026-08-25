# The EM engine, tested on its own before rule_mixture() wraps it. The loop
# order is copied from bmm rather than improved, so these tests pin the copied
# behaviour down: convergence is checked before the M-step, and the reported
# parameters are the ones that produced the converged log-likelihood.

# Contaminants uniform over the plausible response time range, which is the
# model's own assumption. A tight fast block is a different regime and gets its
# own test below, because the ex-Gaussian behaves very differently there.
contaminated <- function(n_core = 400, n_contam = 40, seed = 7) {
  set.seed(seed)
  c(
    rtprep:::.rexgauss(n_core, mu = 0.45, sigma = 0.05, tau = 0.15),
    runif(n_contam, 0.10, 2.50)
  )
}

# --- .resolve_bounds --------------------------------------------------------

test_that(".resolve_bounds() buffers data-driven bounds outward", {
  x <- c(1.0, 1.4, 1.6, 2.2)
  r <- rtprep:::.resolve_bounds(c("min", "max"), x)

  buffer <- max(0.5 * diff(range(x)), 0.1)
  expect_equal(r$bound, c(min(x) - buffer, max(x) + buffer))
  # the buffer is what makes the mixture identifiable: an unbuffered uniform
  # would put its edges exactly on data points
  expect_lt(r$bound[1], min(x))
  expect_gt(r$bound[2], max(x))
  expect_false(r$inverted)
  expect_false(r$excludes_fast)
  expect_false(r$excludes_slow)
})

test_that(".resolve_bounds() floors the lower bound above zero", {
  x <- c(0.05, 0.06, 3.0)
  expect_equal(rtprep:::.resolve_bounds(c("min", "max"), x)$bound[1], 0.001)
})

test_that(".resolve_bounds() passes user numbers through unbuffered", {
  x <- c(0.2, 0.4, 0.6)
  expect_equal(rtprep:::.resolve_bounds(c(0.1, 2), x)$bound, c(0.1, 2))
  expect_equal(rtprep:::.resolve_bounds(c("0.1", "2"), x)$bound, c(0.1, 2))
})

test_that(".resolve_bounds() mixes a number with a keyword", {
  x <- c(0.2, 0.4, 0.6)
  r <- rtprep:::.resolve_bounds(c(0.1, "max"), x)
  expect_equal(r$bound[1], 0.1)
  expect_gt(r$bound[2], max(x))
})

test_that(".resolve_bounds() flags bounds that exclude observed trials", {
  # flagged rather than warned: bounds are resolved once per group, so warning
  # here would emit one per subject
  x <- c(0.2, 0.4, 0.6)
  expect_silent(narrow_lo <- rtprep:::.resolve_bounds(c(0.3, 2), x))
  expect_true(narrow_lo$excludes_fast)
  expect_false(narrow_lo$excludes_slow)

  expect_silent(narrow_hi <- rtprep:::.resolve_bounds(c(0.1, 0.5), x))
  expect_false(narrow_hi$excludes_fast)
  expect_true(narrow_hi$excludes_slow)
})

test_that(".resolve_bounds() falls back when the bounds come out inverted", {
  x <- c(0.2, 0.4, 0.6)
  expect_silent(r <- rtprep:::.resolve_bounds(c("max", "min"), x))
  expect_true(r$inverted)
  expect_lt(r$bound[1], r$bound[2])
  expect_lte(r$bound[1], min(x))
  expect_gte(r$bound[2], max(x))
})

test_that("rt_screen() reports bound problems once for the whole call", {
  set.seed(41)
  # each group straddles the bounds below, so every group would warn twice if
  # the warning lived in .resolve_bounds()
  one <- c(0.15, rtprep:::.rexgauss(38, 0.45, 0.05, 0.15), 2.5)
  rt <- rep(one, 5)
  id <- rep(seq_len(5), each = length(one))

  warnings <- character(0)
  withCallingHandlers(
    rt_screen(rt,
      rule = rule_mixture("lognormal", bound = c(0.3, 1.0)),
      .by = id
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(grep("exclude observed trials", warnings), 1L)
})

# --- the EM loop ------------------------------------------------------------

test_that(".fit_rt_mixture() returns the documented structure", {
  x <- contaminated()
  fit <- rtprep:::.fit_rt_mixture(
    x, "exgaussian", rtprep:::.resolve_bounds(c("min", "max"), x)$bound,
    init = 0.05, max_prop = 0.5, maxit = 100, tol = 1e-6
  )

  expect_named(
    fit,
    c(
      "par", "contaminant_prop", "converged", "iterations", "loglik",
      "n_fitted", "p_correct", "accuracy_inverted"
    )
  )
  # the accuracy fields are empty unless the joint model was asked for
  expect_true(is.na(fit$p_correct))
  expect_false(fit$accuracy_inverted)
  expect_true(fit$converged)
  expect_type(fit$iterations, "integer")
  expect_true(is.finite(fit$loglik))
  expect_equal(fit$n_fitted, length(x))
  expect_named(fit$par, c("mu", "sigma", "tau"))
  expect_true(all(is.finite(fit$par)))
})

test_that(".fit_rt_mixture() finds almost no contamination in clean data", {
  set.seed(11)
  x <- rtprep:::.rexgauss(500, 0.45, 0.05, 0.15)
  fit <- rtprep:::.fit_rt_mixture(
    x, "exgaussian", rtprep:::.resolve_bounds(c("min", "max"), x)$bound,
    init = 0.05, max_prop = 0.5, maxit = 100, tol = 1e-6
  )
  expect_true(fit$converged)
  expect_lt(fit$contaminant_prop, 0.06)
})

test_that("the M-step strictly improves the weighted likelihood", {
  # A no-op M-step would satisfy any "does not decrease" assertion, so start
  # deliberately away from the optimum and require a strict increase. This is
  # the invariant the whole EM rests on.
  set.seed(19)
  x <- contaminated()
  w <- runif(length(x), 0.2, 1)

  wll <- function(par, d) sum(w * rtprep:::.rt_density(x, par, d, log = TRUE))

  for (d in c("exgaussian", "lognormal", "invgaussian")) {
    start <- rtprep:::.init_dist_params(x, d) * 1.3
    updated <- rtprep:::.m_step(x, d, w, start)
    expect_gt(wll(updated, d), wll(start, d))
  }
})

test_that("the EM log-likelihood increases across iterations", {
  x <- contaminated()
  bound <- rtprep:::.resolve_bounds(c("min", "max"), x)$bound

  for (d in c("exgaussian", "lognormal", "invgaussian")) {
    # each fit converges at its own tol, so a looser tol must never reach a
    # higher optimum than a tighter one
    loose <- rtprep:::.fit_rt_mixture(
      x, d, bound,
      init = 0.05, max_prop = 0.5, maxit = 500, tol = 1e-3
    )
    tight <- rtprep:::.fit_rt_mixture(
      x, d, bound,
      init = 0.05, max_prop = 0.5, maxit = 500, tol = 1e-10
    )
    expect_true(loose$converged, info = d)
    expect_true(tight$converged, info = d)
    expect_gte(tight$loglik, loose$loglik - 1e-8, label = d)
    expect_gte(tight$iterations, loose$iterations, label = d)
  }
})

test_that("fewer than five in-bounds trials leaves the fit unconverged", {
  x <- c(0.3, 0.4, 0.5, 0.6)
  fit <- rtprep:::.fit_rt_mixture(
    x, "exgaussian", c(0.001, 5),
    init = 0.05, max_prop = 0.5, maxit = 100, tol = 1e-6
  )
  expect_false(fit$converged)
  expect_null(fit$par)
  expect_true(is.na(fit$contaminant_prop))
  expect_equal(fit$n_fitted, 4L)
  expect_equal(fit$iterations, 0L)
})

test_that("only in-bounds trials are fitted", {
  x <- c(rtprep:::.rexgauss(200, 0.45, 0.05, 0.15), 8, 9)
  fit <- rtprep:::.fit_rt_mixture(
    x, "lognormal", c(0.05, 3),
    init = 0.05, max_prop = 0.5, maxit = 100, tol = 1e-6
  )
  expect_equal(fit$n_fitted, sum(x >= 0.05 & x <= 3))
  expect_lt(fit$n_fitted, length(x))
})

test_that("the contaminant proportion is clipped at max_prop", {
  set.seed(13)
  # a fast block the lognormal core reports at about 0.19 when left alone
  x <- c(
    rtprep:::.rexgauss(400, 0.45, 0.05, 0.15), runif(40, 0.10, 0.20)
  )
  bound <- rtprep:::.resolve_bounds(c("min", "max"), x)$bound
  fit_at <- function(max_prop) {
    rtprep:::.fit_rt_mixture(
      x, "lognormal", bound,
      init = 0.01, max_prop = max_prop, maxit = 500, tol = 1e-6
    )$contaminant_prop
  }

  expect_gt(fit_at(0.5), 0.1)
  expect_equal(fit_at(0.05), 0.05)
  expect_equal(fit_at(0.02), 0.02)
})

test_that("every distribution converges on the same data", {
  x <- contaminated()
  bound <- rtprep:::.resolve_bounds(c("min", "max"), x)$bound

  for (d in c("exgaussian", "lognormal", "invgaussian")) {
    fit <- rtprep:::.fit_rt_mixture(
      x, d, bound,
      init = 0.05, max_prop = 0.5, maxit = 500, tol = 1e-6
    )
    expect_true(fit$converged, info = d)
    expect_gt(fit$contaminant_prop, 0.02, label = d)
    expect_lt(fit$contaminant_prop, 0.30, label = d)
  }
})

test_that("the ex-Gaussian collapses on a tight block of fast contaminants", {
  # Not a bug, and not rtprep's: the ex-Gaussian can absorb a fast uniform block
  # by widening its Gaussian part and sending tau to zero, which reports no
  # contamination at all. bmm's EM does exactly the same thing from the same
  # starting values -- test-equivalence.R asserts they agree -- so the failure
  # belongs to the model, not the implementation. It is a Study 1 result and a
  # reason the roster carries three core distributions rather than one.
  set.seed(7)
  x <- c(
    rtprep:::.rexgauss(400, 0.45, 0.05, 0.15),
    runif(40, 0.10, 0.20)
  )
  bound <- rtprep:::.resolve_bounds(c("min", "max"), x)$bound
  fit_one <- function(d) {
    rtprep:::.fit_rt_mixture(
      x, d, bound,
      init = 0.05, max_prop = 0.5, maxit = 500, tol = 1e-6
    )
  }

  exg <- fit_one("exgaussian")
  expect_true(exg$converged)
  expect_lt(exg$contaminant_prop, 0.001)
  expect_lt(as.numeric(exg$par["tau"]), 0.001) # tau driven to its lower bound

  # the other two find the block
  expect_gt(fit_one("lognormal")$contaminant_prop, 0.1)
  expect_gt(fit_one("invgaussian")$contaminant_prop, 0.1)
})

test_that("every failure mode reports the same empty result", {
  # the <5-trial path and the exhausted-loop path must not differ in what they
  # return, or a caller has to know which one it hit
  x <- contaminated()
  bound <- rtprep:::.resolve_bounds(c("min", "max"), x)$bound

  exhausted <- rtprep:::.fit_rt_mixture(
    x, "lognormal", bound,
    init = 0.05, max_prop = 0.5, maxit = 1, tol = 1e-6
  )
  too_few <- rtprep:::.fit_rt_mixture(
    c(0.3, 0.4, 0.5, 0.6), "lognormal", c(0.001, 5),
    init = 0.05, max_prop = 0.5, maxit = 100, tol = 1e-6
  )

  for (fit in list(exhausted, too_few)) {
    expect_false(fit$converged)
    expect_null(fit$par)
    expect_true(is.na(fit$contaminant_prop))
    # the log-likelihood is computed before each M-step, so on an unconverged
    # loop it belongs to different parameters than the ones being reported;
    # reporting it would invite a comparison that means nothing
    expect_true(is.na(fit$loglik))
  }
  expect_equal(exhausted$iterations, 1L)
  expect_equal(too_few$iterations, 0L)
})

test_that("identical response times do not produce a spurious fit", {
  # .init_dist_params() floors sigma and tau at 0.01, so the ex-Gaussian and
  # lognormal starts stay finite and the EM converges on a degenerate core; the
  # inverse Gaussian's lambda goes infinite and is caught at the start. Either
  # way nothing is flagged, which is what matters.
  rt <- rep(0.4, 30)
  for (d in c("exgaussian", "lognormal", "invgaussian")) {
    out <- suppressWarnings(rt_screen(rt, rule = rule_mixture(d)))
    expect_true(all(out$.keep), info = d)
    expect_true(all(out$.prob >= 0 & out$.prob <= 1), info = d)
  }
  # only the inverse Gaussian's start values actually go non-finite
  expect_warning(
    rt_screen(rt, rule = rule_mixture("invgaussian")), "did not converge"
  )
})

# --- the closed-form M-steps ------------------------------------------------

test_that("the closed-form M-steps maximise the weighted likelihood", {
  # the architecture calls for closed forms where they exist; they are only
  # legitimate if they beat a general optimiser on the same objective.
  # The weights run down to almost zero on purpose: that is what the EM hands
  # the M-step for a confident contaminant, and where the inverse Gaussian's
  # denominator comes closest to cancelling.
  set.seed(17)
  x <- rtprep:::.rinvgauss(300, 0.5, 3)
  w <- c(runif(280, 1e-8, 1), rep(1e-12, 20))

  for (d in c("lognormal", "invgaussian")) {
    closed <- rtprep:::.m_step(x, d, w, rtprep:::.init_dist_params(x, d))
    nll <- function(par) {
      -sum(w * rtprep:::.rt_density(x, par, d, log = TRUE))
    }
    bounds <- rtprep:::.param_bounds(d)
    numeric_fit <- optim(
      rtprep:::.init_dist_params(x, d), nll,
      method = "L-BFGS-B", lower = bounds$lower, upper = bounds$upper
    )
    expect_lte(nll(closed), numeric_fit$value + 1e-6, label = d)
  }
})
