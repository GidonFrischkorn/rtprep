# The extension seam: everything an outside package needs to add a screening
# rule. The generic and the constructor are exported; the contract they define
# is enforced by .check_rule_result() below, so a malformed method fails where
# it went wrong rather than three columns later.

#' Add a screening rule
#'
#' A rule is a parameter object; the engine applies it. Adding one takes a
#' single call to `new_rule()` with `fun =`, the function that decides which
#' trials to keep. The function travels on the rule object, so there is no S3
#' method to write and nothing to register, and [rt_screen()], [rt_keep()],
#' [screen_fits()] and [screen_compare()] all pick the rule up unchanged.
#'
#' [rule_custom()] does the same thing in one call, without a constructor, for
#' a rule used once. A package shipping a family of rules can instead write a
#' method for the [apply_rule()] generic; see "If you are writing a package".
#'
#' @section What the screening function receives:
#' The function declares what it needs by name, and the engine passes exactly
#' that and nothing else. It can supply:
#'
#' \describe{
#'   \item{`rt`}{the response times of one group, in seconds, with missing
#'     values already removed and never empty. The function therefore does no
#'     validation of its own.}
#'   \item{`response`}{accuracy for the same trials, already coerced to 0/1, or
#'     `NULL`. Declaring it makes it mandatory; see "Declaring what a rule
#'     needs".}
#'   \item{`rule`}{the rule object itself, for a function that would rather read
#'     `rule$name` than take parameters one by one.}
#'   \item{`idx_by_group`}{for a `grouped = TRUE` rule only: a list of integer
#'     vectors giving each group's positions in `rt`.}
#'   \item{any parameter stored on the rule}{everything passed to `new_rule()`
#'     through `...`, by the name it was given there.}
#' }
#'
#' A formal the engine cannot supply is an error when the rule is built, rather
#' than in the middle of a screen — unless it has a default, in which case the
#' engine leaves it alone and the default applies. Declaring `...` means "and
#' everything else": the function then receives the whole lot.
#'
#' @section What the screening function must return:
#' The answer is always in *keep* terms: `TRUE`, or a probability near 1, means
#' the trial stays. That is the direction of the `.keep` and `.prob` columns and
#' the opposite of how an exclusion criterion is usually phrased, so it is worth
#' checking once on data whose answer you know.
#'
#' There are three ways to say it, and a rule can start with the first and move
#' to the third without anything else changing.
#'
#' \enumerate{
#'   \item A **logical vector**, one value per trial, `TRUE` for a trial to
#'     keep. The simplest rule, and what most rules are. `.prob` becomes 0 or 1,
#'     and every dropped trial is labelled with the rule's `reason`.
#'   \item A **numeric vector**, one value per trial, in \[0, 1\]: the
#'     probability that the trial came from the decision process. Use this when
#'     the rule is a model rather than a cutoff, as [rule_mixture()] is.
#'     [rt_screen()] turns it into a decision with its own `policy` and
#'     `threshold`, so the function does not decide and must not round.
#'   \item A **list of `prob`, `reason` and `fit`**, the full contract under "If
#'     you are writing a package". Use it when different trials are dropped for
#'     different reasons, or when the rule estimates something per group — a
#'     criterion, a pair of bounds, whether a fit converged — that should become
#'     a column of [screen_fits()]. `reason` is then ignored: the function owns
#'     the reason column.
#' }
#'
#' Whichever shape it returns, it returns one value per trial, in the order `rt`
#' came in, and no `NA`. A rule that cannot evaluate a trial or a whole group,
#' because it has too few trials, a spread of zero, or a fit that did not
#' converge, returns `TRUE`, or 1, and removes nothing. Silence is not evidence
#' of contamination.
#'
#' @section Declaring what a rule needs:
#' Three arguments change how the engine calls the rule.
#'
#' `needs_response = TRUE` makes `response` mandatory: [rt_screen()] then errors
#' when it is not supplied, instead of the function receiving `NULL`. Left
#' unset, it is `TRUE` for a function that declares a `response` argument.
#'
#' `per_trial` names the elements of `...` that hold one value per trial rather
#' than a parameter. The engine checks their length against `rt` up front and
#' subsets them to the group before dispatch, so the function sees only its own
#' group's values. [rule_oracle()] uses this to carry ground truth.
#'
#' `grouped = TRUE` marks a rule that has to see every group at once, one that
#' pools information across participants, say. The engine then calls it once,
#' with all groups, and hands it `idx_by_group`.
#'
#' @section If you are writing a package:
#' A package shipping a family of rules can write a method for the
#' [apply_rule()] generic instead of carrying a function on the object. The two
#' routes are equivalent; a registered `apply_rule.rtprep_rule_<subclass>()`
#' method takes precedence, and a `fun` on the same rule is then ignored.
#'
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
#' A rule that cannot be evaluated on a group returns
#' `prob = rep(1, length(rt))` and removes nothing, for the same reason a
#' screening function returns `TRUE`.
#'
#' A `grouped = TRUE` rule gets a method for [apply_rule_grouped()] instead,
#' called once with every group, and returns `fit` as a list of one-row data
#' frames, one per group.
#'
#' @section Saving a rule:
#' The function travels with the rule, and a screen carries the rule that made
#' it, so saving either saves the function *and the environment it was written
#' in*. A function defined at the top level costs nothing. One defined inside
#' another function drags whatever that function was holding into the file with
#' it, which is how a rule ends up megabytes wide. Define screening functions at
#' the top level, and pass what they need through `...`.
#'
#' @param subclass A string naming the rule family. The object's class becomes
#'   `c("rtprep_rule_<subclass>", "rtprep_rule")`, with `"rtprep_rule_fun"`
#'   between them when the rule carries its own function.
#' @param label A string identifying the rule and its settings, used as the
#'   `.rule` column and by `print()`. Conventionally
#'   `"family(setting, setting)"`.
#' @param ... Named parameters stored on the rule, passed to `fun` by name and
#'   available to an [apply_rule()] method as `rule$name`.
#' @param fun The screening function, or `NULL` to write an [apply_rule()]
#'   method instead. See "What the screening function receives" and "What the
#'   screening function must return".
#' @param description A sentence saying what the rule does, shown by `print()`.
#' @param reason A string naming what a dropped trial was dropped for, used for
#'   the `.reason` column when `fun` returns a bare vector. `rtprep`'s own rules
#'   use `"too_fast"`, `"too_slow"` and `"contaminant"`.
#' @param needs_response,per_trial,grouped See "Declaring what a rule needs".
#' @param rule A rule object, as built by `new_rule()`.
#' @param rt Numeric vector of response times for one group, in seconds, with
#'   missing values already removed.
#' @param response Numeric 0/1 vector of the same length, or `NULL`.
#'
#' @return `new_rule()` returns an object of class
#'   `c("rtprep_rule_<subclass>", "rtprep_rule")`, with `"rtprep_rule_fun"`
#'   inserted before the last when `fun` is given. `apply_rule()` returns the
#'   three-element list described under "If you are writing a package".
#'
#' @examples
#' # a rule that keeps the middle 90% of each group by quantile
#' rule_middle <- function(p = 0.05) {
#'   new_rule(
#'     "middle",
#'     label = paste0("middle(", p, ")"),
#'     p = p,
#'     description = "Keep the middle 90% of each group by quantile.",
#'     fun = function(rt, p) {
#'       b <- stats::quantile(rt, c(p, 1 - p), names = FALSE)
#'       rt >= b[1] & rt <= b[2]
#'     }
#'   )
#' }
#' rule_middle()
#' screen_fits(rt_example$rt, rule_middle(), .by = rt_example$id)
#'
#' # a graded rule returns a probability and lets rt_screen() decide
#' shrinking <- rule_custom(
#'   "shrinking",
#'   function(rt) pmin(1, 0.2 / rt),
#'   description = "The slower the trial, the less likely it is a decision."
#' )
#' head(rt_screen(rt_example$rt, shrinking, .by = rt_example$id))
#'
#' # the package way: a method, for a family with diagnostics to report
#' rule_bounded <- function(p = 0.05) {
#'   new_rule("bounded", label = paste0("bounded(", p, ")"), p = p)
#' }
#' apply_rule.rtprep_rule_bounded <- function(rule, rt, response = NULL) {
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
#'   "apply_rule", "rtprep_rule_bounded", apply_rule.rtprep_rule_bounded
#' )
#' screen_fits(rt_example$rt, rule_bounded(), .by = rt_example$id)
#'
#' @seealso [rule_custom()] for a rule in one call, [rules] for the families
#'   `rtprep` ships.
#' @name extending
NULL

#' @rdname extending
#' @export
new_rule <- function(subclass, label, ..., fun = NULL, description = NULL,
                     reason = "contaminant", needs_response = NULL,
                     per_trial = character(), grouped = FALSE) {
  .check_string(subclass, "subclass")
  .check_string(label, "label")
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
  # needs_response is settled below, on either route, but it is named here so
  # that the attributes keep the order every rule has always had: replacing one
  # leaves it in place, while adding it later would append it after the rest.
  out <- structure(
    c(pars, list(label = label)),
    class = c(paste0("rtprep_rule_", subclass), "rtprep_rule"),
    needs_response = FALSE,
    per_trial = per_trial,
    grouped = grouped
  )
  if (!is.null(description)) {
    .check_string(description, "description")
    attr(out, "description") <- description
  }

  # The method route: the object is finished, and a registered apply_rule()
  # method will do the work.
  if (is.null(fun)) {
    if (is.null(needs_response)) needs_response <- FALSE
    .check_flag(needs_response, "needs_response")
    attr(out, "needs_response") <- needs_response
    return(out)
  }

  # The function route: the rule carries its own screening function, so no
  # method has to be written or registered for it.
  .check_string(reason, "reason")
  .check_rule_fun(fun, out, grouped)
  # a function that asks for `response` is a function that needs one, unless the
  # caller said otherwise in so many words
  if (is.null(needs_response)) {
    needs_response <- "response" %in% .fun_formals(fun)
  }
  .check_flag(needs_response, "needs_response")
  attr(out, "needs_response") <- needs_response
  attr(out, "fun") <- fun
  attr(out, "reason") <- reason
  # after the subclass, so a registered apply_rule.rtprep_rule_<subclass> method
  # still wins; before "rtprep_rule", so this is the fallback and not the first
  # thing found
  class(out) <- c(
    paste0("rtprep_rule_", subclass), "rtprep_rule_fun", "rtprep_rule"
  )
  out
}

# Retained so the package's own constructors read as they always did.
.new_rule <- function(subclass, label, ...) new_rule(subclass, label, ...)

# --- the function route, checked at construction ----------------------------

# Formals of any function, primitives included, where formals() is NULL.
.fun_formals <- function(fun) {
  nms <- names(formals(args(fun)))
  if (is.null(nms)) character() else nms
}

# Everything the engine can hand a rule's own function, by name. `label` is
# stored on the rule like any other value, so a function may declare it.
.rule_supply_names <- function(rule, grouped) {
  c("rt", "response", "rule", if (grouped) "idx_by_group", names(rule))
}

# Checked when the rule is built, so a function that asks for something the
# engine will never supply fails at new_rule() rather than in the middle of a
# screen, with the list of what it could have asked for instead.
.check_rule_fun <- function(fun, rule, grouped) {
  .stopif(!is.function(fun), "'fun' must be a function.")
  supplied <- c("rt", "response", "rule", "idx_by_group")
  clash <- intersect(supplied, names(rule))
  .stopif(
    length(clash) > 0L,
    paste0(
      "A rule parameter cannot be called '", clash[1],
      "': the engine supplies that name to 'fun' itself."
    )
  )

  supply <- .rule_supply_names(rule, grouped)
  # a formal with a default is left alone: the engine simply does not pass it
  # and the default applies, which is ordinary R. One without a default would
  # be an error at call time, so it is an error here instead, where the message
  # can say what went wrong.
  required <- .fun_formals_required(fun)
  unknown <- setdiff(required, supply)
  .stopif(
    length(unknown) > 0L,
    paste0(
      "'fun' takes ", paste0("'", unknown, "'", collapse = ", "),
      ", which the engine cannot supply. It can supply ",
      paste0("'", supply, "'", collapse = ", "),
      ". Anything else has to be stored on the rule, by passing it to ",
      "new_rule() through `...`."
    )
  )
  invisible(NULL)
}

# Formals with no default, `...` excluded: the ones the engine has to supply.
.fun_formals_required <- function(fun) {
  fmls <- formals(args(fun))
  if (is.null(fmls)) {
    return(character())
  }
  # a formal with no default holds the empty symbol, which is the only symbol
  # whose name is the empty string
  no_default <- vapply(
    fmls,
    function(d) is.symbol(d) && !nzchar(as.character(d)),
    logical(1)
  )
  setdiff(names(fmls)[no_default], "...")
}

#' A screening rule from a function, in one call
#'
#' @description
#' The short form of [new_rule()]: pass the function that decides which trials
#' to keep, and get a rule back. No constructor, no S3 method, nothing to
#' register. The result goes anywhere a rule goes — [rt_screen()], [rt_keep()],
#' [screen_fits()], [screen_compare()], and inside [rule_all()] and its
#' relatives.
#'
#' @param label A string identifying the rule, used as the `.rule` column, by
#'   `print()`, and by [screen_compare()], which needs the rules it compares to
#'   be named apart. Conventionally `"family(setting, setting)"`.
#' @param fun The screening function. What it may take is listed under "What the
#'   screening function receives" in [extending]; what it may return, under
#'   "What the screening function must return".
#' @param ... Named parameters stored on the rule and passed to `fun` by name.
#' @param description,reason,needs_response,per_trial,grouped As in
#'   [new_rule()].
#' @param subclass The rule family, for the rare case of wanting a class to hang
#'   a method on later. The default is shared by every `rule_custom()` rule,
#'   which costs nothing: the function travels on the object, not on the class,
#'   so two rules built this way never collide.
#'
#' @return An object of class
#'   `c("rtprep_rule_custom", "rtprep_rule_fun", "rtprep_rule")`.
#'
#' @examples
#' fast <- rule_custom(
#'   "fast(0.35)",
#'   function(rt, cut) rt >= cut,
#'   cut = 0.35,
#'   description = "Exclude trials faster than 350 ms.",
#'   reason = "too_fast"
#' )
#' fast
#' rt_screen(rt_example$rt, fast, .by = rt_example$id)
#'
#' # against one of the rules rtprep ships
#' screen_compare(
#'   rt_example$rt,
#'   list(fast = fast, mad = rule_mad(2.5)),
#'   .by = rt_example$id
#' )
#'
#' @seealso [extending] for the full contract, [new_rule()] to wrap a rule of
#'   your own in a constructor.
#' @export
rule_custom <- function(label, fun, ..., description = NULL,
                        reason = "contaminant", needs_response = NULL,
                        per_trial = character(), grouped = FALSE,
                        subclass = "custom") {
  .stopif(
    missing(fun),
    "'fun' is required: rule_custom() takes the screening function itself."
  )
  new_rule(
    subclass, label, ...,
    fun = fun, description = description, reason = reason,
    needs_response = needs_response, per_trial = per_trial, grouped = grouped
  )
}

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
