# Tests for report_screening().
#
# The paragraph is prose, so most of what matters here is that the numbers in it
# are the numbers in the fits table and that no branch produces a sentence with
# an "NA" or a dangling range in it.
#
# Mutation-checked, by breaking the implementation and confirming the test goes
# red: the roster completeness check, the missing-data decomposition, the
# NA-free claim, the composite prose shapes, the staged counts, the agreement
# between the two methods, the accuracy clause, and the author-year derivation.

screened <- function(rule, data = .engine_data(), grouped = TRUE,
                     needs_response = FALSE, ...) {
  suppressWarnings(rt_screen(
    data$rt, rule,
    response = if (needs_response) data$response else NULL,
    .by = if (grouped) list(participant = data$id) else NULL,
    ...
  ))
}

test_that("every rule in the roster gets a real phrase and resolvable refs", {
  # The point of the completeness check: a rule with no method would fall back
  # to its label, which is legible but is not a description, and the paragraph
  # would say nothing about what the rule does.
  for (nm in names(.engine_roster())) {
    rule <- .engine_roster()[[nm]]$rule
    phrase <- rtprep:::.rule_phrase(rule)
    expect_type(phrase, "character")
    expect_length(phrase, 1L)
    expect_false(is.na(phrase))
    expect_true(nzchar(phrase))
    expect_no_match(phrase, "^the rule \"", info = nm)

    keys <- rtprep:::.rule_reference(rule)
    for (key in keys) {
      expect_s3_class(rtprep:::.ref_entry(key), "bibentry")
      expect_match(rtprep:::.ref_cite(key), "\\(\\d{4}\\)$")
    }
  }
})

test_that("the rules with no published reference are named, not skipped", {
  # Asserted by name so that giving one of them a reference later is a visible
  # test change rather than a silent one.
  expect_identical(rtprep:::.rule_reference(rule_none()), character())
  expect_identical(
    rtprep:::.rule_reference(rule_hierarchical(2.5, n0 = 20)), character()
  )
  expect_identical(
    rtprep:::.rule_reference(rule_oracle(rep(FALSE, 3))), character()
  )
})

test_that("an unknown key is an error rather than a silent gap", {
  expect_error(rtprep:::.ref_entry("nosuchkey"), "No stored reference")
})

test_that("the counts agree with the fits table", {
  scr <- screened(rule_sd(2.5))
  rep <- report_screening(scr)
  fits <- attr(scr, "fits")

  expect_identical(rep$n_excluded, sum(fits$n_dropped))
  expect_identical(rep$n_screened, sum(fits$n_trials))
  expect_identical(rep$n_trials, nrow(scr))
  expect_identical(rep$n_missing + rep$n_screened, rep$n_trials)
  # the trap: sum(!.keep) counts the missing trials, which the rule never saw
  expect_identical(rep$n_excluded + rep$n_missing, sum(!scr$.keep))
  expect_gt(rep$n_missing, 0L)
})

test_that("missing trials are reported apart from the rule's exclusions", {
  rep <- report_screening(screened(rule_sd(2.5)))
  expect_match(rep$text, "missing response time or grouping key")
  expect_match(rep$text, paste0("A further ", rep$n_missing, " of "))
})

test_that("an unfitted cell is excluded from the range, not printed into it", {
  # .engine_data() has a group observed nowhere, so prop_dropped carries an NA
  # row. Asserting only that "NA" is absent from the text is too weak: the
  # formatter turns NA into "not defined", so a paragraph can be nonsense
  # without containing the letters. The count is what encodes the claim.
  for (nm in names(.engine_roster())) {
    spec <- .engine_roster()[[nm]]
    scr <- screened(
      spec$rule,
      grouped = isTRUE(spec$grouped),
      needs_response = isTRUE(spec$needs_response)
    )
    rep <- report_screening(scr)
    fits <- attr(scr, "fits")

    expect_identical(
      rep$cells$fitted, sum(!is.na(fits$prop_dropped)),
      info = nm
    )
    expect_identical(rep$cells$n, nrow(fits), info = nm)
    expect_no_match(rep$text, "NA", fixed = TRUE, info = nm)
    expect_no_match(rep$text, "NaN", fixed = TRUE, info = nm)
    expect_no_match(rep$text, "not defined", fixed = TRUE, info = nm)
  }

  # the empty cell is real, so the paragraph owes the reader a word about it
  grouped <- report_screening(screened(rule_sd(2.5)))
  expect_gt(grouped$cells$n, grouped$cells$fitted)
  expect_match(grouped$text, "had no usable trials")
})

test_that("a range is only reported when there is a range to report", {
  # nothing removed: no range, and no dangling note about the empty cells
  rep <- report_screening(screened(rule_cutoff(0.001)))
  expect_identical(rep$n_excluded, 0L)
  expect_no_match(rep$text, "between")
  expect_no_match(rep$text, "not counted in that range")

  # one cell: a range over it is not a range
  one <- report_screening(screened(rule_sd(2.5), grouped = FALSE))
  expect_identical(one$cells$n, 1L)
  expect_no_match(one$text, "between")
})

test_that("row subsetting is an error, not a quietly wrong paragraph", {
  scr <- screened(rule_sd(2.5))
  expect_error(
    report_screening(scr[scr$.keep, ]), "row subsetting"
  )
  # column subsetting keeps the fits table, so it still reports
  expect_s3_class(report_screening(scr[, ]), "rtprep_report")
})

test_that("the composites each get their own prose shape", {
  by_id <- list(participant = .engine_data()$id)

  staged <- report_screening(screened(
    rule_then(rule_cutoff(0.2), rule_sd(2.5))
  ))
  expect_match(staged$text, "screened in two stages")
  expect_match(staged$text, "each stage estimated on the trials")

  union <- report_screening(screened(rule_all(rule_cutoff(0.2), rule_sd(2.5))))
  expect_match(union$text, "excluded when either of them flagged it")

  inter <- report_screening(screened(rule_any(rule_mad(2.5), rule_iqr(1.5))))
  expect_match(inter$text, "excluded only when both of them flagged it")

  nested <- report_screening(screened(
    rule_all(rule_then(rule_cutoff(0.2), rule_sd(2.5)), rule_iqr(1.5))
  ))
  expect_match(nested$text, "followed by")
  expect_match(nested$text, "estimated on the survivors")
})

test_that("a rule nested more than two deep falls back to its label", {
  deep <- rule_all(
    rule_then(rule_all(rule_mad(2.5), rule_iqr()), rule_cutoff(0.2)),
    rule_sd(3)
  )
  expect_identical(rtprep:::.rule_depth(deep), 3L)

  rep <- report_screening(screened(deep))
  expect_match(rep$text, 'the rule "all(sd(2.5, median, mad), iqr(1.5))"',
    fixed = TRUE
  )
  expect_match(paste(rep$notes, collapse = " "), "nests more than two levels")
  # the fallback exists so the paragraph stays a paragraph
  expect_lt(rep$words, 300L)
})

test_that("the staged counts come from the fits table", {
  scr <- screened(rule_then(rule_cutoff(0.3), rule_sd(2.5)))
  fits <- attr(scr, "fits")
  rep <- report_screening(scr)

  expect_match(rep$text, paste0(
    "The first stage flagged ", sum(fits$r1_n_flagged, na.rm = TRUE),
    " of the ", sum(fits$r1_n_seen, na.rm = TRUE)
  ), fixed = TRUE)
  expect_match(rep$text, paste0(
    "the second stage flagged ", sum(fits$r2_n_flagged, na.rm = TRUE)
  ), fixed = TRUE)
})

test_that("the screen and the data frame methods give the same paragraph", {
  d <- .engine_data()
  d$block <- rep(c("a", "b"), length.out = nrow(d))
  rule <- rule_sd(2.5)

  scr <- suppressWarnings(
    rt_screen(d$rt, rule, .by = list(id = d$id, block = d$block))
  )
  from_screen <- report_screening(scr)
  from_frame <- report_screening(
    cbind(d, as.data.frame(scr)),
    rule = rule, groups = c("id", "block")
  )

  # the cells must be the same cells in the same order, which is why the data
  # frame method rebuilds them through .group_key() rather than pasting a key
  expect_identical(from_screen$text, from_frame$text)
  expect_equal(from_screen$cells, from_frame$cells)
  expect_identical(from_screen$fits$.group, from_frame$fits$.group)
  expect_identical(from_screen$n_excluded, from_frame$n_excluded)
})

test_that("the data frame method asks for what it cannot recover", {
  scr <- screened(rule_sd(2.5))
  plain <- as.data.frame(scr)

  expect_error(report_screening(plain), "cannot be recovered")
  expect_error(
    report_screening(plain[, c(".keep", ".prob")], rule = rule_sd(2.5)),
    "missing the screening columns"
  )
  expect_error(
    report_screening(plain, rule = "sd(2.5)"), "must be a rule object"
  )
  expect_error(
    report_screening(plain, rule = rule_sd(2.5), groups = "nosuchcol"),
    "not a column of 'x'"
  )
})

test_that("the accuracy clause follows whether the rule read accuracy", {
  blind <- report_screening(screened(rule_sd(2.5)))
  expect_match(blind$text, "did not read accuracy")
  expect_false(blind$needs_response)

  # also the first test of needs_response propagating through a composite
  reads <- report_screening(screened(
    rule_all(rule_sd(2.5), rule_ewma()),
    needs_response = TRUE
  ))
  expect_match(reads$text, "The screen read accuracy")
  expect_true(reads$needs_response)
})

test_that("the grouping clause says what it can and no more", {
  d <- .engine_data()

  named <- report_screening(screened(rule_sd(2.5)))
  expect_match(named$text, "within each participant cell (40 cells)",
    fixed = TRUE
  )

  # a bare vector carries no names, so the clause must not invent one
  bare <- suppressWarnings(rt_screen(d$rt, rule_sd(2.5), .by = d$id))
  expect_match(report_screening(bare)$text, "each of the 40 groups")

  # a hierarchical rule pools across groups rather than being computed within
  pooled <- report_screening(screened(rule_hierarchical(2.5, n0 = 20)))
  expect_match(pooled$text, "estimated across all 40")
  expect_no_match(pooled$text, "computed separately")

  # an absolute cutoff estimates nothing, so it is not "computed within"
  fixed_bounds <- report_screening(screened(rule_cutoff(0.2, 2)))
  expect_no_match(fixed_bounds$text, "computed separately")
})

test_that("author-year follows the number of authors", {
  # two authors take "and" in running prose, three or more take et al.
  expect_identical(rtprep:::.ref_cite("miller1991"), "Miller (1991)")
  expect_identical(
    rtprep:::.ref_cite("ulrich1994"), "Ulrich and Miller (1994)"
  )
  expect_identical(rtprep:::.ref_cite("leys2013"), "Leys et al. (2013)")
})

test_that("references are collected over a composite and de-duplicated", {
  # both components cite Miller (1991); it must appear once
  both <- rule_all(rule_sd(2.5), rule_mad(2.5))
  keys <- rtprep:::.rule_reference(both)
  expect_identical(sum(keys == "miller1991"), 1L)
  expect_true("leys2013" %in% keys)

  # the MAD criterion cites Leys et al., which argues against the SD criterion,
  # so a mean/SD screen must not cite it
  expect_false("leys2013" %in% rtprep:::.rule_reference(rule_sd(2.5)))

  rep <- report_screening(screened(rule_recursive("modified")))
  expect_match(paste(utils::toBibtex(rep), collapse = " "), "Van Selst")
})

test_that("the word cap drops clauses whole rather than truncating", {
  for (nm in names(.engine_roster())) {
    spec <- .engine_roster()[[nm]]
    rep <- report_screening(screened(
      spec$rule,
      grouped = isTRUE(spec$grouped),
      needs_response = isTRUE(spec$needs_response)
    ))
    expect_lte(rep$words, 300L)
  }

  tight <- report_screening(screened(rule_sd(2.5)), max_words = 60L)
  expect_no_match(tight$text, "described by")
  # the rule itself is never dropped
  expect_match(tight$text, "standard deviations")
  # and no sentence was cut off mid-way
  expect_match(tight$text, "\\.$")
})

test_that("print and as.character report the same paragraph", {
  rep <- report_screening(screened(rule_mad(2.5)))

  expect_identical(as.character(rep), rep$text)
  expect_length(as.character(rep), 1L)
  expect_no_match(as.character(rep), "\n", fixed = TRUE)

  out <- paste(utils::capture.output(print(rep)), collapse = " ")
  expect_match(out, "median absolute deviations")
  expect_match(out, "words")
  expect_invisible(print(rep))
})

test_that("a screen with nothing usable still reports honestly", {
  empty <- suppressWarnings(rt_screen(c(NA_real_, NA_real_), rule_sd(2.5)))
  rep <- report_screening(empty)

  expect_identical(rep$n_screened, 0L)
  expect_match(rep$text, "never ran")
  expect_no_match(rep$text, "NA", fixed = TRUE)
  expect_no_match(rep$text, "between")
})

test_that("rule_none() reports that nothing was screened, once", {
  rep <- report_screening(screened(rule_none()))
  expect_match(rep$text, "No screening rule was applied")
  # counting what a pass-through removed, and citing it, would be noise
  expect_no_match(rep$text, "This removed")
  expect_no_match(rep$text, "described by")
  expect_identical(rep$references, character())
})

test_that("the policy clause appears only when it changes the answer", {
  # a deterministic rule at the default threshold has nothing to say
  plain <- report_screening(screened(rule_sd(2.5)))
  expect_no_match(plain$text, "probability of being a valid")

  # a mixture returns posteriors, so the cut matters
  mixed <- report_screening(screened(rule_mixture("lognormal")))
  expect_match(mixed$text, "probability of being a valid decision trial")

  drawn <- report_screening(screened(
    rule_mixture("lognormal"),
    policy = "probabilistic"
  ))
  expect_match(drawn$text, "single draw")
})
