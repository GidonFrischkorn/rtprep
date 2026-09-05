# The EZ support screen: closed-form EZ per group, flag response times below
# the fitted non-decision time, one refit, stop. Kept out of
# test-screen-deterministic.R because this rule fits a model.
#
# The main fixture is a gamma core with high accuracy plus a block of fast
# chance-accuracy guesses. On it, the pass-1 fit lands between the guesses and
# the core, and the refit ratchets upward into the core's edge — both
# directions the spec pins behaviorally on this fixture, not as theorems.

ez_fixture <- function() {
  set.seed(42)
  core_rt <- rgamma(80, shape = 5, rate = 10) + 0.35
  core_ok <- rbinom(80, 1, 0.9)
  guess_rt <- runif(20, 0.12, 0.25)
  guess_ok <- rbinom(20, 1, 0.5)
  list(
    rt = c(guess_rt, core_rt),
    ok = c(guess_ok, core_ok),
    guess_idx = 1:20
  )
}

test_that("the final-threshold contract holds and the fast block is flagged", {
  d <- ez_fixture()
  out <- rt_screen(
    d$rt,
    response = d$ok, rule = rule_ez_support(1, refit = TRUE)
  )
  fits <- attr(out, "fits")

  # the one assertion that pins boundary strictness, the two-pass result, and
  # the keep policy together
  expect_equal(out$.keep, d$rt >= 1 * fits$ndt_final)

  expect_false(any(out$.keep[d$guess_idx]))
  expect_true(all(out$.reason[d$guess_idx] == "too_fast"))
  expect_gte(sum(out$.keep), 75L)

  expect_true(fits$usable)
  expect_equal(fits$n_flagged, sum(!out$.keep))
  expect_equal(fits$n_flagged_init, 20L)
  expect_equal(fits$threshold_rt, 1 * fits$ndt_final)
})

test_that("the refit ratchets upward on this fixture and pass-1 flags stay", {
  d <- ez_fixture()
  out <- rt_screen(
    d$rt,
    response = d$ok, rule = rule_ez_support(1, refit = TRUE)
  )
  fits <- attr(out, "fits")

  expect_gte(fits$ndt_final, fits$ndt_init)
  # everything below the pass-1 threshold is still flagged at the end
  expect_true(all(!out$.keep[d$rt < fits$ndt_init]))
})

test_that("the rule stops after exactly one refit", {
  d <- ez_fixture()
  out <- rt_screen(
    d$rt,
    response = d$ok, rule = rule_ez_support(1, refit = TRUE)
  )
  fits <- attr(out, "fits")

  # a third pass would move the threshold again; the rule must not take it
  s <- out$.keep
  e3 <- ez_ddm(mean(d$rt[s]), var(d$rt[s]), mean(d$ok[s]), sum(s))
  expect_false(isTRUE(all.equal(e3$ndt, fits$ndt_final)))
  expect_equal(out$.keep, d$rt >= fits$ndt_final)
})

test_that("refit = FALSE is a single pass", {
  d <- ez_fixture()
  out <- rt_screen(
    d$rt,
    response = d$ok, rule = rule_ez_support(1, refit = FALSE)
  )
  fits <- attr(out, "fits")

  expect_equal(fits$ndt_final, fits$ndt_init)
  expect_equal(out$.keep, d$rt >= fits$ndt_init)
  expect_equal(sum(!out$.keep), 20L)
})

test_that("c_ndt scales the support threshold", {
  d <- ez_fixture()
  out <- rt_screen(
    d$rt,
    response = d$ok, rule = rule_ez_support(0.8, refit = TRUE)
  )
  fits <- attr(out, "fits")
  expect_equal(out$.keep, d$rt >= 0.8 * fits$ndt_final)
  expect_equal(fits$threshold_rt, 0.8 * fits$ndt_final)
})

test_that("fewer than ten trials removes nothing", {
  rt <- seq(0.3, 0.7, length.out = 9)
  out <- rt_screen(rt, rep(1, 9), rule = rule_ez_support())
  expect_true(all(out$.keep))
  fits <- attr(out, "fits")
  expect_false(fits$usable)
  expect_true(is.na(fits$ndt_init))
})

test_that("zero variance removes nothing", {
  out <- rt_screen(rep(0.4, 12), rep(c(1, 0), 6), rule = rule_ez_support())
  expect_true(all(out$.keep))
  expect_false(attr(out, "fits")$usable)
})

test_that("a negative fitted ndt removes nothing", {
  # a fast-heavy bimodal with a huge-variance tail drives the EZ ndt below
  # zero; the fixture verifies itself before asserting the rule's behavior
  rt <- c(rep(0.05, 45), rep(0.10, 40), rep(2.5, 8), rep(3.5, 7))
  ok <- rep(c(1, 1, 1, 0), 25)
  expect_lt(ez_ddm(mean(rt), var(rt), mean(ok), length(rt))$ndt, 0)

  out <- rt_screen(rt, response = ok, rule = rule_ez_support())
  expect_true(all(out$.keep))
  fits <- attr(out, "fits")
  expect_false(fits$usable)
  expect_lt(fits$ndt_init, 0)
})

test_that("the over-trim guard reverts to keep-all", {
  # unreachable through ez_ddm() itself at c_ndt <= 1: the pass-1 threshold
  # mean - MDT sits below the median for any attainable fit, because
  # |mean - median| <= sd while the EZ decision-time mean exceeds ~1.26 sd at
  # every accuracy. The guard is defensive, so the branch is exercised by
  # forcing an absurd fit.
  local_mocked_bindings(
    ez_ddm = function(mean_rt, var_rt, accuracy, n_trials, s = 1) {
      data.frame(drift = 2, bound = 1, ndt = 10)
    }
  )
  rt <- seq(0.3, 0.9, length.out = 30)
  out <- rt_screen(rt, rep(1, 30), rule = rule_ez_support(1, refit = TRUE))
  expect_true(all(out$.keep))
  fits <- attr(out, "fits")
  expect_false(fits$usable)
  expect_equal(fits$n_flagged, 0L)
})

test_that("rule_ez_support() requires response", {
  expect_error(
    rt_screen(seq(0.3, 0.9, length.out = 20), rule = rule_ez_support()),
    "requires 'response'"
  )
})

test_that("the EZ support screen fits per group under .by", {
  d <- ez_fixture()
  set.seed(7)
  slow_rt <- rgamma(40, shape = 5, rate = 10) + 0.60
  slow_ok <- rbinom(40, 1, 0.9)
  rt <- c(d$rt, slow_rt)
  ok <- c(d$ok, slow_ok)
  subject <- rep(c(1, 2), times = c(length(d$rt), length(slow_rt)))

  out <- rt_screen(rt, response = ok, rule = rule_ez_support(), .by = subject)
  fits <- attr(out, "fits")
  expect_equal(nrow(fits), 2L)
  expect_false(isTRUE(all.equal(fits$ndt_final[1], fits$ndt_final[2])))
})
