# Turning a rule into running prose, for report_screening().
#
# Two generics, because a Methods paragraph needs two shapes of the same fact:
#
#   .rule_phrase()   a noun phrase, no capital and no full stop, so it can be
#                    embedded in a larger clause or in another rule's phrase
#   .rule_sentence() a sentence without its terminal stop, so the assembler can
#                    append the grouping clause
#
# This does not reuse .describe_rule() (R/rules.R). That one writes for the
# console: it capitalises, ends in a stop, and renders a composite as an
# indented numbered list with embedded newlines. None of that goes in a
# paragraph, and its default, "No description available.", is acceptable at a
# prompt and not in a manuscript.
#
# Method names run past the object-length limit for the same reason every other
# S3 method in the package does: the class name is the suffix.
# nolint start: object_length_linter.

.rule_phrase <- function(x, depth = 1L) UseMethod(".rule_phrase")

.rule_sentence <- function(x, depth = 1L) UseMethod(".rule_sentence")

# --- sentences ---------------------------------------------------------------

.rule_sentence.default <- function(x, depth = 1L) {
  paste0("Response times were screened with ", .rule_phrase(x, depth + 1L))
}

.rule_sentence.rtprep_rule_none <- function(x, depth = 1L) {
  "No screening rule was applied to the response times"
}

.rule_sentence.rtprep_rule_all <- function(x, depth = 1L) {
  parts <- .component_phrases(x, depth)
  paste0(
    "Response times were screened with ", .join_prose(parts, "or"),
    ", a trial being excluded when ",
    if (length(parts) == 2L) "either" else "any", " of them flagged it"
  )
}

.rule_sentence.rtprep_rule_any <- function(x, depth = 1L) {
  parts <- .component_phrases(x, depth)
  paste0(
    "Response times were screened with ", .join_prose(parts, "and"),
    ", a trial being excluded only when ",
    if (length(parts) == 2L) "both" else "all", " of them flagged it"
  )
}

.rule_sentence.rtprep_rule_then <- function(x, depth = 1L) {
  parts <- .component_phrases(x, depth)
  paste0(
    "Response times were screened in ", .number_word(length(parts)),
    " stages: ", parts[1L], ", then ",
    paste(parts[-1L], collapse = ", then "),
    ", each stage estimated on the trials the previous stages left"
  )
}

.component_phrases <- function(x, depth) {
  # wrapped in a closure so UseMethod() dispatches from this namespace rather
  # than from vapply()'s frame, where the internal generic has no methods
  vapply(x$rules, function(r) .rule_phrase(r, depth + 1L), character(1))
}

# --- phrases -----------------------------------------------------------------

# An extension rule, or any class without a method. The label is the string in
# the .rule column, so a reader can at least match the paragraph to the code.
.rule_phrase.default <- function(x, depth = 1L) {
  paste0("the rule \"", x$label, "\"")
}

.rule_phrase.rtprep_rule_cutoff <- function(x, depth = 1L) {
  has_min <- x$min > 0
  has_max <- is.finite(x$max)
  if (has_min && has_max) {
    paste0(
      "absolute cutoffs at ", .fmt(x$min), " and ", .fmt(x$max), " seconds"
    )
  } else if (has_min) {
    paste0("an absolute lower cutoff at ", .fmt(x$min), " seconds")
  } else if (has_max) {
    paste0("an absolute upper cutoff at ", .fmt(x$max), " seconds")
  } else {
    "absolute cutoffs that excluded nothing, having no finite bound"
  }
}

.rule_phrase.rtprep_rule_sd <- function(x, depth = 1L) {
  .spread_phrase(x$n_sd, x$center, x$scale)
}

# Shared with the hierarchical rule, which takes the same two settings.
.spread_phrase <- function(n_sd, center, scale) {
  units <- switch(scale,
    sd = "standard deviations",
    mad = "median absolute deviations",
    paste0(scale, "s")
  )
  paste0(
    "a criterion of ", .fmt(n_sd), " ", units, " around the ", center
  )
}

.rule_phrase.rtprep_rule_iqr <- function(x, depth = 1L) {
  paste0("Tukey's fences at ", .fmt(x$k), " times the interquartile range")
}

.rule_phrase.rtprep_rule_recursive <- function(x, depth = 1L) {
  # no year here: the citation clause carries it, and naming the year twice in
  # one paragraph reads as a mistake
  body <- switch(x$type,
    moving = "moving criterion",
    modified = "modified recursive criterion",
    hybrid = "hybrid of the moving and modified recursive criteria"
  )
  paste0("the ", body, " of Van Selst and Jolicoeur")
}

.rule_phrase.rtprep_rule_ewma <- function(x, depth = 1L) {
  paste0(
    "an exponentially weighted moving average control chart on accuracy, ",
    "which excludes trials faster than the point at which accuracy first ",
    "departs from ", .fmt(x$chance), " (lambda = ", .fmt(x$lambda),
    ", L = ", .fmt(x$L), ")"
  )
}

.rule_phrase.rtprep_rule_mixture <- function(x, depth = 1L) {
  shape <- switch(x$distribution,
    lognormal = "lognormal",
    exgaussian = "ex-Gaussian",
    invgaussian = "inverse Gaussian",
    x$distribution
  )
  # the bound is a setting that changes the answer, so two screens differing
  # only in it must not produce the same description
  bound <- if (is.numeric(x$bound)) {
    paste0(
      ", the contaminant distribution bounded at ", .fmt(x$bound[1]),
      " and ", .fmt(x$bound[2]), " seconds"
    )
  }
  paste0(
    "a two-component mixture of a uniform contaminant distribution and ",
    .indefinite(shape), " ", shape, " response time distribution, fitted by ",
    "expectation maximisation", bound,
    if (isTRUE(x$use_accuracy)) {
      ", with accuracy in the likelihood (experimental)"
    }
  )
}

.rule_phrase.rtprep_rule_hierarchical <- function(x, depth = 1L) {
  paste0(
    .spread_phrase(x$n_sd, x$center, x$scale),
    ", with each group's centre and spread shrunk towards the values pooled ",
    "over groups (n0 = ", .fmt(x$n0), ")"
  )
}

.rule_phrase.rtprep_rule_oracle <- function(x, depth = 1L) {
  paste0(
    "perfect exclusion of the ", sum(x$contaminant, na.rm = TRUE),
    " trials labelled as contaminants, which requires ground truth and so is ",
    "available for simulated data only"
  )
}

.rule_phrase.rtprep_rule_none <- function(x, depth = 1L) "no screening"

.rule_phrase.rtprep_rule_adaptive_trim <- function(x, depth = 1L) {
  paste0(
    "an adaptive trim of the fastest ", .fmt(100 * x$q_cut),
    "% of trials, applied only where the surviving minimum shifts at least ",
    .fmt(x$s_accept), " of the way to the q", .fmt(200 * x$q_cut),
    " quantile (experimental)"
  )
}

.rule_phrase.rtprep_rule_ez_support <- function(x, depth = 1L) {
  times <- if (isTRUE(all.equal(x$c_ndt, 1))) {
    "the closed-form EZ non-decision time"
  } else {
    paste0(.fmt(x$c_ndt), " times the closed-form EZ non-decision time")
  }
  paste0(
    "exclusion of trials below ", times,
    if (isTRUE(x$refit)) ", refitted once on the survivors",
    " (experimental)"
  )
}

# --- composite phrases -------------------------------------------------------
#
# A composite nested inside another composite. Past two levels of nesting the
# coordinate embedding stops being parseable English ("trials flagged by either
# the combination of the combination of ..."), so the phrase falls back to the
# rule's own label. That is lossless: .compose_rule() builds the label
# recursively from the components' labels, and it is the string in the .rule
# column, so a reader can match it to the code and to ?rules_compose.

.rule_phrase.rtprep_rule_all <- function(x, depth = 1L) {
  if (depth >= 3L) {
    return(.rule_phrase.default(x))
  }
  .join_prose(.component_phrases(x, depth), "or")
}

.rule_phrase.rtprep_rule_any <- function(x, depth = 1L) {
  if (depth >= 3L) {
    return(.rule_phrase.default(x))
  }
  parts <- .component_phrases(x, depth)
  paste0(
    if (length(parts) == 2L) "both " else "all of ",
    .join_prose(parts, "and")
  )
}

.rule_phrase.rtprep_rule_then <- function(x, depth = 1L) {
  if (depth >= 3L) {
    return(.rule_phrase.default(x))
  }
  parts <- .component_phrases(x, depth)
  paste0(
    parts[1L], " followed by ", .join_prose(parts[-1L], "then"),
    ", estimated on the survivors"
  )
}

# nolint end

# --- rule introspection ------------------------------------------------------

# Composite nesting only, so a flat rule is 0 whatever it is wrapped in:
# then(a, b) is 1, all(then(a, b), c) is 2. The phrase methods above fall back
# to the label at depth 3, which is exactly when this reaches 3.
.rule_depth <- function(rule) {
  if (is.null(rule$rules)) {
    return(0L)
  }
  1L + max(vapply(rule$rules, .rule_depth, integer(1)))
}

# How many rules the screen actually applies, for singular/plural agreement.
.rule_leaves <- function(rule) {
  if (is.null(rule$rules)) {
    return(1L)
  }
  sum(vapply(rule$rules, .rule_leaves, integer(1)))
}

# TRUE when every rule in the tree has a phrase method of its own, so that
# report_screening() can say when part of a screen is named only by its label.
.known_rule <- function(rule) {
  if (!is.null(rule$rules)) {
    return(all(vapply(rule$rules, .known_rule, logical(1))))
  }
  !is.null(utils::getS3method(
    ".rule_phrase", class(rule)[1],
    optional = TRUE, envir = asNamespace("rtprep")
  ))
}

.number_word <- function(n) {
  words <- c(
    "one", "two", "three", "four", "five", "six",
    "seven", "eight", "nine", "ten", "eleven", "twelve"
  )
  if (n >= 1L && n <= length(words)) words[n] else as.character(n)
}

# "an ex-Gaussian", "a lognormal". Spelling, not phonetics: every distribution
# name this is used on is written the way it is said.
.indefinite <- function(word) {
  if (grepl("^[aeiou]", word, ignore.case = TRUE)) "an" else "a"
}
