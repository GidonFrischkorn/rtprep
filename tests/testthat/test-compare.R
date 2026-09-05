# screen_compare(): the question the package exists to make askable -- what
# would a different preprocessing choice have removed? Everything here is
# checked against rt_screen() run one rule at a time, because the comparison
# layer must not be a second implementation.

compare_fixture <- function(seed = 201) {
  set.seed(seed)
  c(
    runif(15, 0.08, 0.16), # fast contaminants
    rtprep:::.rexgauss(160, 0.45, 0.05, 0.15),
    runif(15, 2.5, 4.0) # slow contaminants
  )
}

standard_rules <- function() {
  list(
    cutoff = rule_cutoff(0.18, 3),
    sd = rule_sd(2.5),
    none = rule_none()
  )
}

test_that("the matrices have the documented shape and types", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = standard_rules())

  expect_s3_class(cmp, "rtprep_comparison")
  for (part in c("keep", "prob", "reason")) {
    expect_equal(dim(cmp[[part]]), c(length(rt), 3L), info = part)
    expect_equal(colnames(cmp[[part]]), c("cutoff", "sd", "none"), info = part)
  }
  expect_type(cmp$keep, "logical")
  expect_type(cmp$prob, "double")
  expect_type(cmp$reason, "character")
  expect_equal(cmp$n_trials, length(rt))
})

test_that("every column equals the rule run on its own", {
  # the comparison layer must not be a second implementation
  rt <- compare_fixture()
  rules <- standard_rules()
  cmp <- screen_compare(rt, rules = rules)

  for (nm in names(rules)) {
    single <- rt_screen(rt, rule = rules[[nm]])
    expect_equal(cmp$keep[, nm], single$.keep, info = nm)
    expect_equal(cmp$prob[, nm], single$.prob, info = nm)
    expect_equal(cmp$reason[, nm], single$.reason, info = nm)
  }
})

test_that("arguments are forwarded to rt_screen() unchanged", {
  rt <- compare_fixture()
  id <- rep(c("a", "b"), length.out = length(rt))

  cmp <- screen_compare(rt,
    rules = list(sd = rule_sd(2)), .by = id, threshold = 0.75
  )
  single <- rt_screen(rt, rule = rule_sd(2), .by = id, threshold = 0.75)
  expect_equal(cmp$keep[, "sd"], single$.keep)
  expect_equal(nrow(cmp$drops), 2L)
})

test_that("unnamed rules take their own labels", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = list(rule_cutoff(0.18, 3), rule_sd(2.5)))
  expect_equal(colnames(cmp$keep), c("cutoff(0.18, 3)", "sd(2.5, mean, sd)"))

  # and a partially named list fills only the gaps
  mixed <- screen_compare(
    rt,
    rules = list(mine = rule_cutoff(0.2, 3), rule_none())
  )
  expect_equal(colnames(mixed$keep), c("mine", "none"))
})

test_that("screen_compare() rejects a malformed roster", {
  rt <- compare_fixture()
  expect_error(screen_compare(rt, rules = list()), "non-empty list")
  expect_error(screen_compare(rt, rules = rule_sd(2)), "Did you mean list")
  expect_error(
    screen_compare(rt, rules = list(rule_sd(2), "nope")),
    "must be a rule object"
  )
  expect_error(
    screen_compare(rt, rules = list(a = rule_sd(2), a = rule_sd(3))),
    "must be unique"
  )
})

# --- drop table -------------------------------------------------------------

test_that("the drop table has one row per rule and group", {
  rt <- compare_fixture()
  id <- rep(c("a", "b"), length.out = length(rt))
  cmp <- screen_compare(rt, rules = standard_rules(), .by = id)

  expect_equal(nrow(cmp$drops), 6L)
  expect_setequal(cmp$drops$.rule, c("cutoff", "sd", "none"))
  expect_setequal(cmp$drops$.group, c("a", "b"))
  expect_true(all(c("too_fast", "too_slow") %in% names(cmp$drops)))
})

test_that("the drop counts match the keep matrix", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = standard_rules())

  for (nm in colnames(cmp$keep)) {
    row <- cmp$drops[cmp$drops$.rule == nm, ]
    expect_equal(row$n_dropped, sum(!cmp$keep[, nm]), info = nm)
    expect_equal(row$n_trials, length(rt), info = nm)
    expect_equal(row$prop_dropped, mean(!cmp$keep[, nm]), info = nm)
    # the reason columns have to add up to the drops
    expect_equal(row$too_fast + row$too_slow, row$n_dropped, info = nm)
  }
})

test_that("the reason columns are the union across rules", {
  # a rule that never flags anything fast still gets a zero, not a gap
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = list(
    slow_only = rule_cutoff(0, 3),
    both = rule_cutoff(0.18, 3)
  ))

  expect_true(all(c("too_fast", "too_slow") %in% names(cmp$drops)))
  expect_equal(cmp$drops$too_fast[cmp$drops$.rule == "slow_only"], 0L)
  expect_gt(cmp$drops$too_fast[cmp$drops$.rule == "both"], 0L)
})

# --- agreement --------------------------------------------------------------

test_that("agreement and Jaccard are hand-computable and can disagree", {
  # the case that matters: two rules that each drop a little and never the same
  # trial. Agreement is high, Jaccard is zero, and reporting agreement alone
  # would call them interchangeable.
  rt <- c(0.10, 0.12, 0.40, 0.45, 0.50, 0.55, 3.5, 4.0)
  cmp <- screen_compare(rt, rules = list(
    fast = rule_cutoff(0.18, Inf), # drops trials 1-2
    slow = rule_cutoff(0, 3) # drops trials 7-8
  ))

  pair <- cmp$agreement
  expect_equal(nrow(pair), 1L)
  expect_equal(pair$rule_x, "fast")
  expect_equal(pair$rule_y, "slow")
  expect_equal(pair$agree, 4 / 8) # they agree only on the four middle trials
  expect_equal(pair$jaccard, 0) # and never drop the same trial
  expect_equal(pair$n_only_x, 2L)
  expect_equal(pair$n_only_y, 2L)
  expect_equal(pair$n_both, 0L)
})

test_that("identical rules agree perfectly", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = list(a = rule_sd(2.5), b = rule_sd(2.5)))
  expect_equal(cmp$agreement$agree, 1)
  expect_equal(cmp$agreement$jaccard, 1)
})

test_that("Jaccard is NA, not 1, when neither rule drops anything", {
  # two empty sets have no overlap to report; calling it a perfect match would
  # make an empty comparison look like agreement
  rt <- c(0.4, 0.45, 0.5, 0.55)
  cmp <- screen_compare(rt, rules = list(a = rule_none(), b = rule_none()))

  expect_equal(cmp$agreement$agree, 1)
  expect_true(is.na(cmp$agreement$jaccard))
  expect_equal(cmp$agreement$n_both, 0L)
})

test_that("every rule pair appears exactly once", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = standard_rules())
  # three rules make three unordered pairs
  expect_equal(nrow(cmp$agreement), 3L)
  expect_equal(
    anyDuplicated(paste(cmp$agreement$rule_x, cmp$agreement$rule_y)), 0L
  )
})

test_that("one rule gives an empty agreement table with the right columns", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = list(rule_sd(2.5)))

  expect_equal(nrow(cmp$agreement), 0L)
  expect_equal(names(cmp$agreement), c(
    "rule_x", "rule_y", "agree", "jaccard", "n_only_x", "n_only_y", "n_both"
  ))
})

# --- fits -------------------------------------------------------------------

test_that("the stacked fits carry a rule column and every rule's diagnostics", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = list(
    cutoff = rule_cutoff(0.18, 3),
    sd = rule_sd(2.5)
  ))

  expect_true(".rule" %in% names(cmp$fits))
  expect_setequal(cmp$fits$.rule, c("cutoff", "sd"))
  expect_true(all(c("lower", "upper") %in% names(cmp$fits)))
})

# --- methods ----------------------------------------------------------------

test_that("print() names every rule and returns invisibly", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = standard_rules())

  out <- capture.output(print(cmp))
  for (nm in c("cutoff", "sd", "none")) {
    expect_true(any(grepl(nm, out, fixed = TRUE)), info = nm)
  }
  expect_true(any(grepl("least agreement", out)))
  expect_invisible(print(cmp))
})

test_that("summary() prints both tables and returns them invisibly", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = standard_rules())

  out <- capture.output(res <- summary(cmp))
  expect_true(any(grepl("Drop rates", out)))
  expect_true(any(grepl("Pairwise agreement", out)))
  expect_equal(res$drops, cmp$drops)
  expect_equal(res$agreement, cmp$agreement)
})

test_that("plot() works whether or not ggplot2 is installed", {
  rt <- compare_fixture()
  cmp <- screen_compare(rt, rules = standard_rules())

  if (requireNamespace("ggplot2", quietly = TRUE)) {
    p <- plot(cmp)
    expect_s3_class(p, "ggplot")
  }

  # and the base-graphics fallback must not error either: a plot method that
  # stops on a missing Suggests is a trap
  local_mocked_bindings(
    requireNamespace = function(...) FALSE, .package = "base"
  )
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  expect_invisible(plot(cmp))
})

test_that("the roster is the second positional argument", {
  rt <- compare_fixture()
  parts <- c("keep", "prob", "reason", "drops")
  expect_equal(
    screen_compare(rt, standard_rules())[parts],
    screen_compare(rt, rules = standard_rules())[parts]
  )
  # a response vector in the roster's position fails loudly
  expect_error(
    screen_compare(rt, rep(1, length(rt))), "non-empty list of rule objects"
  )
})

test_that("screen_compare() forwards the policy under its new name only", {
  rt <- compare_fixture()
  # rule_none() gives .prob = 1 everywhere, so the two policies part company
  # only at threshold = 1: the threshold policy drops every trial, the
  # probabilistic one keeps every trial. A silently dropped `policy` would
  # fall back to threshold and fail here.
  dropped <- screen_compare(rt, list(rule_none()), threshold = 1)
  kept <- screen_compare(
    rt, list(rule_none()),
    policy = "probabilistic", threshold = 1
  )
  expect_false(any(dropped$keep))
  expect_true(all(kept$keep))
  expect_error(
    screen_compare(rt, standard_rules(), keep = "threshold"), "unused argument"
  )
})
