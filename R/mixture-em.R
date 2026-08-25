# The uniform-contaminant mixture and its EM.
#
#   f(rt)  =  (1 - pi_c) f_RT(rt | theta)  +  pi_c U(rt | a, b)
#
# Ratcliff & Tuerlinckx (2002). The loop below is deliberately a copy of
# bmm:::.fit_rt_mixture(), down to the order of operations, because the
# companion DDM tutorial recommends bmm's defaults on the strength of results
# computed here. Two things follow from that and are load-bearing:
#
#   * convergence is checked BEFORE the M-step, so the reported parameters are
#     the ones that produced the converged log-likelihood rather than a further
#     update of it;
#   * the parameter fit is warm-started from the previous iteration.
#
# The M-steps are where rtprep departs: bmm optimises numerically for all three
# distributions, while the closed forms below are the exact maximisers of the
# same weighted likelihood. They agree to optimiser tolerance and are much
# cheaper in the inner loop.

# Resolve the uniform component's support.
#
# Port of bmm:::.resolve_contaminant_bounds(). The buffer is the part that
# matters: an unbuffered uniform over exactly the observed range puts its edges
# on data points, which leaves the mixture barely identifiable.
#
# Returns the bounds together with flags for the two conditions worth telling
# the user about, rather than warning here. Bound resolution happens once per
# group, so warning inside would emit one per subject -- the same failure
# .warn_unconverged() exists to avoid. rt_screen() reports them once for the
# whole call.
.resolve_bounds <- function(bound, x, buffer = 0.5) {
  data_min <- min(x)
  data_max <- max(x)
  data_range <- data_max - data_min

  is_keyword <- vapply(bound, function(b) {
    !is.numeric(b) && tolower(as.character(b)) %in% c("min", "max")
  }, logical(1))

  resolved <- vapply(seq_along(bound), function(i) {
    b <- bound[[i]]
    if (!is_keyword[i]) {
      return(if (is.numeric(b)) as.numeric(b) else as.numeric(as.character(b)))
    }
    if (tolower(as.character(b)) == "min") data_min else data_max
  }, numeric(1))

  pad <- max(buffer * data_range, 0.1)
  if (is_keyword[1] && buffer > 0) resolved[1] <- max(0.001, resolved[1] - pad)
  if (is_keyword[2] && buffer > 0) resolved[2] <- resolved[2] + pad

  inverted <- resolved[1] >= resolved[2]
  if (inverted) {
    resolved <- c(max(0.001, data_min - pad), data_max + pad)
  }

  list(
    bound = unname(resolved),
    inverted = inverted,
    # trials outside the bounds cannot be classified as contaminants
    excludes_fast = resolved[1] > data_min,
    excludes_slow = resolved[2] < data_max
  )
}

# Weighted maximum likelihood for the response time component.
#
# Closed form for the lognormal and the inverse Gaussian; numeric for the
# ex-Gaussian, where the pnorm() term means there is none -- conditioning on tau
# leaves mu and sigma without closed forms either, so the reduction to a
# one-dimensional problem the architecture hoped for does not exist.
#
# The two branches fail differently on purpose. A closed form that comes out
# non-finite or out of bounds means the weights were degenerate, so the update
# is discarded and the previous parameters stand. optim() is trusted on its own
# convergence code, as in bmm: L-BFGS-B projects onto its box and can land a few
# ulp below the bound it was given, and rejecting those would throw away a
# perfectly good fit in exactly the regime where a parameter is genuinely at its
# boundary -- which is the ex-Gaussian's headline behaviour on fast guesses.
.m_step <- function(x, distribution, w, init) {
  total <- sum(w)
  if (!is.finite(total) || total <= 0) {
    return(init)
  }

  if (distribution == "exgaussian") {
    bounds <- .param_bounds(distribution)
    fit <- tryCatch(
      stats::optim(
        par = init,
        fn = function(p) {
          -sum(w * .rt_density(x, p, distribution, log = TRUE), na.rm = TRUE)
        },
        method = "L-BFGS-B",
        lower = bounds$lower, upper = bounds$upper
      ),
      error = function(e) NULL
    )
    if (is.null(fit) || fit$convergence != 0) {
      return(init)
    }
    # clamp rather than reject: the only way optim() lands outside is the box
    # projection's own rounding
    return(pmax(fit$par, bounds$lower))
  }

  par <- switch(distribution,
    lognormal = {
      lx <- log(x)
      mu <- sum(w * lx) / total
      sigma <- sqrt(sum(w * (lx - mu)^2) / total)
      c(mu = mu, sigma = sigma)
    },
    invgaussian = {
      mu <- sum(w * x) / total
      lambda <- total / sum(w * (1 / x - 1 / mu))
      c(mu = mu, lambda = lambda)
    }
  )

  lower <- .param_bounds(distribution)$lower
  if (!all(is.finite(par)) || any(par < lower)) init else par
}

# One EM iteration's E-step: responsibilities and the mixture log-likelihood.
.e_step <- function(x, par, distribution, pi_rt, pi_c, uniform_dens) {
  dens <- pmax(.rt_density(x, par, distribution), 1e-300)
  numer_rt <- pi_rt * dens
  denom <- numer_rt + pi_c * uniform_dens
  list(gamma_rt = numer_rt / denom, loglik = sum(log(denom)))
}

# Fit the mixture by expectation maximisation.
#
# On anything other than convergence the parameters, mixing weight, and
# log-likelihood come back empty. They would otherwise describe different
# points: the log-likelihood is computed before each M-step, so on an exhausted
# or aborted loop it belongs to the previous parameters rather than the ones
# being reported. bmm returns NA here for the same reason.
.fit_rt_mixture <- function(x, distribution, bound, init, max_prop,
                            maxit, tol) {
  x_valid <- x[x >= bound[1] & x <= bound[2]]
  n_valid <- length(x_valid)

  unfittable <- function(iterations = 0L) {
    list(
      par = NULL, contaminant_prop = NA_real_, converged = FALSE,
      iterations = iterations, loglik = NA_real_, n_fitted = n_valid
    )
  }
  # five is bmm's floor: below it the two components cannot be told apart
  if (n_valid < 5L) {
    return(unfittable())
  }

  # pi_rt is carried rather than recomputed as 1 - pi_c: the round trip is not
  # exact in floating point, and bmm carries it, so recomputing would put a
  # one-ulp wedge between the two implementations at every iteration
  pi_c <- init
  pi_rt <- 1 - pi_c
  par <- .init_dist_params(x_valid, distribution)
  if (!all(is.finite(par))) {
    return(unfittable())
  }
  uniform_dens <- 1 / (bound[2] - bound[1])

  prev_loglik <- -Inf
  converged <- FALSE
  loglik <- NA_real_
  iter <- 0L

  for (i in seq_len(maxit)) {
    iter <- i

    step <- .e_step(x_valid, par, distribution, pi_rt, pi_c, uniform_dens)
    if (anyNA(step$gamma_rt) || !is.finite(step$loglik)) break
    loglik <- step$loglik

    # checked before the M-step, as in bmm
    if (abs(loglik - prev_loglik) < tol) {
      converged <- TRUE
      break
    }
    prev_loglik <- loglik

    pi_rt <- mean(step$gamma_rt)
    pi_c <- 1 - pi_rt
    if (is.na(pi_c)) {
      pi_c <- init
      pi_rt <- 1 - pi_c
    }
    if (pi_c > max_prop) {
      pi_c <- max_prop
      pi_rt <- 1 - pi_c
    }
    par <- .m_step(x_valid, distribution, step$gamma_rt, par)
  }

  if (!converged) {
    return(unfittable(as.integer(iter)))
  }

  list(
    par = par,
    contaminant_prop = pi_c,
    converged = TRUE,
    iterations = as.integer(iter),
    loglik = loglik,
    n_fitted = n_valid
  )
}
