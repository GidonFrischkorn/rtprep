# Screen response times with any rule

Applies a screening rule and returns one row per input trial, whichever
rule was used. That uniformity is the package's reason to exist:
absolute cutoffs, standard deviation criteria, recursive criteria, and
model-based mixtures all come back in the same shape, so a preprocessing
choice can be compared rather than assumed.

## Usage

``` r
rt_screen(
  rt,
  rule,
  response = NULL,
  .by = NULL,
  policy = c("threshold", "probabilistic"),
  threshold = 0.5
)
```

## Arguments

- rt:

  Numeric vector of response times **in seconds**. `NA` is allowed;
  non-positive values are an error.

- rule:

  A rule object; see
  [rules](https://www.gfrischkorn.org/rtprep/reference/rules.md).

- response:

  Optional response coding of the same length as `rt`, given as numeric
  0/1, logical, or a character or factor using labels such as
  `"correct"`/`"error"` or `"upper"`/`"lower"`. Required by
  [`rule_ewma()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  and by
  [`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  with `use_accuracy = TRUE`.

- .by:

  Optional grouping of the same length as `rt` — a vector, factor, list
  of vectors, or data frame. Rules are fitted separately within each
  group. `NULL` treats all trials as one group.

- policy:

  Exclusion policy. `"threshold"` keeps a trial when its probability of
  validity exceeds `threshold`. `"probabilistic"` keeps it with that
  probability, drawing once per trial.

- threshold:

  Cut for `policy = "threshold"`, in `[0, 1]`. Ignored under the
  probabilistic policy.

## Value

A `data.frame` with one row per element of `rt`, in input order:

- `.keep`:

  logical; keep this trial under the stated policy.

- `.prob`:

  numeric; the probability that the trial came from the decision
  process, that is **P(valid)**. Deterministic rules return 0 or 1. Note
  that
  [`bmm::flag_contaminant_rts()`](https://venpopov.com/bmm/reference/flag_contaminant_rts.html)
  returns the complement.

- `.rule`:

  character; the rule's label.

- `.reason`:

  character; why the **rule** flagged the trial — `"too_fast"`,
  `"too_slow"`, `"contaminant"`, or `"missing"`. `NA` whenever the rule
  did not flag it, which includes trials the keep policy dropped anyway
  (at `threshold = 1`, or on a probabilistic draw against a fractional
  `.prob`). A kept trial never carries a reason.

Per-group fit diagnostics are attached as `attr(x, "fits")`: one row per
group with `.group`, `n_trials`, `n_dropped`, and `prop_dropped`, plus
whatever the rule reports (bounds, iterations, EM convergence).
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
returns that table on its own.

## Details

Separating the probability from the decision is deliberate. A mixture
rule produces a genuine posterior probability; a cutoff produces a
degenerate one. Keeping both in the same object means a probabilistic
screen can feed
[`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
as a weight vector without being forced through a threshold first, and
that the same comparison machinery covers both families.

Trials with a missing response time, or a missing value in any `.by`
component, are excluded from every rule's computation and returned with
`.keep = FALSE`, `.prob = NA`, and `.reason = "missing"`.

Under `policy = "probabilistic"` the decision is stochastic by design.
There is no [`set.seed()`](https://rdrr.io/r/base/Random.html) anywhere
in `rtprep`; reproducibility is the caller's.

## Inside a data-frame pipeline

The function takes vectors and returns a data frame, so it drops into
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
unchanged: `mutate(rt_screen(rt, rule_sd(2.5)), .by = id)` splices the
four columns in, and `filter(.keep)` then drops the flagged trials. Two
things to know. `attr(x, "fits")` does not survive `mutate()`; use
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
when the per-group table is what you want. And dplyr reads `.keep =` as
its own argument, so assign the column by splicing rather than by name.
When only the filter is needed,
[`rt_keep()`](https://www.gfrischkorn.org/rtprep/reference/rt_keep.md)
returns the logical vector directly.

## See also

[rules](https://www.gfrischkorn.org/rtprep/reference/rules.md) for the
rules themselves;
[`rt_keep()`](https://www.gfrischkorn.org/rtprep/reference/rt_keep.md)
for the keep vector alone;
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
for the per-group table alone;
[`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
to apply several rules at once;
[`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
to aggregate what survives.

## Examples

``` r
rt <- c(0.12, 0.31, 0.35, 0.38, 0.42, 0.47, 0.55, 2.90)
rt_screen(rt, rule_cutoff(0.18, 2.5))
#>   .keep .prob             .rule  .reason
#> 1 FALSE     0 cutoff(0.18, 2.5) too_fast
#> 2  TRUE     1 cutoff(0.18, 2.5)     <NA>
#> 3  TRUE     1 cutoff(0.18, 2.5)     <NA>
#> 4  TRUE     1 cutoff(0.18, 2.5)     <NA>
#> 5  TRUE     1 cutoff(0.18, 2.5)     <NA>
#> 6  TRUE     1 cutoff(0.18, 2.5)     <NA>
#> 7  TRUE     1 cutoff(0.18, 2.5)     <NA>
#> 8 FALSE     0 cutoff(0.18, 2.5) too_slow

# rules are group-aware without the package depending on dplyr
id <- rep(c("a", "b"), each = 4)
scr <- rt_screen(rt, rule_sd(2), .by = id)
attr(scr, "fits")
#>   .group n_trials n_dropped prop_dropped center     scale       lower    upper
#> 1      a        4         0            0  0.290 0.1169045  0.05619096 0.523809
#> 2      b        4         0            0  1.085 1.2111840 -1.33736799 3.507368

# a rule that reads accuracy takes it by name
correct <- c(0, 1, 1, 1, 0, 1, 1, 1)
rt_screen(rt, rule_ewma(lambda = 0.1), response = correct)
#>   .keep .prob          .rule  .reason
#> 1 FALSE     0 ewma(0.1, 1.5) too_fast
#> 2 FALSE     0 ewma(0.1, 1.5) too_fast
#> 3 FALSE     0 ewma(0.1, 1.5) too_fast
#> 4 FALSE     0 ewma(0.1, 1.5) too_fast
#> 5 FALSE     0 ewma(0.1, 1.5) too_fast
#> 6 FALSE     0 ewma(0.1, 1.5) too_fast
#> 7 FALSE     0 ewma(0.1, 1.5) too_fast
#> 8  TRUE     1 ewma(0.1, 1.5)     <NA>
```
