# Hierarchical screening

A location and spread criterion whose centre and spread are shrunk
towards the values pooled over all groups, rather than estimated from
each group alone.

## Usage

``` r
rule_hierarchical(
  n_sd = 2.5,
  n0 = 20,
  center = c("mean", "median"),
  scale = c("sd", "mad")
)
```

## Arguments

- n_sd:

  Multiplier applied to the shrunk spread.

- n0:

  Trials at which a group is weighted equally between its own estimate
  and the pooled one. Larger values shrink harder. `Inf` gives one
  criterion for every group.

- center:

  Location statistic, `"mean"` or `"median"`.

- scale:

  Spread statistic, `"sd"` or `"mad"`.

## Value

An object of class `c("rtprep_rule_hierarchical", "rtprep_rule")`.

## Details

**Experimental.** No published convention exists for it, so it has no
conventional setting to cite, and it is not a recommendation.

A per-participant criterion is estimated from the very data it is meant
to clean. A participant with a handful of very slow trials has a mean
and a standard deviation pulled outward by exactly those trials, so the
criterion widens to admit them: the more contaminated a participant is,
the less their own criterion removes. Estimating one criterion for
everyone instead trades that for a different error, since participants
really do differ in speed and variability.

Shrinkage sits between the two. Each group's centre is
`w * centre_group + (1 - w) * centre_pooled` with `w = n / (n + n0)`,
and its spread is shrunk the same way on the log scale, which keeps it
positive. `n0` is the number of trials at which a group is weighted
equally between its own estimate and the pooled one: `n0 = 0` gives each
group its own criterion, exactly as
[`rule_sd()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
under the same grouping, and `n0 = Inf` gives every group one common
criterion. A group whose own spread cannot be computed pools completely,
which is the case the method exists for.

## Grouping

`.by` in
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
names the units that are shrunk towards each other, normally
participants. Everything in one call is pooled, so a `.by` that crosses
participants with an experimental condition pools across conditions as
well, and a condition that is genuinely slower drags every centre
towards it. Screen one condition at a time.

## See also

[rules](https://www.gfrischkorn.org/rtprep/reference/rules.md) for the
criteria estimated within each group.

## Examples

``` r
rule_hierarchical()
#> <rtprep rule> hierarchical(2.5, n0 = 20, mean, sd) 
#>  Exclude trials more than 2.5 x sd from the mean, both shrunk towards the pooled value at n0 = 20 (experimental).

# what shrinkage changes, against the same criterion estimated per group
screen_compare(
  rt_example$rt,
  list(
    per_group = rule_mad(2.5),
    shrunk = rule_hierarchical(
      2.5,
      n0 = 20, center = "median", scale = "mad"
    )
  ),
  .by = rt_example$id
)
#> <rtprep comparison> 800 trials, 2 rules
#> 
#>   per_group                    dropped  11.0%
#>   shrunk                       dropped  11.0%
#> 
#>   least agreement: per_group vs shrunk, 100.0% of decisions (Jaccard 1.00)
```
