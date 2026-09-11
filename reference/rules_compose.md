# Combine screening rules

A composite is a rule, so it goes wherever a rule goes:
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md),
[`rt_keep()`](https://www.gfrischkorn.org/rtprep/reference/rt_keep.md),
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md),
[`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md).

## Usage

``` r
rule_all(...)

rule_any(...)

rule_then(..., threshold = 0.5)
```

## Arguments

- ...:

  Two or more rule objects.

- threshold:

  Probability above which a trial survives a stage and is passed to the
  next. Only `rule_then()` takes this: which trials the later stages see
  is part of the rule, not part of the exclusion policy applied
  afterwards by
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md).

## Value

An object of class `c("rtprep_rule_<name>", "rtprep_rule")` holding the
components in `rules`.

## Details

`rule_all()` keeps a trial only when every component keeps it, so the
trials it removes are the *union* of what the components remove.
`rule_any()` keeps a trial that any component keeps, so it removes only
the *intersection*. `rule_then()` runs the components in order, each
estimated on the trials the previous ones left.

## Which one you want

Screening rules disagree because they look in different places. The
location and spread criteria and the recursive criteria read the slow
tail; on anticipations at the leading edge of a right-skewed
distribution they remove nothing, because those trials sit well inside a
criterion built around the mean.
[`rule_ewma()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
reads accuracy and finds the leading edge, and is blind to the slow
tail. Combining one of each with `rule_all()` covers both, which no
single conventional rule does.

`rule_then()` is the other idiom, and it is what a two-stage description
like "trials below 200 ms were discarded, then trials more than 2.5 SD
from each participant's mean" actually means: the standard deviation is
computed after the floor, on the survivors.
`trimr::sdTrim(minRT = , sd = )` does exactly this, and
`rule_then(rule_cutoff(0.2), rule_sd(2.5))` reproduces it. Writing the
two stages in parallel instead gives a different answer, because the
fast trials are still inflating the standard deviation when it is
estimated.

## What `.prob` becomes

`rtprep` keeps the probability that a trial is valid separate from the
decision to drop it, and a composite has to preserve that. `rule_all()`
takes the smallest of the component probabilities and `rule_any()` the
largest, so the composite's `.prob` is still a probability of validity
and still drives `policy = "probabilistic"` and
`rt_summary(weights = )`. For components that return 0 and 1 this
reduces to the logical operation, and a mixture combined with a
deterministic rule keeps its posterior wherever the deterministic rule
does not veto.

`rule_then()` reports the probability from the stage that flagged the
trial, or from the last stage to see it if none did. `.reason` comes
from the first component to flag, in the order given.

## What [`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md) reports

One row per group, as always, with each component's diagnostics prefixed
by its position: `r1_lower`, `r2_criterion`, and so on. `rule_then()`
adds `r1_n_flagged`, `r2_n_flagged`, ... so it is visible how much work
each stage did, which is the number a staged pipeline usually wants and
rarely reports.

## See also

[rules](https://www.gfrischkorn.org/rtprep/reference/rules.md) for the
components.

## Examples

``` r
# the slow tail and the leading edge, which no single rule covers
rule_all(rule_mad(2.5), rule_ewma())
#> <rtprep rule> all(sd(2.5, median, mad), ewma(0.01, 1.5)) 
#>  Exclude a trial that any of these rules excludes:
#>     1. sd(2.5, median, mad)
#>     2. ewma(0.01, 1.5)

# a floor, then a criterion estimated on what the floor left
staged <- rule_then(rule_cutoff(0.2), rule_sd(2.5))
staged
#> <rtprep rule> then(cutoff(0.2, Inf), sd(2.5, mean, sd)) 
#>  Apply in order, each estimated on the trials the last one left (stage threshold 0.5):
#>     1. cutoff(0.2, Inf)
#>     2. sd(2.5, mean, sd)

screen_fits(rt_example$rt, staged, .by = rt_example$id)
#>   .group n_trials n_dropped prop_dropped r1_lower r1_upper r1_n_seen
#> 1     p1      200         6        0.030      0.2      Inf       200
#> 2     p2      200         6        0.030      0.2      Inf       200
#> 3     p3      200         6        0.030      0.2      Inf       200
#> 4     p4      200         7        0.035      0.2      Inf       200
#>   r1_n_flagged r2_center  r2_scale    r2_lower r2_upper r2_n_seen r2_n_flagged
#> 1            0 0.6029486 0.2324541  0.02181338 1.184084       200            6
#> 2            0 0.6125909 0.2707331 -0.06424181 1.289424       200            6
#> 3            0 0.6327961 0.3409229 -0.21951107 1.485103       200            6
#> 4            0 0.6173370 0.3413135 -0.23594682 1.470621       200            7
```
