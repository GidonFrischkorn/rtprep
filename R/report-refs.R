# The references report_screening() cites, and the rule-to-reference map.
#
# The canonical text of each entry is the roxygen @references block of the rule
# that implements it, in R/rules.R. Roxygen is not readable at run time, so the
# entries are transcribed here, and the completeness test in test-report.R is
# what keeps the two from drifting.
#
# .rule_reference() returns keys rather than bibentry objects for three reasons:
# de-duplication over a composite is unique() on a character vector, collection
# recurses in one line to any depth, and the prose citation and the BibTeX entry
# are then built from the same object at the end, so they cannot disagree.

.rule_reference <- function(x) UseMethod(".rule_reference")

# An extension rule from outside the package carries no reference we could
# know. report_screening() says so rather than citing nothing silently.
.rule_reference.default <- function(x) character()

.rule_reference.rtprep_rule_cutoff <- function(x) {
  c("ratcliff1993", "ulrich1994")
}

.rule_reference.rtprep_rule_sd <- function(x) {
  # Leys et al. (2013) is the reference *for* the MAD criterion: its argument is
  # that the mean and standard deviation are the wrong choice. Citing it beside
  # a mean/SD screen would hand the reader a paper arguing against what was
  # done. Miller (1991) is the sample-size bias, which applies to both.
  if (identical(x$center, "median") && identical(x$scale, "mad")) {
    c("leys2013", "miller1991")
  } else {
    "miller1991"
  }
}

.rule_reference.rtprep_rule_iqr <- function(x) "tukey1977"

.rule_reference.rtprep_rule_recursive <- function(x) {
  c("vanselst1994", "cousineau2010")
}

.rule_reference.rtprep_rule_ewma <- function(x) {
  c("vandekerckhove2007", "ratcliffkang2021")
}

.rule_reference.rtprep_rule_mixture <- function(x) {
  c("ratcliff2002", if (isTRUE(x$use_accuracy)) "liu2020")
}

# No published convention exists for the hierarchical screen, so it has nothing
# to cite. Asserted by name in the tests, so that adding a reference later is a
# visible change rather than a silent one.
.rule_reference.rtprep_rule_hierarchical <- function(x) character()

.rule_reference.rtprep_rule_none <- function(x) character()

.rule_reference.rtprep_rule_oracle <- function(x) character()

.rule_reference.rtprep_rule_adaptive_trim <- function(x) character()

.rule_reference.rtprep_rule_ez_support <- function(x) character()

.rule_reference.rtprep_rule_all <- function(x) .collect_references(x)

.rule_reference.rtprep_rule_any <- function(x) .collect_references(x)

.rule_reference.rtprep_rule_then <- function(x) .collect_references(x)

# Recurses to any depth. Unlike the prose, a reference list does not get harder
# to read when the rule nests, so there is no depth cap here.
.collect_references <- function(x) {
  # wrapped in a closure so UseMethod() dispatches from this namespace rather
  # than from lapply()'s frame, where the internal generic has no methods
  unique(unlist(
    lapply(x$rules, function(r) .rule_reference(r)),
    use.names = FALSE
  ))
}

# The store. The default arm stops rather than returning NULL, so a typo in a
# key list above is an error the completeness test catches.
.ref_entry <- function(key) {
  switch(key,
    ratcliff1993 = utils::bibentry(
      bibtype = "Article",
      key = "ratcliff1993",
      author = utils::person("Roger", "Ratcliff"),
      title = "Methods for dealing with reaction time outliers",
      journal = "Psychological Bulletin",
      year = "1993", volume = "114", number = "3", pages = "510--532",
      doi = "10.1037/0033-2909.114.3.510"
    ),
    ulrich1994 = utils::bibentry(
      bibtype = "Article",
      key = "ulrich1994",
      author = c(
        utils::person("Rolf", "Ulrich"),
        utils::person("Jeff", "Miller")
      ),
      title = "Effects of truncation on reaction time analysis",
      journal = "Journal of Experimental Psychology: General",
      year = "1994", volume = "123", number = "1", pages = "34--80",
      doi = "10.1037/0096-3445.123.1.34"
    ),
    leys2013 = utils::bibentry(
      bibtype = "Article",
      key = "leys2013",
      author = c(
        utils::person("Christophe", "Leys"),
        utils::person("Christophe", "Ley"),
        utils::person("Olivier", "Klein"),
        utils::person("Philippe", "Bernard"),
        utils::person("Laurent", "Licata")
      ),
      title = paste(
        "Detecting outliers: Do not use standard deviation around the mean,",
        "use absolute deviation around the median"
      ),
      journal = "Journal of Experimental Social Psychology",
      year = "2013", volume = "49", number = "4", pages = "764--766",
      doi = "10.1016/j.jesp.2013.03.013"
    ),
    miller1991 = utils::bibentry(
      bibtype = "Article",
      key = "miller1991",
      author = utils::person("Jeff", "Miller"),
      title = paste(
        "Reaction time analysis with outlier exclusion:",
        "Bias varies with sample size"
      ),
      journal = "The Quarterly Journal of Experimental Psychology Section A",
      year = "1991", volume = "43", number = "4", pages = "907--912",
      doi = "10.1080/14640749108400962"
    ),
    tukey1977 = utils::bibentry(
      bibtype = "Book",
      key = "tukey1977",
      author = utils::person("John W.", "Tukey"),
      title = "Exploratory data analysis",
      publisher = "Addison-Wesley",
      year = "1977"
    ),
    vanselst1994 = utils::bibentry(
      bibtype = "Article",
      key = "vanselst1994",
      author = c(
        utils::person("Mark", "Van Selst"),
        utils::person("Pierre", "Jolicoeur")
      ),
      title = "A solution to the effect of sample size on outlier elimination",
      journal = "The Quarterly Journal of Experimental Psychology Section A",
      year = "1994", volume = "47", number = "3", pages = "631--650",
      doi = "10.1080/14640749408401131"
    ),
    cousineau2010 = utils::bibentry(
      bibtype = "Article",
      key = "cousineau2010",
      author = c(
        utils::person("Denis", "Cousineau"),
        utils::person("Sylvain", "Chartier")
      ),
      title = "Outliers detection and treatment: A review",
      journal = "International Journal of Psychological Research",
      year = "2010", volume = "3", number = "1", pages = "58--67",
      doi = "10.21500/20112084.844"
    ),
    vandekerckhove2007 = utils::bibentry(
      bibtype = "Article",
      key = "vandekerckhove2007",
      author = c(
        utils::person("Joachim", "Vandekerckhove"),
        utils::person("Francis", "Tuerlinckx")
      ),
      title = "Fitting the Ratcliff diffusion model to experimental data",
      journal = "Psychonomic Bulletin & Review",
      year = "2007", volume = "14", number = "6", pages = "1011--1026",
      doi = "10.3758/bf03193087"
    ),
    ratcliffkang2021 = utils::bibentry(
      bibtype = "Article",
      key = "ratcliffkang2021",
      author = c(
        utils::person("Roger", "Ratcliff"),
        utils::person("Inhan", "Kang")
      ),
      title = paste(
        "Qualitative speed-accuracy tradeoff effects can be explained by a",
        "diffusion/fast-guess mixture model"
      ),
      journal = "Scientific Reports",
      year = "2021", volume = "11", pages = "15169",
      doi = "10.1038/s41598-021-94451-7"
    ),
    ratcliff2002 = utils::bibentry(
      bibtype = "Article",
      key = "ratcliff2002",
      author = c(
        utils::person("Roger", "Ratcliff"),
        utils::person("Francis", "Tuerlinckx")
      ),
      title = paste(
        "Estimating parameters of the diffusion model: Approaches to dealing",
        "with contaminant reaction times and parameter variability"
      ),
      journal = "Psychonomic Bulletin & Review",
      year = "2002", volume = "9", number = "3", pages = "438--481",
      doi = "10.3758/bf03196302"
    ),
    liu2020 = utils::bibentry(
      bibtype = "Article",
      key = "liu2020",
      author = c(
        utils::person("Yue", "Liu"),
        utils::person("Ying", "Cheng"),
        utils::person("Hongyun", "Liu")
      ),
      title = paste(
        "Identifying effortful individuals with mixture modeling response",
        "accuracy and response time simultaneously to improve item parameter",
        "estimation"
      ),
      journal = "Educational and Psychological Measurement",
      year = "2020", volume = "80", number = "4", pages = "775--807",
      doi = "10.1177/0013164419895068"
    ),
    stop("No stored reference for key '", key, "'.")
  )
}

# Author-year for running prose, derived from the entry so that the citation and
# the BibTeX cannot drift apart. "and" rather than "&": this sits in a sentence.
.ref_cite <- function(key) {
  entry <- .ref_entry(key)
  family <- vapply(
    entry$author,
    function(p) paste(p$family, collapse = " "),
    character(1)
  )
  who <- if (length(family) == 1L) {
    family
  } else if (length(family) == 2L) {
    paste(family, collapse = " and ")
  } else {
    paste0(family[1L], " et al.")
  }
  paste0(who, " (", entry$year, ")")
}

# A list joined the way a sentence joins one. Items that already contain a
# comma are separated by semicolons instead, because "a mixture of X, fitted by
# Y or a criterion of Z" reads as though the "or" belonged to the fitting.
.join_prose <- function(x, last = "and") {
  n <- length(x)
  if (n == 0L) {
    return("")
  }
  if (n == 1L) {
    return(x)
  }
  sep <- if (any(grepl(",", x, fixed = TRUE))) "; " else ", "
  if (n == 2L) {
    return(paste0(x[1L], if (identical(sep, "; ")) "; " else " ", last, " ",
      x[2L]
    ))
  }
  paste0(paste(x[-n], collapse = sep), sep, last, " ", x[n])
}
