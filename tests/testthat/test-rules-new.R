# rule_iqr() and rule_oracle().

test_that("rule_iqr() places Tukey's fences at type-7 quartiles", {
  set.seed(301)
  rt <- stats::rgamma(300, shape = 5, scale = 0.12) + 0.15
  fits <- screen_fits(rt, rule_iqr(1.5))
  q <- stats::quantile(rt, c(0.25, 0.75), names = FALSE, type = 7)

  expect_equal(fits$q1, q[1])
  expect_equal(fits$q3, q[2])
  expect_equal(fits$iqr, q[2] - q[1])
  expect_equal(fits$lower, q[1] - 1.5 * (q[2] - q[1]))
  expect_equal(fits$upper, q[2] + 1.5 * (q[2] - q[1]))

  scr <- rt_screen(rt, rule_iqr(1.5))
  expect_identical(scr$.keep, rt >= fits$lower & rt <= fits$upper)
  expect_identical(
    scr$.reason[!scr$.keep & rt < fits$lower],
    rep("too_fast", sum(!scr$.keep & rt < fits$lower))
  )
})

test_that("rule_iqr() fences are asymmetric on a skewed distribution", {
  set.seed(302)
  rt <- stats::rlnorm(2000, log(0.5), 0.4)
  fits <- screen_fits(rt, rule_iqr(1.5))
  centre <- stats::median(rt)
  # the right tail is longer, so the upper fence sits further from the median
  expect_gt(fits$upper - centre, centre - fits$lower)
})

test_that("a larger k removes no more than a smaller one", {
  set.seed(303)
  rt <- stats::rgamma(400, shape = 4, scale = 0.15)
  dropped <- vapply(c(1, 1.5, 3), function(k) {
    sum(!rt_screen(rt, rule_iqr(k))$.keep)
  }, integer(1))
  expect_true(all(diff(dropped) <= 0))
})

test_that("rule_iqr() removes nothing it cannot evaluate", {
  expect_true(all(rt_screen(c(0.3, 0.4, 2.9), rule_iqr())$.keep))
  expect_true(all(rt_screen(rep(0.5, 20), rule_iqr())$.keep))
  expect_true(is.na(screen_fits(rep(0.5, 20), rule_iqr())$upper))
  expect_error(rule_iqr(0), "must be a single number")
  expect_error(rule_iqr(-1), "must be a single number")
})

test_that("rule_oracle() removes exactly the contaminants and nothing else", {
  set.seed(304)
  d <- r_contaminated(400, process = "mixed", rate = 0.12)
  scr <- rt_screen(d$rt, rule_oracle(d$contaminant))

  expect_identical(scr$.keep, !d$contaminant)
  expect_equal(sum(!scr$.keep), sum(d$contaminant))
  # Youden's J is 1 by construction, which is what makes it the ceiling
  sens <- mean(!scr$.keep[d$contaminant])
  spec <- mean(scr$.keep[!d$contaminant])
  expect_equal(sens + spec - 1, 1)
  expect_identical(
    scr$.reason[d$contaminant], rep("contaminant", sum(d$contaminant))
  )
  expect_equal(screen_fits(d$rt, rule_oracle(d$contaminant))$n_contaminant,
    sum(d$contaminant),
    ignore_attr = TRUE
  )
})

test_that("rule_oracle() treats unlabelled trials as valid", {
  truth <- c(TRUE, FALSE, NA, TRUE, FALSE, NA, rep(FALSE, 10))
  rt <- seq(0.3, 0.9, length.out = length(truth))
  scr <- rt_screen(rt, rule_oracle(truth))
  expect_identical(scr$.keep[is.na(truth)], c(TRUE, TRUE))
  expect_true(all(is.na(scr$.reason[is.na(truth)])))
})

test_that("rule_oracle() accepts 0/1 and rejects anything else", {
  expect_s3_class(rule_oracle(c(0, 1, 0, 1)), "rtprep_rule")
  expect_error(rule_oracle(c("yes", "no")), "must be a logical vector")
  expect_error(rule_oracle(c(0, 1, 2)), "must be a logical vector")
})

test_that("the new rules print a description", {
  expect_match(
    paste(utils::capture.output(print(rule_iqr(1.5))), collapse = " "),
    "Tukey's fences"
  )
  expect_match(
    paste(utils::capture.output(print(rule_oracle(c(TRUE, FALSE)))),
      collapse = " "
    ),
    "ground truth"
  )
})
