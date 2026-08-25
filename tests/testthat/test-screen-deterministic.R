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
  out <- rt_screen(d$rt, d$correct, rule = rule_ewma(lambda = 0.05, L = 1.5))

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
    sum(!rt_screen(d$rt, d$correct, rule = rule_ewma(lambda = lam))$.keep)
  }, integer(1))

  expect_true(all(flagged >= 40), info = "every true guess must be caught")
  expect_true(all(flagged <= 50), info = "overshoot must stay bounded")
  expect_false(is.unsorted(rev(flagged)), info = "larger lambda lags less")
})

test_that("rule_ewma() flags nothing when accuracy never leaves chance", {
  rt <- seq(0.10, 1.00, length.out = 100)
  correct <- rep(c(1, 0), 50)
  out <- rt_screen(rt, correct, rule = rule_ewma(lambda = 0.05, L = 1.5))

  expect_true(all(out$.keep))
  expect_true(is.na(attr(out, "fits")$cutoff_rt))
  expect_equal(attr(out, "fits")$n_flagged, 0L)
})

test_that("rule_ewma() accepts the response codings the package documents", {
  d <- ewma_fixture()
  numeric_out <- rt_screen(d$rt, d$correct, rule = rule_ewma(lambda = 0.05))
  chr <- ifelse(d$correct == 1, "correct", "error")
  chr_out <- rt_screen(d$rt, chr, rule = rule_ewma(lambda = 0.05))
  expect_equal(chr_out$.keep, numeric_out$.keep)
})

test_that("rule_ewma() rejects response codings it cannot interpret", {
  d <- ewma_fixture(4, 6)
  expect_error(
    rt_screen(d$rt, rep("maybe", 10), rule = rule_ewma()),
    "Unrecognized response"
  )
})
