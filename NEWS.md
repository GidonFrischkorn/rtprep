# rtprep 0.0.0.9000 (development version)

## New features

* `rt_screen()` applies any screening rule to a response time vector and returns
  the same four per-trial columns whichever rule was used: `.keep`, `.prob`,
  `.rule`, and `.reason`. Per-group fit diagnostics come back as
  `attr(x, "fits")`. Grouping is handled internally through `.by`, so the
  function works inside `dplyr::mutate()`, `dplyr::reframe()`, or
  `data.table`'s `by=` without the package depending on any of them.

* `.prob` is the probability that a trial came from the decision process — that
  is, P(valid) — and the keep decision is a separate, explicit policy
  (`keep = "threshold"` or `"probabilistic"`). Deterministic rules are the
  degenerate case, returning 0 or 1. Note that `bmm::flag_contaminant_rts()`
  returns the complement.

* Rule constructors: `rule_cutoff()` for absolute bounds, `rule_sd()` for the
  standard deviation and median absolute deviation criteria, `rule_mad()` as a
  documented alias of the latter, `rule_recursive()` for van Selst and
  Jolicoeur's (1994) sample-size-dependent moving, modified, and hybrid
  criteria, `rule_ewma()` for the accuracy control chart of Vandekerckhove and
  Tuerlinckx (2007), and `rule_none()` as a pass-through baseline. Each carries
  its defining reference.

* `rule_mixture()` validates and describes itself, but applying it is not yet
  implemented.

## Notes

* Bounds are inclusive throughout: a trial is flagged only when it falls
  strictly outside. `trimr` uses strict comparisons, so the two can disagree on
  a response time sitting exactly on a bound. See `?rule_cutoff`.

* A rule that cannot be evaluated — fewer than two trials in a group, zero
  spread, or a sample below the smallest tabled size for `rule_recursive()` —
  removes nothing rather than returning `NA`.

* Numeric `response` must be coded 0/1. `bmm` coerces with `as.logical()`, which
  reads a 1 = error / 2 = correct column as perfect accuracy; `rtprep` refuses
  it instead.
