# Test whether the fast trials a rule removed were really guesses

A screening rule tells you which trials it removed. It does not tell you
whether it was right. This is one check that it was: if the fast trials
a rule excluded really were guesses, their accuracy should be at chance.

A Beta-Binomial test with a Savage–Dickey Bayes factor, ported from
[`bmm::validate_fast_guesses()`](https://venpopov.com/bmm/reference/validate_fast_guesses.html).

## Usage

``` r
check_guessing(
  keep,
  rt,
  response,
  threshold_type = c("quantile", "absolute"),
  rt_threshold = 0.25,
  chance = 0.5,
  prior_alpha = 1,
  prior_beta = 1,
  credible_mass = 0.95
)
```

## Arguments

- keep:

  Logical vector of keep decisions, typically the `.keep` column of
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md).
  Note this is the *keep* flag, not a contaminant flag — `rtprep`'s
  convention throughout — so a screen's output drops straight in.

- rt:

  Numeric vector of response times, in seconds.

- response:

  Response coding of the same length, in any form
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
  accepts.

- threshold_type:

  Whether `rt_threshold` is a quantile of the response time distribution
  or an absolute value in seconds.

- rt_threshold:

  The cut defining "fast": a quantile in `(0, 1)`, or a positive number
  of seconds.

- chance:

  Accuracy expected from a guess, known from the design.

- prior_alpha, prior_beta:

  Beta prior on the proportion correct. The default `1, 1` is uniform.

- credible_mass:

  Mass of the highest-density interval.

## Value

A one-row `data.frame` — a row rather than `bmm`'s list, because in
practice this goes into a results table:

- `prop_upper`:

  observed proportion correct among the tested trials.

- `hdi_lower`, `hdi_upper`:

  highest-density interval on that proportion.

- `bf_01`:

  Savage–Dickey Bayes factor for guessing against not.

- `guess_in_hdi`:

  whether `chance` falls inside the interval.

- `bf_evidence`:

  the Bayes factor on Jeffreys' scale.

- `posterior_alpha`, `posterior_beta`, `n_tested`, `rt_threshold`,
  `threshold_type`, `credible_mass`, `mean_rt_tested`:

  the inputs and intermediates, so a results table is self-describing.

## Details

The test looks only at trials that were **both excluded and fast**. Slow
exclusions are a different claim — a slow contaminant is an attention
lapse, not a guess, and there is no reason to expect chance accuracy
from one.

This is the diagnostic counterpart of
`rule_mixture(use_accuracy = TRUE)`: one checks accuracy after flagging,
the other uses it during. Given what the package's own tests found about
the latter — that it collapses on overlapping contamination and actively
hurts when contaminants keep their accuracy — this is currently the
safer of the two instruments.

When no trial is both excluded and fast, the row comes back with
`n_tested = 0` and `NA` statistics rather than an error. In a simulation
that cell is common, and informative: it means the rule removed nothing
fast.

## References

Jeffreys, H. (1961). *Theory of Probability* (3rd ed.). Oxford
University Press.

## See also

[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
for the `keep` vector,
[`rule_ewma()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
for a rule that uses accuracy to screen rather than to check.

## Examples

``` r
set.seed(3)
rt <- c(runif(20, 0.15, 0.30), rgamma(80, 5, 10) + 0.2)
response <- c(rbinom(20, 1, 0.5), rbinom(80, 1, 0.85))
scr <- rt_screen(rt, rule = rule_cutoff(0.35, 3))

check_guessing(scr$.keep, rt, response)
#>   prop_upper hdi_lower hdi_upper    bf_01 guess_in_hdi           bf_evidence
#> 1       0.45 0.2543575 0.6568661 3.363762         TRUE moderate_for_guessing
#>   posterior_alpha posterior_beta n_tested rt_threshold threshold_type
#> 1              10             12       20    0.4332132       quantile
#>   credible_mass mean_rt_tested
#> 1          0.95      0.2274065
```
