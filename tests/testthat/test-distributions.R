# Densities and samplers are implemented from first principles so that the
# package carries no runtime dependency. These tests are what stands between
# that independence and a quietly wrong likelihood.

# --- densities integrate to one ---------------------------------------------

test_that(".dexgauss() is a density", {
  total <- integrate(
    function(x) rtprep:::.dexgauss(x, mu = 0.4, sigma = 0.05, tau = 0.15),
    lower = -1, upper = 10
  )
  expect_equal(total$value, 1, tolerance = 1e-5)
})

test_that(".dinvgauss() is a density", {
  total <- integrate(
    function(x) rtprep:::.dinvgauss(x, mu = 0.5, lambda = 3),
    lower = 0, upper = 50
  )
  expect_equal(total$value, 1, tolerance = 1e-5)
})

test_that(".dexgauss() matches a numerical convolution", {
  # the ex-Gaussian is a normal plus an independent exponential, so the density
  # is the convolution integral; computing it the slow way is an independent
  # check on the closed form
  mu <- 0.4
  sigma <- 0.05
  tau <- 0.15
  slow <- function(x) {
    integrate(
      function(e) dnorm(x - e, mu, sigma) * dexp(e, rate = 1 / tau),
      lower = 0, upper = Inf
    )$value
  }
  grid <- c(0.30, 0.35, 0.40, 0.50, 0.70, 1.00)
  expect_equal(
    rtprep:::.dexgauss(grid, mu, sigma, tau),
    vapply(grid, slow, numeric(1)),
    tolerance = 1e-6
  )
})

test_that("the log scale agrees with the natural scale", {
  grid <- c(0.2, 0.4, 0.8, 1.6)
  expect_equal(
    rtprep:::.dexgauss(grid, 0.4, 0.05, 0.15, log = TRUE),
    log(rtprep:::.dexgauss(grid, 0.4, 0.05, 0.15))
  )
  expect_equal(
    rtprep:::.dinvgauss(grid, 0.5, 3, log = TRUE),
    log(rtprep:::.dinvgauss(grid, 0.5, 3))
  )
})

test_that("the log scale stays finite far into the tail", {
  # the whole reason for computing through pnorm(log.p = TRUE)
  far <- 1e-8
  log_dens <- rtprep:::.dexgauss(far, 0.4, 0.01, 0.15, log = TRUE)

  expect_true(is.finite(log_dens))
  expect_equal(rtprep:::.dexgauss(far, 0.4, 0.01, 0.15), 0) # natural scale gone
  # log f(x) = -log(tau) + sigma^2/(2 tau^2) - (x - mu)/tau + log Phi(z)
  z <- (far - 0.4) / 0.01 - 0.01 / 0.15
  expect_equal(
    log_dens,
    -log(0.15) + 0.01^2 / (2 * 0.15^2) - (far - 0.4) / 0.15 +
      pnorm(z, log.p = TRUE)
  )
})

test_that("densities refuse non-positive parameters", {
  grid <- c(0.3, 0.5)
  expect_equal(rtprep:::.dexgauss(grid, 0.4, 0, 0.15), c(0, 0))
  expect_equal(rtprep:::.dexgauss(grid, 0.4, 0.05, -1), c(0, 0))
  expect_equal(
    rtprep:::.dexgauss(grid, 0.4, 0, 0.15, log = TRUE), c(-Inf, -Inf)
  )
  expect_equal(rtprep:::.dinvgauss(grid, 0, 3), c(0, 0))
  expect_equal(rtprep:::.dinvgauss(grid, 0.5, 0), c(0, 0))
})

test_that(".dinvgauss() has no mass at or below zero", {
  expect_equal(rtprep:::.dinvgauss(c(-1, 0), 0.5, 3), c(0, 0))
  expect_equal(rtprep:::.dinvgauss(0, 0.5, 3, log = TRUE), -Inf)
})

# --- samplers ---------------------------------------------------------------

test_that(".rexgauss() draws from the distribution it claims", {
  set.seed(1)
  mu <- 0.4
  sigma <- 0.05
  tau <- 0.15
  x <- rtprep:::.rexgauss(2e4, mu, sigma, tau)

  expect_length(x, 2e4)
  expect_equal(mean(x), mu + tau, tolerance = 0.02)
  expect_equal(var(x), sigma^2 + tau^2, tolerance = 0.05)

  cdf <- function(q) {
    vapply(q, function(u) {
      integrate(
        rtprep:::.dexgauss, -1, u,
        mu = mu, sigma = sigma, tau = tau
      )$value
    }, numeric(1))
  }
  expect_gt(suppressWarnings(ks.test(x, cdf)$p.value), 0.01)
})

test_that(".rinvgauss() draws from the distribution it claims", {
  set.seed(2)
  mu <- 0.5
  lambda <- 3
  x <- rtprep:::.rinvgauss(2e4, mu, lambda)

  expect_length(x, 2e4)
  expect_true(all(x > 0))
  expect_equal(mean(x), mu, tolerance = 0.02)
  expect_equal(var(x), mu^3 / lambda, tolerance = 0.1)

  cdf <- function(q) {
    vapply(q, function(u) {
      integrate(rtprep:::.dinvgauss, 0, u, mu = mu, lambda = lambda)$value
    }, numeric(1))
  }
  expect_gt(suppressWarnings(ks.test(x, cdf)$p.value), 0.01)
})

# --- moments and starting values --------------------------------------------

test_that(".dist_moments() matches the sample moments of large draws", {
  set.seed(3)
  exg <- c(mu = 0.4, sigma = 0.05, tau = 0.15)
  m <- rtprep:::.dist_moments(exg, "exgaussian")
  x <- rtprep:::.rexgauss(5e4, exg["mu"], exg["sigma"], exg["tau"])
  expect_equal(as.numeric(m$mean), mean(x), tolerance = 0.02)
  expect_equal(as.numeric(m$var), var(x), tolerance = 0.05)

  ig <- c(mu = 0.5, lambda = 3)
  m <- rtprep:::.dist_moments(ig, "invgaussian")
  x <- rtprep:::.rinvgauss(5e4, ig["mu"], ig["lambda"])
  expect_equal(as.numeric(m$mean), mean(x), tolerance = 0.02)
  expect_equal(as.numeric(m$var), var(x), tolerance = 0.08)

  ln <- c(mu = -1, sigma = 0.3)
  m <- rtprep:::.dist_moments(ln, "lognormal")
  x <- rlnorm(5e4, ln["mu"], ln["sigma"])
  expect_equal(as.numeric(m$mean), mean(x), tolerance = 0.02)
  expect_equal(as.numeric(m$var), var(x), tolerance = 0.08)
})

test_that(".init_dist_params() returns usable starting values", {
  set.seed(4)
  x <- rtprep:::.rexgauss(500, 0.4, 0.05, 0.15)

  for (d in c("exgaussian", "lognormal", "invgaussian")) {
    par <- rtprep:::.init_dist_params(x, d)
    expect_true(all(is.finite(par)), info = d)
    dens <- rtprep:::.rt_density(x, par, d)
    expect_true(all(is.finite(dens)), info = d)
    expect_true(all(dens >= 0), info = d)
  }
})

# --- against bmm ------------------------------------------------------------

test_that("the densities agree with bmm's", {
  skip_if_not_installed("bmm")
  grid <- c(0.15, 0.3, 0.45, 0.7, 1.2, 3.0)

  expect_equal(
    rtprep:::.dexgauss(grid, 0.4, 0.05, 0.15),
    bmm:::dexgauss(grid, 0.4, 0.05, 0.15)
  )
  expect_equal(
    rtprep:::.dinvgauss(grid, 0.5, 3),
    bmm:::dinvgauss(grid, 0.5, 3)
  )
  expect_equal(
    rtprep:::.dexgauss(grid, 0.4, 0.05, 0.15, log = TRUE),
    bmm:::dexgauss(grid, 0.4, 0.05, 0.15, log = TRUE)
  )
})

test_that("the starting values and moments agree with bmm's", {
  skip_if_not_installed("bmm")
  set.seed(5)
  x <- rtprep:::.rexgauss(300, 0.4, 0.05, 0.15)

  for (d in c("exgaussian", "lognormal", "invgaussian")) {
    expect_equal(
      rtprep:::.init_dist_params(x, d),
      bmm:::.init_dist_params(x, d),
      info = d
    )
    par <- rtprep:::.init_dist_params(x, d)
    expect_equal(
      rtprep:::.dist_moments(par, d),
      bmm:::.dist_moments(par, d),
      info = d
    )
  }
})
