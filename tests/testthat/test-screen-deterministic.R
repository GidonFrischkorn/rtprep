# Deterministic rules: exact keep sets on hand-computed fixtures.
#
# The van Selst & Jolicoeur criterion values used below (2.17 for n = 10 moving,
# 4.11 for n = 10 modified, 2.50 for n = 100 moving) are the published table
# entries, written out as literals so the test asserts the table rather than
# re-reading it. trimr equivalence lives in test-equivalence.R.

# --- cutoff -----------------------------------------------------------------

test_that("rule_cutoff() keeps the closed interval and names both reasons", {
  rt <- c(0.10, 0.18, 0.25, 3.00, 3.01)
  out <- rt_screen(rt, rule = rule_cutoff(0.18, 3))

  expect_equal(out$.keep, c(FALSE, TRUE, TRUE, TRUE, FALSE))
  expect_equal(out$.prob, c(0, 1, 1, 1, 0))
  expect_equal(out$.reason, c("too_fast", NA, NA, NA, "too_slow"))
})

test_that("rule_cutoff() with only a lower bound never flags slow trials", {
  out <- suppressWarnings(rt_screen(c(0.1, 0.5, 20), rule = rule_cutoff(0.18)))
  expect_equal(out$.keep, c(FALSE, TRUE, TRUE))
  expect_equal(out$.reason, c("too_fast", NA, NA))
})

test_that("rule_cutoff() reports its bounds in the fits table", {
  fits <- attr(rt_screen(c(0.3, 0.4), rule = rule_cutoff(0.18, 3)), "fits")
  expect_equal(fits$lower, 0.18)
  expect_equal(fits$upper, 3)
})

# --- sd / mad ---------------------------------------------------------------

test_that("rule_sd() trims at mean +/- n_sd * sd", {
  rt <- c(0.2, 0.4, 0.6, 0.8, 3.0)
  out <- rt_screen(rt, rule = rule_sd(1))

  expect_equal(out$.keep, c(TRUE, TRUE, TRUE, TRUE, FALSE))
  expect_equal(out$.reason, c(NA, NA, NA, NA, "too_slow"))

  fits <- attr(out, "fits")
  expect_equal(fits$lower, mean(rt) - sd(rt))
  expect_equal(fits$upper, mean(rt) + sd(rt))
})

test_that("rule_sd(median, mad) trims at median +/- n_sd * mad", {
  rt <- c(0.2, 0.4, 0.6, 0.8, 3.0)
  out <- rt_screen(rt, rule = rule_mad(2))

  expect_equal(out$.keep, c(TRUE, TRUE, TRUE, TRUE, FALSE))
  fits <- attr(out, "fits")
  expect_equal(fits$lower, median(rt) - 2 * mad(rt))
  expect_equal(fits$upper, median(rt) + 2 * mad(rt))
})

test_that("rule_sd() flags fast trials as well as slow ones", {
  rt <- c(0.05, 0.40, 0.42, 0.44, 0.46)
  out <- rt_screen(rt, rule = rule_sd(1))
  expect_equal(out$.reason[1], "too_fast")
})

test_that("rule_sd() removes nothing when the spread cannot be used", {
  # a single trial: sd is undefined
  expect_true(rt_screen(0.4, rule = rule_sd(2))$.keep)
  # zero spread: every trial sits exactly at the centre
  out <- rt_screen(rep(0.4, 5), rule = rule_sd(2))
  expect_true(all(out$.keep))
  expect_true(all(out$.prob == 1))
})

# --- recursive: moving criterion --------------------------------------------

vsj_fixture <- c(0.30, 0.32, 0.34, 0.36, 0.38, 0.40, 0.42, 0.44, 0.46, 4.00)

test_that("rule_recursive('moving') uses the published criterion for n = 10", {
  out <- rt_screen(vsj_fixture, rule = rule_recursive("moving"))
  k <- 2.17 # van Selst & Jolicoeur (1994), moving criterion at n = 10

  expect_equal(out$.keep, c(rep(TRUE, 9), FALSE))
  fits <- attr(out, "fits")
  expect_equal(fits$criterion, k)
  expect_equal(fits$lower, mean(vsj_fixture) - k * sd(vsj_fixture))
  expect_equal(fits$upper, mean(vsj_fixture) + k * sd(vsj_fixture))
  expect_equal(fits$iterations, 1L)
})

test_that("include_max = FALSE leaves the largest RT out of the criterion", {
  rule <- rule_recursive("moving", include_max = FALSE)
  out <- rt_screen(vsj_fixture, rule = rule)
  base <- vsj_fixture[-which.max(vsj_fixture)]
  k <- 2.17

  fits <- attr(out, "fits")
  expect_equal(fits$upper, mean(base) + k * sd(base))
  expect_true(fits$upper < mean(vsj_fixture) + k * sd(vsj_fixture))
})

test_that("the moving criterion is capped at the n = 100 value", {
  rt <- c(seq(0.30, 0.60, length.out = 149), 9.0)
  fits <- attr(rt_screen(rt, rule = rule_recursive("moving")), "fits")
  expect_equal(fits$criterion, 2.50) # published value at n = 100
})

test_that("no criterion exists below n = 4, so nothing is removed", {
  for (n in 1:3) {
    rt <- c(seq(0.3, 0.4, length.out = n - 1), 5)[seq_len(n)]
    out <- rt_screen(rt, rule = rule_recursive("moving"))
    expect_true(all(out$.keep))
    expect_true(all(is.na(attr(out, "fits")$criterion)))
  }
})

# --- recursive: modified recursive ------------------------------------------

test_that("rule_recursive('modified') removes the outlier and then stops", {
  out <- rt_screen(vsj_fixture, rule = rule_recursive("modified"))

  expect_equal(out$.keep, c(rep(TRUE, 9), FALSE))
  expect_equal(out$.reason[10], "too_slow")
  expect_equal(attr(out, "fits")$iterations, 1L)
})

test_that("the modified criterion always excludes the current maximum", {
  # with the maximum left in, its own contribution to the sd is enough to keep
  # it inside the bound -- setting it aside is what makes the rule bite
  expect_gt(mean(vsj_fixture) + 4.11 * sd(vsj_fixture), max(vsj_fixture))

  out <- rt_screen(vsj_fixture, rule = rule_recursive("modified"))
  fits <- attr(out, "fits")

  # the reported bounds are those of the final, stable iteration: the 4.00 has
  # already gone, so the criterion is the one for the nine survivors and the
  # largest of those is what gets set aside
  survivors <- vsj_fixture[out$.keep]
  base <- survivors[-which.max(survivors)]
  expect_equal(fits$criterion, 4.25) # published value at n = 9
  expect_equal(fits$upper, mean(base) + 4.25 * sd(base))
})

test_that("the modified rule peels one trial at a time until it stops", {
  # three slow contaminants on top of a tight core: the rule should shave them
  # off one per iteration and then leave the core alone
  rt <- c(seq(0.30, 0.50, length.out = 30), 2.0, 2.5, 3.0)
  out <- rt_screen(rt, rule = rule_recursive("modified"))

  expect_true(all(out$.keep[1:30]))
  expect_false(any(out$.keep[31:33]))
  expect_equal(attr(out, "fits")$iterations, 3L)
})

test_that("the modified rule always terminates and never empties the sample", {
  # the n < 5 guard means at most two trials can go once five remain
  set.seed(11)
  for (n in 5:12) {
    rt <- c(stats::rgamma(n - 2, shape = 4, rate = 12) + 0.15, 5, 9)
    out <- rt_screen(rt, rule = rule_recursive("modified"))
    expect_gte(sum(out$.keep), 3L)
    expect_equal(out$.prob, as.numeric(out$.keep))
  }
})

# --- recursive: hybrid ------------------------------------------------------

test_that("hybrid probabilities are the mean of the two component rules", {
  rt <- c(0.30, 0.32, 0.34, 0.36, 0.38, 0.40, 0.42, 0.44, 0.60, 4.00)
  moving <- rt_screen(rt, rule = rule_recursive("moving"))$.prob
  modified <- rt_screen(rt, rule = rule_recursive("modified"))$.prob
  hybrid <- rt_screen(rt, rule = rule_recursive("hybrid"))

  expect_equal(hybrid$.prob, (moving + modified) / 2)
  expect_true(all(hybrid$.prob %in% c(0, 0.5, 1)))
  expect_equal(hybrid$.keep, hybrid$.prob > 0.5)
  expect_equal(attr(hybrid, "fits")$n_disagree, sum(moving != modified))
})

test_that("hybrid keeps a trial only when both component rules keep it", {
  out <- rt_screen(vsj_fixture, rule = rule_recursive("hybrid"))
  expect_equal(out$.keep, c(rep(TRUE, 9), FALSE))
})

test_that("the recursive rules remove nothing when the spread is zero", {
  # lower == upper would flag every trial not exactly at the centre; a criterion
  # that cannot discriminate must not remove data
  flat <- c(rep(0.3, 9), 0.9)
  no_max <- rule_recursive("moving", include_max = FALSE)
  moving <- rt_screen(flat, rule = no_max)
  expect_true(all(moving$.keep))
  expect_true(is.na(attr(moving, "fits")$criterion))

  near_flat <- c(rep(0.300, 20), 0.3000001)
  modified <- rt_screen(near_flat, rule = rule_recursive("modified"))
  expect_true(all(modified$.keep))

  for (type in c("moving", "modified", "hybrid")) {
    flat_rt <- rep(0.4, 8)
    expect_true(all(rt_screen(flat_rt, rule = rule_recursive(type))$.keep))
  }
})

# --- ewma -------------------------------------------------------------------

ewma_fixture <- function(n_fast = 40, n_slow = 60) {
  data.frame(
    rt = c(
      seq(0.10, 0.19, length.out = n_fast),
      seq(0.50, 0.80, length.out = n_slow)
    ),
    # fast trials are guesses (exactly chance); slow trials are all correct
    correct = c(rep(c(1, 0), length.out = n_fast), rep(1, n_slow))
  )
}

test_that("rule_ewma() cuts where accuracy departs from chance", {
  d <- ewma_fixture()
  out <- rt_screen(
    d$rt,
    response = d$correct, rule = rule_ewma(lambda = 0.05, L = 1.5)
  )

  expect_false(any(out$.keep[1:40]))
  expect_true(all(out$.reason[1:40] == "too_fast"))
  expect_gt(sum(out$.keep), 40)

  cutoff <- attr(out, "fits")$cutoff_rt
  expect_false(is.na(cutoff))
  expect_gt(cutoff, 0.19)
  expect_equal(out$.keep, d$rt >= cutoff)
})

test_that("rule_ewma() overshoots the elbow, and by less as lambda grows", {
  # the average needs several above-chance trials to clear the limit, so the
  # cutoff lands past the point where accuracy actually rose. This is inherent
  # to the control chart, is documented in ?rule_ewma, and is the specificity
  # cost Study 1 measures -- pin it down rather than let it drift.
  d <- ewma_fixture()
  flagged <- vapply(c(0.01, 0.05, 0.10, 0.20), function(lam) {
    sum(!rt_screen(
      d$rt,
      response = d$correct, rule = rule_ewma(lambda = lam)
    )$.keep)
  }, integer(1))

  expect_true(all(flagged >= 40), info = "every true guess must be caught")
  expect_true(all(flagged <= 50), info = "overshoot must stay bounded")
  expect_false(is.unsorted(rev(flagged)), info = "larger lambda lags less")
})

test_that("rule_ewma() flags nothing when accuracy never leaves chance", {
  rt <- seq(0.10, 1.00, length.out = 100)
  correct <- rep(c(1, 0), 50)
  out <- rt_screen(
    rt,
    response = correct, rule = rule_ewma(lambda = 0.05, L = 1.5)
  )

  expect_true(all(out$.keep))
  expect_true(is.na(attr(out, "fits")$cutoff_rt))
  expect_equal(attr(out, "fits")$n_flagged, 0L)
})

test_that("rule_ewma() accepts the response codings the package documents", {
  d <- ewma_fixture()
  numeric_out <- rt_screen(
    d$rt,
    response = d$correct, rule = rule_ewma(lambda = 0.05)
  )
  chr <- ifelse(d$correct == 1, "correct", "error")
  chr_out <- rt_screen(d$rt, response = chr, rule = rule_ewma(lambda = 0.05))
  expect_equal(chr_out$.keep, numeric_out$.keep)
})

test_that("rule_ewma() rejects response codings it cannot interpret", {
  d <- ewma_fixture(4, 6)
  expect_error(
    rt_screen(d$rt, rule_ewma(), response = rep("maybe", 10)),
    "Unrecognized response"
  )
})

# --- adaptive leading-edge trim ---------------------------------------------
#
# The S statistic detects a gap-and-jump: an isolated low block with a gap to
# the core sends the surviving minimum most of the way to the reference
# quantile (S near 1), a tightly packed genuine front barely moves it (S near
# 0). Expected values are written out with the same formulas the rule uses, so
# the tests pin the contract rather than arithmetic.

# two displaced fast trials, a clear gap, then a tight core: S ~ .99
at_displaced <- c(0.150, 0.160, seq(0.400, 0.610, length.out = 22))
# a genuinely steep front: the three fastest trials bunch together: S ~ .06
at_steep <- c(0.400, 0.401, 0.402, seq(0.50, 0.90, length.out = 21))

at_expected_s <- function(rt, q_cut = 0.05) {
  thr <- unname(quantile(rt, q_cut))
  (min(rt[rt > thr]) - min(rt)) /
    (unname(quantile(rt, 2 * q_cut)) - min(rt))
}

test_that("rule_adaptive_trim() accepts a cut of displaced mass", {
  rt <- at_displaced
  out <- rt_screen(rt, rule = rule_adaptive_trim(0.05, 0.5))
  thr <- unname(quantile(rt, 0.05))

  expect_equal(out$.keep, rt > thr)
  expect_equal(out$.reason[!out$.keep], rep("too_fast", 2))
  expect_true(all(is.na(out$.reason[out$.keep])))

  fits <- attr(out, "fits")
  expect_equal(fits$S, at_expected_s(rt))
  expect_gt(fits$S, 0.95)
  expect_true(fits$accepted)
  expect_equal(fits$cut_rt, thr)
  expect_equal(fits$ref_q, 0.10)
  expect_equal(fits$n_tentative, 2L)
  expect_equal(fits$n_flagged, 2L)
})

test_that("rule_adaptive_trim() reverts on a steep genuine edge", {
  out <- rt_screen(at_steep, rule = rule_adaptive_trim(0.05, 0.5))

  expect_true(all(out$.keep))
  expect_true(all(out$.prob == 1))

  fits <- attr(out, "fits")
  expect_equal(fits$S, at_expected_s(at_steep))
  expect_lt(fits$S, 0.1)
  expect_false(fits$accepted)
  expect_equal(fits$n_tentative, 2L)
  expect_equal(fits$n_flagged, 0L)
})

test_that("the acceptance decision flips around the realized S", {
  s <- at_expected_s(at_displaced)
  accept <- rt_screen(at_displaced, rule = rule_adaptive_trim(0.05, s - 0.01))
  revert <- rt_screen(at_displaced, rule = rule_adaptive_trim(0.05, s + 0.01))
  expect_equal(sum(!accept$.keep), 2L)
  expect_true(all(revert$.keep))
})

test_that("ties at the quantile threshold are all cut", {
  # n = 21 puts the type-7 q05 exactly on the second order statistic, so the
  # threshold lands on the repeated value and rt <= thr cuts both copies
  rt <- c(0.2, 0.2, seq(0.4, 0.6, length.out = 19))
  expect_equal(unname(quantile(rt, 0.05)), 0.2)
  out <- rt_screen(rt, rule = rule_adaptive_trim(0.05, 0.5))
  expect_equal(sum(!out$.keep), 2L)
  expect_equal(attr(out, "fits")$n_tentative, 2L)
})

test_that("rule_adaptive_trim() removes nothing when S has no footing", {
  # ties from the minimum through the reference quantile: denom = 0
  rt <- c(rep(0.3, 3), seq(0.4, 0.6, length.out = 17))
  expect_equal(unname(quantile(rt, 0.10)), min(rt))
  out <- rt_screen(rt, rule = rule_adaptive_trim(0.05, 0.5))
  expect_true(all(out$.keep))
  expect_true(is.na(attr(out, "fits")$S))
  expect_true(is.na(attr(out, "fits")$accepted))

  # all-equal response times
  flat <- rt_screen(rep(0.4, 24), rule = rule_adaptive_trim(0.05, 0.5))
  expect_true(all(flat$.keep))
  expect_true(is.na(attr(flat, "fits")$S))
})

test_that("the n >= 20 floor separates keep-all from an evaluated rule", {
  core <- function(n) c(0.150, 0.160, seq(0.400, 0.610, length.out = n - 2))
  under <- rt_screen(core(19), rule = rule_adaptive_trim(0.05, 0.5))
  at <- rt_screen(core(20), rule = rule_adaptive_trim(0.05, 0.5))

  expect_true(all(under$.keep))
  expect_true(is.na(attr(under, "fits")$accepted))
  # at n = 20 the rule runs: the decision is recorded, whatever it is
  expect_false(is.na(attr(at, "fits")$accepted))
})

test_that("adaptive trim decides per group under .by", {
  rt <- c(at_displaced, at_steep)
  subject <- rep(c(1, 2), times = c(length(at_displaced), length(at_steep)))
  out <- rt_screen(rt, rule = rule_adaptive_trim(0.05, 0.5), .by = subject)

  fits <- attr(out, "fits")
  expect_equal(nrow(fits), 2L)
  expect_equal(fits$accepted, c(TRUE, FALSE))
  expect_equal(sum(!out$.keep[subject == 1]), 2L)
  expect_true(all(out$.keep[subject == 2]))
})
