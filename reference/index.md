# Package index

## About rtprep

- [`rtprep`](https://www.gfrischkorn.org/rtprep/reference/rtprep-package.md)
  [`rtprep-package`](https://www.gfrischkorn.org/rtprep/reference/rtprep-package.md)
  : rtprep: Screening, Trimming, and Aggregating Response Time Data
- [`rtprep-glossary`](https://www.gfrischkorn.org/rtprep/reference/rtprep-glossary.md)
  [`glossary`](https://www.gfrischkorn.org/rtprep/reference/rtprep-glossary.md)
  : Terms used in rtprep

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
  [`rule_iqr()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_recursive()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_ewma()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_none()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_oracle()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`print(`*`<rtprep_rule>`*`)`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  : Screening rules
- [`format(`*`<rtprep_screen>`*`)`](https://www.gfrischkorn.org/rtprep/reference/rtprep_screen.md)
  [`print(`*`<rtprep_screen>`*`)`](https://www.gfrischkorn.org/rtprep/reference/rtprep_screen.md)
  [`as.data.frame(`*`<rtprep_screen>`*`)`](https://www.gfrischkorn.org/rtprep/reference/rtprep_screen.md)
  [`` `[`( ``*`<rtprep_screen>`*`)`](https://www.gfrischkorn.org/rtprep/reference/rtprep_screen.md)
  : Methods for a screening result

## Combining rules

No single conventional rule reaches both the slow tail and the leading
edge; these put two together.

- [`rule_all()`](https://www.gfrischkorn.org/rtprep/reference/rules_compose.md)
  [`rule_any()`](https://www.gfrischkorn.org/rtprep/reference/rules_compose.md)
  [`rule_then()`](https://www.gfrischkorn.org/rtprep/reference/rules_compose.md)
  : Combine screening rules
- [`rule_hierarchical()`](https://www.gfrischkorn.org/rtprep/reference/rule_hierarchical.md)
  : Hierarchical screening

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
  [`print(`*`<rtprep_comparison_summary>`*`)`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
  [`plot(`*`<rtprep_comparison>`*`)`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
  : Compare what several screening rules would remove
- [`check_guessing()`](https://www.gfrischkorn.org/rtprep/reference/check_guessing.md)
  : Test whether the fast trials a rule removed were really guesses

## Ground truth

Generate data whose contaminants are labelled, and remove exactly those,
so a screen can be scored and read against perfect exclusion.

- [`r_contaminated()`](https://www.gfrischkorn.org/rtprep/reference/r_contaminated.md)
  : Generate response time data with contaminants of known type
- [`rule_cutoff()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_sd()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_mad()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_iqr()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_recursive()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_ewma()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_none()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`rule_oracle()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  [`print(`*`<rtprep_rule>`*`)`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  : Screening rules

## Extending rtprep

Adding a screening rule from your own package.

- [`new_rule()`](https://www.gfrischkorn.org/rtprep/reference/extending.md)
  [`apply_rule()`](https://www.gfrischkorn.org/rtprep/reference/extending.md)
  [`apply_rule_grouped()`](https://www.gfrischkorn.org/rtprep/reference/extending.md)
  : Add a screening rule

## Data

- [`rt_example`](https://www.gfrischkorn.org/rtprep/reference/rt_example.md)
  : Simulated response times from four participants, with ground truth
