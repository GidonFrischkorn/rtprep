# The one pair of methods that covers every rule built with new_rule(fun = ).
# The function lives on the object rather than on the class, so two rules of the
# same subclass can carry different functions and neither needs a method of its
# own. What the engine can supply is matched against the function's own formals:
# it declares what it needs by name and gets exactly that.

.call_rule_fun <- function(rule, rt, response, idx_by_group = NULL) {
  fun <- attr(rule, "fun")
  grouped <- !is.null(idx_by_group)
  # built from the rule the engine handed us, which for a per-trial rule has
  # already been cut down to this group by .subset_rule()
  supply <- c(
    list(rt = rt, response = response, rule = rule),
    if (grouped) list(idx_by_group = idx_by_group),
    unclass(rule)
  )
  fmls <- .fun_formals(fun)
  # `...` means "and whatever else you have": the named formals still match
  # first, so the rest lands in the dots
  args <- if ("..." %in% fmls) {
    supply
  } else {
    supply[intersect(fmls, names(supply))]
  }
  # quote = TRUE so a parameter that happens to be a symbol, a call or a formula
  # is passed as itself rather than evaluated a second time
  do.call(fun, args, quote = TRUE)
}

# Three accepted shapes, one contract out. A bare vector is a keep decision, and
# the engine's contract wants P(valid) and a reason -- the same statement
# written twice.
.coerce_rule_result <- function(res, n, rule) {
  where <- paste0("The screening function of rule '", rule$label, "' ")

  # the full contract, checked downstream by .check_rule_result() as usual
  if (is.list(res) && !is.data.frame(res)) {
    return(res)
  }

  .stopif(
    !is.logical(res) && !is.numeric(res),
    paste0(
      where, "must return a logical vector (TRUE = keep), a numeric vector of ",
      "probabilities, or a list with 'prob', 'reason' and 'fit'; got ",
      class(res)[1], "."
    )
  )
  .stopif(
    length(res) != n,
    paste0(where, "returned ", length(res), " values for ", n, " trials.")
  )
  # NA here would become NA in .keep, NA in n_dropped, and a screen that cannot
  # say what it removed. A rule that cannot evaluate a trial keeps it.
  .stopif(
    anyNA(res),
    paste0(
      where, "returned NA for ", sum(is.na(res)), " trial(s). A rule that ",
      "cannot evaluate a trial keeps it: return TRUE, or 1, rather than NA."
    )
  )

  prob <- as.numeric(res)
  list(
    prob = prob,
    reason = ifelse(prob < 1, attr(rule, "reason"), NA_character_),
    fit = NULL
  )
}

#' @exportS3Method
apply_rule.rtprep_rule_fun <- function(rule, rt, response = NULL) {
  .coerce_rule_result(.call_rule_fun(rule, rt, response), length(rt), rule)
}

#' @exportS3Method
apply_rule_grouped.rtprep_rule_fun <- function(rule, rt, response = NULL,
                                               idx_by_group) {
  .coerce_rule_result(
    .call_rule_fun(rule, rt, response, idx_by_group), length(rt), rule
  )
}
