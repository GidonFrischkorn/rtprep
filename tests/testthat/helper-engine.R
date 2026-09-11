# Shared by test-engine.R and fixtures/make-engine-reference.R, so that the
# frozen answers and the answers under test come from the same specification.

# One seed-fixed data set with the awkward cases the engine has to survive:
# a group whose trials are all missing, missing grouping keys, and a group of
# one trial (degenerate for every spread-based rule).
.engine_data <- function() {
  set.seed(20260905)
  n_groups <- 40L
  n_trials <- 60L

  d <- r_contaminated(
    n_groups * n_trials,
    generator = "ddm", process = "mixed", rate = 0.12,
    par = list(drift = 1.4, bound = 1.1, ndt = 0.30)
  )
  d$id <- rep(sprintf("s%02d", seq_len(n_groups)), each = n_trials)

  # group s07 is observed nowhere: the rule is never fitted and the fits table
  # still owes it a row
  d$rt[d$id == "s07"] <- NA_real_
  # a scatter of missing RTs and missing group keys
  d$rt[c(3L, 121L, 122L, 900L)] <- NA_real_
  d$id[c(15L, 16L, 1700L)] <- NA_character_
  # s40 keeps one trial; every spread-based rule has to bail out rather than
  # divide by a zero spread
  d$rt[which(d$id == "s40")[-1L]] <- NA_real_

  d
}

# Every rule constructor, exported or internal, at its default and at the
# configurations the studies use. `grouped` and `needs_response` are part of
# the specification because the engine takes a different path for each.
.engine_roster <- function() {
  spec <- function(rule, grouped = TRUE, needs_response = FALSE) {
    list(rule = rule, grouped = grouped, needs_response = needs_response)
  }

  list(
    none = spec(rule_none()),
    cutoff = spec(rule_cutoff(0.2, 2.0)),
    cutoff_open = spec(rule_cutoff(0.15)),
    sd = spec(rule_sd(2.5)),
    iqr = spec(rule_iqr(1.5)),
    iqr_k3 = spec(rule_iqr(3)),
    sd_median = spec(rule_sd(2.5, center = "median")),
    mad = spec(rule_mad(2.5)),
    recursive_moving = spec(rule_recursive("moving")),
    recursive_mod = spec(rule_recursive("modified")),
    recursive_hybrid = spec(rule_recursive("hybrid")),
    ewma = spec(rule_ewma(), needs_response = TRUE),
    adaptive_trim = spec(rule_adaptive_trim()),
    ez_support = spec(rule_ez_support(), needs_response = TRUE),
    mix_lognormal = spec(rule_mixture("lognormal")),
    mix_exgaussian = spec(rule_mixture("exgaussian")),
    mix_invgaussian = spec(rule_mixture("invgaussian")),
    mix_fixed_bound = spec(rule_mixture("lognormal", bound = c(0.15, 3))),
    mix_accuracy = spec(
      rule_mixture("lognormal", use_accuracy = TRUE),
      needs_response = TRUE
    ),
    hierarchical = spec(rule_hierarchical(2.5, n0 = 20)),
    hierarchical_mad = spec(
      rule_hierarchical(2.5, n0 = 20, center = "median", scale = "mad")
    ),
    compose_all = spec(rule_all(rule_cutoff(0.2, 2), rule_sd(2.5))),
    compose_any = spec(rule_any(rule_mad(2.5), rule_iqr(1.5))),
    compose_then = spec(rule_then(rule_cutoff(0.2), rule_sd(2.5))),
    compose_mixed = spec(
      rule_all(rule_mixture("lognormal"), rule_sd(3))
    ),
    # the ungrouped path: one group, built by .group_key() rather than from .by
    sd_ungrouped = spec(rule_sd(2.5), grouped = FALSE),
    mix_ungrouped = spec(rule_mixture("lognormal"), grouped = FALSE),
    none_ungrouped = spec(rule_none(), grouped = FALSE)
  )
}

# The comparison layer shares the group bookkeeping, so it is frozen too.
.engine_comparison <- function(d) {
  suppressWarnings(screen_compare(
    d$rt,
    list(
      sd = rule_sd(2.5),
      mad = rule_mad(2.5),
      recursive = rule_recursive("modified"),
      mixture = rule_mixture("lognormal"),
      ewma = rule_ewma()
    ),
    response = d$response,
    .by = d$id
  ))
}

# Warnings are a pure function of the frozen `fits` columns (`converged`,
# `bound_inverted`, `accuracy_inverted`), so suppressing them here loses no
# coverage and keeps the roster's output readable.
.engine_screen <- function(d, spec) {
  suppressWarnings(rt_screen(
    d$rt,
    spec$rule,
    response = if (spec$needs_response) d$response else NULL,
    .by = if (spec$grouped) d$id else NULL
  ))
}
