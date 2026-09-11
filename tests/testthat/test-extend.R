# The extension point. The only real test of whether it works is to define a
# rule the way an outside package would and run it through every consumer.

rule_middle <- function(p = 0.05) {
  new_rule("test_middle", label = paste0("middle(", p, ")"), p = p)
}

apply_rule.rtprep_rule_test_middle <- function(rule, rt, response = NULL) {
  b <- stats::quantile(rt, c(rule$p, 1 - rule$p), names = FALSE)
  list(
    prob = as.numeric(rt >= b[1] & rt <= b[2]),
    reason = ifelse(
      rt < b[1], "too_fast", ifelse(rt > b[2], "too_slow", NA_character_)
    ),
    fit = data.frame(lower = b[1], upper = b[2])
  )
}
registerS3method(
  "apply_rule", "rtprep_rule_test_middle", apply_rule.rtprep_rule_test_middle
)

test_that("a rule defined outside the package works in every consumer", {
  r <- rule_middle(0.05)
  expect_s3_class(r, "rtprep_rule")

  scr <- rt_screen(rt_example$rt, r, .by = rt_example$id)
  expect_equal(nrow(scr), nrow(rt_example))
  expect_setequal(names(scr), c(".keep", ".prob", ".rule", ".reason"))

  expect_type(rt_keep(rt_example$rt, r, .by = rt_example$id, quiet = TRUE), "logical")

  fits <- screen_fits(rt_example$rt, r, .by = rt_example$id)
  expect_equal(nrow(fits), 4L)
  expect_true(all(c("lower", "upper") %in% names(fits)))

  cmp <- screen_compare(
    rt_example$rt, list(middle = r, mad = rule_mad(2.5)),
    .by = rt_example$id
  )
  expect_s3_class(cmp, "rtprep_comparison")

  # and it composes with the package's own rules
  expect_silent(rt_screen(rt_example$rt, rule_all(r, rule_sd(2.5))))
})

test_that("new_rule() validates what it stores", {
  expect_error(new_rule("", "x"), "non-empty string")
  expect_error(new_rule("x", 1), "non-empty string")
  expect_error(new_rule("x", "x", 5), "must be named")
  # `label` is a formal before `...`, so a second one cannot reach the
  # parameter list and shadow it; every route to trying is an error
  expect_error(new_rule("x", "x", label = "y"))
  expect_error(
    do.call(new_rule, c(list(subclass = "x", label = "x"), list(label = "y")))
  )
  expect_error(new_rule("x", "x", per_trial = "nope"), "was not supplied")
  expect_error(new_rule("x", "x", needs_response = "yes"), "TRUE or FALSE")
})

test_that("the return contract is enforced rather than merely documented", {
  bad <- function(subclass, result) {
    r <- new_rule(subclass, label = subclass)
    registerS3method(
      "apply_rule", paste0("rtprep_rule_", subclass),
      function(rule, rt, response = NULL) result(rt)
    )
    r
  }

  short <- bad("test_short", function(rt) {
    list(prob = 1, reason = NA_character_, fit = NULL)
  })
  expect_error(rt_screen(rt_example$rt, short), "must be numeric of length")

  wide <- bad("test_wide", function(rt) {
    list(prob = rep(2, length(rt)), reason = rep(NA_character_, length(rt)), fit = NULL)
  })
  expect_error(rt_screen(rt_example$rt, wide), "outside \\[0, 1\\]")

  rows <- bad("test_rows", function(rt) {
    list(
      prob = rep(1, length(rt)), reason = rep(NA_character_, length(rt)),
      fit = data.frame(a = 1:2)
    )
  })
  expect_error(rt_screen(rt_example$rt, rows), "one-row data frame")
})

test_that("a rule with no method fails at the boundary, not in the loop", {
  expect_error(
    rt_screen(rt_example$rt, new_rule("test_nomethod", "nope")),
    "not yet implemented"
  )
})

test_that("per-trial parameters are subset to the group, never recycled", {
  set.seed(201)
  d <- r_contaminated(200, process = "mixed", rate = 0.1)
  d$id <- rep(1:4, each = 50)

  expect_identical(
    rt_screen(d$rt, rule_oracle(d$contaminant), .by = d$id)$.keep,
    !d$contaminant
  )
  expect_identical(
    rt_screen(d$rt, rule_oracle(d$contaminant))$.keep, !d$contaminant
  )
  expect_error(
    rt_screen(d$rt, rule_oracle(c(TRUE, FALSE))),
    "must be the same length"
  )
})
