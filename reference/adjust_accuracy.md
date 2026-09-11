# Correct accuracy counts for contamination

Removes the estimated contaminant trials from the accuracy counts, on
the assumption that contaminants respond correctly at `guess_rate`. A
port of
[`bmm::adjust_ezdm_accuracy()`](https://venpopov.com/bmm/reference/adjust_ezdm_accuracy.html).

## Usage

``` r
adjust_accuracy(n_upper, n_trials, contaminant_prop, guess_rate = 0.5)
```

## Arguments

- n_upper:

  Count of upper-boundary (correct) responses. Vectorised: the three
  count and proportion arguments recycle to a common length, one row per
  element, so the function takes the columns of a summary table
  directly.

- n_trials:

  Total number of trials.

- contaminant_prop:

  Estimated contaminant proportion, typically the `contaminant_prop`
  column of
  [`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md).
  `NA` or `<= 0` returns that row's counts unchanged.

- guess_rate:

  Accuracy assumed for a contaminant response, known from the design.
  `0.5` for a two-alternative task. One value for every row.

## Value

A `data.frame` with integer `n_upper_adj` and `n_trials_adj`, one row
per input element. A row whose `n_upper` or `n_trials` is `NA` comes
back `NA`.

## Details

**Stochastic by design.** How many trials were contaminants, and how
many of those happened to be correct, are both binomial draws, so
repeated calls differ. That is faithful to the uncertainty in a mixture
estimate, which a point estimate would understate, and it matches `bmm`.
There is no [`set.seed()`](https://rdrr.io/r/base/Random.html) anywhere
in `rtprep`; reproducibility is the caller's.

Each row draws independently. For a single row the two draws are made in
the same order as
[`bmm::adjust_ezdm_accuracy()`](https://venpopov.com/bmm/reference/adjust_ezdm_accuracy.html),
so the two functions give the same answer from the same random seed.

## See also

[`rt_summary()`](https://www.gfrischkorn.org/rtprep/reference/rt_summary.md)
for the counts and the proportion,
[`ez_ddm()`](https://www.gfrischkorn.org/rtprep/reference/ez_ddm.md) for
what to do with them.

## Examples

``` r
set.seed(42)
adjust_accuracy(n_upper = 80, n_trials = 100, contaminant_prop = 0.1)
#>   n_upper_adj n_trials_adj
#> 1          70           86

# one row per cell of a summary table
cells <- data.frame(
  n_upper = c(80, 45), n_trials = c(100, 50), contaminant_prop = c(0.1, 0.2)
)
adjust_accuracy(cells$n_upper, cells$n_trials, cells$contaminant_prop)
#>   n_upper_adj n_trials_adj
#> 1          75           92
#> 2          37           37
```
