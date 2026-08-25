# apply_rule() for the mixture rule.
#
# This is the one rule that returns a genuine posterior probability rather than
# a verdict, and so the one that justifies rt_screen() separating .prob from
# .keep at all.

#' @exportS3Method
apply_rule.rtprep_rule_mixture <- function(rule, rt, response = NULL) {
  resolved <- .resolve_bounds(rule$bound, rt)
  bound <- resolved$bound

  fit <- .fit_rt_mixture(
    rt, rule$distribution, bound,
    init = rule$init, max_prop = rule$max_prop,
    maxit = rule$maxit, tol = rule$tol
  )
  fit_row <- .mixture_fit_row(fit, resolved, rule$distribution)

  if (!fit$converged) {
    # milestone 1's principle: a rule that cannot be evaluated must not remove
    # data. bmm returns NA here, which would put NA into .keep and break the
    # return contract. rt_screen() reports the failure once from `fits`.
    return(list(
      prob = rep(1, length(rt)),
      reason = rep(NA_character_, length(rt)),
      fit = fit_row
    ))
  }

  pi_c <- fit$contaminant_prop
  in_bounds <- rt >= bound[1] & rt <= bound[2]
  uniform_dens <- ifelse(in_bounds, 1 / (bound[2] - bound[1]), 0)
  dens <- pmax(.rt_density(rt, fit$par, rule$distribution), 1e-300)

  # P(contaminant), then complemented: .prob is P(valid) throughout rtprep,
  # which is the reverse of what bmm::flag_contaminant_rts() returns. A trial
  # outside the bounds gets uniform_dens 0 and so .prob exactly 1 -- the
  # contaminant component cannot have produced it.
  numer_c <- pi_c * uniform_dens
  prob <- 1 - numer_c / (numer_c + (1 - pi_c) * dens)

  # .reason records what the rule found, at the fixed 0.5 point; rt_screen()
  # reconciles it with whatever keep policy is in force
  reason <- ifelse(prob <= 0.5, "contaminant", NA_character_)

  list(prob = prob, reason = reason, fit = fit_row)
}

# The accuracy-informed likelihood is not implemented yet. Checked through this
# generic rather than inside apply_rule() so that rt_screen() can raise it
# before touching any group: apply_rule() is never reached when every group is
# empty, and an unsupported rule has to fail loudly regardless.
#' @exportS3Method
.rule_unsupported.rtprep_rule_mixture <- function(rule) {
  if (isTRUE(rule$use_accuracy)) {
    return("The accuracy-informed mixture is not yet implemented.")
  }
  NULL
}

# One row of EM diagnostics. Fitted parameters are prefixed so they cannot
# collide with the engine's bookkeeping columns, and the set of columns depends
# on the distribution -- rt_screen() fills the gaps when groups differ.
.mixture_fit_row <- function(fit, resolved, distribution) {
  row <- data.frame(
    converged = fit$converged,
    iterations = fit$iterations,
    loglik = fit$loglik,
    contaminant_prop = fit$contaminant_prop,
    n_fitted = as.integer(fit$n_fitted),
    bound_lower = resolved$bound[1],
    bound_upper = resolved$bound[2],
    bound_inverted = resolved$inverted,
    bound_excludes_fast = resolved$excludes_fast,
    bound_excludes_slow = resolved$excludes_slow,
    distribution = distribution,
    stringsAsFactors = FALSE
  )

  par <- fit$par
  if (is.null(par)) {
    par <- stats::setNames(
      rep(NA_real_, length(.param_bounds(distribution)$lower)),
      .param_names(distribution)
    )
  }
  for (nm in names(par)) row[[paste0("par_", nm)]] <- unname(par[[nm]])
  row
}

.param_names <- function(distribution) {
  switch(distribution,
    exgaussian = c("mu", "sigma", "tau"),
    lognormal = c("mu", "sigma"),
    invgaussian = c("mu", "lambda")
  )
}
