# rtprep

Screening, trimming, and aggregating response time data before fitting an evidence
accumulation model.

This repository is a research compendium. The `rtprep` package is at the root; the tutorial
manuscript it validates lives in [`manuscript/`](manuscript/) and the simulation studies in
[`scripts/`](scripts/).

> **Status:** scaffolded. No functions implemented yet.

## The problem

Every response time analysis makes an exclusion decision, and most inherit it by convention
— 200 ms and 3 s because that is what the last paper did, or ±2.5 SD because that is what
the field does. The consequences are invisible in the data the researcher can see, and they
are not small: contaminant trials bias evidence accumulation model parameters, and which
contaminants a method can reach depends on how far they sit from the RT distribution the
decision process itself produces.

The methods to deal with this exist and are scattered. What does not exist is a way to
compare them, because every implementation returns a different kind of object: a trimmed
data frame, a vector of per-trial probabilities, a set of summary statistics. `rtprep` gives
them one interface, so a preprocessing choice can be evaluated rather than assumed.

## What it provides

- **Screening** under one return type: absolute cutoffs, standard deviation and median
  absolute deviation criteria, recursive moving criteria, and model-based mixture flagging
- **Aggregation** into EZ-diffusion summary statistics, with mixture down-weighting and
  accuracy adjustment
- **Diagnostics** reporting what each rule removed, per cell, and where rules disagree
- **Generators** for response time data with contaminants of known type, so a chosen
  pipeline can be tested against ground truth on data shaped like yours

That last one matters most. Contamination is invisible in your own data; simulating it is
the only way to check whether your pipeline did what you thought it did.

## Installation

```r
# install.packages("remotes")
remotes::install_github("GidonFrischkorn/rtprep")
```

## Relationship to other packages

`rtprep` implements its screening rules itself and carries no runtime dependency on other
preprocessing packages. Where reference implementations exist —
[`trimr`](https://github.com/JimGrange/trimr) for the trimming families,
[`bmm`](https://github.com/venpopov/bmm) for the mixture EM and EZ aggregation — the test
suite checks equivalence against them.

## Citation

Manuscript in preparation. Cite the repository until it appears.

## License

GPL (>= 3)
