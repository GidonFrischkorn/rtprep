# Package index

## About rtprep

- [`rtprep`](https://www.gfrischkorn.org/rtprep/reference/rtprep-package.md)
  [`rtprep-package`](https://www.gfrischkorn.org/rtprep/reference/rtprep-package.md)
  : rtprep: Screening, Trimming, and Aggregating Response Time Data

## Screening

One engine, one return shape, whichever rule is applied.

- [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
  : Screen response times with any rule
- [`rt_keep()`](https://www.gfrischkorn.org/rtprep/reference/rt_keep.md)
  : Keep vector from a screening rule
- [`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
  : Per-group fit diagnostics from a screening rule
- [`rule_cutoff()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_sd()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_mad()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_recursive()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_ewma()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_none()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`print(`*`<rtprep_rule>`*`)`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  : Screening rules

## Aggregation and estimation

From surviving trials to EZ-diffusion inputs and parameters.

- [`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
  : Aggregate response times into EZ-diffusion summary statistics
- [`adjust_accuracy()`](https://www.gfrischkorn.org/rtprep/reference/adjust_accuracy.md)
  : Correct accuracy counts for contamination
- [`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md) :
  Invert summary statistics into diffusion parameters

## Comparison and diagnostics

What a different choice would have removed, and whether the removed
trials were what you thought.

- [`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
  [`print(`*`<rtprep_comparison>`*`)`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
  [`summary(`*`<rtprep_comparison>`*`)`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
  [`plot(`*`<rtprep_comparison>`*`)`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
  : Compare what several screening rules would remove
- [`check_guessing()`](https://www.gfrischkorn.org/rtprep/reference/check_guessing.md)
  : Test whether the fast trials a rule removed were really guesses

## Ground truth

Generate data with contaminants of known type, so a pipeline can be
tested instead of trusted.

- [`r_contaminated()`](https://www.gfrischkorn.org/rtprep/reference/r_contaminated.md)
  : Generate response time data with contaminants of known type

## Data

- [`rt_example`](https://www.gfrischkorn.org/rtprep/reference/rt_example.md)
  : Simulated response times from four participants, with ground truth
