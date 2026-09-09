# Code of the ground-truth article (vignettes/articles/ground-truth.Rmd).
#
# The article reads this file with knitr::read_chunk() and runs the chunks
# below by label, so the prose and the code that produces its numbers stay in
# separate files. Sourcing the file end to end reproduces the whole example,
# and every quantity it prints is computed here from data generated here.

## ---- gt-pilot ----
# Three numbers a pilot data set gives directly: the mean correct response
# time, the proportion correct, and the coefficient of variation of correct
# response times. A moderate task is used here.
pilot <- list(mean_rt = 1.00, accuracy = 0.80, cv = 0.35)

## ---- gt-match ----
# Invert the observables into diffusion parameters. At a very large trial
# count ez_ddm() is the exact inversion the generator's own matching uses.
matched <- ez_ddm(
  mean_rt = pilot$mean_rt,
  var_rt = (pilot$cv * pilot$mean_rt)^2,
  accuracy = pilot$accuracy,
  n_trials = 1e6
)
matched

# A non-decision time outside 0.206 to 0.942 s would mean the target lies
# outside the region a diffusion process reaches with published parameters.
matched_par <- list(
  drift = matched$drift, bound = matched$bound, ndt = matched$ndt
)

## ---- gt-check-match ----
set.seed(2026095)
clean_check <- r_contaminated(10000, par = matched_par, rate = 0)
correct_rt <- clean_check$rt[clean_check$response == 1]
c(
  mean_rt = mean(correct_rt),
  accuracy = mean(clean_check$response),
  cv = sd(correct_rt) / mean(correct_rt)
)

## ---- gt-design ----
n_participants <- 20
n_trials <- 200

# Contamination the design plausibly produces. An unsupervised online session
# without speed pressure invites disengagement and late starts more than
# anticipations: weights for leading-edge, delay, and informationless.
process_mix <- c(0.2, 0.4, 0.4)

# Participants differ in how much they contaminate (a Beta distribution with
# mean .05 and precision 10) and in ability (a lognormal factor on drift with
# SD 0.2 on the log scale). Both are carried as truth.
set.seed(2026095)
traits <- data.frame(
  id = sprintf("p%02d", seq_len(n_participants)),
  rate = rbeta(n_participants, 0.05 * 10, 0.95 * 10),
  ability = exp(rnorm(n_participants, 0, 0.2))
)
traits$true_drift <- matched$drift * traits$ability
summary(traits$rate)

## ---- gt-generate ----
simulated <- bind_rows(lapply(seq_len(n_participants), function(i) {
  trials <- r_contaminated(
    n_trials,
    par = list(
      drift = traits$true_drift[i], bound = matched$bound, ndt = matched$ndt
    ),
    process = "mixed", mix = process_mix, rate = traits$rate[i]
  )
  data.frame(id = traits$id[i], trial = seq_len(n_trials), trials)
}))
table(simulated$process)

## ---- gt-compare ----
roster <- list(
  cutoff = rule_cutoff(0.18, 3),
  sd = rule_sd(2.5),
  mad = rule_mad(2.5),
  recursive = rule_recursive("modified"),
  mixture = rule_mixture("lognormal"),
  ewma = rule_ewma()
)

comparison <- screen_compare(
  simulated$rt, roster, response = simulated$response, .by = simulated$id
)
comparison

## ---- gt-agreement ----
comparison$agreement

## ---- gt-score ----
# Every rule against the carried truth, overall and by contaminant process.
score_rule <- function(keep) {
  by_process <- tapply(!keep, simulated$process, mean)
  data.frame(
    dropped = mean(!keep),
    sensitivity = mean(!keep[simulated$contaminant]),
    specificity = mean(keep[!simulated$contaminant]),
    anticipations = by_process[["leading_edge"]],
    delays = by_process[["delay"]],
    informationless = by_process[["informationless"]]
  )
}

scored <- bind_rows(
  lapply(names(roster), function(name) score_rule(comparison$keep[, name])),
  .id = "rule"
) |>
  mutate(rule = names(roster))
scored

## ---- gt-guessing ----
# The guessing check applies only to trials a rule removed from below. The
# modified recursive criterion removes none, so it has nothing to test; the
# EWMA chart does, and the check is pooled across participants because the
# per-participant counts are small: summary(per_participant$n_tested) below
# shows how small.
recursive_keep <- comparison$keep[, "recursive"]
ewma_keep <- comparison$keep[, "ewma"]

check_guessing(recursive_keep, simulated$rt, simulated$response) |>
  select(n_tested, prop_upper, bf_01, bf_evidence)

per_participant <- simulated |>
  mutate(keep = ewma_keep) |>
  reframe(check_guessing(keep, rt, response), .by = id)
summary(per_participant$n_tested)

check_guessing(ewma_keep, simulated$rt, simulated$response) |>
  select(n_tested, prop_upper, bf_01, bf_evidence)

## ---- gt-leading-edge ----
# The leading-edge shift statistic: cut at the empirical 5th percentile and
# measure how far the surviving minimum moved toward the original 10th
# percentile. Near 1, the removed mass was displaced (anticipations); near 0,
# a genuine edge was cut. Returned to compare across participants or against
# a clean reference; it defines no cutpoint.
leading_edge_shift <- function(rt) {
  q05 <- quantile(rt, 0.05)
  q10 <- quantile(rt, 0.10)
  kept <- rt[rt > q05]
  (min(kept) - min(rt)) / (q10 - min(rt))
}

shift_by_participant <- tapply(simulated$rt, simulated$id, leading_edge_shift)
mean(shift_by_participant)

## ---- gt-estimate ----
# Drift per participant under three pipelines, against the drift each
# participant was generated with: nothing removed, the chosen rule, and the
# perfect-exclusion oracle that only generated data allows.
estimate_drift <- function(keep, label) {
  simulated[keep, ] |>
    reframe(rt_summary(rt, response), .by = id) |>
    mutate(ez_ddm(mean_rt, var_rt, n_upper / n_trials, n_trials)) |>
    left_join(traits, by = "id") |>
    transmute(pipeline = label, id, rate, true_drift, drift,
              error = drift - true_drift)
}

estimates <- bind_rows(
  estimate_drift(rep(TRUE, nrow(simulated)), "none"),
  estimate_drift(recursive_keep, "recursive"),
  estimate_drift(!simulated$contaminant, "oracle")
)

estimates |>
  summarise(
    mean_error = mean(error),
    rate_error_r = cor(rate, error),
    validity_r = cor(true_drift, drift),
    .by = pipeline
  )

## ---- gt-figure ----
drift_plot <- estimates |>
  mutate(pipeline = factor(pipeline, levels = c("none", "recursive", "oracle"))) |>
  ggplot(aes(true_drift, drift, colour = rate)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2, colour = "grey60") +
  geom_point(size = 2) +
  scale_colour_viridis_c(option = "C", end = 0.85) +
  facet_wrap(~pipeline) +
  labs(x = "True drift", y = "Estimated drift", colour = "Contamination rate")
