# Experimental screening rules (not exported)

Two rules kept out of the exported roster. A function on the package
index reads as a recommendation, and neither is one. The code, its
tests, and this page stay so that the rules' behaviour and failure modes
can be inspected, and so that scripts calling them through `rtprep:::`
keep working. Reach them with `rtprep:::rule_adaptive_trim()` and
`rtprep:::rule_ez_support()`; both return a rule object that
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
applies like any other.

## Usage

``` r
rule_adaptive_trim(q_cut = 0.05, s_accept = 0.5)

rule_ez_support(c_ndt = 1, refit = TRUE)
```

## Arguments

- q_cut:

  Lower quantile of the tentative cut, in (0, 0.5). The validation
  reference quantile is `2 * q_cut`.

- s_accept:

  Minimum proportional shift of the surviving minimum toward the
  reference quantile for the tentative cut to be accepted.

- c_ndt:

  Multiplier on the fitted non-decision time that sets the support
  bound, in (0, 1\]: no valid response time can undercut non-decision
  time, so nothing above 1 has a grounding.

- refit:

  Whether to refit the EZ model once on the survivors and re-flag
  against the updated non-decision time. Exactly one refit; the rule
  never iterates to convergence.

## Value

An object of class `c("rtprep_rule_<name>", "rtprep_rule")`, as for the
exported constructors in
[rules](https://www.gfrischkorn.org/rtprep/reference/rules.md).

## Adaptive leading-edge trim

`rule_adaptive_trim()` cuts at a lower quantile and keeps the cut only
if it looks like removed contaminants rather than removed edge. It turns
an unconditional lower trim into a validated one: cut at the empirical
`q_cut` quantile, then measure how far the surviving minimum shifted
toward the reference quantile at `2 * q_cut`,

\$\$S = \frac{\min(kept) - \min(all)}{q\_{2 q\_{cut}}(all) -
\min(all)},\$\$

and keep the cut only when `S >= s_accept`. Displaced fast contaminants
sit in a low block with a gap to the core, so removing them jumps the
minimum most of the way to the reference (`S` near 1); a genuinely steep
leading edge bunches its fastest trials, so cutting them barely moves
the minimum (`S` near 0). When the cut is rejected the rule removes
nothing, and the computed `S` and the decision are reported in
`attr(x, "fits")` either way.

What the statistic actually detects is a *gap* below the leading edge.
Across-trial variability in non-decision time smears a clean edge into
exactly such a shallow front, which is the rule's documented false-alarm
mode. Groups with fewer than 20 trials, and groups whose reference
quantile ties the minimum, are left untouched.

## EZ support screen

`rule_ez_support()` flags trials the fitted model says are impossible.
Its two failure modes follow from that premise: late delayed start-ups
drag the fitted non-decision time below zero and the rule reverts to
keeping everything, while across-trial variability in non-decision time
pushes genuine trials under the bound and the rule removes them. Every
evidence accumulation model writes a response time as non-decision time
plus a strictly positive decision time, so no valid trial can undercut
non-decision time. The rule fits the closed-form EZ model to a group's
trials, flags everything below `c_ndt` times the fitted non-decision
time, refits once on the survivors (`refit = TRUE`), re-flags against
the updated estimate, and stops there. It never iterates further,
because lower-tail removal shrinks the variance and pushes the estimate
upward, a one-way ratchet that unlimited iteration would run away with.

The catch is the point: fast contaminants drag the fitted non-decision
time down, so the rule's premise is poisoned by exactly the trials it
hunts. Whether one refit recovers the threshold is an empirical
question, not a guarantee. Groups with fewer than ten trials, unusable
fits (including a negative fitted non-decision time, which contaminated
moments can produce), and fits that would flag more than half the group
all remove nothing, with `usable = FALSE` in `attr(x, "fits")`. That
last guard is defensive: at `c_ndt <= 1` a first-pass EZ threshold
cannot exceed the sample median, because the mean never sits more than
one standard deviation above the median while the implied decision-time
mean always exceeds it.

This rule requires `response`, coded as correct/error.

## Examples

``` r
rtprep:::rule_adaptive_trim()
#> <rtprep rule> adaptive_trim(0.05, 0.5) 
#>  Cut the fastest 5% only when the surviving minimum shifts at least 0.5 of the way to the q10 quantile (experimental).

rtprep:::rule_ez_support()
#> <rtprep rule> ez_support(1, refit) 
#>  Exclude trials below 1 x the closed-form EZ non-decision time, refitted once on the survivors (experimental).
```
