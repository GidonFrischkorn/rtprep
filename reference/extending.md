# Add a screening rule

A rule is a parameter object; the engine applies it. Adding a family to
`rtprep`, from this package or any other, is one call to `new_rule()` in
a constructor and one `apply_rule()` method.

## Usage

``` r
new_rule(
  subclass,
  label,
  ...,
  needs_response = FALSE,
  per_trial = character(),
  grouped = FALSE
)

apply_rule(rule, rt, response = NULL)

apply_rule_grouped(rule, rt, response = NULL, idx_by_group)
```

## Arguments

- subclass:

  A string naming the rule family. The object's class becomes
  `c("rtprep_rule_<subclass>", "rtprep_rule")`.

- label:

  A string identifying the rule and its settings, used as the `.rule`
  column and by [`print()`](https://rdrr.io/r/base/print.html).
  Conventionally `"family(setting, setting)"`.

- ...:

  Named parameters stored on the rule and available to the method as
  `rule$name`.

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
`c("rtprep_rule_<subclass>", "rtprep_rule")`. `apply_rule()` returns the
three-element list described above.

## Details

`new_rule()` builds the object. `apply_rule()` is the generic the engine
dispatches on: write a method for your subclass and
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md),
[`rt_keep()`](https://www.gfrischkorn.org/rtprep/reference/rt_keep.md),
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
and
[`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
all pick it up unchanged.

## The method contract

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

A rule that cannot be evaluated on a group, because it has too few
trials, a spread of zero, or a fit that did not converge, returns
`prob = rep(1, length(rt))` and removes nothing. Silence is not evidence
of contamination.

## Declaring what a rule needs

Three arguments change how the engine calls the method.

`needs_response = TRUE` makes `response` mandatory:
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
then errors when it is not supplied, instead of the method receiving
`NULL`.

`per_trial` names the elements of `...` that hold one value per trial
rather than a parameter. The engine checks their length against `rt` up
front and subsets them to the group before dispatch, so the method sees
only its own group's values.
[`rule_oracle()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
uses this to carry ground truth.

`grouped = TRUE` marks a rule that has to see every group at once, one
that pools information across participants, say. The engine then calls
`apply_rule_grouped()` instead, once, with all groups.

## See also

[rules](https://www.gfrischkorn.org/rtprep/reference/rules.md) for the
families `rtprep` ships.

## Examples

``` r
# a rule that keeps the middle 90% of each group by quantile
rule_middle <- function(p = 0.05) {
  new_rule("middle", label = paste0("middle(", p, ")"), p = p)
}

apply_rule.rtprep_rule_middle <- function(rule, rt, response = NULL) {
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
  "apply_rule", "rtprep_rule_middle", apply_rule.rtprep_rule_middle
)

rule_middle()
#> <rtprep rule> middle(0.05) 
#>  No description available.
screen_fits(rt_example$rt, rule_middle(), .by = rt_example$id)
#>   .group n_trials n_dropped prop_dropped     lower    upper
#> 1     p1      200        20         0.10 0.3784500 1.015950
#> 2     p2      200        20         0.10 0.3679546 1.043750
#> 3     p3      200        20         0.10 0.3678500 1.141000
#> 4     p4      200        18         0.09 0.3670000 1.269867
```
