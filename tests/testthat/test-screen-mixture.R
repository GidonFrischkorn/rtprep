# rule_mixture() is the reason rt_screen() separates .prob from .keep at all:
# it is the one rule that returns a genuine posterior rather than a verdict.

mixture_data <- function(n_core = 400, n_contam = 40, seed = 21) {
  set.seed(seed)
  core <- rtprep:::.rexgauss(n_core, mu = 0.45, sigma = 0.05, tau = 0.15)
  contam <- runif(n_contam, 0.10, 0.20)
  data.frame(
    rt = c(core, contam),
    contaminant = rep(c(FALSE, TRUE), c(n_core, n_contam))
  )
}

test_that("rule_mixture() returns probabilities that are not degenerate", {
  d <- mixture_data()
  out <- rt_screen(d$rt, rule = rule_mixture())

  expect_equal(nrow(out), nrow(d))
  expect_true(all(out$.prob >= 0 & out$.prob <= 1))
  # the whole point: a mixture rule must produce intermediate probabilities
  expect_gt(sum(out$.prob > 0.01 & out$.prob < 0.99), 0)
  expect_equal(unique(out$.rule), "mixture(exgaussian)")
})

test_that("rule_mixture() gives the fast contaminants the low probabilities", {
  d <- mixture_data()
  out <- rt_screen(d$rt, rule = rule_mixture("lognormal"))

  expect_lt(mean(out$.prob[d$contaminant]), mean(out$.prob[!d$contaminant]))
  expect_gt(mean(!out$.keep[d$contaminant]), 0.5)
  expect_lt(mean(!out$.keep[!d$contaminant]), 0.15)
})

test_that("the ex-Gaussian core misses a tight block of fast guesses", {
  # The default core distribution absorbs a fast uniform block by widening its
  # Gaussian part rather than calling it contamination, so it flags almost
  # nothing on the archetypal fast-guess case. bmm's EM does the same thing from
  # the same starting values (see test-equivalence.R), so this is a property of
  # the model rather than of the implementation -- but it means the default is
  # not the right choice for fast guesses, and Study 1 has to say so.
  d <- mixture_data()
  exg <- rt_screen(d$rt, rule = rule_mixture("exgaussian"))
  lno <- rt_screen(d$rt, rule = rule_mixture("lognormal"))

  expect_lt(mean(!exg$.keep[d$contaminant]), 0.2)
  expect_gt(mean(!lno$.keep[d$contaminant]), 0.5)
})

test_that(".reason is 'contaminant' exactly where the rule flagged the trial", {
  d <- mixture_data()
  out <- rt_screen(d$rt, rule = rule_mixture("lognormal"))

  flagged <- !out$.keep
  expect_gt(sum(flagged), 0)
  expect_true(all(out$.reason[flagged] == "contaminant"))
  expect_true(all(is.na(out$.reason[!flagged])))
})

test_that("trials outside the contaminant bounds cannot be contaminants", {
  d <- mixture_data()
  rt <- c(d$rt, 6.0, 7.0)
  out <- suppressWarnings(
    rt_screen(rt, rule = rule_mixture(bound = c(0.05, 3)))
  )
  # the uniform component has no mass out there, so P(valid) is exactly 1
  expect_equal(out$.prob[length(rt) - 1:0], c(1, 1))
  expect_true(all(out$.keep[length(rt) - 1:0]))
})

test_that("all three distributions converge and stay within their bounds", {
  d <- mixture_data()
  props <- vapply(c("exgaussian", "lognormal", "invgaussian"), function(dist) {
    out <- rt_screen(d$rt, rule = rule_mixture(dist, maxit = 500))
    expect_true(attr(out, "fits")$converged, info = dist)
    expect_true(all(out$.prob >= 0 & out$.prob <= 1), info = dist)
    mean(!out$.keep)
  }, numeric(1))

  # they do NOT agree -- see the ex-Gaussian test above -- so assert only that
  # each stays inside the model's own max_prop
  expect_true(all(props <= 0.5))
})

test_that("the fits table carries the EM diagnostics", {
  d <- mixture_data()
  fits <- attr(rt_screen(d$rt, rule = rule_mixture(maxit = 500)), "fits")

  expect_true(all(c(
    "converged", "iterations", "loglik", "contaminant_prop", "n_fitted",
    "bound_lower", "bound_upper", "par_mu", "par_sigma", "par_tau"
  ) %in% names(fits)))
  expect_true(fits$converged)
  expect_gt(fits$contaminant_prop, 0)
  expect_lt(fits$bound_lower, min(d$rt))
  expect_gt(fits$bound_upper, max(d$rt))

  ln <- attr(rt_screen(d$rt, rule = rule_mixture("lognormal")), "fits")
  expect_true(all(c("par_mu", "par_sigma") %in% names(ln)))
  expect_false("par_tau" %in% names(ln))
})

test_that("groups are fitted independently", {
  set.seed(23)
  clean <- rtprep:::.rexgauss(300, 0.45, 0.05, 0.15)
  dirty <- c(
    rtprep:::.rexgauss(280, 0.45, 0.05, 0.15), runif(30, 0.10, 0.20)
  )
  rt <- c(clean, dirty)
  id <- rep(c("clean", "dirty"), c(length(clean), length(dirty)))

  scr <- rt_screen(rt, rule = rule_mixture("lognormal"), .by = id)
  fits <- attr(scr, "fits")
  expect_equal(fits$.group, c("clean", "dirty"))
  expect_lt(
    fits$contaminant_prop[fits$.group == "clean"],
    fits$contaminant_prop[fits$.group == "dirty"]
  )
})

test_that("a fit that cannot converge keeps everything and says so once", {
  # four trials per group is below the five the EM needs
  rt <- c(0.30, 0.35, 0.40, 0.45, 0.31, 0.36, 0.41, 0.46)
  id <- rep(c("a", "b"), each = 4)

  expect_warning(
    out <- rt_screen(rt, rule = rule_mixture(), .by = id),
    "did not converge"
  )
  expect_true(all(out$.keep))
  expect_equal(out$.prob, rep(1, 8))
  expect_true(all(is.na(out$.reason)))

  fits <- attr(out, "fits")
  expect_false(any(fits$converged))
  expect_true(all(is.na(fits$contaminant_prop)))
})

test_that("non-convergence warns once, not once per group", {
  # warning inside the group loop would emit one per subject, which at
  # simulation scale buries everything else
  rt <- rep(c(0.30, 0.35, 0.40, 0.45), 20)
  id <- rep(seq_len(20), each = 4)

  warnings <- character(0)
  withCallingHandlers(
    rt_screen(rt, rule = rule_mixture(), .by = id),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(grep("did not converge", warnings), 1L)
  expect_match(warnings[grep("did not converge", warnings)], "20")
})

test_that("the accuracy-informed mixture waits for milestone 4", {
  d <- mixture_data()
  expect_error(
    rt_screen(d$rt, rep(c(1, 0), length.out = nrow(d)),
      rule = rule_mixture(use_accuracy = TRUE)
    ),
    "not yet implemented"
  )
  # and it must say so before touching a group, so an empty one cannot hide it
  expect_error(
    rt_screen(c(NA_real_, NA_real_), c(1, 0),
      rule = rule_mixture(use_accuracy = TRUE)
    ),
    "not yet implemented"
  )
})
