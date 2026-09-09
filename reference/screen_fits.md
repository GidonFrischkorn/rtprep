# Per-group fit diagnostics from a screening rule

The `fits` table of
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
on its own: one row per group with the bookkeeping columns and whatever
the rule reports. It exists because an attribute does not survive
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html),
so the table is otherwise out of reach inside a pipeline.

## Usage

``` r
screen_fits(
  rt,
  rule,
  response = NULL,
  .by = NULL,
  policy = c("threshold", "probabilistic"),
  threshold = 0.5
)
```

## Arguments

- rt:

  Numeric vector of response times **in seconds**. `NA` is allowed;
  non-positive values are an error.

- rule:

  A rule object; see
  [rules](https://www.gfrischkorn.org/rtprep/reference/rules.md).

- response:

  Optional response coding of the same length as `rt`, given as numeric
  0/1, logical, or a character or factor using labels such as
  `"correct"`/`"error"` or `"upper"`/`"lower"`. Required by
  [`rule_ewma()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  and by
  [`rule_mixture()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
  with `use_accuracy = TRUE`.

- .by:

  Optional grouping of the same length as `rt` — a vector, factor, list
  of vectors, or data frame. Rules are fitted separately within each
  group. `NULL` treats all trials as one group.

- policy:

  Exclusion policy. `"threshold"` keeps a trial when its probability of
  validity exceeds `threshold`. `"probabilistic"` keeps it with that
  probability, drawing once per trial.

- threshold:

  Cut for `policy = "threshold"`, in `[0, 1]`. Ignored under the
  probabilistic policy.

## Value

A `data.frame` with one row per group, in group order: `.group`,
`n_trials`, `n_dropped`, `prop_dropped`, then the rule's own columns
(bounds, criterion, iterations, EM convergence, and so on; see
[rules](https://www.gfrischkorn.org/rtprep/reference/rules.md)).
`n_dropped` and `prop_dropped` count under the stated `policy` and
`threshold`, exactly as `attr(rt_screen(...), "fits")` would.

## See also

[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md),
whose per-trial result carries this table as an attribute;
[`screen_compare()`](https://www.gfrischkorn.org/rtprep/reference/screen_compare.md)
for the same table stacked over several rules.

## Examples

``` r
rt <- c(0.12, 0.31, 0.35, 0.38, 0.42, 0.47, 0.55, 2.90)
id <- rep(c("a", "b"), each = 4)
screen_fits(rt, rule_sd(2), .by = id)
#>   .group n_trials n_dropped prop_dropped center     scale       lower    upper
#> 1      a        4         0            0  0.290 0.1169045  0.05619096 0.523809
#> 2      b        4         0            0  1.085 1.2111840 -1.33736799 3.507368

# with dplyr: dat |> reframe(screen_fits(rt, rule_sd(2.5)), .by = id)
```
