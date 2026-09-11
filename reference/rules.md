# Screening rules

Rule constructors are parameter objects: they validate their arguments
and describe themselves, but perform no computation on data. Pass one to
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md),
which applies it and returns the same four per-trial columns whichever
rule was used.

Rules from incompatible families therefore become directly comparable:

- `rule_cutoff()` applies fixed absolute bounds.

- `rule_sd()` applies a location/spread criterion, covering both the SD
  criterion and the median absolute deviation criterion.

- `rule_mad()` is a thin alias of
  `rule_sd(center = "median", scale = "mad")`.

- `rule_iqr()` applies Tukey's quartile fences, asymmetric by
  construction.

- `rule_recursive()` applies the sample-size-dependent criteria of van
  Selst and Jolicoeur (1994).

- `rule_ewma()` applies the accuracy control chart of Vandekerckhove and
  Tuerlinckx (2007).

- `rule_mixture()` fits a uniform-contaminant mixture by EM.

- `rule_none()` is a pass-through baseline.

- `rule_oracle()` is perfect exclusion, for generated data with known
  truth.

## Usage

``` r
rule_cutoff(min = 0, max = Inf)

rule_sd(n_sd = 2.5, center = c("mean", "median"), scale = c("sd", "mad"))

rule_mad(n_mad = 2.5)

rule_iqr(k = 1.5)

rule_recursive(type = c("moving", "modified", "hybrid"), include_max = TRUE)

rule_ewma(lambda = 0.01, L = 1.5, chance = 0.5)

rule_mixture(
  distribution = c("exgaussian", "lognormal", "invgaussian"),
  bound = c("min", "max"),
  use_accuracy = FALSE,
  chance = 0.5,
  init = 0.05,
  max_prop = 0.5,
  maxit = 500,
  tol = 1e-06
)

rule_none()

rule_oracle(contaminant)

# S3 method for class 'rtprep_rule'
print(x, ...)
```

## Arguments

- min, max:

  Absolute bounds in seconds. Bounds are **inclusive**: a trial is
  flagged only when it falls strictly outside. `max = Inf` leaves the
  upper tail untouched.

- n_sd, n_mad:

  Multiplier applied to the spread statistic.

- center:

  Location statistic, `"mean"` or `"median"`.

- scale:

  Spread statistic, `"sd"` or `"mad"`. `"mad"` uses
  [`stats::mad()`](https://rdrr.io/r/stats/mad.html) and so carries the
  usual consistency constant of 1.4826.

- k:

  Multiplier applied to the interquartile range when placing Tukey's
  fences. 1.5 marks an outlier, 3 a far-out point.

- type:

  Which recursive criterion to use; see Details.

- include_max:

  Whether the largest response time enters the mean and standard
  deviation from which the criterion is built. Applies to
  `type = "moving"` only.

- lambda:

  Smoothing weight of the exponentially weighted moving average, in
  `(0, 1]`. Smaller values average over more trials.

- L:

  Control-limit multiplier; the chart signals when the average departs
  from chance by more than `L` standard errors.

- chance:

  Accuracy expected from a contaminant response, known from the design
  (0.5 for a two-alternative task).

- distribution:

  Parametric distribution for the valid response time component of the
  mixture.

- bound:

  Length-2 bounds of the uniform contaminant component. Each element may
  be a number, or `"min"`/`"max"` for a data-driven bound.

- use_accuracy:

  Whether accuracy enters the mixture likelihood. **Experimental**; see
  Details.

- init:

  Starting value for the contaminant proportion.

- max_prop:

  Upper bound on the estimated contaminant proportion.

- maxit:

  Maximum number of EM iterations. A fit that reaches `maxit` is
  reported as unconverged and keeps every trial in its group.
  [`bmm::flag_contaminant_rts()`](https://venpopov.com/bmm/reference/flag_contaminant_rts.html)
  uses 100; pass `maxit` explicitly when comparing the two packages.

- tol:

  Convergence tolerance on the log-likelihood.

- contaminant:

  Logical vector, one value per trial, marking which trials are
  contaminants. `NA` means unknown, and an unknown trial is kept.

- x:

  A rule object.

- ...:

  Ignored.

## Value

An object of class `c("rtprep_rule_<name>", "rtprep_rule")`: a list of
validated parameters plus a `label` element used for the `.rule` column
of
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md).

## Absolute cutoffs

The oldest and still the most common screen: discard anything faster
than a plausible minimum or slower than a plausible maximum. Ratcliff
(1993) is the standard treatment; Ulrich and Miller (1994) is the
counterweight, showing that truncation biases the surviving distribution
even when it removes real contaminants.

Bounds are inclusive, so `rule_cutoff(min = 0.18)` keeps a response time
of exactly 180 ms, since 180 ms is not *below* 180 ms. Note that `trimr`
uses strict comparisons, so the two implementations can disagree on a
trial sitting exactly on a bound.

## Location and spread criteria

`rule_sd()` flags trials further than `n_sd` spread units from a centre,
recomputed within each group of
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md).
`center = "mean", scale = "sd"` is the standard deviation criterion,
modal practice in the field; `center = "median", scale = "mad"` is the
median absolute deviation criterion recommended by Leys et al. (2013),
also available as `rule_mad()`.

One constructor covers both because they are one family: the same
algorithm with a different location/spread pair. Miller (1991) is the
standard warning about the standard deviation criterion: the proportion
of a skewed distribution that survives a fixed multiplier depends on
sample size, so the criterion silently changes what it removes as trial
counts vary. That dependence is what `rule_recursive()` was designed to
remove.

When the spread statistic cannot be used, because a group holds fewer
than two observed trials or because the spread is zero, nothing is
flagged; see
[extending](https://www.gfrischkorn.org/rtprep/reference/extending.md)
for the contract this follows from.

## Quartile fences

`rule_iqr()` flags trials outside Tukey's fences, `Q1 - k * IQR` and
`Q3 + k * IQR`, with quartiles at R's default type 7. `k = 1.5` is
Tukey's (1977) value and `k = 3` his marker for a far-out point. It is
the criterion a boxplot draws, and so the one behind "I removed the
points outside the whiskers".

Not quite, though:
[`grDevices::boxplot.stats()`](https://rdrr.io/r/grDevices/boxplot.stats.html)
places the fences at [`fivenum()`](https://rdrr.io/r/stats/fivenum.html)
hinges rather than at type-7 quartiles, and the two differ at some
sample sizes – for `n = 10` and `n = 50` in a quick check, not for
`n = 9`, `11` or `51`. `rule_iqr()` uses the quartiles, which is what
[`stats::quantile()`](https://rdrr.io/r/stats/quantile.html) and
[`ggplot2::geom_boxplot()`](https://ggplot2.tidyverse.org/reference/geom_boxplot.html)
use.

It belongs to neither family above. `rule_cutoff()` fixes its bounds in
advance; `rule_sd()` places them symmetrically around a centre. Tukey's
fences are estimated from the data like the second and asymmetric like
neither, so on a right-skewed response time distribution the upper fence
sits further from the median than the lower one. That asymmetry is the
reason to have it: a symmetric criterion on skewed data spends its
budget in the tail the distribution is thin in.

Fewer than four observed trials in a group, or an interquartile range of
zero, flags nothing.

## Recursive and moving criteria

Van Selst and Jolicoeur (1994) answered Miller's (1991) sample-size
problem by making the multiplier itself depend on the number of trials.
`rtprep` ships their published criteria (their Table 4, tabulated at 4
to 15, 20, 25, 30, 35, 50, and 100 trials), linearly interpolated
between the tabulated sample sizes as the table's note instructs and as
`trimr` does. Below 4 no criterion exists and nothing is flagged; above
100 the value for 100 is used.

- `type = "moving"` is their non-recursive moving criterion: one pass,
  with the multiplier read off the table for the group's trial count.

- `type = "modified"` is the modified recursive procedure: the largest
  remaining response time is *temporarily set aside* while the mean and
  standard deviation are computed, the most extreme trial at each end is
  removed if it falls outside the resulting bounds, and the procedure
  repeats until nothing is removed or fewer than five trials remain. The
  temporary exclusion is what makes the rule bite, so it applies
  whatever `include_max` says; `include_max` governs `type = "moving"`
  only.

- `type = "hybrid"` averages the two. Per trial, `.prob` is the mean of
  the two rules' decisions and so takes the value 0, 0.5, or 1; under
  the default keep policy a trial survives only if both rules keep it.

Note that van Selst and Jolicoeur's published hybrid statistic is the
mean of the two *condition means*, which no single per-trial keep vector
can reproduce, because the two means have different denominators. To
recover the published statistic, summarise the two rules separately and
average:

    keep_moving <- rt_screen(rt, rule = rule_recursive("moving"))$.keep
    moving <- rt_summary(rt[keep_moving])
    keep_modif <- rt_screen(rt, rule = rule_recursive("modified"))$.keep
    modif <- rt_summary(rt[keep_modif])
    (moving$mean_rt + modif$mean_rt) / 2

## Accuracy control chart

`rule_ewma()` is the exponentially weighted moving average cutoff
introduced with DMAT (Vandekerckhove & Tuerlinckx, 2007), and the only
*published* screen that uses accuracy rather than response time alone.
Trials are ordered from fastest to slowest and an exponentially weighted
average of accuracy is accumulated, starting from `chance`. The control
limit at trial \\i\\ is

\$\$\mathrm{UCL}\_i = \gamma + L\\\sigma
\sqrt{\frac{\lambda}{2-\lambda}\left(1-(1-\lambda)^{2i}\right)},\$\$

with \\\gamma\\ the chance rate and \\\sigma = \sqrt{\gamma(1-\gamma)}\\
the standard deviation of a guess. The cutoff is the response time at
which the average first rises above the limit: below it, accuracy is
indistinguishable from guessing, so those trials are flagged. If the
average never crosses, nothing is flagged.

The chart lags, and the lag is a cost rather than an implementation
detail: the average needs several trials above chance before it clears
the limit, so the cutoff lands past the point where accuracy actually
rose and valid trials just above it are flagged along with the guesses.
Smaller `lambda` averages over more trials and overshoots further.
Ratcliff and Kang (2021) note that this rule has not found much use;
`rtprep` ships it as the published accuracy-based comparator, not as a
recommendation.

This rule requires `response`, coded as correct/error rather than as an
upper/lower boundary.

## Mixture flagging

`rule_mixture()` fits, per group, a two-component mixture of a uniform
contaminant distribution over `bound` and a parametric response time
distribution, by expectation maximisation (Ratcliff & Tuerlinckx, 2002).
`.prob` is then the posterior probability that a trial came from the
response time component. This is the one rule in the package that
returns something other than 0 and 1, and the reason
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
separates the probability from the keep decision at all.

The bounds of the uniform component are buffered outward from the
observed range by half its width. Without that buffer the uniform's
edges sit exactly on data points and the mixture is barely identifiable.

Which core distribution you choose matters more than it looks. On a
tight block of fast guesses the ex-Gaussian can absorb the block by
widening its Gaussian part and driving `tau` to zero, reporting no
contamination at all, where the lognormal and inverse Gaussian cores
find it. The same thing happens in `bmm`'s implementation, so it is a
property of the model rather than of either package. It is still a
reason to check `attr(x, "fits")$contaminant_prop` against what you
expected rather than trusting the default.

When the EM does not converge, or a group has fewer than five trials
inside the bounds, **nothing is flagged** and
`attr(x, "fits")$converged` is `FALSE`.
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
warns once for the whole call, naming how many groups failed, rather
than once per group. Note that `bmm` returns `NA` probabilities in this
situation; `rtprep` keeps the data, because an `NA` would propagate into
`.keep`.

## Accuracy inside the likelihood

`use_accuracy = TRUE` is **experimental**. It puts accuracy inside the
mixture likelihood rather than using it only afterwards, on the
reasoning that a fast trial that is *correct* is less likely to be a
guess than a fast trial that is an error, which an RT-only mixture
cannot see. With `y` the accuracy indicator, \\\gamma\\ the chance rate
known from the design, and \\p_c\\ the estimated accuracy of the
decision process:

\$\$f(rt, y) = (1 - \pi) f\_{RT}(rt \mid \theta)\\
p_c^{y}(1-p_c)^{1-y} + \pi\\ U(rt \mid a, b)\\
\gamma^{y}(1-\gamma)^{1-y}.\$\$

\\\gamma\\ is fixed, not estimated. The M-step for \\p_c\\ is the
responsibility-weighted mean of `y`, so the extension costs the EM
almost nothing; the fitted value comes back as `p_correct` in
`attr(x, "fits")`.

### What is known so far, and it is not all good

The staging is deliberate, and the reasons are concrete. Three things
the package's own tests establish:

- **It can order overlapping guesses better than response time alone.**
  Where contaminants fall inside the valid distribution's range, which
  is the case RT-only detection fails at, the joint posterior ranks them
  more accurately.

- **But the fit tends to collapse.** A contaminant proportion of zero is
  a fixed point of this EM, and the accuracy factor widens its basin
  because it favours the valid component on every correct trial. On
  exactly the overlapping case above, the fit converges cleanly with
  \\\pi \approx 10^{-7}\\ and the rule removes nothing at all: the
  better ordering is one the keep policy never gets to act on. Check
  `collapsed` and `contaminant_prop` in `attr(x, "fits")` against what
  you expected.

- **It actively hurts when contaminants are as accurate as valid
  trials.** A delayed start-up still runs the decision process, so it is
  usually correct, and every correct contaminant has its contaminant
  evidence attenuated by \\\gamma / p_c\\. This is not neutrality: in
  the package's own test the joint model loses a large part of the
  sensitivity the RT-only model had.

The same deflation applies whenever observed accuracy is well above
chance, which in most response time paradigms is always. Treat a
contaminant proportion below the RT-only estimate as expected rather
than as evidence of a cleaner data set.

Two things the method cannot enforce for you:

- It assumes contaminants respond at `chance`. Get `chance` wrong, by
  screening a four-alternative task at 0.5, and detection degrades
  sharply.

- `response` must be coded **correct/error**, not upper/lower boundary.
  Both are 0/1, so `rtprep` cannot tell them apart.

Nothing forces the valid component to be the accurate one either. When a
fit comes back with \\p_c\\ below `chance` the labels have swapped,
which usually means the two components are not separable at that
contamination rate. `rtprep` reports rather than constrains:
`accuracy_inverted` in `attr(x, "fits")`, plus one warning per call.

## No screening

`rule_none()` keeps every trial. It exists so that "no preprocessing" is
an entry in the roster rather than a missing row, and so that pipelines
can be compared against it without a special case.

## Perfect exclusion

`rule_oracle()` removes exactly the trials you tell it are contaminants
and nothing else. It is not a method: on real data nobody has the vector
it needs. It is the ceiling the others are read against.

The reason to have it is that a drop rate and a hit rate do not say what
a pipeline costs. Running the oracle through the same aggregation and
the same estimation as a real rule gives the error that remains when
screening is perfect, and the difference between the two is what the
screening decision actually bought.
[`r_contaminated()`](https://www.gfrischkorn.org/rtprep/reference/r_contaminated.md)
returns the `contaminant` column this takes, so the comparison is two
calls.

`contaminant` holds one value per trial and is subset alongside `rt`, so
the rule works under `.by` grouping like any other.

## References

Ratcliff, R. (1993). Methods for dealing with reaction time outliers.
*Psychological Bulletin*, *114*(3), 510–532.
[doi:10.1037/0033-2909.114.3.510](https://doi.org/10.1037/0033-2909.114.3.510)

Ulrich, R., & Miller, J. (1994). Effects of truncation on reaction time
analysis. *Journal of Experimental Psychology: General*, *123*(1),
34–80.
[doi:10.1037/0096-3445.123.1.34](https://doi.org/10.1037/0096-3445.123.1.34)

Leys, C., Ley, C., Klein, O., Bernard, P., & Licata, L. (2013).
Detecting outliers: Do not use standard deviation around the mean, use
absolute deviation around the median. *Journal of Experimental Social
Psychology*, *49*(4), 764–766.
[doi:10.1016/j.jesp.2013.03.013](https://doi.org/10.1016/j.jesp.2013.03.013)

Miller, J. (1991). Reaction time analysis with outlier exclusion: Bias
varies with sample size. *The Quarterly Journal of Experimental
Psychology Section A*, *43*(4), 907–912.
[doi:10.1080/14640749108400962](https://doi.org/10.1080/14640749108400962)

Tukey, J. W. (1977). *Exploratory data analysis*. Addison-Wesley.

Van Selst, M., & Jolicoeur, P. (1994). A solution to the effect of
sample size on outlier elimination. *The Quarterly Journal of
Experimental Psychology Section A*, *47*(3), 631–650.
[doi:10.1080/14640749408401131](https://doi.org/10.1080/14640749408401131)

Cousineau, D., & Chartier, S. (2010). Outliers detection and treatment:
A review. *International Journal of Psychological Research*, *3*(1),
58–67.
[doi:10.21500/20112084.844](https://doi.org/10.21500/20112084.844)

Vandekerckhove, J., & Tuerlinckx, F. (2007). Fitting the Ratcliff
diffusion model to experimental data. *Psychonomic Bulletin & Review*,
*14*(6), 1011–1026.
[doi:10.3758/bf03193087](https://doi.org/10.3758/bf03193087)

Ratcliff, R., & Kang, I. (2021). Qualitative speed-accuracy tradeoff
effects can be explained by a diffusion/fast-guess mixture model.
*Scientific Reports*, *11*, 15169.
[doi:10.1038/s41598-021-94451-7](https://doi.org/10.1038/s41598-021-94451-7)

Liu, Y., Cheng, Y., & Liu, H. (2020). Identifying effortful individuals
with mixture modeling response accuracy and response time simultaneously
to improve item parameter estimation. *Educational and Psychological
Measurement*, *80*(4), 775–807.
[doi:10.1177/0013164419895068](https://doi.org/10.1177/0013164419895068)

Ratcliff, R., & Tuerlinckx, F. (2002). Estimating parameters of the
diffusion model: Approaches to dealing with contaminant reaction times
and parameter variability. *Psychonomic Bulletin & Review*, *9*(3),
438–481. [doi:10.3758/bf03196302](https://doi.org/10.3758/bf03196302)

## See also

[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
to apply a rule;
[`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
to apply several;
[`rule_all()`](https://www.gfrischkorn.org/rtprep/reference/rules_compose.md)
to combine them;
[`rule_hierarchical()`](https://www.gfrischkorn.org/rtprep/reference/rule_hierarchical.md)
for a criterion pooled across groups. Two further, experimental rules
are unexported and documented in
[`?rules_experimental`](https://www.gfrischkorn.org/rtprep/reference/rules_experimental.md).

## Examples

``` r
rule_cutoff(0.18, 3)
#> <rtprep rule> cutoff(0.18, 3) 
#>  Exclude trials outside [0.18, 3] seconds (bounds inclusive).

rule_sd(2.5)
#> <rtprep rule> sd(2.5, mean, sd) 
#>  Exclude trials more than 2.5 x sd from the mean, computed per group.
rule_mad(3)
#> <rtprep rule> sd(3, median, mad) 
#>  Exclude trials more than 3 x mad from the median, computed per group.

rule_iqr()
#> <rtprep rule> iqr(1.5) 
#>  Exclude trials outside Tukey's fences, Q1 - 1.5 x IQR and Q3 + 1.5 x IQR, computed per group.
rule_iqr(3)
#> <rtprep rule> iqr(3) 
#>  Exclude trials outside Tukey's fences, Q1 - 3 x IQR and Q3 + 3 x IQR, computed per group.

rule_recursive("modified")
#> <rtprep rule> recursive(modified) 
#>  Van Selst & Jolicoeur (1994) modified recursive criterion, iterated.

rule_ewma(lambda = 0.05)
#> <rtprep rule> ewma(0.05, 1.5) 
#>  Exclude trials faster than the response time at which accuracy first departs from 0.5 (lambda = 0.05, L = 1.5).

rule_mixture("lognormal")
#> <rtprep rule> mixture(lognormal) 
#>  Flag trials by their posterior probability under a uniform-contaminant / lognormal mixture.

rule_none()
#> <rtprep rule> none 
#>  Keep every trial.

truth <- rt_example$contaminant
oracle <- rule_oracle(truth)
oracle
#> <rtprep rule> oracle 
#>  Exclude exactly the 60 trials marked as contaminants. Requires ground truth, so simulated data only.

# what a real rule leaves behind, against what perfect exclusion leaves
screen_compare(
  rt_example$rt,
  list(mad = rule_mad(2.5), oracle = oracle),
  .by = rt_example$id
)
#> <rtprep comparison> 800 trials, 2 rules
#> 
#>   mad                          dropped  11.0%
#>   oracle                       dropped   7.5%
#> 
#>   least agreement: mad vs oracle, 86.5% of decisions (Jaccard 0.16)
```
