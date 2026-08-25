# The generator layer: first-principles samplers, observable-space matching,
# and the contaminant processes. Tolerances are Monte Carlo tolerances --
# these tests draw data -- so each stochastic test fixes its seed (test code
# is not package code; the no-set.seed rule binds R/, not tests/).
#
# The anchor cell used throughout is the jointly attainable moderate cell from
# the Milestone-0 verification (attainable_observable_region.R):
# MRT 1.0 s, Pc .80, sd(RT) 35% of MRT.

anchor <- list(mean_rt = 1.0, var_rt = 0.35^2, accuracy = 0.80)

obs_of <- function(d) {
  ok <- d$response == 1L
  c(
    mean_rt = mean(d$rt[ok]), var_rt = stats::var(d$rt[ok]),
    accuracy = mean(d$response == 1L)
  )
}

# ---- closed forms -----------------------------------------------------------

test_that("the EZ forward equations invert ez_ddm() exactly", {
  fwd <- rtprep:::.ez_forward(drift = 1.5, bound = 1.2, ndt = 0.30)
  back <- ez_ddm(
    fwd[["mean_rt"]], fwd[["var_rt"]], fwd[["accuracy"]],
    n_trials = 1e6
  )
  expect_equal(back$drift, 1.5, tolerance = 1e-6)
  expect_equal(back$bound, 1.2, tolerance = 1e-6)
  expect_equal(back$ndt, 0.30, tolerance = 1e-6)
})

test_that("the race decision-time moments integrate to what .r_rdm draws", {
  set.seed(101)
  mom <- rtprep:::.race_dt_moments(v_correct = 2, v_error = 1, bound = 1.5)
  d <- rtprep:::.r_rdm(
    4e4,
    drift = c(2, 1), bound = 1.5, ndt = 0
  )
  ok <- d$response == 1L
  expect_equal(mean(ok), mom[["accuracy"]], tolerance = 0.01)
  expect_equal(mean(d$rt[ok]), mom[["mean_dt"]], tolerance = 0.01)
  expect_equal(stats::sd(d$rt[ok]), mom[["sd_dt"]], tolerance = 0.02)
})

# ---- samplers ---------------------------------------------------------------

test_that(".r_ddm reproduces the closed-form EZ observables", {
  set.seed(102)
  d <- rtprep:::.r_ddm(
    2e4,
    drift = 1.5, bound = 1.2, ndt = 0.30, dt = 5e-4
  )
  fwd <- rtprep:::.ez_forward(drift = 1.5, bound = 1.2, ndt = 0.30)
  got <- obs_of(d)
  expect_equal(got[["accuracy"]], fwd[["accuracy"]], tolerance = 0.02)
  expect_equal(got[["mean_rt"]], fwd[["mean_rt"]], tolerance = 0.02)
  expect_equal(got[["var_rt"]], fwd[["var_rt"]], tolerance = 0.15)
})

test_that(".r_ddm agrees with rtdists", {
  skip_if_not_installed("rtdists")
  set.seed(103)
  d <- rtprep:::.r_ddm(
    2e4,
    drift = 1.5, bound = 1.2, ndt = 0.30, dt = 5e-4
  )
  r <- rtdists::rdiffusion(2e4, a = 1.2, v = 1.5, t0 = 0.30, z = 0.6)
  ours <- d$rt[d$response == 1L]
  theirs <- r$rt[r$response == "upper"]
  expect_equal(mean(d$response), mean(r$response == "upper"), tolerance = 0.02)
  expect_equal(
    stats::quantile(ours, c(.1, .5, .9)),
    stats::quantile(theirs, c(.1, .5, .9)),
    tolerance = 0.03, ignore_attr = TRUE
  )
})

test_that("st0 smears the leading edge without moving the mean", {
  set.seed(104)
  smooth <- rtprep:::.r_ddm(2e4, drift = 1.5, bound = 1.2, ndt = 0.30)
  smeared <- rtprep:::.r_ddm(
    2e4,
    drift = 1.5, bound = 1.2, ndt = 0.30, st0 = 0.20
  )
  # the smear is centred on ndt, so the mean stays put and the spread grows
  expect_equal(mean(smeared$rt), mean(smooth$rt), tolerance = 0.02)
  expect_gt(stats::var(smeared$rt), stats::var(smooth$rt))
  # support: decision time is positive, so no RT below ndt - st0/2
  expect_gte(min(smeared$rt), 0.30 - 0.10)
  expect_lt(min(smeared$rt), min(smooth$rt))
})

# ---- observable-space matching ---------------------------------------------

test_that("matching hits the target observables for the ddm", {
  m <- rtprep:::.match_observables(
    anchor$mean_rt, anchor$var_rt, anchor$accuracy,
    generator = "ddm"
  )
  fwd <- rtprep:::.ez_forward(
    m$par$drift, m$par$bound, m$par$ndt
  )
  expect_equal(fwd[["mean_rt"]], anchor$mean_rt, tolerance = 1e-6)
  expect_equal(fwd[["var_rt"]], anchor$var_rt, tolerance = 1e-6)
  expect_equal(fwd[["accuracy"]], anchor$accuracy, tolerance = 1e-6)
  # the plausibility constraint held
  expect_gte(m$par$ndt, 0.206)
  expect_lte(m$par$ndt, 0.942)

  set.seed(105)
  d <- rtprep:::.r_ddm(
    2e4, m$par$drift, m$par$bound, m$par$ndt,
    dt = 5e-4
  )
  got <- obs_of(d)
  expect_equal(got[["mean_rt"]], anchor$mean_rt, tolerance = 0.02)
  expect_equal(got[["accuracy"]], anchor$accuracy, tolerance = 0.02)
  expect_equal(got[["var_rt"]], anchor$var_rt, tolerance = 0.15)
})

test_that("matching hits the target observables for the rdm", {
  m <- rtprep:::.match_observables(
    anchor$mean_rt, anchor$var_rt, anchor$accuracy,
    generator = "rdm"
  )
  expect_gte(m$par$ndt, 0.206)
  expect_lte(m$par$ndt, 0.942)
  expect_equal(m$observables[["accuracy"]], anchor$accuracy, tolerance = 0.005)
  expect_equal(m$observables[["mean_rt"]], anchor$mean_rt, tolerance = 1e-6)
  expect_equal(m$observables[["var_rt"]], anchor$var_rt, tolerance = 1e-6)

  set.seed(106)
  d <- rtprep:::.r_rdm(3e4, m$par$drift, m$par$bound, m$par$ndt)
  got <- obs_of(d)
  expect_equal(got[["mean_rt"]], anchor$mean_rt, tolerance = 0.02)
  expect_equal(got[["accuracy"]], anchor$accuracy, tolerance = 0.02)
  expect_equal(got[["var_rt"]], anchor$var_rt, tolerance = 0.10)
})

test_that("an unattainable target is refused, not silently approximated", {
  # sd(RT) at 50% of a 1 s MRT with Pc .95: the Milestone-0 map shows the race
  # cannot reach this with a plausible non-decision time
  expect_error(
    rtprep:::.match_observables(1.0, 0.5^2, 0.95, generator = "rdm"),
    "attainable"
  )
  # MRT 3 s at sd_frac .15: the DDM would need ndt far beyond the published
  # range
  expect_error(
    rtprep:::.match_observables(3.0, 0.45^2, 0.80, generator = "ddm"),
    "non-decision"
  )
})

test_that("matched generators agree on the EZ statistics, differ at the edge", {
  md <- rtprep:::.match_observables(
    anchor$mean_rt, anchor$var_rt, anchor$accuracy,
    generator = "ddm"
  )
  mr <- rtprep:::.match_observables(
    anchor$mean_rt, anchor$var_rt, anchor$accuracy,
    generator = "rdm"
  )
  set.seed(107)
  dd <- rtprep:::.r_ddm(
    3e4, md$par$drift, md$par$bound, md$par$ndt,
    dt = 5e-4
  )
  dr <- rtprep:::.r_rdm(3e4, mr$par$drift, mr$par$bound, mr$par$ndt)
  od <- obs_of(dd)
  or <- obs_of(dr)
  # agreement on what EZ sees
  expect_equal(od[["mean_rt"]], or[["mean_rt"]], tolerance = 0.03)
  expect_equal(od[["accuracy"]], or[["accuracy"]], tolerance = 0.02)
  expect_equal(od[["var_rt"]], or[["var_rt"]], tolerance = 0.15)
  # disagreement where the shape lives: the leading edge (cf. the handoff's
  # Q15 table -- q05/q10 carry the generator difference at 5-9x the MCSE)
  q_d <- stats::quantile(dd$rt[dd$response == 1L], c(.05, .10))
  q_r <- stats::quantile(dr$rt[dr$response == 1L], c(.05, .10))
  expect_gt(max(abs(q_d - q_r)), 0.025)
})

# ---- the evidence-quality lapse parameterization ----------------------------

test_that("prop = 0 gives chance accuracy with RTs inside the core's range", {
  set.seed(108)
  # ddm: drift -> 0
  lp <- rtprep:::.lapse_pars(
    list(drift = 1.5, bound = 1.2, ndt = 0.30, zr = 0.5),
    generator = "ddm", prop = 0
  )
  d <- rtprep:::.r_ddm(5e3, lp$drift, lp$bound, lp$ndt, dt = 5e-4)
  expect_equal(mean(d$response), 0.5, tolerance = 0.03)

  clean <- rtprep:::.r_ddm(5e3, 1.5, 1.2, 0.30, dt = 5e-4)
  # degraded evidence, intact speed: same order of magnitude, not a runaway
  expect_lt(mean(d$rt), 3 * mean(clean$rt))
  expect_gt(min(d$rt), 0.30)

  # race: drifts pulled to their common mean, total processing rate held
  lr <- rtprep:::.lapse_pars(
    list(drift = c(3, 1.5), bound = 1.5, ndt = 0.30),
    generator = "rdm", prop = 0
  )
  expect_equal(lr$drift[1], lr$drift[2])
  expect_equal(mean(lr$drift), mean(c(3, 1.5)))
  r <- rtprep:::.r_rdm(5e3, lr$drift, lr$bound, lr$ndt)
  expect_equal(mean(r$response), 0.5, tolerance = 0.03)
  rc <- rtprep:::.r_rdm(5e3, c(3, 1.5), 1.5, 0.30)
  expect_lt(mean(r$rt), 3 * mean(rc$rt))
})

test_that("prop = 1 reproduces the clean process", {
  lp <- rtprep:::.lapse_pars(
    list(drift = 1.5, bound = 1.2, ndt = 0.30, zr = 0.5),
    generator = "ddm", prop = 1
  )
  expect_identical(lp$drift, 1.5)
  lr <- rtprep:::.lapse_pars(
    list(drift = c(3, 1.5), bound = 1.5, ndt = 0.30),
    generator = "rdm", prop = 1
  )
  expect_identical(lr$drift, c(3, 1.5))
})

test_that("intermediate prop is ordered in accuracy", {
  set.seed(109)
  pcs <- vapply(c(0, 0.5, 1), function(p) {
    lp <- rtprep:::.lapse_pars(
      list(drift = c(3, 1.5), bound = 1.5, ndt = 0.30),
      generator = "rdm", prop = p
    )
    mean(rtprep:::.r_rdm(1e4, lp$drift, lp$bound, lp$ndt)$response)
  }, numeric(1))
  expect_true(all(diff(pcs) > 0))
})

# ---- r_contaminated() -------------------------------------------------------

test_that("r_contaminated() returns the documented shape and ground truth", {
  set.seed(110)
  d <- r_contaminated(
    500,
    generator = "ddm", process = "delay", rate = 0.10,
    par = list(drift = 1.5, bound = 1.2, ndt = 0.30)
  )
  expect_s3_class(d, "data.frame")
  expect_named(d, c("rt", "response", "contaminant", "process"))
  expect_equal(nrow(d), 500)
  expect_type(d$contaminant, "logical")
  expect_true(all(d$response %in% c(0L, 1L)))
  expect_true(all(d$process[!d$contaminant] == "clean"))
  expect_true(all(d$process[d$contaminant] == "delay"))
  expect_true(all(d$rt > 0))
})

test_that("rate 0 yields no contaminants; rate is validated", {
  set.seed(111)
  d <- r_contaminated(
    200,
    generator = "ddm", process = "delay", rate = 0,
    par = list(drift = 1.5, bound = 1.2, ndt = 0.30)
  )
  expect_false(any(d$contaminant))
  expect_error(
    r_contaminated(10, rate = 1.5, par = list(drift = 1, bound = 1, ndt = .3)),
    "rate"
  )
})

test_that("delayed start-ups shift genuine trials by the stated window", {
  set.seed(112)
  d <- r_contaminated(
    2000,
    generator = "rdm", process = "delay", rate = 0.15,
    par = list(drift = c(3, 1.5), bound = 1.5, ndt = 0.30),
    delay_min = 1, delay_max = 3
  )
  # a delayed trial is a genuine trial plus at least delay_min
  expect_gte(min(d$rt[d$contaminant]), 0.30 + 1)
  # accuracy is intact: delays keep the core's response
  expect_gt(mean(d$response[d$contaminant]), 0.6)
})

test_that("leading-edge anticipations anchor to the observed clean minimum", {
  set.seed(113)
  d <- r_contaminated(
    2000,
    generator = "ddm", process = "leading_edge", rate = 0.15,
    par = list(drift = 1.5, bound = 1.2, ndt = 0.30),
    anticipation_depth = 0.5
  )
  clean_min <- min(d$rt[!d$contaminant])
  ant <- d$rt[d$contaminant]
  # the band straddles the anchor: (1 - depth) to (1 + depth) times the
  # observed clean minimum
  expect_gte(min(ant), 0.5 * clean_min - 1e-9)
  expect_lte(max(ant), 1.5 * clean_min + 1e-9)
  # chance accuracy
  expect_equal(mean(d$response[d$contaminant]), 0.5, tolerance = 0.07)
})

test_that("informationless responses are chance-accurate but not runaway slow", {
  set.seed(114)
  d <- r_contaminated(
    3000,
    generator = "rdm", process = "informationless", rate = 0.3,
    par = list(drift = c(3, 1.5), bound = 1.5, ndt = 0.30),
    lapse_prop = 0
  )
  expect_equal(mean(d$response[d$contaminant]), 0.5, tolerance = 0.04)
  expect_lt(
    mean(d$rt[d$contaminant]),
    3 * mean(d$rt[!d$contaminant])
  )
})

test_that("the mixed process draws all three with the stated weights", {
  set.seed(115)
  d <- r_contaminated(
    4000,
    generator = "ddm", process = "mixed", rate = 0.3,
    par = list(drift = 1.5, bound = 1.2, ndt = 0.30)
  )
  got <- table(d$process[d$contaminant])
  expect_setequal(
    names(got),
    c("leading_edge", "delay", "informationless")
  )
  expect_equal(
    unname(prop.table(got)),
    rep(1 / 3, 3),
    tolerance = 0.10, ignore_attr = TRUE
  )
})
