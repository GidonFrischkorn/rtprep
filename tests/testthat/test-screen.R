# The engine's contract is the package's reason to exist: whatever rule goes in,
# the same four per-trial columns come out, in input order, one row per input
# trial. These tests pin that contract down independently of any rule's maths.

rt_fixture <- function() {
  c(0.10, 0.32, 0.35, 0.38, 0.41, 0.44, 0.47, 0.50, 0.55, 4.00)
}

test_that("the return object has the documented shape and types", {
  rt <- rt_fixture()
  out <- rt_screen(rt, rule = rule_cutoff(0.18, 3))

  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), length(rt))
  expect_equal(names(out), c(".keep", ".prob", ".rule", ".reason"))
  expect_type(out$.keep, "logical")
  expect_type(out$.prob, "double")
  expect_type(out$.rule, "character")
  expect_type(out$.reason, "character")
  expect_equal(unique(out$.rule), "cutoff(0.18, 3)")
  expect_equal(attr(out, "row.names"), seq_along(rt))
})

test_that("deterministic rules return probabilities of exactly 0 or 1", {
  out <- rt_screen(rt_fixture(), rule = rule_sd(2))
  expect_true(all(out$.prob %in% c(0, 1)))
})

test_that("the threshold moves the keep set as documented", {
  # hybrid is the one rule whose .prob lands on 0.5, so it is where a threshold
  # actually bites. Assert the keep sets, not the expression that produced them.
  rt <- c(0.30, 0.32, 0.34, 0.36, 0.38, 0.40, 0.42, 0.44, 0.60, 4.00)
  out <- rt_screen(rt, rule = rule_recursive("hybrid"))
  half <- out$.prob == 0.5
  expect_true(any(out$.prob == 0), info = "fixture needs a rejected trial")

  # below 0.5 the disputed trials survive; at or above it they do not
  lenient <- rt_screen(rt, rule = rule_recursive("hybrid"), threshold = 0.25)
  strict <- rt_screen(rt, rule = rule_recursive("hybrid"), threshold = 0.75)
  expect_equal(lenient$.keep, out$.prob >= 0.5)
  expect_equal(strict$.keep, out$.prob == 1)
  expect_true(all(lenient$.keep[half]))
  expect_false(any(strict$.keep[half]))

  # threshold = 1 drops everything, threshold = 0 keeps whatever the rule did
  # not reject outright
  expect_false(any(rt_screen(rt, rule = rule_none(), threshold = 1)$.keep))
  expect_equal(
    rt_screen(rt, rule = rule_recursive("hybrid"), threshold = 0)$.keep,
    out$.prob > 0
  )
})

test_that("a kept trial never carries a reason", {
  rt <- c(0.30, 0.35, 0.40, 0.45, 5.0)
  # threshold = 1 drops trials the rule never flagged: they are dropped by the
  # policy, so they carry no rule reason
  out <- rt_screen(rt, rule = rule_cutoff(0.18, 3), threshold = 1)
  expect_false(any(out$.keep))
  expect_equal(out$.reason, c(NA, NA, NA, NA, "too_slow"))

  # and under any policy, .reason is NA wherever .keep is TRUE
  for (th in c(0, 0.25, 0.5)) {
    scr <- rt_screen(rt, rule = rule_recursive("hybrid"), threshold = th)
    expect_true(all(is.na(scr$.reason[scr$.keep])))
  }
})

test_that("the probabilistic policy matches threshold for 0/1 rules", {
  rt <- rt_fixture()
  det <- rt_screen(rt, rule = rule_cutoff(0.18, 3))
  prob <- rt_screen(rt, rule = rule_cutoff(0.18, 3), keep = "probabilistic")
  expect_equal(prob$.keep, det$.keep)
  expect_equal(prob$.prob, det$.prob)
})

test_that("input order is preserved for grouped input", {
  rt <- c(0.3, 5.0, 0.4, 0.35, 6.0, 0.45)
  id <- c("b", "a", "a", "b", "b", "a")

  out <- rt_screen(rt, rule = rule_cutoff(0.18, 3), .by = id)
  expect_equal(out$.keep, rt >= 0.18 & rt <= 3)

  # a rule whose statistics are group-dependent must give the same answer
  # whether or not the rows arrive sorted by group
  ord <- order(id)
  sorted <- rt_screen(rt[ord], rule = rule_sd(1.5), .by = id[ord])
  unsorted <- rt_screen(rt, rule = rule_sd(1.5), .by = id)
  expect_equal(unsorted$.keep[ord], sorted$.keep)
})

test_that(".by accepts vectors, factors, lists and data frames", {
  rt <- rep(c(0.3, 0.4, 0.5, 3.0), 4)
  a <- rep(c("x", "y"), each = 8)
  b <- rep(c("p", "q"), 8)

  ref <- rt_screen(rt, rule = rule_sd(1.5), .by = interaction(a, b))
  expect_equal(
    rt_screen(rt, rule = rule_sd(1.5), .by = list(a, b))$.keep,
    ref$.keep
  )
  expect_equal(
    rt_screen(rt, rule = rule_sd(1.5), .by = data.frame(a = a, b = b))$.keep,
    ref$.keep
  )
  expect_equal(
    rt_screen(rt, rule = rule_sd(1.5), .by = factor(a))$.keep,
    rt_screen(rt, rule = rule_sd(1.5), .by = a)$.keep
  )
})

test_that("groups are screened independently", {
  # the 0.90 is extreme within its own group but unremarkable once the slower
  # group is pooled in, so grouping has to change the answer
  fast <- c(seq(0.30, 0.39, length.out = 10), 0.90)
  slow <- seq(1.00, 1.09, length.out = 10)
  rt <- c(fast, slow)
  id <- rep(c("fast", "slow"), c(11, 10))

  grouped <- rt_screen(rt, rule = rule_sd(1.5), .by = id)
  pooled <- rt_screen(rt, rule = rule_sd(1.5))

  expect_false(grouped$.keep[11])
  expect_true(all(grouped$.keep[-11]))
  expect_true(all(pooled$.keep))
})

test_that("missing RTs are flagged and left out of the statistics", {
  rt <- c(0.3, NA, 0.4, 0.5, 0.45, 0.35)
  out <- rt_screen(rt, rule = rule_sd(2))

  expect_false(out$.keep[2])
  expect_true(is.na(out$.prob[2]))
  expect_equal(out$.reason[2], "missing")

  # the remaining rows must match a screen run on the complete data alone
  complete <- rt_screen(rt[-2], rule = rule_sd(2))
  expect_equal(out$.prob[-2], complete$.prob)
})

test_that("a group of only missing RTs does not error", {
  rt <- c(NA_real_, NA_real_, 0.3, 0.4)
  id <- c("a", "a", "b", "b")
  out <- rt_screen(rt, rule = rule_sd(2), .by = id)

  expect_equal(out$.reason[1:2], c("missing", "missing"))
  expect_false(any(out$.keep[1:2]))
  fits <- attr(out, "fits")
  expect_equal(fits$n_trials[fits$.group == "a"], 0L)
})

test_that("missing group keys are treated as missing trials", {
  rt <- c(0.3, 0.4, 0.5, 0.6)
  id <- c("a", NA, "a", "a")
  out <- rt_screen(rt, rule = rule_cutoff(0.18, 3), .by = id)

  expect_equal(out$.reason[2], "missing")
  expect_false(out$.keep[2])
  expect_true(is.na(out$.prob[2]))
})

test_that("group order follows the grouping variable, not its text", {
  rt <- rep(c(0.3, 0.4, 0.5), 4)
  ids <- rep(c(2, 10, 1, 20), each = 3)
  fits <- attr(rt_screen(rt, rule = rule_cutoff(0.18, 3), .by = ids), "fits")
  expect_equal(fits$.group, c("1", "2", "10", "20"))

  g <- factor(rep(c("low", "med", "high"), each = 4),
    levels = c("low", "med", "high")
  )
  fits <- attr(
    rt_screen(rep(c(0.3, 0.4, 0.5, 0.6), 3), rule = rule_none(), .by = g),
    "fits"
  )
  expect_equal(fits$.group, c("low", "med", "high"))
})

test_that("grouping cells containing a dot are not pooled together", {
  rt <- c(0.30, 0.35, 5.0, 0.40, 0.45, 6.0)
  a <- c("a.b", "a.b", "a.b", "a", "a", "a")
  b <- c("c", "c", "c", "b.c", "b.c", "b.c")
  fits <- attr(
    rt_screen(rt, rule = rule_cutoff(0.18, 3), .by = list(a, b)), "fits"
  )
  expect_equal(nrow(fits), 2L)
})

test_that("the fits attribute has one documented row per group", {
  rt <- c(0.3, 0.4, 5.0, 0.35, 0.45, 6.0)
  id <- c("a", "a", "a", "b", "b", "b")
  out <- rt_screen(rt, rule = rule_cutoff(0.18, 3), .by = id)
  fits <- attr(out, "fits")

  expect_s3_class(fits, "data.frame")
  expect_equal(nrow(fits), 2L)
  expect_true(all(
    c(".group", "n_trials", "n_dropped", "prop_dropped") %in% names(fits)
  ))
  expect_equal(fits$.group, c("a", "b"))
  expect_equal(fits$n_trials, c(3L, 3L))
  expect_equal(fits$n_dropped, c(1L, 1L))
  expect_equal(fits$prop_dropped, c(1 / 3, 1 / 3))

  ungrouped <- attr(rt_screen(rt, rule = rule_cutoff(0.18, 3)), "fits")
  expect_equal(ungrouped$.group, "all")
  expect_equal(ungrouped$n_trials, 6L)
})

test_that("rt_screen() rejects malformed input", {
  rt <- rt_fixture()

  expect_error(rt_screen("a", rule = rule_none()), "must be a numeric vector")
  expect_error(rt_screen(numeric(0), rule = rule_none()), "has length 0")
  expect_error(rt_screen(rt, rule = "sd"), "must be a rule object")
  expect_error(rt_screen(rt, rule = rule_sd), "must be a rule object")
  expect_error(
    rt_screen(rt, response = 1:3, rule = rule_none()), "same length as"
  )
  expect_error(rt_screen(rt, rule = rule_none(), .by = 1:3), "same length as")
  expect_error(
    rt_screen(rt, rule = rule_none(), threshold = 2), "between 0 and 1"
  )
  expect_error(
    rt_screen(rt, rule = rule_none(), threshold = NA), "between 0 and 1"
  )
  expect_error(rt_screen(c(0.3, 0), rule = rule_none()), "Non-positive RT")
  expect_error(rt_screen(c(0.3, -1), rule = rule_none()), "Non-positive RT")
  expect_error(rt_screen(rt, rule = rule_ewma()), "requires 'response'")
})

test_that("implausibly large RTs warn about seconds versus milliseconds", {
  expect_warning(rt_screen(c(300, 400, 500), rule = rule_none()), "seconds")
})

test_that("rule_none() keeps everything", {
  rt <- c(0.001, 0.3, 9.9)
  out <- suppressWarnings(rt_screen(rt, rule = rule_none()))
  expect_true(all(out$.keep))
  expect_equal(out$.prob, rep(1, 3))
  expect_true(all(is.na(out$.reason)))
})

test_that("the mixture rule is not applicable until milestone 2", {
  # flipped by milestone 2, which implements apply_rule.rtprep_rule_mixture()
  expect_error(
    rt_screen(rt_fixture(), rule = rule_mixture()),
    "not yet implemented"
  )
  # and it must fail even when there is nothing to apply it to
  expect_error(
    rt_screen(c(NA_real_, NA_real_), rule = rule_mixture()),
    "not yet implemented"
  )
})

test_that("a missing response is treated as a missing trial", {
  # left unchecked, one NA propagates through the EWMA recursion and silently
  # switches the rule off for the whole group
  d <- data.frame(
    rt = c(seq(0.10, 0.19, length.out = 40), seq(0.50, 0.80, length.out = 60)),
    correct = c(rep(c(1, 0), length.out = 40), rep(1, 60))
  )
  full <- rt_screen(d$rt, d$correct, rule = rule_ewma(lambda = 0.05))

  d$correct[3] <- NA
  holed <- rt_screen(d$rt, d$correct, rule = rule_ewma(lambda = 0.05))

  expect_equal(holed$.reason[3], "missing")
  expect_false(holed$.keep[3])
  expect_true(is.na(holed$.prob[3]))
  # the rule still fires on the trials that do have a response
  expect_gt(sum(!holed$.keep), 0.9 * sum(!full$.keep))

  # a rule that ignores accuracy is unaffected by a missing one
  expect_equal(
    rt_screen(d$rt, d$correct, rule = rule_cutoff(0.18, 3))$.keep,
    d$rt >= 0.18 & d$rt <= 3
  )
})

test_that("fits is an empty data frame when every group key is missing", {
  out <- rt_screen(c(0.3, 0.4), rule = rule_sd(2), .by = c(NA, NA))
  fits <- attr(out, "fits")
  expect_s3_class(fits, "data.frame")
  expect_equal(nrow(fits), 0L)
  expect_true(all(
    c(".group", "n_trials", "n_dropped", "prop_dropped") %in% names(fits)
  ))
  expect_false(any(out$.keep))
})
