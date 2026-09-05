# check_guessing(): the Beta-Binomial test that what a rule removed really was
# guessing. Tests are Monte Carlo where they draw data, so each fixes its seed
# (test code is not package code; the no-set.seed rule binds R/).

guessing_fixture <- function(fast_accuracy = 0.5, n_fast = 40, n_slow = 160,
                             seed = 101) {
  set.seed(seed)
  rt <- c(runif(n_fast, 0.12, 0.24), stats::rgamma(n_slow, 5, 10) + 0.35)
  response <- c(
    rbinom(n_fast, 1, fast_accuracy), rbinom(n_slow, 1, 0.88)
  )
  # a rule that removes exactly the fast block
  keep <- rt >= 0.30
  list(keep = keep, rt = rt, response = response, n_fast = n_fast)
}

test_that("check_guessing() returns one documented row", {
  d <- guessing_fixture()
  out <- check_guessing(d$keep, d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5
  )

  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
  expect_equal(names(out), c(
    "prop_upper", "hdi_lower", "hdi_upper", "bf_01", "guess_in_hdi",
    "bf_evidence", "posterior_alpha", "posterior_beta", "n_tested",
    "rt_threshold", "threshold_type", "credible_mass", "mean_rt_tested"
  ))
  expect_type(out$n_tested, "integer")
  expect_type(out$guess_in_hdi, "logical")
})

test_that("chance accuracy in the excluded fast trials supports guessing", {
  d <- guessing_fixture(fast_accuracy = 0.5)
  out <- check_guessing(d$keep, d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5
  )

  expect_equal(out$n_tested, d$n_fast)
  expect_gt(out$bf_01, 1)
  expect_true(out$guess_in_hdi)
  expect_match(out$bf_evidence, "for_guessing")
})

test_that("high accuracy in the excluded fast trials argues against guessing", {
  # if the rule removed fast trials that were nearly all correct, they were not
  # guesses and the diagnostic has to say so
  d <- guessing_fixture(fast_accuracy = 0.98)
  out <- check_guessing(d$keep, d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5
  )

  expect_lt(out$bf_01, 1 / 3)
  expect_false(out$guess_in_hdi)
  expect_match(out$bf_evidence, "against_guessing")
})

test_that("the HDI brackets the observed proportion", {
  for (acc in c(0.3, 0.5, 0.8)) {
    d <- guessing_fixture(fast_accuracy = acc, seed = 103)
    out <- check_guessing(d$keep, d$rt, d$response,
      threshold_type = "absolute", rt_threshold = 0.5
    )
    expect_lte(out$hdi_lower, out$prop_upper)
    expect_gte(out$hdi_upper, out$prop_upper)
    expect_lt(out$hdi_upper - out$hdi_lower, 1)
  }
})

test_that("both threshold types select the trials they claim", {
  d <- guessing_fixture()

  absolute <- check_guessing(d$keep, d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5
  )
  expect_equal(absolute$rt_threshold, 0.5)
  expect_equal(absolute$n_tested, sum(!d$keep & d$rt < 0.5))

  quantile <- check_guessing(d$keep, d$rt, d$response,
    threshold_type = "quantile", rt_threshold = 0.25
  )
  cut <- as.numeric(stats::quantile(d$rt, 0.25))
  expect_equal(quantile$rt_threshold, cut)
  expect_equal(quantile$n_tested, sum(!d$keep & d$rt < cut))
})

test_that("only trials that were both excluded and fast are tested", {
  # a slow exclusion is an attention lapse, not a guess: including it would
  # test a claim nobody made
  d <- guessing_fixture()
  keep <- d$keep
  keep[d$rt > 1.0] <- FALSE # also exclude the slowest trials

  out <- check_guessing(keep, d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5
  )
  expect_equal(out$n_tested, sum(!keep & d$rt < 0.5))
  expect_lt(out$mean_rt_tested, 0.5)
})

test_that("no fast exclusions gives an empty row rather than an error", {
  d <- guessing_fixture()
  out <- check_guessing(rep(TRUE, length(d$rt)), d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5
  )

  expect_equal(out$n_tested, 0L)
  expect_true(is.na(out$bf_01))
  expect_true(is.na(out$prop_upper))
  expect_true(is.na(out$guess_in_hdi))
  # the threshold is still reported, so a results table stays self-describing
  expect_equal(out$rt_threshold, 0.5)
})

test_that("a chance rate other than one half moves the answer", {
  # a four-alternative task guesses correctly a quarter of the time, so fast
  # trials at 25% accuracy are evidence FOR guessing there and against it at 0.5
  set.seed(107)
  rt <- c(runif(60, 0.12, 0.24), stats::rgamma(140, 5, 10) + 0.35)
  response <- c(rbinom(60, 1, 0.25), rbinom(140, 1, 0.88))
  keep <- rt >= 0.30

  at_quarter <- check_guessing(keep, rt, response,
    threshold_type = "absolute", rt_threshold = 0.5, chance = 0.25
  )
  at_half <- check_guessing(keep, rt, response,
    threshold_type = "absolute", rt_threshold = 0.5
  )

  expect_gt(at_quarter$bf_01, 1)
  expect_true(at_quarter$guess_in_hdi)
  expect_lt(at_half$bf_01, at_quarter$bf_01)
  expect_false(at_half$guess_in_hdi)
})

test_that("a sharper prior narrows the interval", {
  d <- guessing_fixture()
  flat <- check_guessing(d$keep, d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5
  )
  sharp <- check_guessing(d$keep, d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5,
    prior_alpha = 50, prior_beta = 50
  )
  expect_lt(
    sharp$hdi_upper - sharp$hdi_lower, flat$hdi_upper - flat$hdi_lower
  )
})

test_that("credible_mass widens the interval as asked", {
  d <- guessing_fixture()
  narrow <- check_guessing(d$keep, d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5, credible_mass = 0.5
  )
  wide <- check_guessing(d$keep, d$rt, d$response,
    threshold_type = "absolute", rt_threshold = 0.5, credible_mass = 0.99
  )
  expect_lt(
    narrow$hdi_upper - narrow$hdi_lower, wide$hdi_upper - wide$hdi_lower
  )
})

test_that("the Jeffreys categories are cut where they claim", {
  expect_equal(rtprep:::.categorise_bf(11), "strong_for_guessing")
  expect_equal(rtprep:::.categorise_bf(5), "moderate_for_guessing")
  expect_equal(rtprep:::.categorise_bf(2), "anecdotal_for_guessing")
  expect_equal(rtprep:::.categorise_bf(0.5), "anecdotal_against_guessing")
  expect_equal(rtprep:::.categorise_bf(0.2), "moderate_against_guessing")
  expect_equal(rtprep:::.categorise_bf(0.05), "strong_against_guessing")
})

test_that("check_guessing() rejects malformed input", {
  d <- guessing_fixture()
  expect_error(check_guessing(d$rt, d$rt, d$response), "logical vector")
  expect_error(check_guessing(logical(0), numeric(0), numeric(0)), "non-empty")
  expect_error(
    check_guessing(d$keep, d$rt[-1], d$response), "same length as"
  )
  expect_error(
    check_guessing(d$keep, d$rt, d$response, rt_threshold = 1.5),
    "must be a single"
  )
  expect_error(
    check_guessing(d$keep, d$rt, d$response,
      threshold_type = "absolute", rt_threshold = 0
    ),
    "must be a single"
  )
  expect_error(
    check_guessing(d$keep, d$rt, d$response, chance = 0), "must be a single"
  )
  expect_error(
    check_guessing(d$keep, d$rt, d$response, prior_alpha = 0),
    "must be a single"
  )
})

test_that("a screening rule's output drops straight in", {
  # the argument is `keep`, not a contaminant flag, so no negation is needed
  set.seed(109)
  rt <- c(runif(30, 0.10, 0.20), stats::rgamma(170, 5, 10) + 0.35)
  response <- c(rbinom(30, 1, 0.5), rbinom(170, 1, 0.9))

  scr <- rt_screen(rt, rule = rule_cutoff(0.30, 3))
  out <- check_guessing(scr$.keep, rt, response,
    threshold_type = "absolute", rt_threshold = 0.5
  )

  expect_equal(out$n_tested, sum(!scr$.keep & rt < 0.5))
  expect_gt(out$bf_01, 1)
})

test_that("check_guessing() matches bmm::validate_fast_guesses()", {
  # reaches into bmm internals: a bmm release must surface in CI, not on CRAN
  skip_on_cran()
  skip_if_not_installed("bmm")
  d <- guessing_fixture()

  for (type in c("quantile", "absolute")) {
    threshold <- if (type == "quantile") 0.25 else 0.5
    ours <- check_guessing(d$keep, d$rt, d$response,
      threshold_type = type, rt_threshold = threshold
    )
    theirs <- bmm::validate_fast_guesses(
      contam_flag = !d$keep, rt_data = d$rt, response = d$response,
      threshold_type = type, rt_threshold = threshold
    )

    expect_equal(ours$n_tested, theirs$n_tested, info = type)
    expect_equal(ours$prop_upper, theirs$prop_upper, info = type)
    expect_equal(ours$hdi_lower, theirs$hdi_lower, info = type)
    expect_equal(ours$hdi_upper, theirs$hdi_upper, info = type)
    expect_equal(ours$bf_01, theirs$bf_01, info = type)
    expect_equal(ours$guess_in_hdi, theirs$guess_in_hdi, info = type)
    expect_equal(ours$bf_evidence, theirs$bf_evidence, info = type)
    expect_equal(ours$rt_threshold, theirs$rt_threshold, info = type)
    expect_equal(ours$mean_rt_tested, theirs$mean_rt_tested, info = type)
  }
})

test_that(".categorise_bf() names every band of the Jeffreys scale", {
  bands <- c(
    "strong_for_guessing", "moderate_for_guessing", "anecdotal_for_guessing",
    "anecdotal_against_guessing", "moderate_against_guessing",
    "strong_against_guessing"
  )
  bf <- c(30, 5, 2, 0.5, 0.2, 0.05)
  expect_equal(vapply(bf, rtprep:::.categorise_bf, character(1)), bands)
  # the band edges belong to the weaker claim
  expect_equal(rtprep:::.categorise_bf(10), "moderate_for_guessing")
  expect_equal(rtprep:::.categorise_bf(3), "anecdotal_for_guessing")
  expect_equal(rtprep:::.categorise_bf(1), "anecdotal_against_guessing")
  expect_equal(rtprep:::.categorise_bf(1 / 3), "moderate_against_guessing")
  expect_equal(rtprep:::.categorise_bf(1 / 10), "strong_against_guessing")
})
