# Compare what several screening rules would remove

Applies every rule once and reports where they disagree. This is the
question the package exists to make askable: *what would a different
preprocessing choice have removed?* — which is normally unanswerable
because each rule's implementation returns a different shape.

## Usage

``` r
screen_compare(
  rt,
  rules,
  response = NULL,
  .by = NULL,
  policy = c("threshold", "probabilistic"),
  threshold = 0.5
)

# S3 method for class 'rtprep_comparison'
print(x, ...)

# S3 method for class 'rtprep_comparison'
summary(object, ...)

# S3 method for class 'rtprep_comparison'
plot(x, ...)
```

## Arguments

- rt, response, .by, policy, threshold:

  As in
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md),
  and forwarded unchanged.

- rules:

  A [`list()`](https://rdrr.io/r/base/list.html) of rule objects; see
  [rules](https://www.gfrischkorn.org/rtprep/reference/rules.md). Names
  become the labels in the output; unnamed entries take the rule's own
  label.

- x:

  An `rtprep_comparison`.

- ...:

  Ignored.

- object:

  An `rtprep_comparison`.

## Value

An object of class `rtprep_comparison`: a list with

- `keep`, `prob`, `reason`:

  matrices, `length(rt)` rows by one column per rule, so downstream
  analysis needs nothing else.

- `drops`:

  one row per rule and group: `n_trials`, `n_dropped`, `prop_dropped`,
  and a count column per reason.

- `agreement`:

  one row per rule pair: `agree`, `jaccard`, and the counts behind them.

- `fits`:

  the per-group fit diagnostics, stacked, with a `.rule` column.

## Details

`agree` and `jaccard` answer different questions and diverge exactly
where it matters. Two rules that each drop 2% of trials and never the
same one agree on 96% of decisions — and have a Jaccard index of zero.
Agreement alone would call them interchangeable. Jaccard is `NA`, not 1,
when neither rule dropped anything: no overlap can be computed from two
empty sets.

## See also

[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
for a single rule,
[`r_contaminated()`](https://www.gfrischkorn.org/rtprep/reference/r_contaminated.md)
to score the comparison against known ground truth.

## Examples

``` r
set.seed(2)
d <- r_contaminated(300, process = "mixed", rate = 0.1)
cmp <- screen_compare(
  d$rt,
  list(
    cutoff = rule_cutoff(0.18, 3),
    sd = rule_sd(2.5),
    recursive = rule_recursive("modified")
  )
)
cmp
#> <rtprep comparison> 300 trials, 3 rules
#> 
#>   cutoff                       dropped   0.0%
#>   sd                           dropped   2.3%
#>   recursive                    dropped   1.7%
#> 
#>   least agreement: cutoff vs sd, 97.7% of decisions (Jaccard 0.00)
cmp$agreement
#>   rule_x    rule_y     agree   jaccard n_only_x n_only_y n_both
#> 1 cutoff        sd 0.9766667 0.0000000        0        7      0
#> 2 cutoff recursive 0.9833333 0.0000000        0        5      0
#> 3     sd recursive 0.9933333 0.7142857        2        0      5
```
