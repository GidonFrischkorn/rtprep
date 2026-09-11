# Rule constructors are parameter objects: they validate and label, and do no
# computation on data. Everything a rule can get wrong should be caught here,
# because apply_rule() methods are allowed to assume clean parameters.

test_that("every constructor returns the documented classes and a label", {
  rules <- list(
    cutoff = rule_cutoff(0.18, 3),
    sd = rule_sd(2.5),
    recursive = rule_recursive(),
    ewma = rule_ewma(),
    mixture = rule_mixture(),
    adaptive_trim = rule_adaptive_trim(),
    ez_support = rule_ez_support(),
    none = rule_none()
  )

  for (nm in names(rules)) {
    expect_s3_class(rules[[nm]], paste0("rtprep_rule_", nm))
    expect_s3_class(rules[[nm]], "rtprep_rule")
    expect_type(rules[[nm]]$label, "character")
    expect_length(rules[[nm]]$label, 1L)
  }
})

test_that("labels describe the rule's parameters", {
  expect_equal(rule_cutoff(0.18, 3)$label, "cutoff(0.18, 3)")
  expect_equal(rule_cutoff(0.25)$label, "cutoff(0.25, Inf)")
  expect_equal(rule_sd(2.5)$label, "sd(2.5, mean, sd)")
  expect_equal(rule_sd(3, "median", "mad")$label, "sd(3, median, mad)")
  expect_equal(rule_recursive("modified")$label, "recursive(modified)")
  expect_equal(rule_ewma()$label, "ewma(0.01, 1.5)")
  expect_equal(rule_none()$label, "none")
  expect_equal(rule_mixture()$label, "mixture(exgaussian)")
  expect_equal(
    rule_mixture(use_accuracy = TRUE)$label,
    "mixture(exgaussian, accuracy)"
  )
  expect_equal(rule_adaptive_trim()$label, "adaptive_trim(0.05, 0.5)")
  expect_equal(rule_adaptive_trim(0.1, 0.8)$label, "adaptive_trim(0.1, 0.8)")
  expect_equal(rule_ez_support()$label, "ez_support(1, refit)")
  expect_equal(rule_ez_support(0.8, refit = FALSE)$label, "ez_support(0.8)")
})

test_that("rule_mad() is a true alias for rule_sd(median, mad)", {
  expect_identical(
    rule_mad(2.5), rule_sd(2.5, center = "median", scale = "mad")
  )
  expect_identical(rule_mad(3), rule_sd(3, center = "median", scale = "mad"))
})

test_that("rule_cutoff() validates its bounds", {
  expect_error(rule_cutoff("a"), "must be a single")
  expect_error(rule_cutoff(c(1, 2)), "must be a single")
  expect_error(rule_cutoff(NA_real_), "must be a single")
  expect_error(rule_cutoff(-1), "must be a single")
  expect_error(rule_cutoff(-Inf), "must be a single")
  expect_error(rule_cutoff(1, 1), "'min' must be less than 'max'")
  expect_error(rule_cutoff(3, 0.18), "'min' must be less than 'max'")
  expect_silent(rule_cutoff(0.18, Inf))
})

test_that("rule_sd() validates n_sd, center and scale", {
  expect_error(rule_sd(0), "must be a single")
  expect_error(rule_sd(-1), "must be a single")
  expect_error(rule_sd(Inf), "must be a single")
  expect_error(rule_sd(NA_real_), "must be a single")
  expect_error(rule_sd(c(2, 3)), "must be a single")
  expect_error(rule_sd(2.5, center = "mode"))
  expect_error(rule_sd(2.5, scale = "range"))
})

test_that("rule_recursive() validates type and include_max", {
  expect_error(rule_recursive("nonrecursive"))
  bad_flag <- "must be TRUE or FALSE"
  expect_error(rule_recursive("moving", include_max = NA), bad_flag)
  expect_error(rule_recursive("moving", include_max = c(TRUE, TRUE)), bad_flag)
  expect_equal(rule_recursive()$type, "moving")
  expect_true(rule_recursive()$include_max)
})

test_that("rule_ewma() validates lambda, L and chance", {
  expect_error(rule_ewma(lambda = 0), "must be a single")
  expect_error(rule_ewma(lambda = 1.5), "must be a single")
  expect_error(rule_ewma(L = 0), "must be a single")
  expect_error(rule_ewma(L = -1), "must be a single")
  expect_error(rule_ewma(chance = 0), "must be a single")
  expect_error(rule_ewma(chance = 1), "must be a single")
  expect_silent(rule_ewma(lambda = 1, L = 3, chance = 0.25))
})

test_that("rule_adaptive_trim() validates q_cut and s_accept", {
  expect_error(rule_adaptive_trim(q_cut = 0), "must be a single")
  expect_error(rule_adaptive_trim(q_cut = 0.5), "must be a single")
  expect_error(rule_adaptive_trim(q_cut = -1), "must be a single")
  expect_error(rule_adaptive_trim(q_cut = NA_real_), "must be a single")
  expect_error(rule_adaptive_trim(q_cut = c(0.05, 0.1)), "must be a single")
  expect_error(rule_adaptive_trim(s_accept = 0), "must be a single")
  expect_error(rule_adaptive_trim(s_accept = -1), "must be a single")
  expect_error(rule_adaptive_trim(s_accept = Inf), "must be a single")
  expect_error(rule_adaptive_trim(s_accept = NA_real_), "must be a single")
  expect_silent(rule_adaptive_trim(0.499, 1.2))
})

test_that("rule_ez_support() validates c_ndt and refit", {
  expect_error(rule_ez_support(c_ndt = 0), "must be a single")
  expect_error(rule_ez_support(c_ndt = -1), "must be a single")
  expect_error(rule_ez_support(c_ndt = 1.5), "must be a single")
  expect_error(rule_ez_support(c_ndt = NA_real_), "must be a single")
  expect_error(rule_ez_support(c_ndt = c(0.8, 1)), "must be a single")
  expect_error(rule_ez_support(refit = NA), "must be TRUE or FALSE")
  expect_error(rule_ez_support(refit = c(TRUE, TRUE)), "must be TRUE or FALSE")
  expect_silent(rule_ez_support(1))
  expect_silent(rule_ez_support(0.8, refit = FALSE))
})

test_that("rule_mixture() validates its EM controls", {
  expect_error(rule_mixture(distribution = "gamma"))
  expect_error(rule_mixture(bound = "min"), "length 2")
  expect_error(rule_mixture(bound = c(1, 0.5)), "lower bound")
  expect_error(rule_mixture(bound = c("nope", "max")), "numeric or")
  expect_error(rule_mixture(chance = 0), "must be a single")
  expect_error(rule_mixture(init = 0), "must be a single")
  expect_error(rule_mixture(init = 1), "must be a single")
  expect_error(rule_mixture(max_prop = 0), "must be a single")
  expect_error(rule_mixture(max_prop = 1.5), "must be a single")
  expect_error(
    rule_mixture(init = 0.6, max_prop = 0.5),
    "'init' must be less than 'max_prop'"
  )
  expect_error(rule_mixture(maxit = 0), "must be a single")
  expect_error(rule_mixture(maxit = 2.5), "must be a single")
  expect_error(rule_mixture(tol = 0), "must be a single")
  expect_error(rule_mixture(use_accuracy = NA), "must be TRUE or FALSE")
  expect_silent(rule_mixture(bound = c(0.1, 5)))
  expect_silent(rule_mixture(bound = c("min", "max")))
})

test_that("print() reports the label and returns its input invisibly", {
  r <- rule_sd(2.5)
  expect_output(print(r), "sd\\(2\\.5, mean, sd\\)")
  expect_output(expect_invisible(print(r)))
  capture.output(vis <- withVisible(print(r)))
  expect_identical(vis$value, r)

  expect_output(print(rule_none()), "none")
  expect_output(print(rule_recursive("hybrid")), "recursive\\(hybrid\\)")
  expect_output(print(rule_ewma()), "ewma")
  expect_output(print(rule_mixture()), "mixture")
  expect_output(print(rule_cutoff(0.2, 2)), "cutoff")
  expect_output(print(rule_adaptive_trim()), "adaptive_trim\\(0\\.05, 0\\.5\\)")
  expect_output(print(rule_ez_support()), "ez_support\\(1, refit\\)")
})

test_that("rule_mixture() accepts the contaminant bounds as a list", {
  expect_equal(
    rule_mixture(bound = list(0.15, "max"))$bound,
    rule_mixture(bound = c(0.15, "max"))$bound
  )
  expect_equal(rule_mixture(bound = list(0.15, 3))$bound, c(0.15, 3))
  expect_error(rule_mixture(bound = list(0.15)), "length 2")
})
