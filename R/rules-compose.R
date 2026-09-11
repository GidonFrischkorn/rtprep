# Composite rules. Two shapes, because the literature uses both and they are
# not the same operation: rules that each see the raw data (parallel), and rules
# staged so that each is estimated on what the last one left (sequential).

#' Combine screening rules
#'
#' A composite is a rule, so it goes wherever a rule goes: [rt_screen()],
#' [rt_keep()], [screen_fits()], [screen_compare()].
#'
#' `rule_all()` keeps a trial only when every component keeps it, so the trials
#' it removes are the *union* of what the components remove. `rule_any()` keeps
#' a trial that any component keeps, so it removes only the *intersection*.
#' `rule_then()` runs the components in order, each estimated on the trials the
#' previous ones left.
#'
#' @section Which one you want:
#' Screening rules disagree because they look in different places. The location
#' and spread criteria and the recursive criteria read the slow tail; on
#' anticipations at the leading edge of a right-skewed distribution they remove
#' nothing, because those trials sit well inside a criterion built around the
#' mean. `rule_ewma()` reads accuracy and finds the leading edge, and is blind
#' to the slow tail. Combining one of each with `rule_all()` covers both,
#' which no single conventional rule does.
#'
#' `rule_then()` is the other idiom, and it is what a two-stage description like
#' "trials below 200 ms were discarded, then trials more than 2.5 SD from each
#' participant's mean" actually means: the standard deviation is computed after
#' the floor, on the survivors. `trimr::sdTrim(minRT = , sd = )` does exactly
#' this, and `rule_then(rule_cutoff(0.2), rule_sd(2.5))` reproduces it. Writing
#' the two stages in parallel instead gives a different answer, because the
#' fast trials are still inflating the standard deviation when it is estimated.
#'
#' @section What `.prob` becomes:
#' `rtprep` keeps the probability that a trial is valid separate from the
#' decision to drop it, and a composite has to preserve that. `rule_all()`
#' takes the smallest of the component probabilities and `rule_any()` the
#' largest, so the composite's `.prob` is still a probability of validity and
#' still drives `policy = "probabilistic"` and `rt_summary(weights = )`. For
#' components that return 0 and 1 this reduces to the logical operation, and a
#' mixture combined with a deterministic rule keeps its posterior wherever the
#' deterministic rule does not veto.
#'
#' `rule_then()` reports the probability from the stage that flagged the trial,
#' or from the last stage to see it if none did. `.reason` comes from the first
#' component to flag, in the order given.
#'
#' @section What `screen_fits()` reports:
#' One row per group, as always, with each component's diagnostics prefixed by
#' its position: `r1_lower`, `r2_criterion`, and so on. `rule_then()` adds
#' `r1_n_flagged`, `r2_n_flagged`, ... so it is visible how much work each stage
#' did, which is the number a staged pipeline usually wants and rarely reports.
#'
#' @param ... Two or more rule objects.
#' @param threshold Probability above which a trial survives a stage and is
#'   passed to the next. Only `rule_then()` takes this: which trials the later
#'   stages see is part of the rule, not part of the exclusion policy applied
#'   afterwards by [rt_screen()].
#'
#' @return An object of class `c("rtprep_rule_<name>", "rtprep_rule")` holding
#'   the components in `rules`.
#'
#' @examples
#' # the slow tail and the leading edge, which no single rule covers
#' rule_all(rule_mad(2.5), rule_ewma())
#'
#' # a floor, then a criterion estimated on what the floor left
#' staged <- rule_then(rule_cutoff(0.2), rule_sd(2.5))
#' staged
#'
#' screen_fits(rt_example$rt, staged, .by = rt_example$id)
#'
#' @seealso [rules] for the components.
#' @name rules_compose
NULL

.compose_rule <- function(subclass, verb, rules, ...) {
  .stopif(
    length(rules) < 2L,
    paste0("'", verb, "' needs at least two rules; got ", length(rules), ".")
  )
  bad <- !vapply(rules, inherits, logical(1), "rtprep_rule")
  .stopif(
    any(bad),
    paste0(
      "Every argument to '", verb, "' must be a rule object, e.g. from ",
      "rule_sd(). Got ", paste(unique(vapply(rules[bad], function(r) {
        class(r)[1]
      }, character(1))), collapse = ", "), "."
    )
  )
  labels <- vapply(rules, function(r) r$label, character(1))
  new_rule(
    subclass,
    label = paste0(verb, "(", paste(labels, collapse = ", "), ")"),
    rules = unname(rules),
    ...,
    # wrapped in closures so UseMethod() dispatches from this namespace rather
    # than from vapply()'s frame, where the internal generic has no methods
    needs_response = any(vapply(rules, function(r) .needs_response(r), NA)),
    grouped = any(vapply(rules, function(r) .is_grouped_rule(r), NA))
  )
}

#' @rdname rules_compose
#' @export
rule_all <- function(...) {
  .compose_rule("all", "all", list(...))
}

#' @rdname rules_compose
#' @export
rule_any <- function(...) {
  .compose_rule("any", "any", list(...))
}

#' @rdname rules_compose
#' @export
rule_then <- function(..., threshold = 0.5) {
  .check_scalar(threshold, "threshold", lower = 0, upper = 1)
  .compose_rule("then", "then", list(...), threshold = threshold)
}

.describe_rule.rtprep_rule_all <- function(x) {
  .describe_composite(x, "Exclude a trial that any of these rules excludes:")
}

.describe_rule.rtprep_rule_any <- function(x) {
  .describe_composite(x, "Exclude a trial that all of these rules exclude:")
}

.describe_rule.rtprep_rule_then <- function(x) { # nolint: object_length_linter.
  .describe_composite(
    x,
    paste0(
      "Apply in order, each estimated on the trials the last one left ",
      "(stage threshold ", .fmt(x$threshold), "):"
    )
  )
}

.describe_composite <- function(x, header) {
  parts <- vapply(
    seq_along(x$rules),
    function(i) paste0("\n    ", i, ". ", x$rules[[i]]$label),
    character(1)
  )
  paste0(header, paste(parts, collapse = ""))
}
