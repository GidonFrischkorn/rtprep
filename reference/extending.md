# Add a screening rule

A rule is a parameter object; the engine applies it. Adding one takes a
single call to `new_rule()` with `fun =`, the function that decides
which trials to keep. The function travels on the rule object, so there
is no S3 method to write and nothing to register, and
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md),
[`rt_keep()`](https://www.gfrischkorn.org/rtprep/reference/rt_keep.md),
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
and
[`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
all pick the rule up unchanged.

## Usage

``` r
new_rule(
  subclass,
  label,
  ...,
  fun = NULL,
  description = NULL,
  reason = "contaminant",
  needs_response = NULL,
  per_trial = character(),
  grouped = FALSE
)

apply_rule(rule, rt, response = NULL)

apply_rule_grouped(rule, rt, response = NULL, idx_by_group)
```

## Arguments

- subclass:

  A string naming the rule family. The object's class becomes
  `c("rtprep_rule_<subclass>", "rtprep_rule")`, with `"rtprep_rule_fun"`
  between them when the rule carries its own function.

- label:

  A string identifying the rule and its settings, used as the `.rule`
  column and by [`print()`](https://rdrr.io/r/base/print.html).
  Conventionally `"family(setting, setting)"`.

- ...:

  Named parameters stored on the rule, passed to `fun` by name and
  available to an `apply_rule()` method as `rule$name`.

- fun:

  The screening function, or `NULL` to write an `apply_rule()` method
  instead. See "What the screening function receives" and "What the
  screening function must return".

- description:

  A sentence saying what the rule does, shown by
  [`print()`](https://rdrr.io/r/base/print.html).

- reason:

  A string naming what a dropped trial was dropped for, used for the
  `.reason` column when `fun` returns a bare vector. `rtprep`'s own
  rules use `"too_fast"`, `"too_slow"` and `"contaminant"`.

- needs_response, per_trial, grouped:

  See "Declaring what a rule needs".

- rule:

  A rule object, as built by `new_rule()`.

- rt:

  Numeric vector of response times for one group, in seconds, with
  missing values already removed.

- response:

  Numeric 0/1 vector of the same length, or `NULL`.

- idx_by_group:

  A list of integer vectors, one per group, giving each group's
  positions in `rt`.

## Value

`new_rule()` returns an object of class
`c("rtprep_rule_<subclass>", "rtprep_rule")`, with `"rtprep_rule_fun"`
inserted before the last when `fun` is given. `apply_rule()` returns the
three-element list described under "If you are writing a package".

## Details

[`rule_custom()`](https://www.gfrischkorn.org/rtprep/reference/rule_custom.md)
does the same thing in one call, without a constructor, for a rule used
once. A package shipping a family of rules can instead write a method
for the `apply_rule()` generic; see "If you are writing a package".

## What the screening function receives

The function declares what it needs by name, and the engine passes
exactly that and nothing else. It can supply:

- `rt`:

  the response times of one group, in seconds, with missing values
  already removed and never empty. The function therefore does no
  validation of its own.

- `response`:

  accuracy for the same trials, already coerced to 0/1, or `NULL`.
  Declaring it makes it mandatory; see "Declaring what a rule needs".

- `rule`:

  the rule object itself, for a function that would rather read
  `rule$name` than take parameters one by one.

- `idx_by_group`:

  for a `grouped = TRUE` rule only: a list of integer vectors giving
  each group's positions in `rt`.

- any parameter stored on the rule:

  everything passed to `new_rule()` through `...`, by the name it was
  given there.

A formal the engine cannot supply is an error when the rule is built,
rather than in the middle of a screen — unless it has a default, in
which case the engine leaves it alone and the default applies. Declaring
`...` means "and everything else": the function then receives the whole
lot.

## What the screening function must return

The answer is always in *keep* terms: `TRUE`, or a probability near 1,
means the trial stays. That is the direction of the `.keep` and `.prob`
columns and the opposite of how an exclusion criterion is usually
phrased, so it is worth checking once on data whose answer you know.

There are three ways to say it, and a rule can start with the first and
move to the third without anything else changing.

1.  A **logical vector**, one value per trial, `TRUE` for a trial to
    keep. The simplest rule, and what most rules are. `.prob` becomes 0
    or 1, and every dropped trial is labelled with the rule's `reason`.

2.  A **numeric vector**, one value per trial, in \[0, 1\]: the
    probability that the trial came from the decision process. Use this
    when the rule is a model rather than a cutoff, as
    [`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
    is.
    [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
    turns it into a decision with its own `policy` and `threshold`, so
    the function does not decide and must not round.

3.  A **list of `prob`, `reason` and `fit`**, the full contract under
    "If you are writing a package". Use it when different trials are
    dropped for different reasons, or when the rule estimates something
    per group — a criterion, a pair of bounds, whether a fit converged —
    that should become a column of
    [`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md).
    `reason` is then ignored: the function owns the reason column.

Whichever shape it returns, it returns one value per trial, in the order
`rt` came in, and no `NA`. A rule that cannot evaluate a trial or a
whole group, because it has too few trials, a spread of zero, or a fit
that did not converge, returns `TRUE`, or 1, and removes nothing.
Silence is not evidence of contamination.

## Declaring what a rule needs

Three arguments change how the engine calls the rule.

`needs_response = TRUE` makes `response` mandatory:
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
then errors when it is not supplied, instead of the function receiving
`NULL`. Left unset, it is `TRUE` for a function that declares a
`response` argument.

`per_trial` names the elements of `...` that hold one value per trial
rather than a parameter. The engine checks their length against `rt` up
front and subsets them to the group before dispatch, so the function
sees only its own group's values.
[`rule_oracle()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
uses this to carry ground truth.

`grouped = TRUE` marks a rule that has to see every group at once, one
that pools information across participants, say. The engine then calls
it once, with all groups, and hands it `idx_by_group`.

## If you are writing a package

A package shipping a family of rules can write a method for the
`apply_rule()` generic instead of carrying a function on the object. The
two routes are equivalent; a registered
`apply_rule.rtprep_rule_<subclass>()` method takes precedence, and a
`fun` on the same rule is then ignored.

`apply_rule()` is called once per group, with `rt` already stripped of
missing values and guaranteed non-empty, and `response` already coerced
to 0/1 (or `NULL`). Methods therefore do no validation of their own. A
method returns a list of three elements:

- `prob`:

  numeric, `length(rt)`, in \[0, 1\]: the probability that the trial
  came from the decision process. Note the direction: this is P(valid),
  not P(contaminant). A deterministic rule returns 0 and 1.

- `reason`:

  character, `length(rt)`, `NA` wherever the trial is valid. `rtprep`'s
  own rules use `"too_fast"`, `"too_slow"` and `"contaminant"`; a new
  rule may use any label.

- `fit`:

  a one-row `data.frame` of whatever the rule estimated for that group
  (bounds, criteria, convergence), or `NULL` if it estimated nothing.
  These become the extra columns of
  [`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md).

A rule that cannot be evaluated on a group returns
`prob = rep(1, length(rt))` and removes nothing, for the same reason a
screening function returns `TRUE`.

A `grouped = TRUE` rule gets a method for `apply_rule_grouped()`
instead, called once with every group, and returns `fit` as a list of
one-row data frames, one per group.

## Saving a rule

The function travels with the rule, and a screen carries the rule that
made it, so saving either saves the function *and the environment it was
written in*. A function defined at the top level costs nothing. One
defined inside another function drags whatever that function was holding
into the file with it, which is how a rule ends up megabytes wide.
Define screening functions at the top level, and pass what they need
through `...`.

## See also

[`rule_custom()`](https://www.gfrischkorn.org/rtprep/reference/rule_custom.md)
for a rule in one call,
[rules](https://www.gfrischkorn.org/rtprep/reference/rules.md) for the
families `rtprep` ships.

## Examples

``` r
# a rule that keeps the middle 90% of each group by quantile
rule_middle <- function(p = 0.05) {
  new_rule(
    "middle",
    label = paste0("middle(", p, ")"),
    p = p,
    description = "Keep the middle 90% of each group by quantile.",
    fun = function(rt, p) {
      b <- stats::quantile(rt, c(p, 1 - p), names = FALSE)
      rt >= b[1] & rt <= b[2]
    }
  )
}
rule_middle()
#> <rtprep rule> middle(0.05) 
#>  Keep the middle 90% of each group by quantile.
#>   screened by a function of (rt, p)
screen_fits(rt_example$rt, rule_middle(), .by = rt_example$id)
#>   .group n_trials n_dropped prop_dropped
#> 1     p1      200        20         0.10
#> 2     p2      200        20         0.10
#> 3     p3      200        20         0.10
#> 4     p4      200        18         0.09

# a graded rule returns a probability and lets rt_screen() decide
shrinking <- rule_custom(
  "shrinking",
  function(rt) pmin(1, 0.2 / rt),
  description = "The slower the trial, the less likely it is a decision."
)
head(rt_screen(rt_example$rt, shrinking, .by = rt_example$id))
#> <rtprep screen> 6 trials, shrinking
#>   kept 0 (0.0%), dropped 6 (100.0%)
#>   reasons: contaminant 6
#>   policy: keep where .prob > 0.5
#>   per-group diagnostics: dropped by subsetting; screen_fits() to refit
#> 
#>   .keep     .prob     .rule     .reason
#> 1 FALSE 0.3389831 shrinking contaminant
#> 2 FALSE 0.4901961 shrinking contaminant
#> 3 FALSE 0.1499250 shrinking contaminant
#> 4 FALSE 0.3552398 shrinking contaminant
#> 5 FALSE 0.3484321 shrinking contaminant
#> 6 FALSE 0.3007519 shrinking contaminant

# the package way: a method, for a family with diagnostics to report
rule_bounded <- function(p = 0.05) {
  new_rule("bounded", label = paste0("bounded(", p, ")"), p = p)
}
apply_rule.rtprep_rule_bounded <- function(rule, rt, response = NULL) {
  b <- stats::quantile(rt, c(rule$p, 1 - rule$p), names = FALSE)
  list(
    prob = as.numeric(rt >= b[1] & rt <= b[2]),
    reason = ifelse(
      rt < b[1], "too_fast", ifelse(rt > b[2], "too_slow", NA)
    ),
    fit = data.frame(lower = b[1], upper = b[2])
  )
}
registerS3method(
  "apply_rule", "rtprep_rule_bounded", apply_rule.rtprep_rule_bounded
)
screen_fits(rt_example$rt, rule_bounded(), .by = rt_example$id)
#>   .group n_trials n_dropped prop_dropped     lower    upper
#> 1     p1      200        20         0.10 0.3784500 1.015950
#> 2     p2      200        20         0.10 0.3679546 1.043750
#> 3     p3      200        20         0.10 0.3678500 1.141000
#> 4     p4      200        18         0.09 0.3670000 1.269867
```
