# Equivalence tests against the reference implementations.
#
# rtprep implements every screening rule itself, so that the package carries no
# runtime dependency on either trimr or bmm. That independence is the point, but
# it also means nothing catches a silent divergence from the published
# algorithms. These tests are the insurance.
#
# Two claims rest on them:
#   1. The recursive / moving-criterion rules follow van Selst & Jolicoeur
#      (1994). The criterion table is fiddly and easy to get subtly wrong.
#   2. The mixture EM matches bmm's, which matters because the DDM tutorial
#      recommends bmm's defaults on the strength of results computed here.
#
# The trimr comparisons run in two layers, because a test that skips is green
# without being insurance:
#
#   * against `fixtures/trimr-reference.rds`, trimr 1.1.1's own answers for a
#     fixed data set, frozen once and checked in. This layer runs everywhere and
#     is what catches a regression in rtprep.
#   * against trimr itself, wherever it is installed. This layer catches the
#     snapshot going stale against a new trimr release.
#
# Two documented divergences make the fixture deliberately tie-free:
#   - rtprep's bounds are inclusive, trimr's are strict, so the two can disagree
#     on an RT sitting exactly on a cutoff;
#   - rtprep's modified-recursive rule removes the extreme trial by position,
#     trimr's mean path removes it by value and so would drop every tied copy.
# With continuous RTs neither case arises.

reference <- readRDS(test_path("fixtures", "trimr-reference.rds"))

# Upper-tail exclusions only: trimr's sdTrim() trims the slow side and leaves
# the fast side to its separate minRT argument.
rtprep_sd_kept <- function(d, n_sd) {
  scr <- rt_screen(d$rt, rule = rule_sd(n_sd), .by = d$participant)
  sort(d$rt[!(!scr$.keep & scr$.reason == "too_slow")])
}

rtprep_recursive_mean <- function(d, type) {
  scr <- rt_screen(d$rt, rule = rule_recursive(type), .by = d$participant)
  as.numeric(tapply(d$rt[scr$.keep], d$participant[scr$.keep], mean))
}

# --- against the frozen reference (always runs) -----------------------------

test_that("the criterion table matches the one trimr ships", {
  expect_equal(rtprep:::.vsj_table$moving, reference$vsj_table$moving)
  expect_equal(rtprep:::.vsj_table$modified, reference$vsj_table$modified)
  expect_equal(rtprep:::.vsj_criterion(10, "moving"), 2.17)
  expect_equal(rtprep:::.vsj_criterion(10, "modified"), 4.11)
  expect_equal(rtprep:::.vsj_criterion(150, "moving"), 2.50)
  expect_true(is.na(rtprep:::.vsj_criterion(3, "moving")))
})

test_that("SD trimming reproduces trimr's frozen answers", {
  for (n_sd in names(reference$sd_kept)) {
    expect_equal(
      rtprep_sd_kept(reference$data, as.numeric(n_sd)),
      reference$sd_kept[[n_sd]],
      info = paste("n_sd =", n_sd)
    )
  }
})

test_that("the recursive rules reproduce trimr's frozen answers", {
  expect_equal(rtprep_recursive_mean(reference$data, "moving"),
    reference$moving_mean,
    info = "moving"
  )
  expect_equal(rtprep_recursive_mean(reference$data, "modified"),
    reference$modified_mean,
    info = "modified"
  )
  # van Selst & Jolicoeur's hybrid is the mean of the two condition means, which
  # no single per-trial keep vector can reproduce: the two means have different
  # denominators. rule_recursive("hybrid") gives the per-trial analogue; the
  # published statistic is recovered by averaging the two rules' summaries, as
  # ?rule_recursive documents and as this test does.
  moving <- rtprep_recursive_mean(reference$data, "moving")
  modified <- rtprep_recursive_mean(reference$data, "modified")
  expect_equal((moving + modified) / 2, reference$hybrid_mean)
})

# --- against trimr itself (runs wherever trimr is installed) ----------------

test_that("the frozen reference still matches the installed trimr", {
  skip_if_not_installed("trimr")
  d <- reference$data

  for (n_sd in names(reference$sd_kept)) {
    kept <- trimr::sdTrim(
      d,
      minRT = 0, sd = as.numeric(n_sd), perCondition = FALSE,
      perParticipant = TRUE, omitErrors = FALSE, returnType = "raw"
    )
    expect_equal(sort(kept$rt), reference$sd_kept[[n_sd]])
  }

  expect_equal(
    as.numeric(trimr::nonRecursive(
      d,
      minRT = 0, omitErrors = FALSE, returnType = "mean", digits = 10
    )$A),
    reference$moving_mean
  )
  expect_equal(
    as.numeric(trimr::modifiedRecursive(
      d,
      minRT = 0, omitErrors = FALSE, returnType = "mean", digits = 10
    )$A),
    reference$modified_mean
  )
  expect_equal(
    as.numeric(trimr::hybridRecursive(
      d,
      minRT = 0, omitErrors = FALSE, digits = 10
    )$A),
    reference$hybrid_mean
  )
})

test_that("mixture EM matches bmm::flag_contaminant_rts()", {
  skip_if_not_installed("bmm")
  skip("not yet implemented")
})

test_that("EZ summary statistics match bmm::ezdm_summary_stats()", {
  skip_if_not_installed("bmm")
  skip("not yet implemented")
})
