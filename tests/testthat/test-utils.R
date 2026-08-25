# The internal helpers are where a silent wrong answer would start: a response
# coding read the wrong way round, two grouping cells collapsed into one, a
# non-finite RT that disables a rule instead of tripping it.

# --- .as_upper --------------------------------------------------------------

test_that(".as_upper() accepts the documented codings", {
  expect_equal(rtprep:::.as_upper(c(1, 0, 1)), c(TRUE, FALSE, TRUE))
  expect_equal(rtprep:::.as_upper(c(TRUE, FALSE)), c(TRUE, FALSE))
  expect_equal(
    rtprep:::.as_upper(c("correct", "error", "upper", "lower")),
    c(TRUE, FALSE, TRUE, FALSE)
  )
  expect_equal(
    rtprep:::.as_upper(factor(c("Correct", "ERROR"))),
    c(TRUE, FALSE)
  )
  expect_equal(
    rtprep:::.as_upper(c("yes", "no", "hit", "miss")),
    c(TRUE, FALSE, TRUE, FALSE)
  )
})

test_that(".as_upper() keeps missing responses missing", {
  expect_equal(rtprep:::.as_upper(c(1, NA, 0)), c(TRUE, NA, FALSE))
  expect_equal(rtprep:::.as_upper(c("correct", NA)), c(TRUE, NA))
})

test_that(".as_upper() refuses codings it would silently misread", {
  # 1 = error / 2 = correct is a common export, and as.logical() would read the
  # whole column as correct
  expect_error(rtprep:::.as_upper(c(1, 2, 2, 1)), "coded 0/1")
  expect_error(rtprep:::.as_upper(c(-1, 1)), "coded 0/1")
  expect_error(
    rtprep:::.as_upper(c("maybe", "correct")), "Unrecognized response"
  )
  expect_error(rtprep:::.as_upper(list(1, 2)), "must be numeric, logical")
})

# --- .check_rt --------------------------------------------------------------

test_that(".check_rt() rejects what no rule could handle", {
  expect_error(rtprep:::.check_rt("a"), "must be a numeric vector")
  expect_error(rtprep:::.check_rt(matrix(c(0.3, 0.4), 1, 2)), "numeric vector")
  expect_error(rtprep:::.check_rt(numeric(0)), "has length 0")
  expect_error(rtprep:::.check_rt(c(0.3, 0)), "Non-positive")
  expect_error(rtprep:::.check_rt(c(0.3, -1)), "Non-positive")
  expect_error(rtprep:::.check_rt(c(0.3, Inf)), "Infinite")
  expect_warning(rtprep:::.check_rt(c(0.3, 500)), "seconds")
  expect_silent(rtprep:::.check_rt(c(0.3, NA, 0.4)))
})

test_that("an infinite RT is an error rather than a disabled rule", {
  # left unchecked this makes sd() non-finite, the rule bails out, and the
  # offending trial survives alongside every genuine outlier
  rt <- c(seq(0.30, 0.50, length.out = 20), 3.0, Inf)
  expect_error(rt_screen(rt, rule = rule_sd(2.5)), "Infinite")
  expect_error(rt_screen(rt, rule = rule_recursive("moving")), "Infinite")
})

# --- .group_key -------------------------------------------------------------

test_that(".group_key() labels a single group when .by is NULL", {
  key <- rtprep:::.group_key(NULL, 3)
  expect_equal(key$id, c(1L, 1L, 1L))
  expect_equal(key$labels, "all")
})

test_that(".group_key() keeps cells apart when labels contain the separator", {
  # pasting with "." would make both rows the key "a.b.c"
  key <- rtprep:::.group_key(list(c("a.b", "a"), c("c", "b.c")), 2)
  expect_length(unique(key$id), 2L)
  expect_length(key$labels, 2L)
  expect_setequal(key$labels, c("a.b.c", "a.b.c"))
})

test_that(".group_key() orders numeric group keys numerically", {
  key <- rtprep:::.group_key(c(2, 10, 1, 20), 4)
  expect_equal(key$labels, c("1", "2", "10", "20"))
  expect_equal(key$id, c(2L, 3L, 1L, 4L))
})

test_that(".group_key() respects existing factor levels", {
  g <- factor(rep(c("low", "med", "high"), each = 2),
    levels = c("low", "med", "high")
  )
  expect_equal(rtprep:::.group_key(g, 6)$labels, c("low", "med", "high"))
})

test_that(".group_key() propagates missing components", {
  key <- rtprep:::.group_key(list(c("a", NA, "a"), c("x", "x", "x")), 3)
  expect_true(is.na(key$id[2]))
  expect_false(any(is.na(key$id[-2])))
})

test_that(".group_key() rejects a malformed grouping", {
  expect_error(rtprep:::.group_key(1:3, 10), "same length as")
  expect_error(rtprep:::.group_key(list(), 3), "at least one")
  expect_error(
    rt_screen(c(0.3, 0.4), rule = rule_none(), .by = list()),
    "at least one"
  )
})

# --- bounds -----------------------------------------------------------------

test_that("bounds are inclusive on both sides", {
  expect_equal(rtprep:::.prob_from_bounds(c(1, 2, 3), 1, 3), c(1, 1, 1))
  expect_equal(rtprep:::.prob_from_bounds(c(0.9, 3.1), 1, 3), c(0, 0))
  expect_equal(
    rtprep:::.reason_from_bounds(c(0.9, 1, 3, 3.1), 1, 3),
    c("too_fast", NA, NA, "too_slow")
  )
})
