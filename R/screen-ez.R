# apply_rule() method for the EZ support screen.
#
# Layering exception, named in local/spec-experimental-screens.md: this
# Layer-2 screen calls the Layer-3 closed-form ez_ddm(), which is what makes a
# model-implied support bound available at screening cost. ez_ddm() is called
# unqualified so the tests can rebind it.

#' @exportS3Method
apply_rule.rtprep_rule_ez_support <- function(rule, rt, response = NULL) {
  n <- length(rt)
  keep_all <- function(ndt_init, ndt_final) {
    list(
      prob = rep(1, n),
      reason = rep(NA_character_, n),
      fit = data.frame(
        ndt_init = ndt_init, ndt_final = ndt_final,
        threshold_rt = NA_real_, n_flagged_init = NA_integer_,
        n_flagged = 0L, refit = rule$refit, usable = FALSE
      )
    )
  }

  if (n < 10L) {
    return(keep_all(NA_real_, NA_real_))
  }

  e1 <- ez_ddm(mean(rt), stats::var(rt), mean(response), n)
  ndt_init <- e1$ndt[1]
  # contaminated moments can push the fitted ndt to or below zero; a support
  # bound that is not a positive time removes nothing
  if (is.na(e1$drift[1]) || is.na(ndt_init) || ndt_init <= 0) {
    return(keep_all(ndt_init, NA_real_))
  }

  flag1 <- rt < rule$c_ndt * ndt_init
  ndt_final <- ndt_init
  if (rule$refit && sum(!flag1) >= 10L) {
    srt <- rt[!flag1]
    sok <- response[!flag1]
    e2 <- ez_ddm(mean(srt), stats::var(srt), mean(sok), length(srt))
    if (!is.na(e2$drift[1]) && !is.na(e2$ndt[1]) && e2$ndt[1] > 0) {
      ndt_final <- e2$ndt[1]
    }
  }
  # exactly two passes: lower-tail removal shrinks the variance and raises the
  # fitted ndt, so iterating to convergence would be a one-way ratchet

  flag <- rt < rule$c_ndt * ndt_final
  # defensive: unreachable through ez_ddm() at c_ndt <= 1 (the pass-1
  # threshold cannot exceed the sample median), kept as an invariant
  if (sum(flag) > n / 2) {
    return(keep_all(ndt_init, ndt_final))
  }

  list(
    prob = as.numeric(!flag),
    reason = ifelse(flag, "too_fast", NA_character_),
    fit = data.frame(
      ndt_init = ndt_init, ndt_final = ndt_final,
      threshold_rt = rule$c_ndt * ndt_final,
      n_flagged_init = as.integer(sum(flag1)),
      n_flagged = as.integer(sum(flag)),
      refit = rule$refit, usable = TRUE
    )
  )
}
