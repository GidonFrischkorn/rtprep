# Response time densities and samplers, from first principles.
#
# rtprep imports stats and utils only, so the distributions the mixture needs
# are implemented here rather than taken from a distribution package. The
# densities are ports of bmm's and must agree with them to machine precision:
# tests/testthat/test-distributions.R is the check.
#
# None of these validate, and NA in `x` is the caller's problem. They are called
# from the EM inner loop with parameters the optimiser has already bounded, and
# at the scale the simulation scripts need (10^4 subjects x 10^2 trials) a
# per-call check would cost more than it catches.

# Ex-Gaussian: the convolution of N(mu, sigma^2) with Exp(rate = 1 / tau).
#
# Computed on the log scale throughout, because the natural-scale form
# underflows to zero in the far lower tail while the log scale stays finite.
# The EM's E-step asks for the natural scale and floors it at 1e-300 anyway, so
# the precision matters mainly in the ex-Gaussian M-step objective, which sums
# log densities directly.
.dexgauss <- function(x, mu, sigma, tau, log = FALSE) {
  if (sigma <= 0 || tau <= 0) {
    return(rep(if (log) -Inf else 0, length(x)))
  }

  z <- (x - mu) / sigma - sigma / tau
  log_dens <- -log(tau) + (sigma^2) / (2 * tau^2) - (x - mu) / tau +
    stats::pnorm(z, log.p = TRUE)

  if (log) log_dens else exp(log_dens)
}

# Inverse Gaussian (Wald) in the mean / shape parameterisation.
.dinvgauss <- function(x, mu, lambda, log = FALSE) {
  if (mu <= 0 || lambda <= 0) {
    return(rep(if (log) -Inf else 0, length(x)))
  }

  valid <- x > 0
  log_dens <- rep(-Inf, length(x))
  if (any(valid)) {
    xv <- x[valid]
    log_dens[valid] <- 0.5 * (log(lambda) - log(2 * pi) - 3 * log(xv)) -
      (lambda * (xv - mu)^2) / (2 * mu^2 * xv)
  }

  if (log) log_dens else exp(log_dens)
}

.rexgauss <- function(n, mu, sigma, tau) {
  stats::rnorm(n, mu, sigma) + stats::rexp(n, rate = 1 / tau)
}

# Shuster (1968): the inverse-Gaussian CDF in terms of the normal CDF. The
# exp(2 * lambda / mu) factor can overflow for extreme shape/mean ratios, so it
# is folded into pnorm's log scale.
.pinvgauss <- function(q, mu, lambda) {
  out <- numeric(length(q))
  valid <- q > 0
  if (any(valid)) {
    qv <- q[valid]
    a <- stats::pnorm(sqrt(lambda / qv) * (qv / mu - 1))
    b <- exp(
      2 * lambda / mu +
        stats::pnorm(-sqrt(lambda / qv) * (qv / mu + 1), log.p = TRUE)
    )
    out[valid] <- pmin(a + b, 1)
  }
  out
}

# Michael, Schucany & Haas (1976): an exact transform, not an approximation, so
# no rejection loop and no accuracy tuning.
.rinvgauss <- function(n, mu, lambda) {
  y <- stats::rnorm(n)^2
  x <- mu + mu^2 * y / (2 * lambda) -
    (mu / (2 * lambda)) * sqrt(4 * mu * lambda * y + mu^2 * y^2)
  ifelse(stats::runif(n) <= mu / (mu + x), x, mu^2 / x)
}

# One entry point for the three densities, so the EM does not carry a switch()
# at every call site.
.rt_density <- function(x, par, distribution, log = FALSE) {
  switch(distribution,
    exgaussian = .dexgauss(x, par["mu"], par["sigma"], par["tau"], log = log),
    lognormal = stats::dlnorm(x, par["mu"], par["sigma"], log = log),
    invgaussian = .dinvgauss(x, par["mu"], par["lambda"], log = log)
  )
}

# Analytic mean and variance of the fitted component. rt_summary(method =
# "mixture") reads its moments from here rather than from the data, which is
# what makes contaminants influence nothing.
.dist_moments <- function(par, distribution) {
  switch(distribution,
    exgaussian = list(
      mean = par["mu"] + par["tau"],
      var = par["sigma"]^2 + par["tau"]^2
    ),
    lognormal = list(
      mean = exp(par["mu"] + par["sigma"]^2 / 2),
      var = exp(2 * par["mu"] + par["sigma"]^2) * (exp(par["sigma"]^2) - 1)
    ),
    invgaussian = list(
      mean = par["mu"],
      var = par["mu"]^3 / par["lambda"]
    )
  )
}

# Method-of-moments starting values, matching bmm:::.init_dist_params()
# exactly. The EM is only reproducible from the same starting point, and the
# equivalence test rests on that.
.init_dist_params <- function(x, distribution) {
  m <- mean(x)
  v <- stats::var(x)
  s <- stats::sd(x)

  switch(distribution,
    exgaussian = {
      # no closed-form method of moments that stays in bounds; bmm's heuristic
      # gives tau about a third of the spread and lets the EM take it from there
      tau <- max(s / 3, 0.01)
      sigma <- max(sqrt(max(v - tau^2, 0.0001)), 0.01)
      mu <- max(m - tau, 0.01)
      c(mu = mu, sigma = sigma, tau = tau)
    },
    lognormal = {
      sigma2 <- log(1 + v / m^2)
      sigma <- sqrt(max(sigma2, 0.01))
      mu <- log(m) - sigma2 / 2
      c(mu = mu, sigma = sigma)
    },
    invgaussian = {
      mu <- max(m, 0.01)
      lambda <- max(mu^3 / v, 0.01)
      c(mu = mu, lambda = lambda)
    }
  )
}

# Optimiser bounds for the one distribution without a closed-form M-step. The
# lognormal and inverse Gaussian entries exist so that tests can check the
# closed forms against a general optimiser on the same objective.
.param_bounds <- function(distribution) {
  switch(distribution,
    exgaussian = list(lower = c(-Inf, 1e-6, 1e-6), upper = c(Inf, Inf, Inf)),
    lognormal = list(lower = c(-Inf, 1e-6), upper = c(Inf, Inf)),
    invgaussian = list(lower = c(1e-6, 1e-6), upper = c(Inf, Inf))
  )
}
