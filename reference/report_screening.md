# Report a screening procedure in prose

Turns a screen into a paragraph that can go into a Methods section:
which rule at which setting, the grouping the criterion was computed
within, how much it removed in total and per cell, what it caught,
whether it read accuracy, the keep policy, and the references for the
criteria used.

Every number and every description is derived from the screen, so
editing the rule and forgetting to edit the paragraph is not a way to
publish a wrong Methods section.

## Usage

``` r
report_screening(x, ...)

# S3 method for class 'rtprep_screen'
report_screening(x, rule = NULL, groups = NULL, max_words = 300L, ...)

# S3 method for class 'data.frame'
report_screening(
  x,
  rule,
  groups = NULL,
  policy = c("threshold", "probabilistic"),
  threshold = 0.5,
  max_words = 300L,
  ...
)
```

## Arguments

- x:

  A screening result from
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md),
  or a data frame carrying its four columns.

- ...:

  Ignored.

- rule:

  The rule that produced the screen. Optional for an
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
  result, which carries it; required for a data frame, where it cannot
  be recovered.

- groups:

  Character vector naming the grouping variables, for the sentence that
  says what the criterion was computed within. Optional for an
  [`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
  result when `.by` was a data frame or a named list, which supplies
  them. For a data frame these must be columns of `x`, since their
  values are needed to rebuild the cells.

- max_words:

  A guard on the length of the paragraph. Optional clauses are dropped,
  lowest priority first, rather than any sentence being truncated.

- policy, threshold:

  The exclusion policy the screen was run under. Read from the object
  where it carries them; pass them for a data frame if they were not
  left at the defaults.

## Value

An object of class `rtprep_report`: a list whose `text` element is the
paragraph, carrying alongside it every number the paragraph quotes
(`n_trials`, `n_missing`, `n_screened`, `n_excluded`, `prop_excluded`,
`reasons`, `cells`, `words`), the `fits` table it read them from, the
rule, the reference keys and their `bibliography`, and any `notes`.

## Details

The counts separate what the rule excluded from what was never screened.
Trials with a missing response time, a missing grouping key, or (for a
rule that reads accuracy) a missing response, come back with
`.keep = FALSE` and `.reason = "missing"`, so `sum(!.keep)` overstates
the rule's work. The percentages quoted for the rule are out of the
trials it actually saw, and the missing trials get their own sentence.

## Which object to pass

[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
attaches the rule and the grouping to its result, so
`report_screening(scr)` needs nothing else. Inside
`dplyr::mutate(rt_screen(rt, rule), .by = ...)` the four columns are
spliced into the data frame and the attributes are lost, so the data
frame method asks for the `rule` back and for `groups`, the names of the
grouping columns. It recomputes the per-cell counts from `.keep` and
those columns, which needs no refitting and gives the same answer.

## What it does not claim

The reference list names the sources for the criteria used and the
standard caveats on them, which are not the same thing:
[`rule_sd()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
cites Miller (1991) on sample-size bias, and
[`rule_mad()`](https://www.gfrischkorn.org/rtprep/reference/rules.md)
also cites Leys et al. (2013), whose argument is that the mean and
standard deviation are the wrong choice. Read the sentence as a pointer
to the literature, not as an endorsement.
[`toBibtex()`](https://rdrr.io/r/utils/toLatex.html) on the result gives
the entries.

## See also

[`rt_screen()`](https://www.gfrischkorn.org/rtprep/reference/rt_screen.md)
for the screen,
[`screen_fits()`](https://www.gfrischkorn.org/rtprep/reference/screen_fits.md)
for the per-cell table the counts come from, and
[rtprep_report](https://www.gfrischkorn.org/rtprep/reference/rtprep_report.md)
for the print and BibTeX methods.

## Examples

``` r
scr <- rt_screen(rt_example$rt, rule_mad(2.5), .by = rt_example$id)
report_screening(scr, groups = "participant")
#> Response times were screened with a criterion of 2.5 median absolute
#> deviations around the median, computed separately within each
#> participant cell (4 cells). This removed 88 of the 800 trials it
#> screened (11.0%), between 8% and 12% per cell. All the exclusions were
#> slow trials. The criterion did not read accuracy, so error trials
#> passed through the screen on their response times alone. The criterion
#> is described by Leys et al. (2013) and Miller (1991).
#> 
#> [75 words; 2 references; toBibtex(x) for BibTeX]

# every number in the paragraph, for a sentence written by hand
rep <- report_screening(scr)
rep$n_excluded
#> [1] 88
rep$cells
#>   n fitted   min   max
#> 1 4      4 0.085 0.125
```
