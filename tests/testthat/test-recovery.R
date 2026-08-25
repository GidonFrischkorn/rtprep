# Parameter recovery as a unit test, not as a simulation study: one replication
# per cell, generous tolerances, and the question is only "does the EM find
# roughly what generated the data" rather than "how well does it do so". The
# real recovery study lives in scripts/.
#
# This is the test that would catch an M-step that is wrong but self-consistent
# -- the failure mode the bmm equivalence test cannot see, because a shared
# mistake would agree with itself.

fit_known <- function(rt, distribution, bound = c("min", "max")) {
  rtprep:::.fit_rt_mixture(
    rt, distribution, rtprep:::.resolve_bounds(bound, rt)$bound,
    init = 0.05, max_prop = 0.5, maxit = 500, tol = 1e-8
  )
}

test_that("the EM recovers ex-Gaussian parameters and the mixing weight", {
  set.seed(101)
  n <- 4000
  pi_c <- 0.10
  par <- c(mu = 0.45, sigma = 0.05, tau = 0.15)

  is_contam <- runif(n) < pi_c
  rt <- ifelse(
    is_contam,
    runif(n, 0.10, 2.50),
    rtprep:::.rexgauss(n, par["mu"], par["sigma"], par["tau"])
  )

  fit <- fit_known(rt, "exgaussian")
  expect_true(fit$converged)
  expect_equal(fit$contaminant_prop, pi_c, tolerance = 0.4)
  expect_equal(as.numeric(fit$par["mu"]), 0.45, tolerance = 0.15)
  expect_equal(as.numeric(fit$par["tau"]), 0.15, tolerance = 0.4)
})

test_that("the EM recovers lognormal parameters and the mixing weight", {
  set.seed(102)
  n <- 4000
  pi_c <- 0.15
  par <- c(mu = -0.9, sigma = 0.3)

  is_contam <- runif(n) < pi_c
  rt <- ifelse(
    is_contam,
    runif(n, 0.05, 3.00),
    rlnorm(n, par["mu"], par["sigma"])
  )

  fit <- fit_known(rt, "lognormal")
  expect_true(fit$converged)
  expect_equal(fit$contaminant_prop, pi_c, tolerance = 0.4)
  expect_equal(as.numeric(fit$par["mu"]), -0.9, tolerance = 0.1)
  expect_equal(as.numeric(fit$par["sigma"]), 0.3, tolerance = 0.2)
})

test_that("the EM recovers inverse Gaussian parameters and the mixing weight", {
  set.seed(103)
  n <- 4000
  pi_c <- 0.12
  par <- c(mu = 0.5, lambda = 3)

  is_contam <- runif(n) < pi_c
  rt <- ifelse(
    is_contam,
    runif(n, 0.05, 3.00),
    rtprep:::.rinvgauss(n, par["mu"], par["lambda"])
  )

  fit <- fit_known(rt, "invgaussian")
  expect_true(fit$converged)
  expect_equal(fit$contaminant_prop, pi_c, tolerance = 0.5)
  expect_equal(as.numeric(fit$par["mu"]), 0.5, tolerance = 0.2)
  expect_equal(as.numeric(fit$par["lambda"]), 3, tolerance = 0.5)
})

test_that("the recovered mixing weight tracks the true one", {
  # a single point estimate can be lucky; the ordering across rates cannot
  set.seed(104)
  n <- 3000
  rates <- c(0.02, 0.10, 0.25)

  estimated <- vapply(rates, function(pi_c) {
    is_contam <- runif(n) < pi_c
    rt <- ifelse(
      is_contam,
      runif(n, 0.05, 3.00),
      rlnorm(n, -0.9, 0.3)
    )
    fit_known(rt, "lognormal")$contaminant_prop
  }, numeric(1))

  expect_false(is.unsorted(estimated))
  expect_true(all(abs(estimated - rates) < 0.1))
})

test_that("clean data yields a mixing weight near zero", {
  set.seed(105)
  rt <- rlnorm(3000, -0.9, 0.3)
  fit <- fit_known(rt, "lognormal")

  expect_true(fit$converged)
  expect_lt(fit$contaminant_prop, 0.05)
  expect_equal(as.numeric(fit$par["mu"]), -0.9, tolerance = 0.05)
  expect_equal(as.numeric(fit$par["sigma"]), 0.3, tolerance = 0.1)
})

test_that("per-trial responsibilities separate the two components", {
  set.seed(106)
  n_core <- 2000
  n_contam <- 300
  rt <- c(
    rlnorm(n_core, -0.9, 0.2),
    runif(n_contam, 0.05, 0.12) # well below the core
  )
  truth <- rep(c(FALSE, TRUE), c(n_core, n_contam))

  out <- rt_screen(rt, rule = rule_mixture("lognormal"))
  flagged <- !out$.keep

  sensitivity <- sum(flagged & truth) / sum(truth)
  specificity <- sum(!flagged & !truth) / sum(!truth)
  expect_gt(sensitivity, 0.7)
  expect_gt(specificity, 0.9)
})
