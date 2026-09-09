# rtprep: Screening, Trimming, and Aggregating Response Time Data

A uniform interface to the response time preprocessing decisions that
precede fitting an evidence accumulation model. Screening rules from
incompatible families – absolute cutoffs, standard deviation and median
absolute deviation criteria, recursive moving criteria, and model-based
mixture flagging – all return the same per-trial object, so that the
consequences of a preprocessing choice can be compared rather than
assumed. Also provides aggregation into EZ-diffusion summary statistics,
diagnostics reporting what each rule removed and where rules disagree,
and generators for response time data with contaminants of known type,
so that a chosen pipeline can be tested against ground truth. Screening
criteria follow Van Selst and Jolicoeur (1994)
[doi:10.1080/14640749408401131](https://doi.org/10.1080/14640749408401131)
, the contaminant mixture Ratcliff and Tuerlinckx (2002)
[doi:10.3758/BF03196302](https://doi.org/10.3758/BF03196302) , and the
EZ-diffusion equations Wagenmakers, van der Maas and Grasman (2007)
[doi:10.3758/BF03194023](https://doi.org/10.3758/BF03194023) .

## See also

Useful links:

- <https://github.com/GidonFrischkorn/rtprep>

- <https://www.gfrischkorn.org/rtprep/>

- Report bugs at <https://github.com/GidonFrischkorn/rtprep/issues>

## Author

**Maintainer**: Gidon T. Frischkorn
<gidon.frischkorn@psychologie.uzh.ch>
([ORCID](https://orcid.org/0000-0002-5055-9764)) \[copyright holder\]

Authors:

- Gidon T. Frischkorn <gidon.frischkorn@psychologie.uzh.ch>
  ([ORCID](https://orcid.org/0000-0002-5055-9764)) \[copyright holder\]
