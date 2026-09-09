# Invert summary statistics into diffusion parameters

The closed-form EZ-diffusion equations of Wagenmakers, van der Maas and
Grasman (2007): mean response time, response time variance, and accuracy
in; drift rate, boundary separation, and non-decision time out.

Exported so that the whole pipeline-to-parameters check runs with only
`rtprep` installed — a reader can screen, aggregate, and estimate
without reaching for a model-fitting package.

## Usage

``` r
ez_ddm(mean_rt, var_rt, accuracy, n_trials, s = 1)
```

## Arguments

- mean_rt, var_rt:

  Mean and variance of the response times, in seconds. Wagenmakers et
  al. define these on *correct* responses; `version = "3par"` of
  [`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
  pools both boundaries, which is equivalent under an unbiased diffusion
  and not otherwise. Use `version = "4par"` if the starting point may be
  off centre.

- accuracy:

  Proportion of upper-boundary (correct) responses, in `[0, 1]`.

- n_trials:

  Number of trials the statistics came from. Required: it sets the size
  of the edge correction.

- s:

  Scaling constant. `1` here; Wagenmakers et al. use `0.1`. This is a
  units convention, not a modelling one — `drift` and `bound` scale
  linearly with `s` and `ndt` does not, so a drift of 0.1 at `s = 0.1`
  and a drift of 1.0 at `s = 1` describe the same process.

## Value

A `data.frame` with `drift`, `bound`, `ndt`, and a logical
`edge_corrected`, one row per input element (inputs recycle to a common
length). `edge_corrected` flags the rows that needed the correction
below.

## Details

The equations divide by `logit(accuracy)` and break down at accuracies
of 0, 0.5, and 1. Wagenmakers et al.'s edge correction moves the
offending value by `1 / (2 * n_trials)`: 1 becomes `1 - 1/(2n)`, 0
becomes `1/(2n)`, and 0.5 becomes `0.5 + 1/(2n)`. It is applied
silently, because it is the published behaviour and a warning per cell
would bury a simulation run — but which cells were corrected comes back
in the `edge_corrected` column, so a script can count them. It is a
column rather than an attribute so that it survives `[`,
[`rbind()`](https://rdrr.io/r/base/cbind.html), and the dplyr verbs.

EZ is fragile under contamination: a handful of fast guesses moves the
drift estimate a long way (Ratcliff, 2008). That fragility is the point
of the comparison this package exists to support, not a reason to avoid
the estimator.

## References

Wagenmakers, E.-J., van der Maas, H. L. J., & Grasman, R. P. P. P.
(2007). An EZ-diffusion model for response time and accuracy.
*Psychonomic Bulletin & Review*, *14*(1), 3–22.
[doi:10.3758/bf03194023](https://doi.org/10.3758/bf03194023)

Ratcliff, R. (2008). The EZ diffusion method: Too EZ? *Psychonomic
Bulletin & Review*, *15*(6), 1218–1228.
[doi:10.3758/pbr.15.6.1218](https://doi.org/10.3758/pbr.15.6.1218)

## See also

[`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md),
which produces exactly the inputs this takes.

## Examples

``` r
# the worked example from Wagenmakers et al. (2007)
ez_ddm(
  mean_rt = 0.723, var_rt = 0.112, accuracy = 0.802,
  n_trials = 100, s = 0.1
)
#>        drift     bound     ndt edge_corrected
#> 1 0.09993853 0.1399702 0.30003          FALSE
```
