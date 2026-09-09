# Changelog

## rtprep 0.1.0

Initial CRAN release. `rtprep` gives the response time preprocessing
steps that precede an evidence accumulation model fit one interface:
screening, aggregation, EZ-diffusion estimation, and data generation
with known ground truth.

- [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
  applies any screening rule to a response time vector and returns the
  same per-trial columns (`.keep`, `.prob`, `.rule`, `.reason`)
  whichever rule was used, with `.by` grouping so it works inside
  [`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
  and
  [`dplyr::reframe()`](https://dplyr.tidyverse.org/reference/reframe.html).

- [`rt_keep()`](https://www.gfrischkorn.org/rtprep/reference/rt_keep.md)
  returns the keep decision as a logical vector and reports how many
  trials were dropped, so `dplyr::filter(rt_keep(rt, rule, .by = id))`
  is the whole exclusion step.

- [`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
  returns the per-group fit diagnostics of a rule as a data frame.

- [`rule_cutoff()`](https://www.gfrischkorn.org/rtprep/reference/rules.md),
  [`rule_sd()`](https://www.gfrischkorn.org/rtprep/reference/rules.md),
  [`rule_mad()`](https://www.gfrischkorn.org/rtprep/reference/rules.md),
  [`rule_recursive()`](https://www.gfrischkorn.org/rtprep/reference/rules.md),
  [`rule_ewma()`](https://www.gfrischkorn.org/rtprep/reference/rules.md),
  and
  [`rule_none()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  implement absolute cutoffs, the SD and MAD criteria, the recursive
  criteria of van Selst and Jolicoeur (1994), the EWMA control chart of
  Vandekerckhove and Tuerlinckx (2007), and a pass-through baseline.

- [`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  fits a uniform-contaminant mixture with an ex-Gaussian, lognormal, or
  inverse Gaussian core by expectation maximisation and returns a
  per-trial posterior probability that the trial came from the decision
  process.

- `rule_mixture(use_accuracy = TRUE)` is an experimental, off-by-default
  variant that puts accuracy inside the mixture likelihood.

- `.prob` is always the probability that a trial is valid, and
  `policy = "threshold"` or `"probabilistic"` turns it into the `.keep`
  decision.

- [`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
  aggregates surviving trials into EZ-diffusion summary statistics by
  sample moments, robust moments, or the analytic moments of a fitted
  mixture, and accepts `.prob` as weights.

- [`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md)
  inverts those statistics into drift, bound, and non-decision time
  (Wagenmakers et al., 2007), with the published edge correction and
  `s = 1` as the scaling convention.

- [`adjust_accuracy()`](https://www.gfrischkorn.org/rtprep/reference/adjust_accuracy.md)
  corrects accuracy counts for estimated contamination, vectorised over
  the rows of a summary table.

- [`check_guessing()`](https://www.gfrischkorn.org/rtprep/reference/check_guessing.md)
  tests whether the fast trials a rule removed were guesses, by a Bayes
  factor against the chance rate.

- [`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
  applies several rules at once and reports drop rates, pairwise
  agreement, and the Jaccard overlap of the excluded sets, with
  [`print()`](https://rdrr.io/r/base/print.html),
  [`summary()`](https://rdrr.io/r/base/summary.html), and
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods.

- [`r_contaminated()`](https://www.gfrischkorn.org/rtprep/reference/r_contaminated.md)
  generates response times from a diffusion or racing diffusion core
  with leading-edge anticipations, delayed start-ups, or informationless
  responses added at a known rate, and returns the ground truth with the
  data.

- `rt_example` is a small simulated data set with ground truth, used by
  the examples and the get-started vignette
  ([`vignette("rtprep")`](https://www.gfrischkorn.org/rtprep/articles/rtprep.md)).

- Equivalence tests check the screening rules against `trimr` and the
  mixture, aggregation, and accuracy functions against `bmm`.
