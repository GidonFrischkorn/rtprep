# apply_rule() methods for the composites.
#
# Each dispatches its components through the same generic the engine uses, so a
# composite works with any rule family, including one from another package and
# including another composite.

# Run one component over the trials it is allowed to see. Trials outside `on`
# are not the component's business: they come back valid, with no reason.
.run_component <- function(rule, rt, response, on) {
  n <- length(rt)
  if (!any(on)) {
    return(list(prob = rep(1, n), reason = rep(NA_character_, n), fit = NULL))
  }
  sub_response <- if (is.null(response)) NULL else response[on]
  # per-trial parameters are cut to the same trials the component sees
  part <- apply_rule(.subset_rule(rule, which(on)), rt[on], sub_response)
  .check_rule_result(part, sum(on), rule)
  .check_rule_fit(part$fit, rule)

  prob <- rep(1, n)
  reason <- rep(NA_character_, n)
  prob[on] <- part$prob
  reason[on] <- part$reason
  list(prob = prob, reason = reason, fit = part$fit)
}

# Component diagnostics, prefixed by position so the fits contract holds and
# two components of the same family do not collide.
.compose_fit <- function(fits, extra = NULL) {
  parts <- list()
  for (i in seq_along(fits)) {
    f <- fits[[i]]
    if (!is.null(f)) {
      names(f) <- paste0("r", i, "_", names(f))
      parts[[length(parts) + 1L]] <- f
    }
    if (!is.null(extra)) {
      e <- extra[[i]]
      names(e) <- paste0("r", i, "_", names(e))
      parts[[length(parts) + 1L]] <- e
    }
  }
  if (length(parts) == 0L) {
    return(NULL)
  }
  do.call(cbind, parts)
}

# The first component to flag a trial owns the reason. Later components may also
# have flagged it; naming the first keeps the reason stable when a rule is added
# to the end of a composite.
.first_reason <- function(reasons) {
  out <- reasons[[1]]
  for (r in reasons[-1]) {
    out[is.na(out)] <- r[is.na(out)]
  }
  out
}

.parallel_compose <- function(rule, rt, response, combine) {
  n <- length(rt)
  parts <- lapply(rule$rules, .run_component, rt, response, rep(TRUE, n))
  prob <- Reduce(combine, lapply(parts, function(p) p$prob))
  reasons <- lapply(parts, function(p) p$reason)
  list(
    prob = prob,
    reason = ifelse(prob < 1, .first_reason(reasons), NA_character_),
    fit = .compose_fit(lapply(parts, function(p) p$fit))
  )
}

# The most sceptical component governs: the probability reading of "every rule
# has to keep it".
#' @exportS3Method
apply_rule.rtprep_rule_all <- function(rule, rt, response = NULL) {
  .parallel_compose(rule, rt, response, pmin)
}

#' @exportS3Method
apply_rule.rtprep_rule_any <- function(rule, rt, response = NULL) {
  .parallel_compose(rule, rt, response, pmax)
}

#' @exportS3Method
apply_rule.rtprep_rule_then <- function(rule, rt, response = NULL) {
  n <- length(rt)
  alive <- rep(TRUE, n)
  prob <- rep(1, n)
  reasons <- vector("list", length(rule$rules))
  fits <- vector("list", length(rule$rules))
  counts <- vector("list", length(rule$rules))

  for (i in seq_along(rule$rules)) {
    part <- .run_component(rule$rules[[i]], rt, response, alive)
    # a stage's verdict is recorded only for the trials it actually saw, so an
    # earlier flag is never overwritten by a stage never shown the trial
    prob[alive] <- part$prob[alive]
    reasons[[i]] <- part$reason
    fits[[i]] <- part$fit
    flagged <- alive & part$prob <= rule$threshold
    counts[[i]] <- data.frame(n_seen = sum(alive), n_flagged = sum(flagged))
    alive <- alive & !flagged
  }

  list(
    prob = prob,
    reason = ifelse(
      prob <= rule$threshold, .first_reason(reasons), NA_character_
    ),
    fit = .compose_fit(fits, extra = counts)
  )
}
