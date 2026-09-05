# rtprep 0.1.0

Initial CRAN release. `rtprep` gives the response time preprocessing
decisions that precede an evidence accumulation model fit one interface:
screening rules from incompatible families return the same per-trial object,
aggregation into EZ-diffusion summary statistics and the closed-form inversion
are separate, comparable steps, and a generator with known ground truth lets a
chosen pipeline be tested rather than trusted. The package is the companion
to a tutorial in preparation for *Advances in Methods and Practices in
Psychological Science*; the entries below describe what it does and the
decisions behind it.

## Interface changes before the first release

These are the changes that would have needed a deprecation cycle after
release, made while the package was still unreleased.

* The rule is now the second argument: `rt_screen(rt, rule, response = NULL,
  .by = NULL, ...)`, and likewise `screen_compare(rt, rules, response = NULL,
  .by = NULL, ...)`. `rt_screen(rt, rule_sd(2.5))` works as it reads, and
  `response`, which most rules do not need, is passed by name. A call that
  still passes `response` in the second position fails with "'rule' must be a
  rule object" rather than doing something else quietly.

* The exclusion policy argument is `policy = c("threshold", "probabilistic")`,
  not `keep =`. The column that holds the decision is `.keep`; the argument
  that chooses how the decision is made is the policy, and one word for two
  things was one too many. The old name is refused outright (it is not a
  prefix of the new one, so partial matching cannot rescue it).

* `rt_keep()` returns the `.keep` column alone, as a logical vector, and
  reports once how many trials it dropped: `dat |> filter(rt_keep(rt,
  rule_sd(2.5), .by = id))` is the whole filter step, with the exclusion count
  logged next to the exclusion. `quiet = TRUE` silences the message. Inside a
  grouped `filter()` the message would fire once per group, so pass `.by` to
  `rt_keep()` instead; the keep vector is the same either way.

* `screen_fits()` returns the per-group fits table alone. `attr(x, "fits")`
  does not survive `dplyr::mutate()`, so inside a pipeline the table was
  otherwise out of reach. `dat |> reframe(screen_fits(rt, rule_sd(2.5)),
  .by = id)` is now one call.

* `adjust_accuracy()` vectorises over rows: the columns of a summary table go
  straight in, one row per cell, each row drawing independently. Rows with a
  missing count come back `NA` rather than stopping the call. For a single
  row the draws are made in `bmm::adjust_ezdm_accuracy()`'s order, so the
  draw-for-draw equivalence with `bmm` still holds and is still tested.

* `ez_ddm()` returns `edge_corrected` as a column rather than an attribute, so
  the flag survives `[`, `rbind()`, and every dplyr verb instead of being
  dropped by the first one.

## New features

* `rt_screen()` applies any screening rule to a response time vector and returns
  the same four per-trial columns whichever rule was used: `.keep`, `.prob`,
  `.rule`, and `.reason`. Per-group fit diagnostics come back as
  `attr(x, "fits")`. Grouping is handled internally through `.by`, so the
  function works inside `dplyr::mutate()`, `dplyr::reframe()`, or
  `data.table`'s `by=` without the package depending on any of them.

* `.prob` is the probability that a trial came from the decision process — that
  is, P(valid) — and the keep decision is a separate, explicit policy
  (`policy = "threshold"` or `"probabilistic"`). Deterministic rules are the
  degenerate case, returning 0 or 1. Note that `bmm::flag_contaminant_rts()`
  returns the complement.

* Rule constructors: `rule_cutoff()` for absolute bounds, `rule_sd()` for the
  standard deviation and median absolute deviation criteria, `rule_mad()` as a
  documented alias of the latter, `rule_recursive()` for van Selst and
  Jolicoeur's (1994) sample-size-dependent moving, modified, and hybrid
  criteria, `rule_ewma()` for the accuracy control chart of Vandekerckhove and
  Tuerlinckx (2007), and `rule_none()` as a pass-through baseline. Each carries
  its defining reference.

* `rule_mixture()` fits a uniform-contaminant mixture by expectation
  maximisation and returns a genuine per-trial posterior probability — the case
  `.prob` exists for. Cores available are the ex-Gaussian, lognormal, and
  inverse Gaussian. The EM reproduces `bmm:::.fit_rt_mixture()`, which
  `tests/testthat/test-equivalence.R` checks across several fixtures, with two
  deliberate differences: the M-steps for the lognormal and inverse Gaussian
  use the exact weighted maximum likelihood estimator where `bmm` optimises
  numerically, and a failed fit keeps the data rather than returning `NA`.

* `rule_mixture(use_accuracy = TRUE)` puts accuracy inside the mixture
  likelihood rather than checking it afterwards, on the reasoning that a fast
  trial that is *correct* is less likely to be a guess than a fast trial that
  is an error. The chance rate is fixed from the design and the accuracy of the
  decision process is estimated, with a closed-form M-step. **Experimental**:
  it is off by default and stays that way until the simulation says otherwise.

  What is known so far is mixed, and the tests pin all of it. The joint
  posterior does *order* overlapping guesses better than response time alone —
  the case RT-only detection fails at. But on that same data the fit collapses
  to a contaminant proportion near zero and the rule removes nothing, so the
  better ordering is one the keep policy never acts on; a `collapsed` flag in
  `attr(x, "fits")` reports it. And for delayed start-ups, whose accuracy is
  intact, the model does not merely fail to help — it loses a large part of the
  sensitivity the RT-only model had, because every correct contaminant has its
  contaminant evidence attenuated by `chance / p_correct`.

  None of that is a reason to drop the idea; it is the reason the flag defaults
  to off and the simulation exists.

* `rule_adaptive_trim()` cuts at a lower quantile only when the surviving
  minimum jumps toward the reference quantile at twice the cut — the
  signature of displaced fast contaminants, which leave a gap below the core
  that a genuinely steep leading edge does not. The computed shift statistic
  and the accept/revert decision come back in `attr(x, "fits")` either way.
  **Experimental**: no published convention exists, and the design's
  smeared-ndt cells are exactly the shallow clean edge that should fool it;
  it enters the simulation as a sweep-only family until the results speak.

* `rule_ez_support()` flags response times below the closed-form EZ
  non-decision time — impossible under any evidence accumulation model — then
  refits once on the survivors and stops, because lower-tail removal raises
  the fitted estimate and unlimited iteration would ratchet. Fast contaminants
  drag the fitted bound down, so the rule's premise is poisoned by exactly the
  trials it hunts; whether one refit recovers is what the simulation measures.
  **Experimental**, same footing as above. Requires `response`.

* `rt_summary()` aggregates surviving trials into the EZ-diffusion summary
  statistics, three ways: the sample moments, robust moments (median with
  IQR/1.349 or MAD), and the analytic moments of a fitted contaminant mixture.
  A `weights` argument takes the `.prob` column of `rt_screen()` directly, so a
  probabilistic screen can feed aggregation without being forced through a
  threshold first. Matches `bmm::ezdm_summary_stats()`.

* `adjust_accuracy()` corrects accuracy counts for estimated contamination, a
  port of `bmm::adjust_ezdm_accuracy()`. Stochastic by design.

* `r_contaminated()` generates response time data with contaminants of known
  type: an evidence accumulation core — a first-principles diffusion or a
  racing diffusion with exact inverse-Gaussian draws — plus three
  psychologically motivated contaminant processes (leading-edge anticipations
  anchored to the observed clean minimum, delayed start-ups, and
  informationless responses as evidence-quality lapses that scale the
  evidence while holding the speed of processing fixed, because zero drift
  has no racing analogue). Ground truth comes back with the data. The
  internal matching solver (`rtprep:::.match_observables()`) returns
  parameters for either generator that hit a target (mean RT, RT variance,
  accuracy) subject to the constraint that the implied non-decision time
  stays inside the published range — and refuses unattainable targets rather
  than silently approximating them. Contamination is invisible in real data, so
  ground truth is the only way to find out whether a pipeline worked — which is
  why this is a package rather than a wrapper.

* `ez_ddm()` inverts those statistics into drift, bound, and non-decision time
  (Wagenmakers et al., 2007), including the published edge correction for
  accuracies of 0, 0.5, and 1. Exported, so the whole
  screen-aggregate-estimate pipeline runs with only `rtprep` installed.

* `screen_compare()` applies a whole roster of rules at once and reports where
  they disagree: per-trial keep, probability, and reason matrices, drop rates
  per rule and group broken out by reason, and pairwise agreement alongside the
  Jaccard overlap of the excluded sets. Both agreement measures are reported
  because they diverge exactly where it matters — two rules that each drop 2%
  of trials and never the same one agree on 96% of decisions and overlap not at
  all. `print()`, `summary()`, and `plot()` methods; the plot uses `ggplot2`
  when it is installed and falls back to base graphics when it is not.

* `check_guessing()` tests whether the fast trials a rule removed really were
  guesses, by a Beta-Binomial Savage–Dickey Bayes factor against the chance
  rate. A port of `bmm::validate_fast_guesses()`, matching it exactly, but
  taking `.keep` rather than a contaminant flag and returning a one-row data
  frame rather than a list.

## Performance

* `rt_screen()` and `screen_compare()` now scale linearly in the number of
  groups. Both used to locate each group's trials by scanning the whole trial
  vector once per group, which is quadratic in participants: screening 10,000
  participants with 100 trials each took 147 s, and 2,000 participants 7.3 s.
  The same calls now take 2.1 s and 0.4 s. Nothing about the results changed —
  `tests/testthat/test-engine.R` holds the previous engine's answers for the
  whole rule roster and compares against them.

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

* Which mixture core you choose matters. On a tight block of fast guesses the
  ex-Gaussian absorbs the block by widening its Gaussian part and driving `tau`
  to zero, reporting no contamination, where the lognormal and inverse Gaussian
  find it. `bmm` behaves identically, so this is a property of the model rather
  than of either implementation.

* Warnings about failed fits and about contaminant bounds that exclude observed
  trials are raised once per call, naming how many groups were affected, rather
  than once per group. Per-group detail is in `attr(x, "fits")`.

* `rt_summary()` defaults to `method = "simple"` where
  `bmm::ezdm_summary_stats()` defaults to `"mixture"`. A tutorial about
  preprocessing choices should not make one of the choices silently.

* `ez_ddm()` uses `s = 1`; Wagenmakers et al. use `s = 0.1`. This is a units
  convention — `drift` and `bound` scale linearly with `s` while `ndt` does
  not — but it has to be stated, because a drift of 0.1 at `s = 0.1` and a
  drift of 1.0 at `s = 1` describe the same process.
