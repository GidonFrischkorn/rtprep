# The function route: new_rule(fun = ) and rule_custom(). A rule carries its own
# screening function instead of a registered method, so the tests here are the
# ones a user's rule would have to pass -- every return shape, every way the
# engine can hand the function what it asked for, and every consumer.
#
# test-extend.R stays the guard for the method route; the two must not diverge,
# which is what the equivalence test at the bottom of this file checks.

contaminated <- function(n = 200, groups = 4) {
  withr::local_seed(201)
  d <- r_contaminated(n, process = "mixed", rate = 0.1)
  d$id <- rep(seq_len(groups), each = n / groups)
  d
}

# --- the three return shapes ------------------------------------------------

test_that("a logical return keeps TRUE and flags FALSE", {
  d <- contaminated()
  r <- rule_custom("fast", function(rt, cut) rt > cut, cut = 0.6,
                   reason = "too_fast")
  s <- rt_screen(d$rt, r, .by = d$id)

  expect_identical(s$.keep, d$rt > 0.6)
  expect_identical(s$.prob, as.numeric(d$rt > 0.6))
  expect_identical(unique(s$.reason[!s$.keep]), "too_fast")
  expect_true(all(is.na(s$.reason[s$.keep])))
  expect_identical(unique(s$.rule), "fast")
})

test_that("the default reason names a dropped trial a contaminant", {
  d <- contaminated()
  r <- rule_custom("fast", function(rt) rt > 0.6)
  s <- rt_screen(d$rt, r, .by = d$id)
  expect_identical(unique(s$.reason[!s$.keep]), "contaminant")
})

test_that("a numeric return is a probability the policy decides on", {
  d <- contaminated()
  r <- rule_custom("graded", function(rt) pmin(1, 0.5 / rt))
  s <- rt_screen(d$rt, r, .by = d$id, threshold = 0.4)

  # the function's answer reaches .prob untouched, fractions and all
  expect_equal(s$.prob, pmin(1, 0.5 / d$rt))
  expect_identical(s$.keep, s$.prob > 0.4)
  # a trial the rule doubted but the policy kept carries no reason
  graded_and_kept <- s$.keep & s$.prob < 1
  expect_true(any(graded_and_kept))
  expect_true(all(is.na(s$.reason[graded_and_kept])))
})

test_that("a full list return passes through and reaches screen_fits()", {
  d <- contaminated()
  r <- rule_custom("bounded", function(rt, p) {
    b <- stats::quantile(rt, c(p, 1 - p), names = FALSE)
    list(
      prob = as.numeric(rt >= b[1] & rt <= b[2]),
      reason = ifelse(rt < b[1], "too_fast", ifelse(rt > b[2], "too_slow", NA)),
      fit = data.frame(lower = b[1], upper = b[2])
    )
  }, p = 0.05)

  s <- rt_screen(d$rt, r, .by = d$id)
  expect_setequal(stats::na.omit(unique(s$.reason)), c("too_fast", "too_slow"))
  fits <- screen_fits(d$rt, r, .by = d$id)
  expect_true(all(c("lower", "upper") %in% names(fits)))
})

test_that("a bare return reports no diagnostics rather than empty ones", {
  d <- contaminated()
  r <- rule_custom("fast", function(rt) rt > 0.6)
  expect_identical(
    names(screen_fits(d$rt, r, .by = d$id)),
    c(".group", "n_trials", "n_dropped", "prop_dropped")
  )
})

# --- what the function receives ---------------------------------------------

test_that("parameters reach the function by name, and only the declared ones", {
  d <- contaminated()
  # `spare` is stored on the rule but not declared: passing it would error with
  # "unused argument", which is exactly what this asserts does not happen
  r <- rule_custom("named", function(rt, cut) rt > cut, cut = 0.6, spare = 99)
  expect_identical(rt_screen(d$rt, r, .by = d$id)$.keep, d$rt > 0.6)
})

test_that("a function may take the rule object instead of its parameters", {
  d <- contaminated()
  r <- rule_custom("obj", function(rule, rt) rt > rule$cut, cut = 0.6)
  expect_identical(rt_screen(d$rt, r, .by = d$id)$.keep, d$rt > 0.6)
})

test_that("`...` means the function receives everything", {
  d <- contaminated()
  seen <- NULL
  r <- rule_custom("dots", function(rt, ...) {
    seen <<- names(list(...))
    rt > list(...)$cut
  }, cut = 0.6)

  expect_identical(rt_screen(d$rt, r, .by = d$id)$.keep, d$rt > 0.6)
  expect_true(all(c("response", "rule", "cut", "label") %in% seen))
})

test_that("rt arrives without missing values and never empty", {
  rt <- c(0.5, NA, 0.8, NA)
  r <- rule_custom("clean", function(rt) {
    expect_false(anyNA(rt))
    expect_gt(length(rt), 0)
    rep(TRUE, length(rt))
  })
  s <- rt_screen(rt, r)
  expect_identical(s$.keep, c(TRUE, FALSE, TRUE, FALSE))
  expect_identical(s$.reason[2], "missing")
})

test_that("a formal the engine cannot supply fails when the rule is built", {
  expect_error(
    rule_custom("typo", function(rt, respones) rt > 0),
    "'fun' takes 'respones', which the engine cannot supply"
  )
  # the message says where the value should have come from
  expect_error(
    rule_custom("typo", function(rt, respones) rt > 0),
    "stored on the rule"
  )
  # ... but a default is ordinary R, and the engine leaves it alone
  defaulted <- rule_custom("defaulted", function(rt, k = 3) rt > k)
  expect_true(all(rt_screen(c(4, 5), defaulted)$.keep))
})

test_that("a parameter cannot shadow a name the engine supplies", {
  for (nm in c("rt", "response", "rule")) {
    args <- list("clash", function(rt) rt > 0)
    args[[nm]] <- 1:5
    expect_error(
      do.call(rule_custom, args),
      paste0("cannot be called '", nm, "'")
    )
  }
})

test_that("idx_by_group is offered to grouped rules only", {
  expect_error(
    rule_custom("ungrouped", function(rt, idx_by_group) rt > 0),
    "'fun' takes 'idx_by_group', which the engine cannot supply"
  )
  expect_no_error(
    rule_custom("grouped", function(rt, idx_by_group) rt > 0, grouped = TRUE)
  )
})

# --- declaring what a rule needs --------------------------------------------

test_that("declaring `response` makes it mandatory, and saying so overrides", {
  d <- contaminated()
  r <- rule_custom("acc", function(rt, response) response == 1)
  expect_true(attr(r, "needs_response"))
  expect_error(rt_screen(d$rt, r, .by = d$id), "requires 'response'")
  expect_identical(
    rt_screen(d$rt, r, response = d$response, .by = d$id)$.keep,
    d$response == 1
  )

  off <- rule_custom("opt", function(rt, response) rep(TRUE, length(rt)),
                     needs_response = FALSE)
  expect_false(attr(off, "needs_response"))
  expect_true(all(rt_screen(d$rt, off, .by = d$id)$.keep))
})

test_that("a grouped rule sees every group once, in its own coordinates", {
  d <- contaminated()
  r <- rule_custom("pooled", function(rt, idx_by_group) {
    # the indices address the rt this function was handed, and partition it
    expect_identical(sort(unname(unlist(idx_by_group))), seq_along(rt))
    expect_length(idx_by_group, 4L)
    rt <= 3 * stats::median(rt)
  }, grouped = TRUE)

  s <- rt_screen(d$rt, r, .by = d$id)
  expect_identical(s$.keep, d$rt <= 3 * stats::median(d$rt))
})

test_that("per-trial parameters are subset to the group, never recycled", {
  d <- contaminated()
  oracle <- rule_custom("oracle-by-hand", function(rt, truth) !truth,
                        truth = d$contaminant, per_trial = "truth")

  # against ground truth, not against rule_oracle(): both go through
  # .subset_rule(), so comparing them would survive a broken subsetter
  for (by in list(d$id, NULL)) {
    expect_identical(rt_screen(d$rt, oracle, .by = by)$.keep, !d$contaminant)
    expect_identical(
      rt_screen(d$rt, oracle, .by = by)$.keep,
      rt_screen(d$rt, rule_oracle(d$contaminant), .by = by)$.keep
    )
  }
  expect_error(
    rt_screen(d$rt, rule_custom("short", function(rt, truth) !truth,
                                truth = c(TRUE, FALSE), per_trial = "truth")),
    "must be the same length"
  )
})

# --- the other consumers ----------------------------------------------------

test_that("a rule carrying a function composes with one that does not", {
  d <- contaminated()
  own <- rule_custom("own", function(rt) rt > 0.4)
  for (compose in list(rule_all, rule_any, rule_then)) {
    s <- rt_screen(d$rt, compose(own, rule_sd(2.5)), .by = d$id)
    expect_length(s$.keep, nrow(d))
    expect_false(anyNA(s$.keep))
  }
})

test_that("two rule_custom() rules share a class without colliding", {
  d <- contaminated()
  cmp <- screen_compare(
    d$rt,
    list(
      loose = rule_custom("loose", function(rt) rt > 0.4),
      tight = rule_custom("tight", function(rt) rt > 0.6),
      mad = rule_mad(2.5)
    ),
    .by = d$id
  )
  expect_s3_class(cmp, "rtprep_comparison")
  expect_setequal(unique(cmp$drops$.rule), c("loose", "tight", "mad"))
  # each rule is reported on its own terms, not merged by class
  drops <- tapply(cmp$drops$n_dropped, cmp$drops$.rule, sum)
  expect_gt(drops[["tight"]], drops[["loose"]])
})

test_that("report_screening() describes a rule it does not know", {
  d <- contaminated()
  r <- rule_custom("mine", function(rt) rt > 0.6)
  rep <- report_screening(rt_screen(d$rt, r, .by = d$id))
  txt <- paste(utils::capture.output(print(rep)), collapse = " ")
  expect_match(txt, "mine")
  expect_match(txt, "not from rtprep's own roster")
})

# --- the contract, enforced -------------------------------------------------

test_that("a malformed return is caught and named", {
  d <- contaminated()
  bad <- function(f) rt_screen(d$rt, rule_custom("bad", f))

  expect_error(bad(function(rt) rt[1:5] > 0), "returned 5 values for 200")
  expect_error(
    bad(function(rt) rep(NA, length(rt))), "cannot evaluate a trial keeps it"
  )
  expect_error(bad(function(rt) "hello"), "must return a logical vector")
  # the full-list route is still checked by the contract it opted into
  expect_error(
    bad(function(rt) {
      list(
        prob = rep(2, length(rt)),
        reason = rep(NA_character_, length(rt)),
        fit = NULL
      )
    }),
    "outside \\[0, 1\\]"
  )
})

test_that("new_rule() checks fun before the screen runs", {
  expect_error(new_rule("x", "x", fun = "not a function"), "must be a function")
  expect_error(rule_custom("x"), "'fun' is required")
})

# --- printing and precedence ------------------------------------------------

test_that("a description reaches print(), on either route", {
  with_fun <- rule_custom("f", function(rt, cut) rt > cut, cut = 0.5,
                          description = "Keeps the slow ones.")
  out <- utils::capture.output(print(with_fun))
  expect_match(paste(out, collapse = " "), "Keeps the slow ones.")
  # the formals print: the one thing about the rule not otherwise visible
  expect_match(paste(out, collapse = " "), "function of \\(rt, cut\\)")

  # a rule with a method and no function can describe itself the same way
  expect_match(
    paste(
      utils::capture.output(
        print(new_rule("m", "m", description = "A method rule."))
      ),
      collapse = " "
    ),
    "A method rule."
  )
  expect_match(
    paste(utils::capture.output(print(rule_custom("f", function(rt) rt > 0))),
          collapse = " "),
    "No description available."
  )
})

test_that("a registered method takes precedence over a stored function", {
  d <- contaminated()
  r <- new_rule("precedence", "precedence",
                fun = function(rt) rep(TRUE, length(rt)))
  registerS3method("apply_rule", "rtprep_rule_precedence",
                   function(rule, rt, response = NULL) {
                     list(prob = rep(0, length(rt)),
                          reason = rep("method", length(rt)), fit = NULL)
                   })
  s <- rt_screen(d$rt, r, .by = d$id)
  expect_false(any(s$.keep))
  expect_identical(unique(s$.reason), "method")
})

test_that("rule_custom() builds the three classes the engine dispatches on", {
  r <- rule_custom("c", function(rt) rt > 0)
  expect_identical(
    class(r),
    c("rtprep_rule_custom", "rtprep_rule_fun", "rtprep_rule")
  )
  mine <- rule_custom("c", function(rt) rt > 0, subclass = "mine")
  expect_identical(class(mine)[1], "rtprep_rule_mine")
  # a rule with no function keeps the two-element class it always had
  expect_identical(class(new_rule("plain", "plain")),
                   c("rtprep_rule_plain", "rtprep_rule"))
})

# --- the claim: the two routes are the same route ---------------------------

test_that("a function-route rule reproduces one of rtprep's own exactly", {
  d <- contaminated()
  by_hand <- rule_custom("mad-by-hand", function(rt, n_mad) {
    centre <- stats::median(rt)
    spread <- stats::mad(rt)
    # the escape every rule owes a group it cannot evaluate
    if (length(rt) < 2L || !is.finite(spread) || spread == 0) {
      return(rep(TRUE, length(rt)))
    }
    rt >= centre - n_mad * spread & rt <= centre + n_mad * spread
  }, n_mad = 2.5)

  expect_identical(
    rt_screen(d$rt, by_hand, .by = d$id)$.keep,
    rt_screen(d$rt, rule_mad(2.5), .by = d$id)$.keep
  )
  # and on rt_example, where the groups are uneven
  expect_identical(
    rt_screen(rt_example$rt, by_hand, .by = rt_example$id)$.keep,
    rt_screen(rt_example$rt, rule_mad(2.5), .by = rt_example$id)$.keep
  )
})
