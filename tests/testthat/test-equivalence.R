# Equivalence tests against the reference implementations.
#
# rtprep implements every screening rule itself, so that the package carries no
# runtime dependency on either trimr or bmm. That independence is the point, but
# it also means nothing catches a silent divergence from the published
# algorithms. These tests are the insurance.
#
# Two claims rest on them:
#   1. The recursive / moving-criterion rules follow van Selst & Jolicoeur
#      (1994). The criterion table is fiddly and easy to get subtly wrong.
#   2. The mixture EM matches bmm's, which matters because the DDM tutorial
#      recommends bmm's defaults on the strength of results computed here.
#
# The trimr comparisons run in two layers, because a test that skips is green
# without being insurance:
#
#   * against `fixtures/trimr-reference.rds`, trimr 1.1.1's own answers for a
#     fixed data set, frozen once and checked in. This layer runs everywhere and
#     is what catches a regression in rtprep.
#   * against trimr itself, wherever it is installed. This layer catches the
#     snapshot going stale against a new trimr release.
#
# Two documented divergences make the fixture deliberately tie-free:
#   - rtprep's bounds are inclusive, trimr's are strict, so the two can disagree
#     on an RT sitting exactly on a cutoff;
#   - rtprep's modified-recursive rule removes the extreme trial by position,
#     trimr's mean path removes it by value and so would drop every tied copy.
# With continuous RTs neither case arises.

reference <- readRDS(test_path("fixtures", "trimr-reference.rds"))

# Upper-tail exclusions only: trimr's sdTrim() trims the slow side and leaves
# the fast side to its separate minRT argument.
rtprep_sd_kept <- function(d, n_sd) {
  scr <- rt_screen(d$rt, rule = rule_sd(n_sd), .by = d$participant)
  sort(d$rt[!(!scr$.keep & scr$.reason == "too_slow")])
}

rtprep_recursive_mean <- function(d, type) {
  scr <- rt_screen(d$rt, rule = rule_recursive(type), .by = d$participant)
  as.numeric(tapply(d$rt[scr$.keep], d$participant[scr$.keep], mean))
}

# --- against the frozen reference (always runs) -----------------------------

test_that("the criterion table matches the one trimr ships", {
  expect_equal(rtprep:::.vsj_table$moving, reference$vsj_table$moving)
  expect_equal(rtprep:::.vsj_table$modified, reference$vsj_table$modified)
  expect_equal(rtprep:::.vsj_criterion(10, "moving"), 2.17)
  expect_equal(rtprep:::.vsj_criterion(10, "modified"), 4.11)
  expect_equal(rtprep:::.vsj_criterion(150, "moving"), 2.50)
  expect_true(is.na(rtprep:::.vsj_criterion(3, "moving")))
})

test_that("SD trimming reproduces trimr's frozen answers", {
  for (n_sd in names(reference$sd_kept)) {
    expect_equal(
      rtprep_sd_kept(reference$data, as.numeric(n_sd)),
      reference$sd_kept[[n_sd]],
      info = paste("n_sd =", n_sd)
    )
  }
})

test_that("the recursive rules reproduce trimr's frozen answers", {
  expect_equal(rtprep_recursive_mean(reference$data, "moving"),
    reference$moving_mean,
    info = "moving"
  )
  expect_equal(rtprep_recursive_mean(reference$data, "modified"),
    reference$modified_mean,
    info = "modified"
  )
  # van Selst & Jolicoeur's hybrid is the mean of the two condition means, which
  # no single per-trial keep vector can reproduce: the two means have different
  # denominators. rule_recursive("hybrid") gives the per-trial analogue; the
  # published statistic is recovered by averaging the two rules' summaries, as
  # ?rule_recursive documents and as this test does.
  moving <- rtprep_recursive_mean(reference$data, "moving")
  modified <- rtprep_recursive_mean(reference$data, "modified")
  expect_equal((moving + modified) / 2, reference$hybrid_mean)
})

# --- against trimr itself (runs wherever trimr is installed) ----------------

test_that("the frozen reference still matches the installed trimr", {
  skip_if_not_installed("trimr")
  d <- reference$data

  for (n_sd in names(reference$sd_kept)) {
    kept <- trimr::sdTrim(
      d,
      minRT = 0, sd = as.numeric(n_sd), perCondition = FALSE,
      perParticipant = TRUE, omitErrors = FALSE, returnType = "raw"
    )
    expect_equal(sort(kept$rt), reference$sd_kept[[n_sd]])
  }

  expect_equal(
    as.numeric(trimr::nonRecursive(
      d,
      minRT = 0, omitErrors = FALSE, returnType = "mean", digits = 10
    )$A),
    reference$moving_mean
  )
  expect_equal(
    as.numeric(trimr::modifiedRecursive(
      d,
      minRT = 0, omitErrors = FALSE, returnType = "mean", digits = 10
    )$A),
    reference$modified_mean
  )
  expect_equal(
    as.numeric(trimr::hybridRecursive(
      d,
      minRT = 0, omitErrors = FALSE, digits = 10
    )$A),
    reference$hybrid_mean
  )
})

# --- against bmm ------------------------------------------------------------

# The claim these carry: the companion DDM tutorial recommends bmm's defaults on
# the strength of results computed by rtprep's EM, and that citation is only
# honest while the two agree.
#
# rtprep's .prob is P(valid); bmm's flag_contaminant_rts() returns
# P(contaminant). The mapping is 1 - .prob and is asserted here rather than
# assumed anywhere else.
#
# Every comparison runs over a set of seeds rather than one fixture. A
# single-fixture equivalence test insures nothing: the two implementations use
# different M-steps for two of the three distributions, so they stop at slightly
# different points, and how much that matters varies with the draw.
bmm_seeds <- c(31, 39, 1025, 2019, 3037, 7, 101, 404)

bmm_fixture <- function(seed) {
  set.seed(seed)
  c(
    rtprep:::.rexgauss(400, mu = 0.45, sigma = 0.05, tau = 0.15),
    runif(40, 0.10, 0.20)
  )
}

test_that("mixture EM reaches the same keep decisions as bmm", {
  # The claim that has to hold downstream. rtprep uses the exact weighted
  # maximiser where bmm optimises numerically, so the fitted parameters differ
  # by the optimiser's own tolerance. Decisions may then differ only for trials
  # whose posterior sits essentially on the 0.5 cut, where the decision is
  # arbitrary under either implementation.
  skip_if_not_installed("bmm")

  for (seed in bmm_seeds) {
    rt <- bmm_fixture(seed)
    for (dist in c("exgaussian", "lognormal", "invgaussian")) {
      theirs <- suppressWarnings(
        as.numeric(
          bmm::flag_contaminant_rts(rt, distribution = dist, maxit = 500)
        )
      )
      ours <- suppressWarnings(
        rt_screen(rt, rule = rule_mixture(dist, maxit = 500))
      )
      label <- paste(dist, "seed", seed)

      disagree <- ours$.keep != (theirs < 0.5)
      expect_true(
        all(abs(theirs[disagree] - 0.5) < 0.01),
        info = paste(label, "- decisions differ away from the 0.5 cut")
      )
      expect_lt(max(abs((1 - ours$.prob) - theirs)), 0.02, label = label)
    }
  }
})

test_that("the exact M-steps never fit worse than bmm's numerical ones", {
  # Per M-step, on identical weights and an identical starting point: a
  # closed-form maximiser of the weighted likelihood cannot be beaten by
  # L-BFGS-B on the same objective. If this ever reverses, the closed form is
  # wrong.
  #
  # Note this does NOT extend to the mixture log-likelihood at the stopping
  # iteration, which depends on which run trips `tol` first -- that is what the
  # loose bound in the next test allows for.
  skip_if_not_installed("bmm")

  for (seed in bmm_seeds[1:4]) {
    x <- bmm_fixture(seed)
    set.seed(seed)
    w <- runif(length(x), 1e-8, 1)

    for (dist in c("lognormal", "invgaussian")) {
      init <- rtprep:::.init_dist_params(x, dist)
      nll <- function(par) {
        -sum(w * rtprep:::.rt_density(x, par, dist, log = TRUE))
      }
      closed <- rtprep:::.m_step(x, dist, w, init)
      numeric_par <- bmm:::.fit_dist_params(x, dist, w, init)
      expect_lte(nll(closed), nll(numeric_par) + 1e-8,
        label = paste(dist, "seed", seed)
      )
    }
  }
})

test_that("the fitted mixture matches bmm's diagnostics", {
  skip_if_not_installed("bmm")

  for (seed in bmm_seeds) {
    rt <- bmm_fixture(seed)
    for (dist in c("exgaussian", "lognormal", "invgaussian")) {
      theirs <- attr(
        suppressWarnings(
          bmm::flag_contaminant_rts(rt, distribution = dist, maxit = 500)
        ),
        "diagnostics"
      )
      ours <- attr(
        suppressWarnings(rt_screen(rt, rule = rule_mixture(dist, maxit = 500))),
        "fits"
      )
      label <- paste(dist, "seed", seed)

      expect_equal(ours$converged, theirs$converged, info = label)
      expect_lt(
        abs(ours$contaminant_prop - theirs$contaminant_prop), 0.02,
        label = label
      )
      expect_lt(abs(ours$loglik - theirs$loglik), 0.05, label = label)
      # rtprep counts the trials it fitted, bmm every non-missing trial; with
      # the default buffered bounds nothing falls outside, so they coincide
      in_bounds <- sum(rt >= ours$bound_lower & rt <= ours$bound_upper)
      expect_equal(ours$n_fitted, in_bounds, info = label)
      expect_equal(theirs$n_trials, length(rt), info = label)
    }
  }
})

test_that("n_fitted counts in-bounds trials, unlike bmm's n_trials", {
  # the two only coincide because the default bounds are buffered past the data
  skip_if_not_installed("bmm")
  rt <- bmm_fixture(31)

  ours <- attr(
    suppressWarnings(
      rt_screen(rt, rule = rule_mixture("lognormal", bound = c(0.3, 1.0)))
    ),
    "fits"
  )
  expect_lt(ours$n_fitted, length(rt))
  expect_equal(ours$n_fitted, sum(rt >= 0.3 & rt <= 1.0))
})

test_that("the resolved contaminant bounds match bmm's", {
  skip_if_not_installed("bmm")

  for (seed in bmm_seeds) {
    rt <- bmm_fixture(seed)
    expect_equal(
      rtprep:::.resolve_bounds(c("min", "max"), rt)$bound,
      unname(bmm:::.resolve_contaminant_bounds(c("min", "max"), rt)),
      info = paste("seed", seed)
    )
    expect_equal(
      rtprep:::.resolve_bounds(c(0.05, 3), rt)$bound,
      unname(suppressWarnings(
        bmm:::.resolve_contaminant_bounds(c(0.05, 3), rt)
      )),
      info = paste("seed", seed)
    )
  }
})

test_that("the EM iterates almost identically to bmm's for the ex-Gaussian", {
  # the one arm where both use the same numerical M-step, so any divergence is
  # in the loop itself: the pre-M-step convergence check, the warm start, or the
  # clipping. rtprep clamps optim()'s box-projection rounding where bmm does
  # not, which is the only remaining source of difference.
  skip_if_not_installed("bmm")

  for (seed in bmm_seeds) {
    rt <- bmm_fixture(seed)
    bound <- rtprep:::.resolve_bounds(c("min", "max"), rt)$bound

    ours <- rtprep:::.fit_rt_mixture(
      rt, "exgaussian", bound,
      init = 0.05, max_prop = 0.5, maxit = 500, tol = 1e-6
    )
    theirs <- bmm:::.fit_rt_mixture(
      rt, "exgaussian", bound, 0.05, 0.5, 500, 1e-6
    )
    label <- paste("seed", seed)

    expect_equal(ours$converged, theirs$converged, info = label)
    expect_lt(
      abs(ours$contaminant_prop - theirs$contaminant_prop), 1e-3,
      label = label
    )
    expect_lt(abs(ours$loglik - theirs$loglik), 0.05, label = label)

    # Compare the fitted distribution rather than the raw parameters. Once tau
    # is at its lower bound the two are separated by optim()'s box-projection
    # rounding, which is a relative difference of order 1 on a parameter of
    # order 1e-6 and means nothing. The moments are what propagate downstream
    # into rt_summary(method = "mixture"), so they are what has to agree.
    ours_m <- rtprep:::.dist_moments(ours$par, "exgaussian")
    theirs_m <- rtprep:::.dist_moments(theirs$params, "exgaussian")
    expect_lt(abs(ours_m$mean - theirs_m$mean), 1e-3, label = label)
    expect_lt(abs(ours_m$var - theirs_m$var), 1e-3, label = label)
  }
})

test_that("EZ summary statistics match bmm::ezdm_summary_stats()", {
  skip_if_not_installed("bmm")

  for (seed in bmm_seeds[1:4]) {
    rt <- bmm_fixture(seed)
    set.seed(seed)
    correct <- rbinom(length(rt), 1, 0.8)

    grid <- expand.grid(
      method = c("simple", "robust", "mixture"),
      version = c("3par", "4par"),
      distribution = c("exgaussian", "lognormal", "invgaussian"),
      stringsAsFactors = FALSE
    )
    for (row in seq_len(nrow(grid))) {
      method <- grid$method[row]
      version <- grid$version[row]
      distribution <- grid$distribution[row]
      local({
        label <- paste(method, version, distribution, "seed", seed)
        ours <- suppressWarnings(rt_summary(
          rt, correct,
          method = method, version = version,
          distribution = distribution, maxit = 500
        ))
        theirs <- suppressWarnings(bmm::ezdm_summary_stats(
          rt, correct,
          method = method, version = version,
          distribution = distribution, maxit = 500
        ))

        expect_equal(names(ours), names(theirs), info = label)
        expect_equal(ours$n_trials, theirs$n_trials, info = label)
        expect_equal(ours$n_upper, theirs$n_upper, info = label)

        # the mixture arm inherits the M-step difference documented above, so
        # it gets the same tolerance the probabilities do; the other two are
        # exact
        tol <- if (method == "mixture") 5e-3 else 1e-12
        cols <- grep("^(mean|var|contaminant)", names(ours), value = TRUE)
        for (col in cols) {
          if (is.na(ours[[col]]) || is.na(theirs[[col]])) {
            expect_equal(is.na(ours[[col]]), is.na(theirs[[col]]),
              info = paste(label, col)
            )
          } else {
            expect_lt(
              abs(ours[[col]] - theirs[[col]]),
              tol + tol * abs(theirs[[col]]),
              label = paste(label, col)
            )
          }
        }
      })
    }
  }
})

test_that("robust aggregation matches bmm for both scale statistics", {
  skip_if_not_installed("bmm")
  rt <- bmm_fixture(31)
  set.seed(31)
  correct <- rbinom(length(rt), 1, 0.8)

  for (scale in c("iqr", "mad")) {
    ours <- rt_summary(rt, correct, method = "robust", robust_scale = scale)
    theirs <- bmm::ezdm_summary_stats(
      rt, correct,
      method = "robust", robust_scale = scale
    )
    expect_equal(ours$mean_rt, theirs$mean_rt, info = scale)
    expect_equal(ours$var_rt, theirs$var_rt, info = scale)
  }
})

test_that("adjust_accuracy() matches bmm::adjust_ezdm_accuracy()", {
  # both draw binomials, so the comparison is between distributions rather than
  # between single calls
  skip_if_not_installed("bmm")

  draw <- function(f, n) {
    vapply(seq_len(n), function(i) {
      as.numeric(f(80, 100, 0.15, 0.5)[1, ])
    }, numeric(2))
  }

  set.seed(71)
  ours <- draw(adjust_accuracy, 3000)
  set.seed(71)
  theirs <- draw(bmm::adjust_ezdm_accuracy, 3000)

  # same RNG stream, same two rbinom() calls in the same order
  expect_equal(ours, theirs)
})

test_that("adjust_accuracy() leaves counts alone exactly as bmm does", {
  skip_if_not_installed("bmm")
  for (prop in list(NA, 0, -0.1)) {
    expect_equal(
      as.numeric(adjust_accuracy(80, 100, prop)[1, ]),
      as.numeric(bmm::adjust_ezdm_accuracy(80, 100, prop)[1, ]),
      info = paste("contaminant_prop =", prop)
    )
  }
})
