# The hierarchical screen and the cross-group engine path it uses.
#
# The two limit tests are the rule's characterising properties, promoted here
# from scripts/04_conformance_checks.R.

grouped_data <- function(seed = 21) {
  set.seed(seed)
  do.call(rbind, lapply(1:12, function(i) {
    x <- r_contaminated(
      sample(c(30, 80, 200), 1),
      process = "mixed", rate = 0.08
    )
    x$id <- paste0("s", i)
    x
  }))
}

test_that("n0 = 0 reproduces the same criterion estimated within each group", {
  d <- grouped_data()
  expect_identical(
    rt_screen(d$rt, rule_hierarchical(2.5, n0 = 0), .by = d$id)$.keep,
    rt_screen(d$rt, rule_sd(2.5), .by = d$id)$.keep
  )
  expect_identical(
    rt_screen(
      d$rt, rule_hierarchical(2.5, n0 = 0, center = "median", scale = "mad"),
      .by = d$id
    )$.keep,
    rt_screen(d$rt, rule_mad(2.5), .by = d$id)$.keep
  )
})

test_that("n0 = Inf gives every group one common criterion", {
  d <- grouped_data()
  fits <- screen_fits(d$rt, rule_hierarchical(2.5, n0 = Inf), .by = d$id)
  expect_equal(length(unique(round(fits$lower, 10))), 1L)
  expect_equal(length(unique(round(fits$upper, 10))), 1L)
  expect_true(all(fits$weight == 0))
})

test_that("shrinkage moves each group between its own value and the pooled one", {
  d <- grouped_data()
  fits <- screen_fits(d$rt, rule_hierarchical(2.5, n0 = 20), .by = d$id)

  pooled <- mean(fits$center_group)
  between <- (fits$center - pmin(fits$center_group, pooled)) >= -1e-9 &
    (pmax(fits$center_group, pooled) - fits$center) >= -1e-9
  expect_true(all(between))

  # a group with more trials is shrunk less
  expect_true(all(diff(fits$weight[order(
    vapply(split(d$rt, d$id), length, integer(1))[fits$.group]
  )]) >= -1e-9))
})

test_that("only a cross-group rule takes the cross-group path", {
  expect_false(.is_grouped_rule(rule_sd(2.5)))
  expect_false(.is_grouped_rule(rule_mixture()))
  expect_true(.is_grouped_rule(rule_hierarchical()))
  # a composite is cross-group exactly when one of its components is
  expect_false(.is_grouped_rule(rule_all(rule_sd(2.5), rule_mad(2.5))))
  expect_true(.is_grouped_rule(rule_all(rule_hierarchical(), rule_sd(2.5))))
})

test_that("a group whose own spread is unusable pools completely", {
  rt <- c(rep(0.5, 3), rnorm(60, 0.55, 0.08), rnorm(60, 0.6, 0.09))
  id <- c(rep("tied", 3), rep("a", 60), rep("b", 60))
  fits <- screen_fits(rt, rule_hierarchical(2.5, n0 = 20), .by = id)

  tied <- fits[fits$.group == "tied", ]
  expect_equal(tied$weight, 0)
  expect_false(is.na(tied$upper))
})

test_that("with nothing usable anywhere, nothing is removed", {
  rt <- rep(0.5, 12)
  id <- rep(c("a", "b"), each = 6)
  scr <- rt_screen(rt, rule_hierarchical(2.5), .by = id)
  expect_true(all(scr$.keep))
  expect_true(all(scr$.prob == 1))
})

test_that("missing response times do not shift the groups a cross-group rule sees", {
  d <- grouped_data()
  d$rt[c(5, 50, 300)] <- NA
  scr <- rt_screen(d$rt, rule_hierarchical(2.5), .by = d$id)

  expect_identical(scr$.reason[c(5, 50, 300)], rep("missing", 3))
  expect_false(any(scr$.keep[c(5, 50, 300)]))
  # the surviving trials get the same answer as if the NAs had never been there
  complete <- !is.na(d$rt)
  bare <- rt_screen(d$rt[complete], rule_hierarchical(2.5), .by = d$id[complete])
  expect_equal(scr$.prob[complete], bare$.prob)
})
