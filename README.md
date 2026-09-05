
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rtprep <img src="man/figures/logo.png" align="right" height="139" alt="rtprep hex sticker: a response time density with contaminant trials flagged outside two cutoffs" />

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/rtprep)](https://CRAN.R-project.org/package=rtprep)
[![R-CMD-check](https://github.com/GidonFrischkorn/rtprep/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/GidonFrischkorn/rtprep/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/GidonFrischkorn/rtprep/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/GidonFrischkorn/rtprep/actions/workflows/test-coverage.yaml)
[![downloads](https://cranlogs.r-pkg.org/badges/rtprep)](https://cran.r-project.org/package=rtprep)
<!-- badges: end -->

Screening, trimming, and aggregating response time data before fitting
an evidence accumulation model.

This repository is a research compendium. The `rtprep` package is at the
root; the tutorial manuscript it validates lives in
[`manuscript/`](manuscript/) and the simulation studies in
[`scripts/`](scripts/).

## The problem

Every response time analysis makes an exclusion decision, and most
inherit it by convention — 200 ms and 3 s because that is what the last
paper did, or ±2.5 SD because that is what the field does. The
consequences are invisible in the data the researcher can see, and they
are not small: contaminant trials bias evidence accumulation model
parameters, and which contaminants a method can reach depends on how far
they sit from the RT distribution the decision process itself produces.

The methods to deal with this exist and are scattered. What does not
exist is a way to compare them, because every implementation returns a
different kind of object: a trimmed data frame, a vector of per-trial
probabilities, a set of summary statistics. `rtprep` gives them one
interface, so a preprocessing choice can be evaluated rather than
assumed.

## What it provides

- **Screening** under one return type: absolute cutoffs, standard
  deviation and median absolute deviation criteria, recursive moving
  criteria, and model-based mixture flagging
- **Aggregation** into EZ-diffusion summary statistics, with mixture
  down-weighting and accuracy adjustment
- **Diagnostics** reporting what each rule removed, per cell, and where
  rules disagree
- **Generators** for response time data with contaminants of known type,
  so a chosen pipeline can be tested against ground truth on data shaped
  like yours

That last one matters most. Contamination is invisible in your own data;
simulating it is the only way to check whether your pipeline did what
you thought it did.

## Installation

``` r
# the development version, from GitHub
# install.packages("remotes")
remotes::install_github("GidonFrischkorn/rtprep")

# from CRAN, once the first release is accepted
# install.packages("rtprep")
```

## A first look

Every rule is a constructor, one engine applies it, and the result has
the same four columns whichever rule went in:

``` r
library(rtprep)

set.seed(1)
dat <- r_contaminated(400, process = "mixed", rate = 0.1)

scr <- rt_screen(dat$rt, rule_sd(2.5))
head(scr)
#>   .keep .prob             .rule .reason
#> 1  TRUE     1 sd(2.5, mean, sd)    <NA>
#> 2  TRUE     1 sd(2.5, mean, sd)    <NA>
#> 3  TRUE     1 sd(2.5, mean, sd)    <NA>
#> 4  TRUE     1 sd(2.5, mean, sd)    <NA>
#> 5  TRUE     1 sd(2.5, mean, sd)    <NA>
#> 6  TRUE     1 sd(2.5, mean, sd)    <NA>

# how much each rule would have removed, and how much the removed sets overlap
cmp <- screen_compare(
  dat$rt,
  list(cutoff = rule_cutoff(0.18, 3), sd = rule_sd(2.5), mad = rule_mad(2.5))
)
cmp
#> <rtprep comparison> 400 trials, 3 rules
#> 
#>   cutoff                       dropped   0.0%
#>   sd                           dropped   3.8%
#>   mad                          dropped  10.8%
#> 
#>   least agreement: cutoff vs mad, 89.2% of decisions (Jaccard 0.00)
```

Because `r_contaminated()` carries the ground truth, the screen can be
scored rather than trusted:

``` r
table(flagged = !scr$.keep, contaminant = dat$contaminant)
#>        contaminant
#> flagged FALSE TRUE
#>   FALSE   357   28
#>   TRUE      2   13
```

## Relationship to other packages

`rtprep` implements its screening rules itself and carries no runtime
dependency on other preprocessing packages. Where reference
implementations exist — [`trimr`](https://github.com/JimGrange/trimr)
for the trimming families, [`bmm`](https://github.com/popov-lab/bmm) for
the mixture EM and EZ aggregation — the test suite checks equivalence
against them.

## Citation

Manuscript in preparation. Until it appears, cite the package:
`citation("rtprep")`.

## License

GPL (\>= 3)
