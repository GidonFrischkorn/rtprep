# Engine regression net.
#
# rt_screen() is one loop over groups shared by every rule, so a change to the
# group bookkeeping can move an answer for a rule nobody was thinking about.
# This file freezes what the engine returns for the whole roster on one
# seed-fixed data set and compares against it. It is not a correctness test --
# the per-rule files own that -- it is what makes refactoring the engine safe.
#
# The fixture was produced by the shipped engine and must survive every
# refactor unchanged. Regenerate it -- by loading the package and running
# fixtures/make-engine-reference.R -- only when a change to a rule's answer is
# intended and has been reviewed.
#
# (test code is not package code; the no-set.seed rule binds R/.)

reference <- readRDS(test_path("fixtures", "screen-engine-reference.rds"))

test_that("the fixture is the data set this file builds", {
  expect_equal(.engine_data(), reference$data)
})

test_that("every rule returns the frozen per-trial columns and fits", {
  d <- reference$data
  for (nm in names(reference$screens)) {
    got <- .engine_screen(d, .engine_roster()[[nm]])
    want <- reference$screens[[nm]]

    expect_equal(got$.keep, want$.keep, info = nm)
    expect_equal(got$.prob, want$.prob, info = nm)
    expect_equal(got$.rule, want$.rule, info = nm)
    expect_equal(got$.reason, want$.reason, info = nm)
    expect_equal(attr(got, "fits"), want$fits, info = nm)
  }
})

test_that("screen_compare() returns the frozen tables", {
  d <- reference$data
  cmp <- .engine_comparison(d)
  expect_equal(cmp$keep, reference$comparison$keep)
  expect_equal(cmp$prob, reference$comparison$prob)
  expect_equal(cmp$reason, reference$comparison$reason)
  expect_equal(cmp$drops, reference$comparison$drops)
  expect_equal(cmp$agreement, reference$comparison$agreement)
  expect_equal(cmp$fits, reference$comparison$fits)
})

# No rule currently in the package reports different columns for different
# groups, so the fits table's padding contract is not exercised by the roster
# above. It is still a contract -- a rule whose fit depends on which branch it
# took would hit it -- so it is tested directly.
test_that("the fits table pads groups and columns the rule did not report", {
  fits <- list(
    data.frame(lower = 0.2, upper = 2.5),
    NULL,
    data.frame(lower = 0.3, upper = 2.1, converged = TRUE)
  )
  out <- rtprep:::.fill_fits(fits)

  expect_equal(names(out), c("lower", "upper", "converged"))
  expect_equal(out$lower, c(0.2, NA, 0.3))
  expect_equal(out$upper, c(2.5, NA, 2.1))
  expect_equal(out$converged, c(NA, NA, TRUE))
  expect_equal(nrow(out), 3L)
})

test_that("a rule reporting nothing leaves only the bookkeeping columns", {
  expect_null(rtprep:::.fill_fits(list(NULL, NULL)))

  scr <- rt_screen(c(0.3, 0.5, 0.9), rule = rule_none(), .by = c(1, 1, 2))
  expect_named(
    attr(scr, "fits"),
    c(".group", "n_trials", "n_dropped", "prop_dropped")
  )
})

test_that("the comparison tables are empty when every group key is missing", {
  cmp <- screen_compare(
    c(0.3, 0.4),
    rules = list(sd = rule_sd(2), none = rule_none()),
    .by = c(NA, NA)
  )

  for (tbl in list(cmp$drops, cmp$fits)) {
    expect_s3_class(tbl, "data.frame")
    expect_equal(nrow(tbl), 0L)
  }
  expect_type(cmp$fits$n_trials, "integer")
  expect_type(cmp$fits$prop_dropped, "double")
  expect_false(any(cmp$keep))
})

# The engine used to rescan the full trial vector once per group, which is
# O(n x groups) and put an applied user with a few thousand participants at
# minutes per call. This is a regression guard on that, not a benchmark: the
# budget is loose enough to survive a slow machine and tight enough that the
# quadratic version (188 s at 10,000 groups, 8.8 s at 2,000) cannot pass.
test_that("screening stays linear in the number of groups", {
  skip_on_cran()
  skip_on_ci()

  n_groups <- 5000L
  n_trials <- 100L
  rt <- rep(seq(0.2, 1.4, length.out = n_trials), times = n_groups)
  id <- rep(seq_len(n_groups), each = n_trials)

  elapsed <- system.time(
    scr <- rt_screen(rt, rule = rule_sd(2.5), .by = id)
  )[["elapsed"]]

  expect_equal(nrow(scr), n_groups * n_trials)
  expect_equal(nrow(attr(scr, "fits")), n_groups)
  expect_lt(elapsed, 5)
})
