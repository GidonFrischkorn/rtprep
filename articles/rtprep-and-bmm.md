# rtprep and bmm: the correspondence, function by function

`bmm` fits measurement models, among them the EZ-diffusion model and the
full diffusion model, and it ships four helpers for the preprocessing
that comes before a fit. `rtprep` is the package for that preprocessing,
and it reimplements those four rather than depending on `bmm`, so that a
package about preprocessing choices carries no model-fitting dependency
and every rule returns the same shape. Reimplementation has a known
cost: nothing catches a silent divergence from the published algorithm
except a test that compares the two. `rtprep`’s test suite runs those
comparisons on every check, and this page runs the same comparisons
live, so what it shows is demonstrated on the versions named at the
bottom rather than asserted.

``` r

library(rtprep)
library(dplyr)
```

## The correspondence

| `bmm` | `rtprep` | What differs |
|----|----|----|
| `flag_contaminant_rts(rt, distribution, contaminant_bound, init_contaminant, max_contaminant, maxit = 100)` | `rt_screen(rt, rule_mixture(distribution, bound, init, max_prop, maxit = 500))` | returns P(contaminant); `.prob` is P(valid). Diagnostics as an attribute; [`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md) as a table. `NA` on a failed fit; every trial kept. |
| `ezdm_summary_stats(rt, response, method = "mixture", ...)` | `rt_summary(rt, response, method = "simple", ...)` | same columns, same names; the default method differs, and `maxit` |
| `adjust_ezdm_accuracy(n_upper, n_trials, contaminant_prop, guess_rate)` | `adjust_accuracy(n_upper, n_trials, contaminant_prop, guess_rate)` | identical, draw for draw, and vectorised over rows |
| `validate_fast_guesses(contam_flag, rt_data, response, ..., guess_prob)` | `check_guessing(keep, rt, response, ..., chance)` | takes the keep flag rather than the contaminant flag; returns a one-row data frame rather than a list |

The comparisons below pass `maxit = 500` on both sides, because that is
the one default that differs and a comparison at two different iteration
limits compares nothing.

## Flagging

[`bmm::flag_contaminant_rts()`](https://venpopov.com/bmm/reference/flag_contaminant_rts.html)
returns the posterior probability that each trial is a contaminant.
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
with
[`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
returns the complement, the probability that the trial came from the
decision process, because the same column has to hold the 0 and 1 of a
deterministic rule and “1 means keep” is the convention that makes
`filter(.keep)` read correctly. The mapping is one minus the other:

``` r

p3_hard <- rt_example |>
  filter(id == "p3", condition == "hard")

theirs <- bmm::flag_contaminant_rts(
  p3_hard$rt, distribution = "lognormal", maxit = 500
)
ours <- rt_screen(p3_hard$rt, rule_mixture("lognormal", maxit = 500))

max(abs((1 - ours$.prob) - as.numeric(theirs)))
#> [1] 3.095631e-05
all(ours$.keep == (as.numeric(theirs) < 0.5))
#> [1] TRUE
```

The two agree to the optimiser’s tolerance rather than exactly, because
`rtprep` uses the closed-form weighted maximiser for the lognormal and
inverse-Gaussian cores where `bmm` optimises numerically; the test suite
allows the decisions to differ only for a trial whose posterior sits
within 0.01 of the cut. The fit diagnostics are the same quantities in
two shapes: `bmm` attaches a one-row data frame with a list column of
parameters, `rtprep` returns one row per group with the parameters as
`par_` columns, so that a comparison across participants is a table
without unnesting:

``` r

attr(theirs, "diagnostics") |>
  select(contaminant_prop, converged, iterations, loglik)
#>   contaminant_prop converged iterations   loglik
#> 1        0.0272247      TRUE         12 10.73694

screen_fits(p3_hard$rt, rule_mixture("lognormal", maxit = 500)) |>
  select(contaminant_prop, converged, iterations, loglik, par_mu, par_sigma)
#>   contaminant_prop converged iterations   loglik     par_mu par_sigma
#> 1       0.02722565      TRUE         12 10.73694 -0.5553563 0.3382753
```

When the EM does not converge `bmm` returns `NA` probabilities. `rtprep`
keeps every trial in that group and records `converged = FALSE`, because
an `NA` would propagate into `.keep` and a screen that cannot be
evaluated has no grounds to remove data.

## Summary statistics

[`bmm::ezdm_summary_stats()`](https://venpopov.com/bmm/reference/ezdm_summary_stats.html)
and
[`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
return the same columns under the same names, for every method and both
versions, so a summary table built with one drops into a workflow
written for the other:

``` r

bind_rows(lapply(c("simple", "robust", "mixture"), function(method) {
  ours <- rt_summary(
    p3_hard$rt, p3_hard$response,
    method = method, distribution = "lognormal", maxit = 500
  )
  theirs <- bmm::ezdm_summary_stats(
    p3_hard$rt, p3_hard$response,
    method = method, distribution = "lognormal", maxit = 500
  )
  tibble(
    method = method,
    same_names = identical(names(ours), names(theirs)),
    max_abs_diff = max(abs(unlist(ours) - unlist(theirs)), na.rm = TRUE)
  )
}))
#> # A tibble: 3 × 3
#>   method  same_names max_abs_diff
#>   <chr>   <lgl>             <dbl>
#> 1 simple  TRUE         0         
#> 2 robust  TRUE         0         
#> 3 mixture TRUE         0.00000224
```

The simple and robust moments agree exactly; the mixture moments agree
to the optimiser’s tolerance. Two defaults differ. `bmm` defaults to
`method = "mixture"` and `rtprep` to `"simple"`, because a package about
preprocessing choices should not make one of them silently. And `rtprep`
defaults to `maxit = 500` where `bmm` keeps 100; [the mixture
article](https://www.gfrischkorn.org/rtprep/articles/mixture-screening.md)
shows what the cap does to a fit that has not converged. For
`version = "4par"` with mixture moments both packages resolve the
contaminant bounds once on the pooled response times before splitting by
boundary, so the two halves are fitted against the same uniform
component.

## Accuracy adjustment

Both functions draw the number of contaminants and the number that
happened to be correct as binomials, and they make the two draws in the
same order, so from the same seed they return the same counts:

``` r

set.seed(2026097)
adjust_accuracy(n_upper = 84, n_trials = 100, contaminant_prop = 0.10)
#>   n_upper_adj n_trials_adj
#> 1          80           91

set.seed(2026097)
bmm::adjust_ezdm_accuracy(n_upper = 84, n_trials = 100, contaminant_prop = 0.10)
#>   n_upper_adj n_trials_adj
#> 1          80           91
```

`rtprep`’s version is vectorised over its rows, so the columns of a
summary table go in directly; `bmm`’s takes one row at a time.

## The guessing check

[`check_guessing()`](https://www.gfrischkorn.org/rtprep/reference/check_guessing.md)
is a port of
[`bmm::validate_fast_guesses()`](https://venpopov.com/bmm/reference/validate_fast_guesses.html)
with two interface changes. It takes the *keep* flag, so the `.keep`
column of a screen drops in without negation, and it returns a one-row
data frame, because in practice the result goes into a results table.
The argument `chance` is `bmm`’s `guess_prob`:

``` r

screened <- rt_screen(
  rt_example$rt, rule_cutoff(0.35, 3),
  .by = list(rt_example$id, rt_example$condition)
)

ours <- check_guessing(screened$.keep, rt_example$rt, rt_example$response)
theirs <- bmm::validate_fast_guesses(
  contam_flag = !screened$.keep, rt_data = rt_example$rt,
  response = rt_example$response
)

c(ours = ours$bf_01, bmm = theirs$bf_01)
#>     ours      bmm 
#> 3.523941 3.523941
c(ours = ours$n_tested, bmm = theirs$n_tested)
#> ours  bmm 
#>   19   19
```

## The differences, listed

Beyond the two defaults, the packages part in six places, each
deliberate:

- **`.prob` is P(valid)**, the complement of what
  [`flag_contaminant_rts()`](https://venpopov.com/bmm/reference/flag_contaminant_rts.html)
  returns.
- **A rule that cannot be evaluated removes nothing.** Fewer than two
  trials in a group, zero spread, a sample below the smallest tabled
  size for the recursive criteria, or an unconverged mixture: `rtprep`
  keeps the trials and says so in the fits table, where `bmm` returns
  `NA`.
- **Numeric `response` must be coded 0/1.** `bmm` coerces with
  [`as.logical()`](https://rdrr.io/r/base/logical.html), which reads a 1
  = error / 2 = correct column as perfect accuracy; `rtprep` refuses it
  instead.
- **Warnings come once per call**, naming how many groups failed, rather
  than once per group.
- **Bounds are inclusive.** A trial is flagged only when it falls
  strictly outside
  [`rule_cutoff()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)’s
  bounds; `trimr` uses strict comparisons, so the two can disagree on a
  trial sitting exactly on a bound.
- **[`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md)
  uses `s = 1`**, as `bmm` does, where Wagenmakers et al. use 0.1; drift
  and bound scale with `s` and non-decision time does not.

## Handing a screened data set to `bmm`

The point of matching the column names is that a `bmm` fit takes
`rtprep`’s output without translation. Both models need Stan, so the
calls are shown and not run. The EZ-diffusion model fits a summary
table, which
[`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
and
[`adjust_accuracy()`](https://www.gfrischkorn.org/rtprep/reference/adjust_accuracy.md)
produce per cell:

``` r

library(bmm)

ezdm_data <- trial_data |>
  reframe(
    rt_summary(rt, response, method = "mixture", distribution = "lognormal"),
    .by = c(subject, condition)
  ) |>
  mutate(adjust_accuracy(n_upper, n_trials, contaminant_prop))

fit_ez <- bmm(
  formula = bmf(drift ~ condition, bound ~ 1, ndt ~ 1),
  data = ezdm_data,
  model = ezdm(
    mean_rt = "mean_rt", var_rt = "var_rt",
    n_upper = "n_upper_adj", n_trials = "n_trials_adj"
  )
)
```

The full diffusion model fits trial-level data, which a screen filters
in one verb:

``` r

clean_data <- trial_data |>
  filter(rt_keep(rt, rule_recursive("modified"), .by = list(subject, condition)))

fit_ddm <- bmm(
  formula = bmf(drift ~ condition, bound ~ 1, ndt ~ 1),
  data = clean_data,
  model = ddm(resp1 = "rt", resp2 = "response")
)
```

The alternative to filtering is to keep every trial and hand the
mixture’s posterior to the aggregation as a weight; the aggregation
article compares the two.

## `trimr`

`trimr` implements the absolute cutoff, the SD criterion, and van Selst
and Jolicoeur’s criteria, and returns trimmed data or per-cell means
rather than per-trial decisions. Its `sdTrim()` trims the slow side and
leaves the fast side to a separate `minRT` argument, so the comparison
is on the upper tail; `rtprep` flags both tails from one rule. The two
keep the same trials:

``` r

trimr_data <- rt_example |>
  transmute(participant = id, condition, rt, accuracy = response)

kept_by_trimr <- trimr::sdTrim(
  trimr_data,
  minRT = 0, sd = 2.5, perCondition = TRUE, perParticipant = TRUE,
  omitErrors = FALSE, returnType = "raw"
)

kept_by_rtprep <- rt_example |>
  filter(rt_keep(rt, rule_sd(2.5), .by = list(id, condition)))
#> sd(2.5, mean, sd): dropped 26 of 800 trials (3.2%)

c(trimr = nrow(kept_by_trimr), rtprep = nrow(kept_by_rtprep))
#>  trimr rtprep 
#>    774    774
setequal(kept_by_trimr$rt, kept_by_rtprep$rt)
#> [1] TRUE
```

The recursive criteria compare on the per-cell means that `trimr`
returns:

``` r

trimr_means <- trimr::modifiedRecursive(
  trimr_data,
  minRT = 0, omitErrors = FALSE, returnType = "mean", digits = 10
)

rtprep_means <- rt_example |>
  filter(rt_keep(rt, rule_recursive("modified"), .by = list(id, condition))) |>
  summarise(mean_rt = mean(rt), .by = c(id, condition)) |>
  tidyr::pivot_wider(names_from = condition, values_from = mean_rt)
#> recursive(modified): dropped 33 of 800 trials (4.1%)

all.equal(
  as.numeric(as.matrix(trimr_means[, c("hard", "easy")])),
  as.numeric(as.matrix(rtprep_means[, c("hard", "easy")]))
)
#> [1] TRUE
```

Two documented divergences remain. `trimr` compares strictly and
`rtprep` inclusively, so a trial sitting exactly on a bound is removed
by one and kept by the other. And `trimr`’s modified recursive procedure
removes an extreme by value, which would take every tied copy at once,
where `rtprep` removes it by position; with continuous response times
the two agree, as they do above. `trimr`’s hybrid statistic, the mean of
the two condition means, is recoverable from `rtprep` by summarising the
two variants separately, as
[`?rule_recursive`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
shows, and not from any single keep vector.

## Versions this page was built against

``` r

c(
  rtprep = as.character(packageVersion("rtprep")),
  bmm = if (has_bmm) as.character(packageVersion("bmm")) else "not installed",
  trimr = if (has_trimr) as.character(packageVersion("trimr")) else "not installed"
)
#>  rtprep     bmm   trimr 
#> "0.1.0" "1.3.1" "1.1.1"
```

A release of `bmm` or `trimr` that changed an algorithm would show here,
and in `rtprep`’s check workflow, which installs both and runs the same
comparisons with tighter tolerances than a page can show.
