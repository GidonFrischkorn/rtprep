# Aggregate response times into EZ-diffusion summary statistics

Screening decides which trials survive; aggregation decides what the
survivors are summarised *as*. They fail differently, so `rtprep` keeps
them apart and makes both comparable: the same trials summarised three
ways can give three different parameter estimates, and that is a
preprocessing choice as consequential as the exclusion rule.

## Usage

``` r
rt_summary(
  rt,
  response = NULL,
  method = c("simple", "robust", "trimmed", "winsorized", "mixture"),
  version = c("3par", "4par"),
  distribution = c("exgaussian", "lognormal", "invgaussian"),
  robust_scale = c("iqr", "mad"),
  trim = 0.1,
  weights = NULL,
  min_trials = 10,
  ...
)
```

## Arguments

- rt:

  Numeric vector of response times **in seconds**.

- response:

  Optional response coding of the same length as `rt`, in any form
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
  accepts. Required for `version = "4par"`; without it `n_upper` is
  `NA`. A trial whose response is missing belongs to neither boundary
  and is left out of both, but still counts towards `n_trials`, as in
  `bmm`, so `n_upper / n_trials` understates accuracy when responses are
  missing. Drop those trials first if that matters.

- method:

  How the moments are computed.

  - `"simple"` gives the sample mean and variance. The baseline, and
    what almost everyone does.

  - `"robust"` gives the median, with the variance from the
    interquartile range (divided by 1.349) or the median absolute
    deviation. Statistic-level robustness, after Chávez De la Peña et
    al. (2026).

  - `"trimmed"` gives the mean of the middle `1 - 2 * trim` of the
    trials, with the variance from the Winsorized sample. The
    robust-statistics answer.

  - `"winsorized"` gives the same variance, with the mean of the
    Winsorized sample rather than the trimmed one.

  - `"mixture"` gives the analytic moments of the response time
    component of a fitted contaminant mixture, and its estimated
    contaminant proportion.

- version:

  `"3par"` pools the two response boundaries; `"4par"` summarises each
  separately.

- distribution:

  Core distribution for `method = "mixture"`; see
  [`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md).

- robust_scale:

  Spread statistic for `method = "robust"`.

- trim:

  Proportion of trials cut from *each* tail by `method = "trimmed"` and
  `method = "winsorized"`, as in
  [`base::mean()`](https://rdrr.io/r/base/mean.html). `floor(n * trim)`
  trials go from each end.

- weights:

  Optional per-trial weights, typically the `.prob` column of
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md).
  Defined for `method = "simple"` only.

- min_trials:

  Below this many trials the moments are `NA` rather than noise;
  `n_trials` is still reported. With `weights`, the comparison uses
  Kish's effective sample size `sum(w)^2 / sum(w^2)`, so two unit
  weights among ninety-eight zeros count as two trials rather than a
  hundred.

- ...:

  Passed to the mixture fit: `bound`, `init`, `max_prop`, `maxit`,
  `tol`, as documented in
  [`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  and with the same defaults, including `maxit = 500` where
  [`bmm::ezdm_summary_stats()`](https://venpopov.com/bmm/reference/ezdm_summary_stats.html)
  uses 100.

## Value

A one-row `data.frame` holding the inputs
[`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md)
needs.

`version = "3par"`: `mean_rt`, `var_rt`, `n_upper`, `n_trials`,
`contaminant_prop`.

`version = "4par"`: `mean_rt_upper`, `mean_rt_lower`, `var_rt_upper`,
`var_rt_lower`, `n_upper`, `n_trials`, `contaminant_prop_upper`,
`contaminant_prop_lower`.

`contaminant_prop` is `NA` for every method but `"mixture"`, which is
the only one that estimates it.

## Two ways of not letting contaminants count

`method = "mixture"` reads its moments from the *parametric component*,
not from the data, so a trial the uniform component owns contributes
nothing at all. `weights` instead computes weighted sample moments, so
such a trial contributes a little. They are two models of the same
doubt, which is why both are here and why combining them is an error
rather than a convenience.

Weighted variances use the reliability-weight denominator
`sum(w) - sum(w^2) / sum(w)`, which reduces to `n - 1` when the weights
are equal. Frequency weights would use `sum(w) - 1` and are the wrong
model: `.prob` is a probability, not a count.

## Trimming and Winsorizing

Both cut the same `floor(n * trim)` trials from each tail. Trimming
drops them; Winsorizing replaces each with the nearest surviving value,
so the count stays the same and the extremes stop pulling. The variance
comes from the Winsorized sample either way, rescaled so that it
estimates the variance of the response time distribution rather than the
variance of the trimmed mean. It is the same kind of correction as the
1.349 that `robust_scale = "iqr"` applies, and it is necessary because
[`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md)
reads `var_rt` as a moment of the distribution.

The divisor is not the familiar `(1 - 2 * trim)^2` of Tukey and
McLaughlin (1963). That one estimates `n` times the variance of the
trimmed *mean*, and using it here would report a variance 6% high at
`trim = 0.1` and 14% high at `trim = 0.2`, which
[`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md)
would read as a slower drift.

`contaminant_prop` stays `NA`. `trim` is the proportion removed, not an
estimate of the proportion contaminated, and
[`adjust_accuracy()`](https://www.gfrischkorn.org/rtprep/reference/adjust_accuracy.md)
would apply a second correction to counts that have already been
trimmed.

Under `version = "4par"` the trim applies within each boundary, so the
surviving count per boundary is about `(1 - 2 * trim)` of what arrived;
set `min_trials` with that in mind.

## Differences from `bmm`

[`bmm::ezdm_summary_stats()`](https://venpopov.com/bmm/reference/ezdm_summary_stats.html)
defaults to `method = "mixture"`; this function defaults to `"simple"`.
A package about preprocessing choices should not make one of the choices
silently.

For `version = "4par"` with `method = "mixture"`, the contaminant bounds
are resolved once on the pooled response times before the split.
Resolving them per boundary would make the uniform component's density
depend on which side happened to have the wider range, so the two halves
would be fitted against different models.

When the mixture fit fails the moments fall back to `"robust"` with a
warning, as in `bmm`.
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
resolves the analogous failure the other way and keeps every trial (see
[extending](https://www.gfrischkorn.org/rtprep/reference/extending.md)).
The two layers differ because a screen can decline to act, and a summary
still has to return a number.

## References

Wagenmakers, E.-J., van der Maas, H. L. J., Dolan, C. V., & Grasman, R.
P. P. P. (2008). EZ does it! Extensions of the EZ-diffusion model.
*Psychonomic Bulletin & Review*, *15*(6), 1229–1235.
[doi:10.3758/pbr.15.6.1229](https://doi.org/10.3758/pbr.15.6.1229)

Chávez De La Peña, A. F., Shin, E., & Vandekerckhove, J. (2026). Robust
Bayesian hypothesis testing with the hierarchical EZ-DDM. *Behavior
Research Methods*, *58*(7), 177.
[doi:10.3758/s13428-026-03066-1](https://doi.org/10.3758/s13428-026-03066-1)

## See also

[`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md) to
invert these statistics into parameters,
[`adjust_accuracy()`](https://www.gfrischkorn.org/rtprep/reference/adjust_accuracy.md)
to correct the counts for contamination,
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
to decide which trials get here.

## Examples

``` r
rt <- c(0.32, 0.35, 0.38, 0.41, 0.44, 0.47, 0.50, 0.55, 0.62, 0.71, 1.90)
correct <- c(1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0)

rt_summary(rt, correct, min_trials = 5)
#>     mean_rt    var_rt n_upper n_trials contaminant_prop
#> 1 0.6045455 0.1982673       8       11               NA
rt_summary(rt, correct, method = "robust", min_trials = 5)
#>   mean_rt     var_rt n_upper n_trials contaminant_prop
#> 1    0.47 0.01983733       8       11               NA

# a probabilistic screen can feed aggregation without a threshold
scr <- rt_screen(rt, rule = rule_sd(2))
rt_summary(rt, correct, weights = scr$.prob, min_trials = 5)
#>   mean_rt     var_rt n_upper n_trials contaminant_prop
#> 1   0.475 0.01518333       8       11               NA
```
