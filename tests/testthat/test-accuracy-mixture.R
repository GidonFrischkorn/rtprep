# The accuracy-informed mixture: accuracy inside the likelihood rather than
# checked after the fact. Experimental, and staged deliberately -- these tests
# are what Study 1's evidence will be weighed against, so they assert the
# claims the method makes rather than just that it runs.

fit_joint <- function(rt, y, chance = 0.5, distribution = "lognormal",
                      maxit = 500) {
  bound <- rtprep:::.resolve_bounds(c("min", "max"), rt)$bound
  rtprep:::.fit_rt_mixture(
    rt, distribution, bound,
    init = 0.05, max_prop = 0.5, maxit = maxit, tol = 1e-8,
    y = y, chance = chance
  )
}

fit_rt_only <- function(rt, distribution = "lognormal", maxit = 500) {
  bound <- rtprep:::.resolve_bounds(c("min", "max"), rt)$bound
  rtprep:::.fit_rt_mixture(
    rt, distribution, bound,
    init = 0.05, max_prop = 0.5, maxit = maxit, tol = 1e-8
  )
}

# guessing contaminants: fast-ish, and at chance
guessing_data <- function(n_core = 500, n_contam = 60, p_correct = 0.9,
                          overlap = TRUE, seed = 81) {
  set.seed(seed)
  core <- rtprep:::.rexgauss(n_core, mu = 0.45, sigma = 0.05, tau = 0.15)
  contam <- if (overlap) {
    # squarely inside the core's range: RT alone cannot separate these
    runif(n_contam, 0.35, 0.75)
  } else {
    runif(n_contam, 0.10, 0.20)
  }
  data.frame(
    rt = c(core, contam),
    correct = c(
      rbinom(n_core, 1, p_correct), rbinom(n_contam, 1, 0.5)
    ),
    contaminant = rep(c(FALSE, TRUE), c(n_core, n_contam))
  )
}

# --- the extra term is wired in correctly -----------------------------------

test_that("p_c equal to chance cancels out of the responsibilities exactly", {
  # When the two components predict accuracy equally well the Bernoulli factors
  # are identical and must cancel, leaving the responsibilities untouched. This
  # is the sharpest check that the joint likelihood is assembled the right way
  # round; anything looser would tolerate the factors being applied to the
  # wrong component.
  set.seed(93)
  x <- rtprep:::.rexgauss(200, 0.45, 0.05, 0.15)
  y <- rbinom(200, 1, 0.7)
  par <- rtprep:::.init_dist_params(x, "lognormal")

  rt_only <- rtprep:::.e_step(x, par, "lognormal", 0.95, 0.05, 1 / 2)
  # deliberately NOT at 0.5: with p_correct == chance == 0.5 the two factors
  # are numerically identical, so swapping them between the components would be
  # a no-op and this test would be blind to exactly the error it exists to
  # catch. At 0.8 the cancellation is still exact but the factors are not.
  joint <- rtprep:::.e_step(
    x, par, "lognormal", 0.95, 0.05, 1 / 2,
    y = y, p_correct = 0.8, chance = 0.8
  )

  expect_equal(joint$gamma_rt, rt_only$gamma_rt)
  # the log-likelihood differs only by the constant both components picked up
  expect_equal(
    joint$loglik,
    rt_only$loglik + sum(y * log(0.8) + (1 - y) * log(0.2))
  )
})

test_that("the accuracy factors are attached to the right components", {
  # asymmetric p_correct and chance, so applying them the wrong way round
  # changes the answer. Without this the whole joint likelihood can be fitted
  # backwards with every other test still green.
  set.seed(95)
  x <- rtprep:::.rexgauss(200, 0.45, 0.05, 0.15)
  y <- rbinom(200, 1, 0.7)
  par <- rtprep:::.init_dist_params(x, "lognormal")

  right <- rtprep:::.e_step(
    x, par, "lognormal", 0.9, 0.1, 1 / 2,
    y = y, p_correct = 0.9, chance = 0.25
  )
  swapped <- rtprep:::.e_step(
    x, par, "lognormal", 0.9, 0.1, 1 / 2,
    y = y, p_correct = 0.25, chance = 0.9
  )
  expect_false(isTRUE(all.equal(right$gamma_rt, swapped$gamma_rt)))

  # a correct trial must weigh towards the component that is more often correct
  correct <- y == 1
  expect_gt(mean(right$gamma_rt[correct]), mean(right$gamma_rt[!correct]))
  expect_lt(mean(swapped$gamma_rt[correct]), mean(swapped$gamma_rt[!correct]))
})

test_that(".bernoulli_factor() is p^y (1 - p)^(1 - y)", {
  y <- c(1, 0, 1, 1, 0)
  for (p in c(0.25, 0.5, 0.9)) {
    expect_equal(rtprep:::.bernoulli_factor(y, p), p^y * (1 - p)^(1 - y))
  }
})

test_that("a decision process at chance gives back nearly the RT-only fit", {
  # the practical form of the same property: with the core responding at chance
  # the accuracy dimension carries no information, so the joint fit should have
  # nothing to add
  d <- guessing_data(p_correct = 0.5)

  for (dist in c("exgaussian", "lognormal", "invgaussian")) {
    joint <- fit_joint(d$rt, d$correct, chance = 0.5, distribution = dist)
    rt_only <- fit_rt_only(d$rt, distribution = dist)

    expect_equal(joint$converged, rt_only$converged, info = dist)
    expect_lt(
      abs(joint$contaminant_prop - rt_only$contaminant_prop), 0.01,
      label = dist
    )
    expect_equal(joint$par, rt_only$par, tolerance = 1e-2, info = dist)
    # p_c lands on the observed accuracy, which is chance up to sampling noise
    expect_equal(as.numeric(joint$p_correct), 0.5, tolerance = 0.1)
  }
})

test_that("the p_c M-step is the responsibility-weighted mean of accuracy", {
  set.seed(83)
  y <- rbinom(200, 1, 0.8)
  w <- runif(200, 1e-6, 1)
  expect_equal(rtprep:::.p_correct_step(y, w), sum(w * y) / sum(w))

  # and it is clamped away from the boundaries: all-correct data would send it
  # to exactly 1, where a later error trial has likelihood zero
  expect_lt(rtprep:::.p_correct_step(rep(1, 50), rep(1, 50)), 1)
  expect_gt(rtprep:::.p_correct_step(rep(0, 50), rep(1, 50)), 0)
})

test_that("the RT-only path is untouched by the joint machinery", {
  # milestone 2's bmm equivalence rests on this
  d <- guessing_data()
  bound <- rtprep:::.resolve_bounds(c("min", "max"), d$rt)$bound
  explicit_null <- rtprep:::.fit_rt_mixture(
    d$rt, "lognormal", bound, 0.05, 0.5, 500, 1e-8,
    y = NULL, chance = 0.5
  )
  default <- rtprep:::.fit_rt_mixture(
    d$rt, "lognormal", bound, 0.05, 0.5, 500, 1e-8
  )
  expect_equal(explicit_null, default)
  expect_true(is.na(default$p_correct))
})

# --- recovery ---------------------------------------------------------------

test_that("the p_c M-step moves p_c away from the observed accuracy", {
  # p_correct starts at the raw accuracy. If the M-step were a no-op the fit
  # would stay there and every tolerance-based recovery test would still pass,
  # so the movement itself has to be asserted.
  set.seed(11)
  rt <- c(
    rtprep:::.rexgauss(800, 0.45, 0.05, 0.15), runif(120, 0.10, 0.20)
  )
  y <- c(rbinom(800, 1, 0.95), rbinom(120, 1, 0.5))

  fit <- fit_joint(rt, y)
  expect_true(fit$converged)
  # the raw accuracy is dragged down by the guesses; the fitted accuracy of the
  # decision process should be markedly higher, and closer to the true 0.95
  expect_gt(as.numeric(fit$p_correct) - mean(y), 0.05)
  expect_equal(as.numeric(fit$p_correct), 0.95, tolerance = 0.05)
  expect_false(fit$collapsed)
})

test_that("the joint EM recovers the mixing weight and the valid accuracy", {
  d <- guessing_data(n_core = 2000, n_contam = 300, p_correct = 0.9, seed = 85)
  fit <- fit_joint(d$rt, d$correct)

  expect_true(fit$converged)
  expect_equal(fit$contaminant_prop, 300 / 2300, tolerance = 0.6)
  expect_equal(as.numeric(fit$p_correct), 0.9, tolerance = 0.15)
  expect_false(fit$accuracy_inverted)
})

test_that("the joint log-likelihood increases across EM iterations", {
  d <- guessing_data()
  loose <- fit_joint(d$rt, d$correct, maxit = 500)
  tight <- rtprep:::.fit_rt_mixture(
    d$rt, "lognormal",
    rtprep:::.resolve_bounds(c("min", "max"), d$rt)$bound,
    0.05, 0.5, 500, 1e-12,
    y = d$correct, chance = 0.5
  )
  expect_true(loose$converged)
  expect_true(tight$converged)
  expect_gte(tight$loglik, loose$loglik - 1e-8)
})

# --- the claims the method makes --------------------------------------------

# sensitivity at matched specificity: raw flag counts are not comparable across
# two rules that flag different numbers of trials
sensitivity_at <- function(prob, truth, target_specificity = 0.9) {
  cut <- stats::quantile(prob[!truth], probs = 1 - target_specificity)
  flagged <- prob <= cut
  # a degenerate .prob (every value equal, as a collapsed or failed fit
  # returns) makes every trial fall at the cut, which reads as perfect
  # sensitivity at zero specificity. Refuse to report that as a number.
  realised <- sum(!flagged & !truth) / sum(!truth)
  if (realised < target_specificity - 0.05) {
    return(NA_real_)
  }
  sum(flagged & truth) / sum(truth)
}

test_that("accuracy orders overlapping guesses better, but the fit collapses", {
  # Contaminants drawn from inside the core's own range: response time carries
  # almost no signal, so this is the case the accuracy dimension exists for.
  # The ranking does improve. The fitted mixture, however, collapses to a
  # contaminant proportion of essentially zero, so the rule as shipped removes
  # nothing at all -- the improvement is in an ordering the keep policy never
  # gets to act on. Both halves are asserted, because reporting only the first
  # would overstate what the method currently does.
  d <- guessing_data(
    n_core = 1500, n_contam = 250, p_correct = 0.95,
    overlap = TRUE, seed = 87
  )

  joint <- rt_screen(d$rt,
    response = d$correct,
    rule = rule_mixture("lognormal", use_accuracy = TRUE, maxit = 500)
  )
  rt_only <- rt_screen(d$rt, rule = rule_mixture("lognormal", maxit = 500))

  expect_gt(
    sensitivity_at(joint$.prob, d$contaminant),
    sensitivity_at(rt_only$.prob, d$contaminant)
  )

  fits <- attr(joint, "fits")
  expect_true(fits$converged)
  expect_true(fits$collapsed)
  expect_lt(fits$contaminant_prop, 1e-4)
  expect_equal(sum(!joint$.keep), 0L)
  # and the collapse is what makes the ranking unusable: every posterior sits
  # within a whisker of 1
  expect_gt(min(joint$.prob), 0.999)
})

test_that("accuracy actively hurts when the contaminants' accuracy is intact", {
  # A delayed start-up runs the decision process, just later, so it is as
  # accurate as a valid trial. The model assumes contaminants respond at
  # chance, which is simply false here -- and the cost is not neutrality. Every
  # correct contaminant has its contaminant evidence attenuated by
  # chance / p_correct, so the joint model loses a large part of the
  # sensitivity the RT-only model had.
  #
  # The delay is small enough that the RT-only comparator is well off ceiling;
  # at a larger delay it sits at exactly 1.0 and the comparison cannot fail in
  # either direction.
  set.seed(89)
  n_core <- 1200
  n_contam <- 200
  core <- rtprep:::.rexgauss(n_core, 0.45, 0.05, 0.15)
  delayed <- rtprep:::.rexgauss(n_contam, 0.45, 0.05, 0.15) + 0.25
  d <- data.frame(
    rt = c(core, delayed),
    correct = rbinom(n_core + n_contam, 1, 0.9),
    contaminant = rep(c(FALSE, TRUE), c(n_core, n_contam))
  )

  joint <- rt_screen(d$rt,
    response = d$correct,
    rule = rule_mixture("lognormal", use_accuracy = TRUE, maxit = 500)
  )
  rt_only <- rt_screen(d$rt, rule = rule_mixture("lognormal", maxit = 500))

  joint_sens <- sensitivity_at(joint$.prob, d$contaminant)
  rt_sens <- sensitivity_at(rt_only$.prob, d$contaminant)

  # the comparator has to have room to move in both directions
  expect_gt(rt_sens, 0.1)
  expect_lt(rt_sens, 0.9)
  # and the joint model is meaningfully worse, not merely no better
  expect_lt(joint_sens, rt_sens - 0.05)
})

# --- degenerate data --------------------------------------------------------

test_that("all-correct data fits without error and stays inside the clamp", {
  d <- guessing_data()
  fit <- fit_joint(d$rt, rep(1, nrow(d)))

  expect_true(fit$converged)
  expect_lt(as.numeric(fit$p_correct), 1)
  expect_gt(as.numeric(fit$p_correct), 0.9)
  expect_false(fit$accuracy_inverted)
})

test_that("all-error data is flagged as inverted rather than quietly fitted", {
  # p_c below chance means the labels have swapped: the model is calling the
  # less accurate component the decision process
  d <- guessing_data()
  fit <- fit_joint(d$rt, rep(0, nrow(d)))

  expect_gt(as.numeric(fit$p_correct), 0)
  expect_lt(as.numeric(fit$p_correct), 0.5)
  expect_true(fit$accuracy_inverted)
})

test_that("rt_screen() reports an inverted fit once for the whole call", {
  d <- guessing_data(n_core = 100, n_contam = 20)
  rt <- rep(d$rt, 3)
  correct <- rep(0, length(rt))
  id <- rep(seq_len(3), each = nrow(d))

  warnings <- character(0)
  withCallingHandlers(
    rt_screen(rt,
      response = correct,
      rule = rule_mixture("lognormal", use_accuracy = TRUE), .by = id
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(grep("less accurate than chance", warnings), 1L)
})

# --- plumbing ---------------------------------------------------------------

test_that("the accuracy-informed rule is now applicable", {
  d <- guessing_data()
  out <- rt_screen(d$rt,
    response = d$correct,
    rule = rule_mixture("lognormal", use_accuracy = TRUE, maxit = 500)
  )

  expect_equal(nrow(out), nrow(d))
  expect_true(all(out$.prob >= 0 & out$.prob <= 1))
  expect_equal(unique(out$.rule), "mixture(lognormal, accuracy)")
  expect_gt(sum(!out$.keep), 0)
})

test_that("the fits table reports the valid process's accuracy", {
  d <- guessing_data(p_correct = 0.9)

  joint <- attr(
    rt_screen(d$rt,
      response = d$correct,
      rule = rule_mixture("lognormal", use_accuracy = TRUE, maxit = 500)
    ),
    "fits"
  )
  expect_true(all(
    c("p_correct", "collapsed", "accuracy_inverted") %in% names(joint)
  ))
  expect_false(is.na(joint$p_correct))
  expect_gt(joint$p_correct, 0.5)

  # the RT-only fit reports the columns too, empty
  rt_only <- attr(
    rt_screen(d$rt, rule = rule_mixture("lognormal", maxit = 500)), "fits"
  )
  expect_true(is.na(rt_only$p_correct))
  expect_false(rt_only$accuracy_inverted)
})

test_that("the accuracy-informed rule still requires a response", {
  d <- guessing_data()
  expect_error(
    rt_screen(d$rt, rule = rule_mixture(use_accuracy = TRUE)),
    "requires 'response'"
  )
})

test_that("a chance rate other than one half is honoured", {
  # a four-alternative task guesses correctly a quarter of the time
  d <- guessing_data(n_core = 800, n_contam = 150, p_correct = 0.9, seed = 91)
  set.seed(91)
  d$correct[d$contaminant] <- rbinom(sum(d$contaminant), 1, 0.25)

  fit <- fit_joint(d$rt, d$correct, chance = 0.25)
  expect_true(fit$converged)
  expect_false(fit$accuracy_inverted)
  expect_gt(as.numeric(fit$p_correct), 0.25)
})
