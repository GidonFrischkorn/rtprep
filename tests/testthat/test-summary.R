# Aggregation. Screening decides which trials survive; aggregation decides what
# the survivors are summarised as. The paper's argument depends on those failing
# differently, so they are tested apart.

summary_data <- function(n_core = 300, n_contam = 30, seed = 51) {
  set.seed(seed)
  data.frame(
    rt = c(
      rtprep:::.rexgauss(n_core, mu = 0.45, sigma = 0.05, tau = 0.15),
      runif(n_contam, 0.10, 0.20)
    ),
    correct = c(
      rbinom(n_core, 1, 0.85), rbinom(n_contam, 1, 0.5)
    ),
    contaminant = rep(c(FALSE, TRUE), c(n_core, n_contam))
  )
}

# --- shape ------------------------------------------------------------------

test_that("rt_summary() returns one row with the documented 3par columns", {
  d <- summary_data()
  out <- rt_summary(d$rt, d$correct)

  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
  expect_equal(
    names(out),
    c("mean_rt", "var_rt", "n_upper", "n_trials", "contaminant_prop")
  )
  expect_type(out$mean_rt, "double")
  expect_type(out$n_upper, "integer")
  expect_type(out$n_trials, "integer")
  expect_equal(out$n_trials, nrow(d))
  expect_equal(out$n_upper, sum(d$correct))
})

test_that("rt_summary() returns the documented 4par columns", {
  d <- summary_data()
  out <- rt_summary(d$rt, d$correct, version = "4par")

  expect_equal(nrow(out), 1L)
  expect_equal(names(out), c(
    "mean_rt_upper", "mean_rt_lower", "var_rt_upper", "var_rt_lower",
    "n_upper", "n_trials", "contaminant_prop_upper", "contaminant_prop_lower"
  ))
  expect_equal(out$mean_rt_upper, mean(d$rt[d$correct == 1]))
  expect_equal(out$mean_rt_lower, mean(d$rt[d$correct == 0]))
})

test_that("rt_summary() works without a response, except for 4par", {
  d <- summary_data()
  out <- rt_summary(d$rt)

  expect_true(is.na(out$n_upper))
  expect_equal(out$mean_rt, mean(d$rt))
  expect_error(rt_summary(d$rt, version = "4par"), "requires 'response'")
})

# --- methods ----------------------------------------------------------------

test_that("method = 'simple' is the sample mean and variance", {
  d <- summary_data()
  out <- rt_summary(d$rt, d$correct, method = "simple")

  expect_equal(out$mean_rt, mean(d$rt))
  expect_equal(out$var_rt, var(d$rt))
  expect_true(is.na(out$contaminant_prop))
})

test_that("method = 'robust' is the median and a scaled spread", {
  d <- summary_data()

  iqr <- rt_summary(d$rt, d$correct, method = "robust")
  expect_equal(iqr$mean_rt, median(d$rt))
  expect_equal(iqr$var_rt, (IQR(d$rt) / 1.349)^2)

  m <- rt_summary(d$rt, d$correct, method = "robust", robust_scale = "mad")
  expect_equal(m$mean_rt, median(d$rt))
  expect_equal(m$var_rt, mad(d$rt)^2)
  expect_true(is.na(m$contaminant_prop))
})

test_that("method = 'mixture' reports the fitted core, not the sample", {
  d <- summary_data()
  out <- rt_summary(
    d$rt, d$correct,
    method = "mixture", distribution = "lognormal"
  )

  expect_false(is.na(out$contaminant_prop))
  expect_gt(out$contaminant_prop, 0)
  # the contaminants drag the sample mean down; the core should not follow
  expect_gt(out$mean_rt, mean(d$rt))
  expect_lt(abs(out$mean_rt - mean(d$rt[!d$contaminant])), 0.1)
})

test_that("the mixture moments are far less contamination-sensitive", {
  # Conditional on the fitted parameters, a trial the uniform component owns
  # contributes nothing to the reported moments. It does not follow that the
  # moments are invariant: adding contaminants changes the responsibilities, so
  # the fit itself moves. What has to hold is that it moves much less than the
  # sample mean does -- the residual shift is the identifiability limit this
  # package exists to measure, not a bug.
  set.seed(53)
  core <- rtprep:::.rexgauss(400, 0.45, 0.05, 0.15)
  contaminated <- function(n, seed) {
    set.seed(seed)
    c(core, runif(n, 0.05, 0.10)) # well clear of the core
  }
  mixture_mean <- function(x) {
    suppressWarnings(rt_summary(x,
      method = "mixture", distribution = "lognormal", maxit = 500
    ))$mean_rt
  }

  few <- contaminated(10, 53)
  many <- contaminated(60, 54)

  mixture_shift <- abs(mixture_mean(few) - mixture_mean(many))
  sample_shift <- abs(mean(few) - mean(many))
  expect_gt(sample_shift / mixture_shift, 2)

  props <- vapply(list(few, many), function(x) {
    suppressWarnings(rt_summary(x,
      method = "mixture", distribution = "lognormal", maxit = 500
    ))$contaminant_prop
  }, numeric(1))
  expect_gt(props[2], props[1])
})

# --- weights ----------------------------------------------------------------

test_that("equal weights reproduce the unweighted moments", {
  d <- summary_data()
  out <- rt_summary(d$rt, d$correct, weights = rep(1, nrow(d)))

  expect_equal(out$mean_rt, mean(d$rt))
  expect_equal(out$var_rt, var(d$rt))
  # and the scale of the weights must not matter
  half <- rt_summary(d$rt, d$correct, weights = rep(0.5, nrow(d)))
  expect_equal(half$mean_rt, out$mean_rt)
  expect_equal(half$var_rt, out$var_rt)
})

test_that("zero weights drop trials exactly", {
  d <- summary_data()
  w <- as.numeric(!d$contaminant)
  weighted <- rt_summary(d$rt, d$correct, weights = w)
  clean <- rt_summary(d$rt[!d$contaminant], d$correct[!d$contaminant])

  expect_equal(weighted$mean_rt, clean$mean_rt)
  expect_equal(weighted$var_rt, clean$var_rt)
})

test_that("a probabilistic screen can feed aggregation directly", {
  d <- summary_data()
  scr <- rt_screen(d$rt, rule = rule_mixture("lognormal"))
  out <- rt_summary(d$rt, d$correct, weights = scr$.prob)

  # down-weighting the contaminants must move the mean towards the core
  expect_gt(out$mean_rt, mean(d$rt))
  expect_true(is.na(out$contaminant_prop))
})

test_that("weights only make sense alongside the simple moments", {
  d <- summary_data()
  w <- runif(nrow(d))

  only_simple <- "method = \"simple\""
  expect_error(
    rt_summary(d$rt, weights = w, method = "robust"), only_simple
  )
  expect_error(
    rt_summary(d$rt, weights = w, method = "mixture"), only_simple
  )
})

test_that("rt_summary() rejects malformed weights", {
  d <- summary_data()
  expect_error(rt_summary(d$rt, weights = c(1, 2)), "same length as")
  expect_error(rt_summary(d$rt, weights = rep(-1, nrow(d))), "non-negative")
  expect_error(rt_summary(d$rt, weights = rep(0, nrow(d))), "at least one")
  expect_error(
    rt_summary(d$rt, weights = c(Inf, rep(1, nrow(d) - 1))), "must be finite"
  )
})

test_that("a misspelled argument is an error, not a silent no-op", {
  # the dangerous case: `...` reaches the mixture fit only on the mixture
  # branch, so without a check a typo produces an unweighted summary quietly
  d <- summary_data()
  w <- runif(nrow(d))

  expect_error(rt_summary(d$rt, weigths = w), "Unknown argument")
  expect_error(rt_summary(d$rt, maxIT = 3), "Unknown argument")
  expect_error(
    rt_summary(d$rt, method = "mixture", maxIT = 3), "Unknown argument"
  )
})

test_that("the mixture controls get rule_mixture()'s validation", {
  d <- summary_data()
  bad_scalar <- "must be a single"
  expect_error(rt_summary(d$rt, method = "mixture", init = 1.5), bad_scalar)
  expect_error(rt_summary(d$rt, method = "mixture", maxit = -1), "whole number")
  expect_error(rt_summary(d$rt, method = "mixture", bound = 3), "length 2")
  expect_error(rt_summary(d$rt, method = "mixture", tol = 0), bad_scalar)
})

# --- min_trials and missingness ---------------------------------------------

test_that("too few trials gives NA moments but still counts them", {
  rt <- c(0.3, 0.4, 0.5)
  out <- rt_summary(rt, min_trials = 10)

  expect_true(is.na(out$mean_rt))
  expect_true(is.na(out$var_rt))
  expect_equal(out$n_trials, 3L)

  enough <- rt_summary(rt, min_trials = 3)
  expect_equal(enough$mean_rt, mean(rt))
})

test_that("4par lets one sparse boundary be NA without taking the other down", {
  set.seed(57)
  rt <- rtprep:::.rexgauss(40, 0.45, 0.05, 0.15)
  correct <- c(rep(1, 37), rep(0, 3))
  out <- rt_summary(rt, correct, version = "4par", min_trials = 10)

  expect_false(is.na(out$mean_rt_upper))
  expect_true(is.na(out$mean_rt_lower))
  expect_equal(out$n_trials, 40L)
  expect_equal(out$n_upper, 37L)
})

test_that("a missing response belongs to neither boundary", {
  # indexing with a logical NA puts an NA into BOTH subsets, so one missing
  # response would otherwise take down the whole 4par summary
  set.seed(59)
  rt <- rtprep:::.rexgauss(60, 0.45, 0.05, 0.15)
  correct <- rbinom(60, 1, 0.75)
  correct[c(5, 20)] <- NA

  out <- rt_summary(rt, correct, version = "4par")
  expect_false(is.na(out$mean_rt_upper))
  expect_false(is.na(out$mean_rt_lower))
  expect_equal(out$mean_rt_upper, mean(rt[which(correct == 1)]))
  expect_equal(out$mean_rt_lower, mean(rt[which(correct == 0)]))

  # and the same holds once weights are in play
  weighted <- rt_summary(rt, correct, version = "4par", weights = rep(1, 60))
  expect_equal(weighted$mean_rt_upper, out$mean_rt_upper)
  expect_equal(weighted$var_rt_upper, out$var_rt_upper)
})

test_that("min_trials counts information, not rows", {
  # two trials at weight 1 among 98 at weight 0 is two trials' worth of
  # information; reporting a variance from it is the failure min_trials exists
  # to prevent
  set.seed(60)
  rt <- rtprep:::.rexgauss(100, 0.45, 0.05, 0.15)
  w <- c(1, 1, rep(0, 98))

  out <- rt_summary(rt, weights = w, min_trials = 10)
  expect_true(is.na(out$mean_rt))
  expect_true(is.na(out$var_rt))
  expect_equal(out$n_trials, 100L)

  # Kish's effective n, so a broad shallow down-weighting still counts
  expect_false(is.na(rt_summary(rt, weights = rep(0.2, 100))$mean_rt))
  expect_equal(rtprep:::.effective_n(rep(0.5, 40)), 40)
})

test_that("weighted moments match a hand computation under unequal weights", {
  x <- c(0.30, 0.40, 0.50, 0.60, 0.70)
  w <- c(0.1, 0.2, 0.4, 0.8, 1.0)
  out <- rt_summary(x, weights = w, min_trials = 2)

  mu <- sum(w * x) / sum(w)
  denom <- sum(w) - sum(w^2) / sum(w)
  expect_equal(out$mean_rt, mu)
  expect_equal(out$var_rt, sum(w * (x - mu)^2) / denom)
})

test_that("missing response times are dropped before anything else", {
  d <- summary_data()
  rt <- c(d$rt, NA, NA)
  correct <- c(d$correct, 1, 0)
  out <- rt_summary(rt, correct)

  expect_equal(out$n_trials, nrow(d))
  expect_equal(out$mean_rt, mean(d$rt))
})

test_that("rt_summary() rejects what no summary could be made of", {
  expect_error(rt_summary("a"), "must be a numeric vector")
  expect_error(rt_summary(numeric(0)), "has length 0")
  expect_error(rt_summary(c(0.3, 0)), "Non-positive")
  expect_error(rt_summary(c(0.3, 0.4), response = 1), "same length as")
  expect_error(rt_summary(c(0.3, 0.4), min_trials = 0), "must be a single")
})

test_that("a failed mixture fit falls back to robust moments and says so", {
  rt <- c(0.30, 0.32, 0.34, 0.36, 0.38, 0.40, 0.42, 0.44, 0.46, 0.48)
  expect_warning(
    out <- rt_summary(rt, method = "mixture", maxit = 1),
    "did not converge"
  )
  robust <- rt_summary(rt, method = "robust")
  expect_equal(out$mean_rt, robust$mean_rt)
  expect_equal(out$var_rt, robust$var_rt)
  expect_true(is.na(out$contaminant_prop))
})

# --- adjust_accuracy --------------------------------------------------------

test_that("adjust_accuracy() returns coherent integer counts", {
  set.seed(61)
  for (i in 1:50) {
    out <- adjust_accuracy(n_upper = 80, n_trials = 100, contaminant_prop = 0.1)
    expect_equal(names(out), c("n_upper_adj", "n_trials_adj"))
    expect_type(out$n_upper_adj, "integer")
    expect_type(out$n_trials_adj, "integer")
    expect_gte(out$n_upper_adj, 0L)
    expect_lte(out$n_upper_adj, out$n_trials_adj)
    expect_lte(out$n_trials_adj, 100L)
  }
})

test_that("adjust_accuracy() removes the right counts on average", {
  set.seed(62)
  draws <- vapply(1:4000, function(i) {
    unlist(adjust_accuracy(80, 100, 0.1))
  }, numeric(2))

  # expected trials remaining: 100 minus a tenth of them
  expect_equal(mean(draws["n_trials_adj", ]), 90, tolerance = 0.004)
  # expected correct remaining: 80, less the contaminants that guessed right
  expect_equal(mean(draws["n_upper_adj", ]), 75, tolerance = 0.004)

  # and guess_rate has to move that second number
  set.seed(63)
  high <- mean(vapply(1:4000, function(i) {
    adjust_accuracy(80, 100, 0.1, guess_rate = 1)$n_upper_adj
  }, integer(1)))
  expect_equal(high, 70, tolerance = 0.006)
})

test_that("adjust_accuracy() leaves the counts alone when there is nothing", {
  expect_equal(adjust_accuracy(80, 100, NA)$n_trials_adj, 100L)
  expect_equal(adjust_accuracy(80, 100, NA)$n_upper_adj, 80L)
  expect_equal(adjust_accuracy(80, 100, 0)$n_trials_adj, 100L)
  expect_equal(adjust_accuracy(80, 100, -0.1)$n_trials_adj, 100L)
})

test_that("adjust_accuracy() validates its inputs", {
  bad_scalar <- "must be a single"
  expect_error(adjust_accuracy("a", 100, 0.1), "whole number")
  expect_error(adjust_accuracy(80, 100, 0.1, guess_rate = 1.5), bad_scalar)
  expect_error(adjust_accuracy(80, 100, 0.1, guess_rate = -1), bad_scalar)
  expect_error(adjust_accuracy(120, 100, 0.1), "cannot exceed")
  # counts must be whole numbers, and a proportion must be in [0, 1]
  expect_error(adjust_accuracy(80.5, 100.7, 0.1), "whole number")
  expect_error(adjust_accuracy(80, 100, 1.5), "cannot exceed 1")
  expect_error(adjust_accuracy(80, 100, "0.1"), "must be numeric")
  # one bad row is enough
  expect_error(adjust_accuracy(c(80, 120), 100, 0.1), "cannot exceed")
})

test_that("adjust_accuracy() vectorises over rows, one draw per row", {
  # the idiom bmm's vignette teaches: a summary table with one row per cell
  tbl <- data.frame(
    n_upper = c(80L, 45L, 95L), n_trials = c(100L, 50L, 100L),
    contaminant_prop = c(0.1, 0.2, 0.05)
  )
  set.seed(64)
  out <- adjust_accuracy(tbl$n_upper, tbl$n_trials, tbl$contaminant_prop)

  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 3L)
  expect_equal(names(out), c("n_upper_adj", "n_trials_adj"))
  expect_type(out$n_upper_adj, "integer")
  expect_type(out$n_trials_adj, "integer")
  expect_true(all(out$n_trials_adj <= tbl$n_trials))
  expect_true(all(out$n_upper_adj >= 0L & out$n_upper_adj <= out$n_trials_adj))

  # the same rows are adjusted independently: over many draws each row's mean
  # removal matches its own proportion
  set.seed(65)
  draws <- vapply(1:3000, function(i) {
    adj <- adjust_accuracy(tbl$n_upper, tbl$n_trials, tbl$contaminant_prop)
    adj$n_trials_adj
  }, integer(3))
  expect_equal(rowMeans(draws), c(90, 40, 95), tolerance = 0.005)
})

test_that("adjust_accuracy() recycles scalars against vectors", {
  set.seed(66)
  out <- adjust_accuracy(c(80, 40), 100, 0.1)
  expect_equal(nrow(out), 2L)
  expect_true(all(out$n_trials_adj <= 100L))

  # a fractional recycle is a mistake worth saying out loud, as in ez_ddm()
  expect_warning(
    adjust_accuracy(c(80, 40, 60), c(100, 100), 0.1), "not a multiple"
  )
})

test_that("adjust_accuracy() leaves rows with nothing to adjust alone", {
  set.seed(67)
  out <- adjust_accuracy(
    n_upper = c(80L, 80L, 80L, 80L), n_trials = 100L,
    contaminant_prop = c(0.3, NA, 0, -0.1)
  )
  expect_equal(out$n_trials_adj[2:4], rep(100L, 3))
  expect_equal(out$n_upper_adj[2:4], rep(80L, 3))
  expect_lt(out$n_trials_adj[1], 100L)

  # a missing count gives a missing answer rather than an error, so the
  # function survives a summary table with an empty cell
  na_row <- adjust_accuracy(c(80L, NA), c(100L, 100L), 0.1)
  expect_equal(na_row$n_upper_adj[2], NA_integer_)
  expect_equal(na_row$n_trials_adj[2], NA_integer_)
  expect_false(is.na(na_row$n_trials_adj[1]))
})

test_that("the length-1 path draws exactly as bmm does", {
  # the equivalence test needs bmm installed; this pins the same contract
  # without it. bmm draws rbinom(1, n_trials, prop) then rbinom(1, n_contam,
  # guess_rate), in that order, and nothing when there is nothing to adjust.
  set.seed(68)
  out <- adjust_accuracy(80, 100, 0.15, guess_rate = 0.5)
  set.seed(68)
  n_contam <- rbinom(1, 100, 0.15)
  n_contam_upper <- rbinom(1, n_contam, 0.5)
  expect_equal(out$n_trials_adj, 100L - n_contam)
  expect_equal(out$n_upper_adj, 80L - n_contam_upper)

  # rows that need no adjustment must not consume the stream either
  set.seed(69)
  adjust_accuracy(80, 100, NA)
  after_na <- runif(1)
  set.seed(69)
  expect_equal(after_na, runif(1))
})

# --- ez_ddm -----------------------------------------------------------------

test_that("ez_ddm() reproduces the Wagenmakers et al. (2007) example", {
  # their Pc = .802, VRT = .112, MRT = .723 with s = 0.1 was generated from
  # drift = .1, bound = .14, ndt = .3
  out <- ez_ddm(
    mean_rt = 0.723, var_rt = 0.112, accuracy = 0.802,
    n_trials = 100, s = 0.1
  )

  expect_equal(names(out), c("drift", "bound", "ndt", "edge_corrected"))
  expect_equal(out$drift, 0.1, tolerance = 0.001)
  expect_equal(out$bound, 0.14, tolerance = 0.001)
  expect_equal(out$ndt, 0.3, tolerance = 0.001)
})

# forward EZ moments, so the inversion can be checked against something other
# than itself
ez_forward <- function(drift, bound, ndt, s = 1) {
  y <- -bound * drift / s^2
  e <- exp(y)
  list(
    accuracy = 1 / (1 + e),
    mean_rt = ndt + (bound / (2 * drift)) * ((1 - e) / (1 + e)),
    var_rt = ((bound * s^2) / (2 * drift^3)) *
      (2 * y * e - exp(2 * y) + 1) / ((e + 1)^2)
  )
}

test_that("ez_ddm() inverts the forward equations exactly", {
  for (s in c(1, 0.1)) {
    for (par in list(c(1.2, 1.5, 0.30), c(0.6, 2.0, 0.25), c(2.5, 1.0, 0.40))) {
      p <- par * c(s, s, 1) # drift and bound scale with s, ndt does not
      m <- ez_forward(p[1], p[2], p[3], s = s)
      out <- ez_ddm(m$mean_rt, m$var_rt, m$accuracy, n_trials = 1000, s = s)

      expect_equal(out$drift, p[1], tolerance = 1e-6)
      expect_equal(out$bound, p[2], tolerance = 1e-6)
      expect_equal(out$ndt, p[3], tolerance = 1e-6)
    }
  }
})

test_that("s is a units convention: drift and bound scale, ndt does not", {
  m <- ez_forward(1.2, 1.5, 0.3, s = 1)
  at_1 <- ez_ddm(m$mean_rt, m$var_rt, m$accuracy, 1000, s = 1)
  at_01 <- ez_ddm(m$mean_rt, m$var_rt, m$accuracy, 1000, s = 0.1)

  expect_equal(at_01$drift, at_1$drift * 0.1)
  expect_equal(at_01$bound, at_1$bound * 0.1)
  expect_equal(at_01$ndt, at_1$ndt)
})

test_that("ez_ddm() vectorises and recycles", {
  out <- ez_ddm(
    mean_rt = c(0.7, 0.8, 0.9), var_rt = 0.1,
    accuracy = c(0.8, 0.75, 0.7), n_trials = 100
  )
  expect_equal(nrow(out), 3L)
  expect_true(all(out$drift > 0))
  # slower and less accurate should not give a higher drift
  expect_false(is.unsorted(rev(out$drift)))
})

test_that("accuracy below chance gives a negative drift", {
  out <- ez_ddm(0.7, 0.1, 0.3, n_trials = 100)
  expect_lt(out$drift, 0)
  expect_gt(out$bound, 0)
})

test_that("ez_ddm() applies the published edge correction", {
  n <- 50
  out <- ez_ddm(
    mean_rt = rep(0.7, 4), var_rt = rep(0.1, 4),
    accuracy = c(1, 0, 0.5, 0.8), n_trials = n
  )

  expect_true(all(is.finite(out$drift)))
  expect_equal(out$edge_corrected, c(TRUE, TRUE, TRUE, FALSE))
  expect_type(out$edge_corrected, "logical")
  # a column survives what an attribute does not: subsetting and binding
  expect_null(attr(out, "edge_corrected"))
  expect_equal(rbind(out, out)$edge_corrected, rep(out$edge_corrected, 2))
  expect_equal(out[2:3, ]$edge_corrected, c(TRUE, TRUE))

  # each corrected value must equal the uncorrected fit at the shifted accuracy
  expect_equal(out$drift[1], ez_ddm(0.7, 0.1, 1 - 1 / (2 * n), n)$drift)
  expect_equal(out$drift[2], ez_ddm(0.7, 0.1, 1 / (2 * n), n)$drift)
  expect_equal(out$drift[3], ez_ddm(0.7, 0.1, 0.5 + 1 / (2 * n), n)$drift)
})

test_that("ez_ddm() returns NA where the inputs carry no information", {
  out <- ez_ddm(
    mean_rt = c(0.7, 0.7, NA, 0.7, 0.7), var_rt = c(0, -1, 0.1, 0.1, 0.1),
    accuracy = c(0.8, 0.8, 0.8, NA, 0.8), n_trials = c(100, 100, 100, 100, NA)
  )
  expect_true(all(is.na(out$drift)))
  expect_true(all(is.na(out$bound)))
  expect_true(all(is.na(out$ndt)))
})

test_that("ez_ddm() handles degenerate lengths without inventing rows", {
  empty <- ez_ddm(numeric(0), 0.1, 0.8, 100)
  expect_equal(nrow(empty), 0L)
  expect_equal(names(empty), c("drift", "bound", "ndt", "edge_corrected"))
  expect_type(empty$edge_corrected, "logical")

  # a fractional recycle is a mistake worth saying out loud
  expect_warning(
    ez_ddm(c(0.7, 0.8), 0.1, c(0.8, 0.75, 0.7), 100), "not a multiple"
  )
})

test_that("ez_ddm() cannot correct an edge with a single trial", {
  # 0 and 1 both land on 0.5 at n = 1, where the equations break down anyway
  out <- ez_ddm(0.7, 0.1, c(1, 0, 0.5), n_trials = 1)
  expect_true(all(is.na(out$drift)))
  expect_equal(out$edge_corrected, c(TRUE, TRUE, TRUE))

  expect_false(is.na(ez_ddm(0.7, 0.1, 1, n_trials = 2)$drift))
})

test_that("ez_ddm() validates its inputs", {
  expect_error(ez_ddm(0.7, 0.1, 1.5, 100), "between 0 and 1")
  expect_error(ez_ddm(0.7, 0.1, -0.1, 100), "between 0 and 1")
  expect_error(ez_ddm(0.7, 0.1, 0.8, 0), "at least 1")
  expect_error(ez_ddm(0.7, 0.1, 0.8, 100, s = 0), "must be a single")
  expect_error(ez_ddm(0.7, 0.1, 0.8, "100"), "must be numeric")
  expect_error(ez_ddm("a", 0.1, 0.8, 100), "must be numeric")
})

test_that("rt_summary() output feeds ez_ddm() directly", {
  d <- summary_data()
  s <- rt_summary(d$rt, d$correct)
  out <- ez_ddm(s$mean_rt, s$var_rt, s$n_upper / s$n_trials, s$n_trials)

  expect_equal(nrow(out), 1L)
  expect_true(all(is.finite(unlist(out))))
})
