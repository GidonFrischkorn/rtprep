# Composition. The claim tests here are the algebra (idempotence, identity) and
# the equivalence with trimr's published two-stage idiom; both were checked by
# mutation, breaking the implementation and confirming they go red.

roster <- function() {
  list(
    cutoff = rule_cutoff(0.2, 2),
    sd = rule_sd(2.5),
    mad = rule_mad(2.5),
    iqr = rule_iqr(1.5),
    recursive = rule_recursive("modified"),
    mixture = rule_mixture("lognormal")
  )
}

test_that("a combination needs at least two rules, and they must be rules", {
  expect_error(rule_all(rule_sd(2.5)), "at least two rules")
  expect_error(rule_any(), "at least two rules")
  expect_error(rule_all(rule_sd(2.5), "mad"), "must be a rule object")
})

test_that("rule_all() is idempotent and rule_none() is its identity", {
  set.seed(101)
  d <- r_contaminated(300, process = "mixed", rate = 0.1)
  for (nm in names(roster())) {
    r <- roster()[[nm]]
    once <- rt_screen(d$rt, r, response = d$response)
    twice <- rt_screen(d$rt, rule_all(r, r), response = d$response)
    expect_equal(twice$.prob, once$.prob, info = nm)

    with_none <- rt_screen(d$rt, rule_all(rule_none(), r), response = d$response)
    expect_equal(with_none$.prob, once$.prob, info = nm)

    staged <- rt_screen(
      d$rt, rule_then(rule_none(), r),
      response = d$response
    )
    expect_equal(staged$.prob, once$.prob, info = nm)
  }
})

test_that("all() takes the minimum probability and any() the maximum", {
  set.seed(102)
  d <- r_contaminated(200, process = "mixed", rate = 0.1)
  a <- rule_mixture("lognormal")
  b <- rule_sd(2)
  pa <- rt_screen(d$rt, a)$.prob
  pb <- rt_screen(d$rt, b)$.prob

  expect_equal(rt_screen(d$rt, rule_all(a, b))$.prob, pmin(pa, pb))
  expect_equal(rt_screen(d$rt, rule_any(a, b))$.prob, pmax(pa, pb))
  # a continuous component keeps its posterior where nothing vetoes it
  untouched <- pb == 1
  expect_equal(
    rt_screen(d$rt, rule_all(a, b))$.prob[untouched], pa[untouched]
  )
})

test_that("all() removes the union and any() the intersection", {
  set.seed(103)
  d <- r_contaminated(300, process = "mixed", rate = 0.1)
  ka <- rt_screen(d$rt, rule_mad(2.5))$.keep
  kb <- rt_screen(d$rt, rule_cutoff(0.25, 1.5))$.keep

  expect_identical(
    rt_screen(d$rt, rule_all(rule_mad(2.5), rule_cutoff(0.25, 1.5)))$.keep,
    ka & kb
  )
  expect_identical(
    rt_screen(d$rt, rule_any(rule_mad(2.5), rule_cutoff(0.25, 1.5)))$.keep,
    ka | kb
  )
})

test_that("rule_then() fits each stage on the survivors of the last", {
  set.seed(104)
  rt <- c(runif(15, 0.05, 0.19), rnorm(150, 0.55, 0.1), runif(35, 2.5, 5))

  staged <- rt_screen(rt, rule_then(rule_cutoff(0.2), rule_sd(2.5)))
  parallel <- rt_screen(rt, rule_all(rule_cutoff(0.2), rule_sd(2.5)))

  # the fast trials still inflate the standard deviation when both rules see
  # the raw data, so the two are not the same operation
  expect_false(identical(staged$.keep, parallel$.keep))

  # stage 2's criterion is the one computed on stage 1's survivors
  survivors <- rt[rt_screen(rt, rule_cutoff(0.2))$.keep]
  alone <- screen_fits(survivors, rule_sd(2.5))
  fits <- screen_fits(rt, rule_then(rule_cutoff(0.2), rule_sd(2.5)))
  expect_equal(fits$r2_lower, alone$lower)
  expect_equal(fits$r2_upper, alone$upper)
  expect_equal(fits$r2_n_seen, length(survivors))
})

test_that("a composite reports each stage's diagnostics under its own prefix", {
  fits <- screen_fits(
    rt_example$rt, rule_then(rule_cutoff(0.2), rule_sd(2.5)),
    .by = rt_example$id
  )
  expect_true(all(
    c("r1_lower", "r1_n_seen", "r1_n_flagged", "r2_center", "r2_n_seen") %in%
      names(fits)
  ))
  # the engine's own bookkeeping still comes first
  expect_identical(
    names(fits)[1:4], c(".group", "n_trials", "n_dropped", "prop_dropped")
  )
  expect_equal(fits$n_dropped, fits$r1_n_flagged + fits$r2_n_flagged)
})

test_that("a convergence warning still fires from inside a composite", {
  set.seed(105)
  rt <- stats::rnorm(30, 0.5, 0.05)
  hard <- rule_mixture("exgaussian", maxit = 2)

  expect_warning(rt_screen(rt, hard), "did not converge")
  expect_warning(rt_screen(rt, rule_all(hard, rule_sd(2.5))), "did not converge")
  expect_warning(
    rt_screen(rt, rule_then(rule_sd(3), hard)), "did not converge"
  )
})

test_that("a composite inherits its components' need for response", {
  expect_error(
    rt_screen(rt_example$rt, rule_all(rule_ewma(), rule_sd(2.5))),
    "requires 'response'"
  )
  expect_silent(
    rt_screen(
      rt_example$rt, rule_all(rule_ewma(), rule_sd(2.5)),
      response = rt_example$response
    )
  )
})

test_that("composites nest and carry a per-trial component through grouping", {
  set.seed(106)
  d <- r_contaminated(200, process = "mixed", rate = 0.1)
  d$id <- rep(1:4, each = 50)

  nested <- rule_all(rule_cutoff(0.2), rule_any(rule_sd(3), rule_mad(3)))
  expect_s3_class(rt_screen(d$rt, nested, .by = d$id), "data.frame")

  # the oracle's truth vector is subset to each group, not recycled
  with_truth <- rule_any(rule_oracle(d$contaminant), rule_none())
  expect_identical(
    rt_screen(d$rt, rule_all(rule_oracle(d$contaminant), rule_none()),
      .by = d$id
    )$.keep,
    !d$contaminant
  )
  expect_true(all(rt_screen(d$rt, with_truth, .by = d$id)$.keep))
})

test_that("print() lists the components", {
  out <- utils::capture.output(print(rule_then(rule_cutoff(0.2), rule_sd(2.5))))
  expect_match(paste(out, collapse = " "), "1\\. cutoff")
  expect_match(paste(out, collapse = " "), "2\\. sd")
})
