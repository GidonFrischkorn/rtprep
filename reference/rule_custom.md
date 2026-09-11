# A screening rule from a function, in one call

The short form of
[`new_rule()`](https://www.gfrischkorn.org/rtprep/reference/extending.md):
pass the function that decides which trials to keep, and get a rule
back. No constructor, no S3 method, nothing to register. The result goes
anywhere a rule goes —
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md),
[`rt_keep()`](https://www.gfrischkorn.org/rtprep/reference/rt_keep.md),
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md),
[`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md),
and inside
[`rule_all()`](https://www.gfrischkorn.org/rtprep/reference/rules_compose.md)
and its relatives.

## Usage

``` r
rule_custom(
  label,
  fun,
  ...,
  description = NULL,
  reason = "contaminant",
  needs_response = NULL,
  per_trial = character(),
  grouped = FALSE,
  subclass = "custom"
)
```

## Arguments

- label:

  A string identifying the rule, used as the `.rule` column, by
  [`print()`](https://rdrr.io/r/base/print.html), and by
  [`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md),
  which needs the rules it compares to be named apart. Conventionally
  `"family(setting, setting)"`.

- fun:

  The screening function. What it may take is listed under "What the
  screening function receives" in
  [extending](https://www.gfrischkorn.org/rtprep/reference/extending.md);
  what it may return, under "What the screening function must return".

- ...:

  Named parameters stored on the rule and passed to `fun` by name.

- description, reason, needs_response, per_trial, grouped:

  As in
  [`new_rule()`](https://www.gfrischkorn.org/rtprep/reference/extending.md).

- subclass:

  The rule family, for the rare case of wanting a class to hang a method
  on later. The default is shared by every `rule_custom()` rule, which
  costs nothing: the function travels on the object, not on the class,
  so two rules built this way never collide.

## Value

An object of class
`c("rtprep_rule_custom", "rtprep_rule_fun", "rtprep_rule")`.

## See also

[extending](https://www.gfrischkorn.org/rtprep/reference/extending.md)
for the full contract,
[`new_rule()`](https://www.gfrischkorn.org/rtprep/reference/extending.md)
to wrap a rule of your own in a constructor.

## Examples

``` r
fast <- rule_custom(
  "fast(0.35)",
  function(rt, cut) rt >= cut,
  cut = 0.35,
  description = "Exclude trials faster than 350 ms.",
  reason = "too_fast"
)
fast
#> <rtprep rule> fast(0.35) 
#>  Exclude trials faster than 350 ms.
#>   screened by a function of (rt, cut)
rt_screen(rt_example$rt, fast, .by = rt_example$id)
#> <rtprep screen> 800 trials, fast(0.35), 4 groups
#>   kept 781 (97.6%), dropped 19 (2.4%)
#>   reasons: too_fast 19
#>   policy: keep where .prob > 0.5
#>   per-group diagnostics: screen_fits(), or attr(x, "fits") -- 4 rows
#> 
#>   .keep .prob      .rule .reason
#> 1  TRUE     1 fast(0.35)    <NA>
#> 2  TRUE     1 fast(0.35)    <NA>
#> 3  TRUE     1 fast(0.35)    <NA>
#> 4  TRUE     1 fast(0.35)    <NA>
#> 5  TRUE     1 fast(0.35)    <NA>
#> 6  TRUE     1 fast(0.35)    <NA>
#> # 794 more trials; as.data.frame(x) for all of them

# against one of the rules rtprep ships
screen_compare(
  rt_example$rt,
  list(fast = fast, mad = rule_mad(2.5)),
  .by = rt_example$id
)
#> <rtprep comparison> 800 trials, 2 rules
#> 
#>   fast                         dropped   2.4%
#>   mad                          dropped  11.0%
#> 
#>   least agreement: fast vs mad, 86.6% of decisions (Jaccard 0.00)
```
