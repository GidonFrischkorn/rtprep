# rtprep: Screening, Trimming, and Aggregating Response Time Data

Tools for the decisions made about response times before a model is
fitted: which trials to keep, how to summarise the ones that survive,
and how to check what either choice did.

The screening rules come from families that were never built to be
compared: absolute cutoffs, criteria based on a centre and a spread, the
recursive criteria, a control chart on accuracy, a fitted contaminant
mixture. Every published implementation returns something different.
Here they all return one row per trial with the same four columns, so
swapping one for another is a one-word change and the difference between
them can be measured.

## The four layers

- Screening:

  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
  applies a rule and returns the keep decision, the probability behind
  it, and the reason.
  [`rt_keep()`](https://www.gfrischkorn.org/rtprep/reference/rt_keep.md)
  gives the decision alone for
  [`filter()`](https://rdrr.io/r/stats/filter.html);
  [`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
  gives the per-group diagnostics. The rules are in
  [rules](https://www.gfrischkorn.org/rtprep/reference/rules.md), and
  [`rule_all()`](https://www.gfrischkorn.org/rtprep/reference/rules_compose.md)
  and its companions combine them.

- Aggregation:

  [`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
  turns surviving trials into the mean, variance and accuracy the
  EZ-diffusion equations take, by sample moments, robust moments,
  trimming, or a fitted mixture.
  [`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md)
  inverts them into parameters;
  [`adjust_accuracy()`](https://www.gfrischkorn.org/rtprep/reference/adjust_accuracy.md)
  corrects the counts.

- Comparison:

  [`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
  applies several rules at once and reports how much each removed and
  how far they disagree.
  [`check_guessing()`](https://www.gfrischkorn.org/rtprep/reference/check_guessing.md)
  asks whether the fast trials a rule removed were really guesses.

- Ground truth:

  [`r_contaminated()`](https://www.gfrischkorn.org/rtprep/reference/r_contaminated.md)
  generates response times with contaminants labelled, and
  [`rule_oracle()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  removes exactly those, which is the ceiling every real rule is read
  against.

## Two things that hold everywhere

`.prob` is always the probability that a trial came from the decision
process, never the probability that it is a contaminant, and the keep
decision is a separate step. A deterministic rule returns 0 and 1; a
mixture returns a posterior; both can feed `rt_summary(weights = )`
without a threshold being chosen.

A rule that cannot be evaluated removes nothing: too few trials, zero
spread or a fit that did not converge keeps every trial in the group and
records why in
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md).
[extending](https://www.gfrischkorn.org/rtprep/reference/extending.md)
states the contract that follows from.

## Terms

See
[rtprep-glossary](https://www.gfrischkorn.org/rtprep/reference/rtprep-glossary.md)
for *contaminant*, *drift*, *bound*, *ndt*, *leading edge*, and the
difference between screening, trimming and aggregation.

## See also

[`vignette("rtprep")`](https://www.gfrischkorn.org/rtprep/articles/rtprep.md)
for the whole chain on one data set;
[extending](https://www.gfrischkorn.org/rtprep/reference/extending.md)
to add a rule of your own.

## Author

**Maintainer**: Gidon T. Frischkorn
<gidon.frischkorn@psychologie.uzh.ch>
([ORCID](https://orcid.org/0000-0002-5055-9764)) \[copyright holder\]

Authors:

- Gidon T. Frischkorn <gidon.frischkorn@psychologie.uzh.ch>
  ([ORCID](https://orcid.org/0000-0002-5055-9764)) \[copyright holder\]
