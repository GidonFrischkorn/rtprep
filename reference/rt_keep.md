# Keep vector from a screening rule

The `.keep` column of
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
on its own, for the case where a filter is all that is wanted. It
reports how many trials it dropped, once per call, so that the exclusion
count is logged next to the exclusion rather than reconstructed
afterwards.

## Usage

``` r
rt_keep(
  rt,
  rule,
  response = NULL,
  .by = NULL,
  policy = c("threshold", "probabilistic"),
  threshold = 0.5,
  quiet = FALSE
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

- quiet:

  If `FALSE` (the default), one message states the rule, the number of
  trials dropped, and the proportion. `TRUE` suppresses it.

## Value

A logical vector the length of `rt`: `TRUE` for a trial to keep. Trials
with a missing response time or grouping key are `FALSE`, as in
[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md).

## Details

Inside a grouped [`filter()`](https://rdrr.io/r/stats/filter.html) the
message fires once per group, because the function is called once per
group. Pass `.by` to `rt_keep()` instead of to
[`filter()`](https://rdrr.io/r/stats/filter.html): the keep vector is
identical either way, and the count then covers the whole data set in
one line. Or set `quiet = TRUE`.

## See also

[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
for the probability and the reason alongside the decision;
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
for the per-group diagnostics.

## Examples

``` r
rt <- c(0.12, 0.31, 0.35, 0.38, 0.42, 0.47, 0.55, 2.90)
keep <- rt_keep(rt, rule_cutoff(0.18, 2.5))
#> cutoff(0.18, 2.5): dropped 2 of 8 trials (25.0%)
rt[keep]
#> [1] 0.31 0.35 0.38 0.42 0.47 0.55

# with dplyr: dat |> filter(rt_keep(rt, rule_sd(2.5), .by = id))
```
