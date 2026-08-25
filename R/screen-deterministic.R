# apply_rule() methods for the rules that need no model fitting.
#
# Every method is called once per group, with rt already stripped of missing
# values and guaranteed non-empty, and returns list(prob, reason, fit).

# --- absolute cutoffs -------------------------------------------------------

#' @exportS3Method
apply_rule.rtprep_rule_cutoff <- function(rule, rt, response = NULL) {
  list(
    prob = .prob_from_bounds(rt, rule$min, rule$max),
    reason = .reason_from_bounds(rt, rule$min, rule$max),
    fit = data.frame(lower = rule$min, upper = rule$max)
  )
}

# --- location / spread criteria --------------------------------------------

#' @exportS3Method
apply_rule.rtprep_rule_sd <- function(rule, rt, response = NULL) {
  centre <- if (rule$center == "mean") mean(rt) else stats::median(rt)
  spread <- if (rule$scale == "sd") stats::sd(rt) else stats::mad(rt)

  # A rule that cannot be evaluated must not remove data: fewer than two trials
  # leaves sd undefined, and zero spread would flag nothing or everything
  # depending on floating-point luck.
  if (length(rt) < 2L || !is.finite(spread) || spread == 0) {
    return(list(
      prob = rep(1, length(rt)),
      reason = rep(NA_character_, length(rt)),
      fit = data.frame(
        center = centre, scale = spread,
        lower = NA_real_, upper = NA_real_
      )
    ))
  }

  lower <- centre - rule$n_sd * spread
  upper <- centre + rule$n_sd * spread
  list(
    prob = .prob_from_bounds(rt, lower, upper),
    reason = .reason_from_bounds(rt, lower, upper),
    fit = data.frame(
      center = centre, scale = spread, lower = lower, upper = upper
    )
  )
}

# --- van Selst & Jolicoeur (1994) recursive criteria ------------------------

# The published criterion table: multipliers for sample sizes 4 to 100, one
# column per procedure. Transcribed from van Selst & Jolicoeur (1994) and
# cross-checked against trimr's `linearInterpolation` data set, which is the
# reference implementation the equivalence tests compare against.
.vsj_table <- list(
  moving = c(
    1.4580, 1.6800, 1.8410, 1.9610, 2.0500, 2.1200, 2.1700, 2.2200,
    2.2460, 2.2740, 2.3100, 2.3260, 2.3390, 2.3520, 2.3650, 2.3780,
    2.3910, 2.3948, 2.3986, 2.4024, 2.4062, 2.4100, 2.4141, 2.4182,
    2.4223, 2.4264, 2.4305, 2.4344, 2.4383, 2.4422, 2.4461, 2.4500,
    2.4520, 2.4540, 2.4560, 2.4580, 2.4600, 2.4620, 2.4640, 2.4660,
    2.4680, 2.4700, 2.4720, 2.4740, 2.4760, 2.4780, 2.4800, 2.4804,
    2.4808, 2.4812, 2.4816, 2.4820, 2.4824, 2.4828, 2.4832, 2.4836,
    2.4840, 2.4844, 2.4848, 2.4852, 2.4856, 2.4860, 2.4864, 2.4868,
    2.4872, 2.4876, 2.4880, 2.4884, 2.4888, 2.4892, 2.4896, 2.4900,
    2.4904, 2.4908, 2.4912, 2.4916, 2.4920, 2.4924, 2.4928, 2.4932,
    2.4936, 2.4940, 2.4944, 2.4948, 2.4952, 2.4956, 2.4960, 2.4964,
    2.4968, 2.4972, 2.4976, 2.4980, 2.4984, 2.4988, 2.4992, 2.4996,
    2.5000
  ),
  modified = c(
    8.0000, 6.2000, 5.3000, 4.8000, 4.4750, 4.2500, 4.1100, 4.0000,
    3.9200, 3.8500, 3.8000, 3.7500, 3.7280, 3.7060, 3.6840, 3.6620,
    3.6400, 3.6310, 3.6220, 3.6130, 3.6040, 3.5950, 3.5860, 3.5770,
    3.5680, 3.5590, 3.5500, 3.5480, 3.5460, 3.5440, 3.5420, 3.5400,
    3.5380, 3.5360, 3.5340, 3.5320, 3.5300, 3.5280, 3.5260, 3.5240,
    3.5220, 3.5200, 3.5180, 3.5160, 3.5140, 3.5120, 3.5100, 3.5098,
    3.5096, 3.5094, 3.5092, 3.5090, 3.5088, 3.5086, 3.5084, 3.5082,
    3.5080, 3.5078, 3.5076, 3.5074, 3.5072, 3.5070, 3.5068, 3.5066,
    3.5064, 3.5062, 3.5060, 3.5058, 3.5056, 3.5054, 3.5052, 3.5050,
    3.5048, 3.5046, 3.5044, 3.5042, 3.5040, 3.5038, 3.5036, 3.5034,
    3.5032, 3.5030, 3.5028, 3.5026, 3.5024, 3.5022, 3.5020, 3.5018,
    3.5016, 3.5014, 3.5012, 3.5010, 3.5008, 3.5006, 3.5004, 3.5002,
    3.5000
  )
)

.vsj_min_n <- 4L
.vsj_max_n <- 100L

# Criterion multiplier for a sample of n trials. NA below the tabled minimum:
# no criterion exists there, so nothing is flagged. Above the tabled maximum the
# value for n = 100 is used, as in van Selst & Jolicoeur and in trimr.
.vsj_criterion <- function(n, type) {
  if (n < .vsj_min_n) {
    return(NA_real_)
  }
  .vsj_table[[type]][min(n, .vsj_max_n) - .vsj_min_n + 1L]
}

#' @exportS3Method
apply_rule.rtprep_rule_recursive <- function(rule, rt, response = NULL) {
  switch(rule$type,
    moving = .vsj_moving(rt, rule$include_max),
    modified = .vsj_modified(rt),
    hybrid = .vsj_hybrid(rt, rule$include_max)
  )
}

.vsj_no_criterion <- function(rt, extra = list()) {
  list(
    prob = rep(1, length(rt)),
    reason = rep(NA_character_, length(rt)),
    fit = do.call(data.frame, c(
      list(
        criterion = NA_real_, lower = NA_real_, upper = NA_real_,
        iterations = 0L
      ),
      extra
    ))
  )
}

# One pass with the criterion read off the table for this sample size.
.vsj_moving <- function(rt, include_max = TRUE) {
  n <- length(rt)
  k <- .vsj_criterion(n, "moving")
  base <- if (include_max || n < 2L) rt else rt[-which.max(rt)]

  spread <- if (length(base) < 2L) NA_real_ else stats::sd(base)
  if (is.na(k) || !is.finite(spread) || spread == 0) {
    return(.vsj_no_criterion(rt))
  }

  lower <- mean(base) - k * spread
  upper <- mean(base) + k * spread
  list(
    prob = .prob_from_bounds(rt, lower, upper),
    reason = .reason_from_bounds(rt, lower, upper),
    fit = data.frame(
      criterion = k, lower = lower, upper = upper, iterations = 1L
    )
  )
}

# The modified recursive procedure. The largest remaining trial is temporarily
# set aside while the criterion is computed -- that exclusion is the
# modification, so it applies regardless of `include_max`. The most extreme
# trial at each end is then removed if it falls outside, and the procedure
# repeats until nothing is removed or fewer than five trials remain.
#
# Removal is by position, so exactly one trial goes per bound per iteration.
# trimr removes by value in its aggregating paths, which would drop every tied
# copy of an extreme at once; with continuous response times the two agree.
.vsj_modified <- function(rt) {
  n <- length(rt)
  alive <- seq_len(n)
  iterations <- 0L
  k <- NA_real_
  lower <- NA_real_
  upper <- NA_real_

  repeat {
    if (length(alive) <= 2L) break
    k_iter <- .vsj_criterion(length(alive), "modified")
    if (is.na(k_iter)) break

    cur <- rt[alive]
    base <- cur[-which.max(cur)]
    spread <- stats::sd(base)
    # zero spread makes lower == upper, which would flag every survivor that is
    # not exactly at the centre; a criterion that cannot discriminate removes
    # nothing
    if (!is.finite(spread) || spread == 0) break

    k <- k_iter
    lower <- mean(base) - k * spread
    upper <- mean(base) + k * spread

    imax <- which.max(cur)
    imin <- which.min(cur)
    drop <- c(if (cur[imax] > upper) imax, if (cur[imin] < lower) imin)
    if (length(drop) == 0L) break

    alive <- alive[-unique(drop)]
    iterations <- iterations + 1L
    if (length(alive) < 5L) break
  }

  if (is.na(k)) {
    return(.vsj_no_criterion(rt))
  }

  prob <- rep(0, n)
  prob[alive] <- 1
  reason <- rep(NA_character_, n)
  dropped <- setdiff(seq_len(n), alive)
  # bounds are those of the final iteration, so a dropped trial is named by
  # which side of the surviving distribution it sits on
  reason[dropped] <- ifelse(
    rt[dropped] > mean(rt[alive]), "too_slow", "too_fast"
  )

  list(
    prob = prob,
    reason = reason,
    fit = data.frame(
      criterion = k, lower = lower, upper = upper,
      iterations = iterations
    )
  )
}

# Van Selst & Jolicoeur's hybrid averages the two procedures. At trial level
# that makes .prob the mean of the two decisions -- 0, 0.5, or 1 -- so under the
# default keep policy a trial survives only when both rules keep it. The
# published hybrid *statistic* is the mean of the two condition means and cannot
# be recovered from a single keep vector; see ?rule_recursive.
.vsj_hybrid <- function(rt, include_max = TRUE) {
  moving <- .vsj_moving(rt, include_max)
  modified <- .vsj_modified(rt)

  prob <- (moving$prob + modified$prob) / 2
  reason <- ifelse(is.na(moving$reason), modified$reason, moving$reason)
  reason[prob == 1] <- NA_character_

  list(
    prob = prob,
    reason = reason,
    fit = data.frame(
      criterion = modified$fit$criterion,
      lower = modified$fit$lower,
      upper = modified$fit$upper,
      iterations = modified$fit$iterations,
      criterion_moving = moving$fit$criterion,
      lower_moving = moving$fit$lower,
      upper_moving = moving$fit$upper,
      n_disagree = sum(moving$prob != modified$prob)
    )
  )
}

# --- EWMA accuracy control chart -------------------------------------------

#' @exportS3Method
apply_rule.rtprep_rule_ewma <- function(rule, rt, response = NULL) {
  n <- length(rt)
  correct <- as.numeric(.as_upper(response))

  ord <- order(rt)
  y <- correct[ord]
  lambda <- rule$lambda
  gamma <- rule$chance

  # exponentially weighted average of accuracy, walking from fastest to slowest:
  # z_i = lambda * y_i + (1 - lambda) * z_{i-1}, starting from z_0 = chance
  z <- as.numeric(stats::filter(
    lambda * y,
    filter = 1 - lambda, method = "recursive", init = gamma
  ))

  sigma <- sqrt(gamma * (1 - gamma))
  i <- seq_len(n)
  ucl <- gamma + rule$L * sigma *
    sqrt(lambda / (2 - lambda) * (1 - (1 - lambda)^(2 * i)))

  crossed <- which(z > ucl)
  if (length(crossed) == 0L) {
    return(list(
      prob = rep(1, n),
      reason = rep(NA_character_, n),
      fit = data.frame(cutoff_rt = NA_real_, n_flagged = 0L)
    ))
  }

  cutoff_rt <- rt[ord][crossed[1]]
  prob <- as.numeric(rt >= cutoff_rt)
  reason <- ifelse(prob == 1, NA_character_, "too_fast")

  list(
    prob = prob,
    reason = reason,
    fit = data.frame(
      cutoff_rt = cutoff_rt, n_flagged = as.integer(sum(prob == 0))
    )
  )
}

# --- pass-through -----------------------------------------------------------

#' @exportS3Method
apply_rule.rtprep_rule_none <- function(rule, rt, response = NULL) {
  list(
    prob = rep(1, length(rt)),
    reason = rep(NA_character_, length(rt)),
    fit = NULL
  )
}
