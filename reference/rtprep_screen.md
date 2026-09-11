# Methods for a screening result

[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
returns one row per trial with the per-group diagnostics attached as an
attribute. [`print()`](https://rdrr.io/r/base/print.html) reports what
was removed and why before the rows, because the count is usually the
answer wanted and the rows are usually too many to read.

## Usage

``` r
# S3 method for class 'rtprep_screen'
format(x, ...)

# S3 method for class 'rtprep_screen'
print(x, n = 6L, ...)

# S3 method for class 'rtprep_screen'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)

# S3 method for class 'rtprep_screen'
x[i, j, drop = TRUE]
```

## Arguments

- x:

  A screening result from
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md).

- ...:

  Ignored.

- n:

  Number of trials to show.
  [`print()`](https://rdrr.io/r/base/print.html) shows the screen
  summary in full whatever this is.

- row.names, optional:

  Passed to
  [`base::as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html).

- i, j:

  Row and column indices.

- drop:

  Whether to drop to a vector when one column is selected.

## Value

[`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly.
[`format()`](https://rdrr.io/r/base/format.html) returns the summary as
a character vector.
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns a
plain `data.frame`.

## Details

The `fits` attribute describes the screen, so it survives column
subsetting and is dropped by row subsetting: after `scr[scr$.keep, ]`
its `n_dropped` and `prop_dropped` count rows that are no longer there,
and carrying it along would attach a table that quietly disagrees with
the object. The class survives for as long as the four columns do.

[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) strips
the class and the attributes, for when a plain frame is wanted.

## Examples

``` r
scr <- rt_screen(rt_example$rt, rule_mad(2.5), .by = rt_example$id)
scr
#> <rtprep screen> 800 trials, sd(2.5, median, mad), 4 groups
#>   kept 712 (89.0%), dropped 88 (11.0%)
#>   reasons: too_slow 88
#>   policy: keep where .prob > 0.5
#>   per-group diagnostics: screen_fits(), or attr(x, "fits") -- 4 rows
#> 
#>   .keep .prob                .rule  .reason
#> 1  TRUE     1 sd(2.5, median, mad)     <NA>
#> 2  TRUE     1 sd(2.5, median, mad)     <NA>
#> 3 FALSE     0 sd(2.5, median, mad) too_slow
#> 4  TRUE     1 sd(2.5, median, mad)     <NA>
#> 5  TRUE     1 sd(2.5, median, mad)     <NA>
#> 6  TRUE     1 sd(2.5, median, mad)     <NA>
#> # 794 more trials; as.data.frame(x) for all of them

# the per-group diagnostics the summary points at
head(attr(scr, "fits"))
#>   .group n_trials n_dropped prop_dropped center     scale      lower     upper
#> 1     p1      200        23        0.115 0.5385 0.1393644 0.19008900 0.8869110
#> 2     p2      200        23        0.115 0.5270 0.1551555 0.13911121 0.9148888
#> 3     p3      200        17        0.085 0.5390 0.1842486 0.07837841 0.9996216
#> 4     p4      200        25        0.125 0.4915 0.1475187 0.12270325 0.8602967
```
