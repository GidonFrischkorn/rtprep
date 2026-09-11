# The extension seam: everything an outside package needs to add a screening
# rule. The generic and the constructor are exported; the contract they define
# is enforced by .check_rule_result() below, so a malformed method fails where
# it went wrong rather than three columns later.

#' Add a screening rule
#'
#' A rule is a parameter object; the engine applies it. Adding a family to
#' `rtprep`, from this package or any other, is one call to `new_rule()` in a
#' constructor and one [apply_rule()] method.
#'
#' `new_rule()` builds the object. `apply_rule()` is the generic the engine
#' dispatches on: write a method for your subclass and [rt_screen()],
#' [rt_keep()], [screen_fits()] and [screen_compare()] all pick it up unchanged.
#'
#' @section The method contract:
#' `apply_rule()` is called once per group, with `rt` already stripped of
#' missing values and guaranteed non-empty, and `response` already coerced to
#' 0/1 (or `NULL`). Methods therefore do no validation of their own. A method
#' returns a list of three elements:
#'
#' \describe{
#'   \item{`prob`}{numeric, `length(rt)`, in \[0, 1\]: the probability that the
#'     trial came from the decision process. Note the direction: this is
#'     P(valid), not P(contaminant). A deterministic rule returns 0 and 1.}
#'   \item{`reason`}{character, `length(rt)`, `NA` wherever the trial is valid.
#'     `rtprep`'s own rules use `"too_fast"`, `"too_slow"` and `"contaminant"`;
#'     a new rule may use any label.}
#'   \item{`fit`}{a one-row `data.frame` of whatever the rule estimated for that
#'     group (bounds, criteria, convergence), or `NULL` if it estimated
#'     nothing. These become the extra columns of [screen_fits()].}
#' }
#'
#' A rule that cannot be evaluated on a group, because it has too few trials, a
#' spread of zero, or a fit that did not converge, returns
#' `prob = rep(1, length(rt))` and removes nothing. Silence is not evidence of
#' contamination.
#'
#' @section Declaring what a rule needs:
#' Three arguments change how the engine calls the method.
#'
#' `needs_response = TRUE` makes `response` mandatory: [rt_screen()] then errors
#' when it is not supplied, instead of the method receiving `NULL`.
#'
#' `per_trial` names the elements of `...` that hold one value per trial rather
#' than a parameter. The engine checks their length against `rt` up front and
#' subsets them to the group before dispatch, so the method sees only its own
#' group's values. [rule_oracle()] uses this to carry ground truth.
#'
#' `grouped = TRUE` marks a rule that has to see every group at once, one that
#' pools information across participants, say. The engine then calls
#' [apply_rule_grouped()] instead, once, with all groups.
#'
#' @param subclass A string naming the rule family. The object's class becomes
#'   `c("rtprep_rule_<subclass>", "rtprep_rule")`.
#' @param label A string identifying the rule and its settings, used as the
#'   `.rule` column and by `print()`. Conventionally
#'   `"family(setting, setting)"`.
#' @param ... Named parameters stored on the rule and available to the method as
#'   `rule$name`.
#' @param needs_response,per_trial,grouped See "Declaring what a rule needs".
#' @param rule A rule object, as built by `new_rule()`.
#' @param rt Numeric vector of response times for one group, in seconds, with
#'   missing values already removed.
#' @param response Numeric 0/1 vector of the same length, or `NULL`.
#'
#' @return `new_rule()` returns an object of class
#'   `c("rtprep_rule_<subclass>", "rtprep_rule")`. `apply_rule()` returns the
#'   three-element list described above.
#'
#' @examples
#' # a rule that keeps the middle 90% of each group by quantile
#' rule_middle <- function(p = 0.05) {
#'   new_rule("middle", label = paste0("middle(", p, ")"), p = p)
#' }
#'
#' apply_rule.rtprep_rule_middle <- function(rule, rt, response = NULL) {
#'   b <- stats::quantile(rt, c(rule$p, 1 - rule$p), names = FALSE)
#'   list(
#'     prob = as.numeric(rt >= b[1] & rt <= b[2]),
#'     reason = ifelse(
#'       rt < b[1], "too_fast", ifelse(rt > b[2], "too_slow", NA)
#'     ),
#'     fit = data.frame(lower = b[1], upper = b[2])
#'   )
#' }
#' registerS3method(
#'   "apply_rule", "rtprep_rule_middle", apply_rule.rtprep_rule_middle
#' )
#'
#' rule_middle()
#' screen_fits(rt_example$rt, rule_middle(), .by = rt_example$id)
#'
#' @seealso [rules] for the families `rtprep` ships.
#' @name extending
NULL

#' @rdname extending
#' @export
new_rule <- function(subclass, label, ..., needs_response = FALSE,
                     per_trial = character(), grouped = FALSE) {
  .check_string(subclass, "subclass")
  .check_string(label, "label")
  .check_flag(needs_response, "needs_response")
  .check_flag(grouped, "grouped")
  pars <- list(...)
  .stopif(
    length(pars) > 0L && (is.null(names(pars)) || any(names(pars) == "")),
    "All parameters passed to new_rule() through `...` must be named."
  )
  # `label` is stored alongside the parameters, so one passed through `...`
  # would shadow the argument and rule$label would report the wrong thing
  .stopif(
    "label" %in% names(pars),
    "'label' is an argument of new_rule(); it cannot also be passed in `...`."
  )
  .stopif(
    !is.character(per_trial),
    "'per_trial' must be a character vector of parameter names."
  )
  missing_pars <- setdiff(per_trial, names(pars))
  .stopif(
    length(missing_pars) > 0L,
    paste0(
      "'per_trial' names a parameter that was not supplied: ",
      paste(missing_pars, collapse = ", "), "."
    )
  )
  structure(
    c(pars, list(label = label)),
    class = c(paste0("rtprep_rule_", subclass), "rtprep_rule"),
    needs_response = needs_response,
    per_trial = per_trial,
    grouped = grouped
  )
}

# Retained so the package's own constructors read as they always did.
.new_rule <- function(subclass, label, ...) new_rule(subclass, label, ...)

#' @rdname extending
#' @export
apply_rule <- function(rule, rt, response = NULL) UseMethod("apply_rule")

#' @exportS3Method
apply_rule.default <- function(rule, rt, response = NULL) {
  stop(
    "apply_rule() is not yet implemented for rule class '",
    class(rule)[1], "'.",
    call. = FALSE
  )
}

#' @rdname extending
#'
#' @param idx_by_group A list of integer vectors, one per group, giving each
#'   group's positions in `rt`.
#'
#' @export
apply_rule_grouped <- function(rule, rt, response = NULL, idx_by_group) {
  UseMethod("apply_rule_grouped")
}

#' @exportS3Method
apply_rule_grouped.default <- function(rule, rt, response = NULL,
                                       idx_by_group) {
  stop(
    "apply_rule_grouped() is not implemented for rule class '",
    class(rule)[1], "'.",
    call. = FALSE
  )
}

# --- the contract, enforced -------------------------------------------------

# Checked on every return, because the generic is public: without this a method
# returning the wrong length recycles into prob[idx] and produces a wrong answer
# under a warning R raises three assignments later.
.check_rule_result <- function(res, n, rule, grouped = FALSE) {
  what <- if (grouped) "apply_rule_grouped()" else "apply_rule()"
  where <- paste0("The ", what, " method for '", class(rule)[1], "' ")
  .stopif(
    !is.list(res) || !all(c("prob", "reason", "fit") %in% names(res)),
    paste0(where, "must return a list with elements 'prob', 'reason', 'fit'.")
  )
  .stopif(
    !is.numeric(res$prob) || length(res$prob) != n,
    paste0(
      where, "returned 'prob' of length ", length(res$prob),
      "; it must be numeric of length ", n, "."
    )
  )
  .stopif(
    !all(is.na(res$prob) | (res$prob >= 0 & res$prob <= 1)),
    paste0(
      where, "returned 'prob' outside [0, 1]. 'prob' is the probability ",
      "that a trial is valid."
    )
  )
  .stopif(
    !is.character(res$reason) || length(res$reason) != n,
    paste0(
      where, "returned 'reason' of length ", length(res$reason),
      "; it must be a character vector of length ", n, "."
    )
  )
  invisible(res)
}

# One row per group for a grouped rule, one row overall for a per-group rule.
.check_rule_fit <- function(fit, rule, grouped = FALSE, n_groups = 1L) {
  if (is.null(fit)) {
    return(invisible(NULL))
  }
  what <- if (grouped) "apply_rule_grouped()" else "apply_rule()"
  where <- paste0("The ", what, " method for '", class(rule)[1], "' ")
  if (grouped) {
    .stopif(
      !is.list(fit) || length(fit) != n_groups,
      paste0(
        where, "must return 'fit' as NULL or a list of ", n_groups,
        " one-row data frames, one per group."
      )
    )
    for (f in fit) {
      .stopif(
        !is.null(f) && (!is.data.frame(f) || nrow(f) != 1L),
        paste0(
          where, "returned a 'fit' entry that is not a one-row data frame."
        )
      )
    }
  } else {
    .stopif(
      !is.data.frame(fit) || nrow(fit) != 1L,
      paste0(
        where, "must return 'fit' as NULL or a one-row data frame; got ",
        if (is.data.frame(fit)) paste0(nrow(fit), " rows") else class(fit)[1],
        "."
      )
    )
  }
  invisible(fit)
}
