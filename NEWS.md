# rtprep 0.1.0

Initial CRAN release. `rtprep` gives the response time preprocessing steps
that precede an evidence accumulation model fit one interface: screening,
aggregation, EZ-diffusion estimation, and data generation with known ground
truth.

* `rt_screen()` applies any screening rule to a response time vector and
  returns the same per-trial columns (`.keep`, `.prob`, `.rule`, `.reason`)
  whichever rule was used, with `.by` grouping so it works inside
  `dplyr::mutate()` and `dplyr::reframe()`.

* `rt_keep()` returns the keep decision as a logical vector and reports how
  many trials were dropped, so `dplyr::filter(rt_keep(rt, rule, .by = id))`
  is the whole exclusion step.

* `screen_fits()` returns the per-group fit diagnostics of a rule as a data
  frame.

* `report_screening()` turns a screen into a Methods paragraph: the rule and
  its setting, the grouping the criterion was computed within, how much it
  removed in total and per cell, what it caught, whether it read accuracy, the
  keep policy, and the references for the criteria used. It separates what the
  rule excluded from what it never saw, so a missing response time is not
  counted as an exclusion. The returned object carries every number the
  paragraph quotes, and `toBibtex()` on it gives the BibTeX entries.

* `rule_cutoff()`, `rule_sd()`, `rule_mad()`, `rule_iqr()`,
  `rule_recursive()`, `rule_ewma()`, and `rule_none()` implement absolute
  cutoffs, the SD and MAD criteria, Tukey's quartile fences, the recursive
  criteria of van Selst and Jolicoeur (1994), the EWMA control chart of
  Vandekerckhove and Tuerlinckx (2007), and a pass-through baseline.

* `rule_all()`, `rule_any()` and `rule_then()` combine rules. `rule_all()`
  removes the union of what its components remove, which is how a slow-tail
  criterion and a leading-edge detector cover between them what neither covers
  alone. `rule_then()` stages them, each fitted on the trials the last one
  left, which is what `trimr::sdTrim(minRT = , sd = )` does and what a
  two-stage description in a Methods section usually means.

* `rule_hierarchical()` shrinks each group's centre and spread towards the
  values pooled over all groups, so a participant's criterion is not estimated
  entirely from the data it is meant to clean. Experimental.

* `rule_oracle()` removes exactly the trials named as contaminants. Only
  meaningful on generated data, where it is the ceiling the other rules are
  read against.

* `rule_mixture()` fits a uniform-contaminant mixture with an ex-Gaussian,
  lognormal, or inverse Gaussian core by expectation maximisation and returns
  a per-trial posterior probability that the trial came from the decision
  process.

* `rule_mixture(use_accuracy = TRUE)` is an experimental, off-by-default
  variant that puts accuracy inside the mixture likelihood.

* `.prob` is always the probability that a trial is valid, and
  `policy = "threshold"` or `"probabilistic"` turns it into the `.keep`
  decision.

* `rt_summary()` aggregates surviving trials into EZ-diffusion summary
  statistics by sample moments, robust moments, trimmed or Winsorized moments,
  or the analytic moments of a fitted mixture, and accepts `.prob` as weights.

* `ez_ddm()` inverts those statistics into drift, bound, and non-decision time
  (Wagenmakers et al., 2007), with the published edge correction and `s = 1`
  as the scaling convention.

* `adjust_accuracy()` corrects accuracy counts for estimated contamination,
  vectorised over the rows of a summary table.

* `check_guessing()` tests whether the fast trials a rule removed were guesses,
  by a Bayes factor against the chance rate.

* `screen_compare()` applies several rules at once and reports drop rates,
  pairwise agreement, and the Jaccard overlap of the excluded sets.
  `summary()` returns those tables as an object with its own `print()` method,
  so assigning it is quiet; `print()` and `plot()` return their input
  invisibly, and `plot()` draws with ggplot2 when it is installed and base
  graphics when it is not.

* `r_contaminated()` generates response times from a diffusion or racing
  diffusion core with leading-edge anticipations, delayed start-ups, or
  informationless responses added at a known rate, and returns the ground
  truth with the data.

* `rt_screen()`'s result prints as a summary of the screen, reporting what was
  removed and why, rather than as one row per trial.

* `new_rule(fun = )` takes the screening function itself, so adding a rule needs
  neither an S3 method nor a `registerS3method()` call. The function declares
  what it needs by name -- `rt`, `response`, `rule`, `idx_by_group` for a
  grouped rule, and any parameter stored on the rule -- and the engine passes
  exactly that; an argument it cannot supply is an error when the rule is built
  rather than in the middle of a screen. The function may return a logical
  vector (`TRUE` = keep), a numeric vector of probabilities, or the full
  `list(prob, reason, fit)`. `description =` gives the rule a sentence for
  `print()`, and `reason =` names what a dropped trial was dropped for.

* `rule_custom()` does the whole thing in one call, for a rule used once:
  `rule_custom("fast(0.35)", function(rt, cut) rt >= cut, cut = 0.35)`.

* `new_rule()` and the `apply_rule()` generic are exported, so a package can add
  a screening family with one constructor and one method instead. `?extending`
  documents both routes, and the engine checks the contract on every return.

* `?rtprep` describes the package and `?rtprep-glossary` defines the terms the
  rest of the documentation uses.

* `rt_example` is a small simulated data set with ground truth, used by the
  examples and the get-started vignette (`vignette("rtprep")`).

* Equivalence tests check the screening rules against `trimr` and the mixture,
  aggregation, and accuracy functions against `bmm`.
