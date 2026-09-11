# Methods for a screening report

[`report_screening()`](https://www.gfrischkorn.org/rtprep/reference/report_screening.md)
returns the paragraph together with every number in it.
[`print()`](https://rdrr.io/r/base/print.html) wraps the paragraph to
the console width and says how long it is;
[`as.character()`](https://rdrr.io/r/base/character.html) returns it
unwrapped, for pasting into a document or an inline `r` chunk.

## Usage

``` r
# S3 method for class 'rtprep_report'
format(x, width = 0.9 * getOption("width"), ...)

# S3 method for class 'rtprep_report'
print(x, ...)

# S3 method for class 'rtprep_report'
as.character(x, ...)

# S3 method for class 'rtprep_report'
toBibtex(object, ...)
```

## Arguments

- x, object:

  A report from
  [`report_screening()`](https://www.gfrischkorn.org/rtprep/reference/report_screening.md).

- width:

  Wrapping width for [`print()`](https://rdrr.io/r/base/print.html).

- ...:

  Ignored.

## Value

[`format()`](https://rdrr.io/r/base/format.html) returns the wrapped
paragraph as a character vector,
[`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly,
[`as.character()`](https://rdrr.io/r/base/character.html) returns the
paragraph as a single string, and
[`toBibtex()`](https://rdrr.io/r/utils/toLatex.html) returns the BibTeX
entries for the references cited.

## Examples

``` r
scr <- rt_screen(rt_example$rt, rule_mad(2.5), .by = rt_example$id)
rep <- report_screening(scr, groups = "participant")
rep
#> Response times were screened with a criterion of 2.5 median absolute
#> deviations around the median, computed separately within each
#> participant cell (4 cells). This removed 88 of the 800 trials it
#> screened (11.0%), between 8% and 12% per cell. All the exclusions were
#> slow trials. The criterion did not read accuracy, so error trials
#> passed through the screen on their response times alone. The criterion
#> is described by Leys et al. (2013) and Miller (1991).
#> 
#> [75 words; 2 references; toBibtex(x) for BibTeX]

cat(as.character(rep))
#> Response times were screened with a criterion of 2.5 median absolute deviations around the median, computed separately within each participant cell (4 cells). This removed 88 of the 800 trials it screened (11.0%), between 8% and 12% per cell. All the exclusions were slow trials. The criterion did not read accuracy, so error trials passed through the screen on their response times alone. The criterion is described by Leys et al. (2013) and Miller (1991).
utils::toBibtex(rep)
#> @Article{leys2013,
#>   author = {Christophe Leys and Christophe Ley and Olivier Klein and Philippe Bernard and Laurent Licata},
#>   title = {Detecting outliers: Do not use standard deviation around the mean, use absolute deviation around the median},
#>   journal = {Journal of Experimental Social Psychology},
#>   year = {2013},
#>   volume = {49},
#>   number = {4},
#>   pages = {764--766},
#>   doi = {10.1016/j.jesp.2013.03.013},
#> }
#> 
#> @Article{miller1991,
#>   author = {Jeff Miller},
#>   title = {Reaction time analysis with outlier exclusion: Bias varies with sample size},
#>   journal = {The Quarterly Journal of Experimental Psychology Section A},
#>   year = {1991},
#>   volume = {43},
#>   number = {4},
#>   pages = {907--912},
#>   doi = {10.1080/14640749108400962},
#> }
```
