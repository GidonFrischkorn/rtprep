#' Test whether the fast trials a rule removed were really guesses
#'
#' @description
#' A screening rule tells you which trials it removed. It does not tell you
#' whether it was right. This is one check that it was: if the fast trials a
#' rule excluded really were guesses, their accuracy should be at chance.
#'
#' A Beta-Binomial test with a Savage–Dickey Bayes factor, ported from
#' `bmm::validate_fast_guesses()`.
#'
#' @param keep Logical vector of keep decisions, typically the `.keep` column of
#'   [rt_screen()]. Note this is the *keep* flag, not a contaminant flag —
#'   `rtprep`'s convention throughout — so a screen's output drops straight in.
#' @param rt Numeric vector of response times, in seconds.
#' @param response Response coding of the same length, in any form
#'   [rt_screen()] accepts.
#' @param threshold_type Whether `rt_threshold` is a quantile of the response
#'   time distribution or an absolute value in seconds.
#' @param rt_threshold The cut defining "fast": a quantile in `(0, 1)`, or a
#'   positive number of seconds.
#' @param chance Accuracy expected from a guess, known from the design.
#' @param prior_alpha,prior_beta Beta prior on the proportion correct. The
#'   default `1, 1` is uniform.
#' @param credible_mass Mass of the highest-density interval.
#'
#' @return A one-row `data.frame` — a row rather than `bmm`'s list, because in
#'   practice this goes into a results table:
#'
#'   \describe{
#'     \item{`prop_upper`}{observed proportion correct among the tested trials.}
#'     \item{`hdi_lower`, `hdi_upper`}{highest-density interval on that
#'       proportion.}
#'     \item{`bf_01`}{Savage–Dickey Bayes factor for guessing against not.}
#'     \item{`guess_in_hdi`}{whether `chance` falls inside the interval.}
#'     \item{`bf_evidence`}{the Bayes factor on Jeffreys' scale.}
#'     \item{`posterior_alpha`, `posterior_beta`, `n_tested`, `rt_threshold`,
#'       `threshold_type`, `credible_mass`, `mean_rt_tested`}{the inputs and
#'       intermediates, so a results table is self-describing.}
#'   }
#'
#' @details
#' The test looks only at trials that were **both excluded and fast**. Slow
#' exclusions are a different claim — a slow contaminant is an attention lapse,
#' not a guess, and there is no reason to expect chance accuracy from one.
#'
#' This is the diagnostic counterpart of `rule_mixture(use_accuracy = TRUE)`:
#' one checks accuracy after flagging, the other uses it during. Given what the
#' package's own tests found about the latter — that it collapses on overlapping
#' contamination and actively hurts when contaminants keep their accuracy — this
#' is currently the safer of the two instruments.
#'
#' When no trial is both excluded and fast, the row comes back with
#' `n_tested = 0` and `NA` statistics rather than an error. In a simulation that
#' cell is common, and informative: it means the rule removed nothing fast.
#'
#' @references
#' Jeffreys, H. (1961). *Theory of Probability* (3rd ed.). Oxford University
#' Press.
#'
#' @seealso [rt_screen()] for the `keep` vector, [rule_ewma()] for a rule that
#'   uses accuracy to screen rather than to check.
#'
#' @examples
#' set.seed(3)
#' rt <- c(runif(20, 0.15, 0.30), rgamma(80, 5, 10) + 0.2)
#' response <- c(rbinom(20, 1, 0.5), rbinom(80, 1, 0.85))
#' scr <- rt_screen(rt, rule = rule_cutoff(0.35, 3))
#'
#' check_guessing(scr$.keep, rt, response)
#'
#' @export
check_guessing <- function(keep, rt, response,
                           threshold_type = c("quantile", "absolute"),
                           rt_threshold = 0.25, chance = 0.5,
                           prior_alpha = 1, prior_beta = 1,
                           credible_mass = 0.95) {
  threshold_type <- match.arg(threshold_type)
  .stopif(
    !is.logical(keep) || length(keep) == 0L,
    "'keep' must be a non-empty logical vector."
  )
  .stopif(
    length(rt) != length(keep) || length(response) != length(keep),
    "'rt' and 'response' must have the same length as 'keep'."
  )
  .check_scalar(prior_alpha, "prior_alpha", lower = 0, incl_lower = FALSE)
  .check_scalar(prior_beta, "prior_beta", lower = 0, incl_lower = FALSE)
  .check_scalar(chance, "chance",
    lower = 0, upper = 1,
    incl_lower = FALSE, incl_upper = FALSE
  )
  .check_scalar(credible_mass, "credible_mass",
    lower = 0, upper = 1,
    incl_lower = FALSE, incl_upper = FALSE
  )
  if (threshold_type == "quantile") {
    .check_scalar(rt_threshold, "rt_threshold",
      lower = 0, upper = 1,
      incl_lower = FALSE, incl_upper = FALSE
    )
    cut <- as.numeric(stats::quantile(rt, rt_threshold, na.rm = TRUE))
  } else {
    .check_scalar(rt_threshold, "rt_threshold", lower = 0, incl_lower = FALSE)
    cut <- rt_threshold
  }

  # only trials that were both excluded and fast: a slow exclusion is an
  # attention lapse, and there is no reason to expect chance accuracy from one
  tested <- !is.na(keep) & !keep & !is.na(rt) & rt < cut
  n_tested <- sum(tested)

  empty <- data.frame(
    prop_upper = NA_real_, hdi_lower = NA_real_, hdi_upper = NA_real_,
    bf_01 = NA_real_, guess_in_hdi = NA, bf_evidence = NA_character_,
    posterior_alpha = NA_real_, posterior_beta = NA_real_,
    n_tested = 0L, rt_threshold = cut, threshold_type = threshold_type,
    credible_mass = credible_mass, mean_rt_tested = NA_real_,
    stringsAsFactors = FALSE
  )
  if (n_tested == 0L) {
    return(empty)
  }

  is_upper <- .as_upper(response)
  n_upper <- sum(is_upper[tested], na.rm = TRUE)
  posterior_alpha <- prior_alpha + n_upper
  posterior_beta <- prior_beta + (n_tested - n_upper)

  hdi <- .beta_hdi(posterior_alpha, posterior_beta, credible_mass)
  bf_01 <- stats::dbeta(chance, posterior_alpha, posterior_beta) /
    stats::dbeta(chance, prior_alpha, prior_beta)

  data.frame(
    prop_upper = n_upper / n_tested,
    hdi_lower = hdi$lower, hdi_upper = hdi$upper,
    bf_01 = bf_01,
    guess_in_hdi = chance >= hdi$lower && chance <= hdi$upper,
    bf_evidence = .categorise_bf(bf_01),
    posterior_alpha = posterior_alpha, posterior_beta = posterior_beta,
    n_tested = as.integer(n_tested),
    rt_threshold = cut, threshold_type = threshold_type,
    credible_mass = credible_mass,
    mean_rt_tested = mean(rt[tested]),
    stringsAsFactors = FALSE
  )
}

# Jeffreys (1961), as bmm labels it.
.categorise_bf <- function(bf_01) {
  if (bf_01 > 10) {
    "strong_for_guessing"
  } else if (bf_01 > 3) {
    "moderate_for_guessing"
  } else if (bf_01 > 1) {
    "anecdotal_for_guessing"
  } else if (bf_01 > 1 / 3) {
    "anecdotal_against_guessing"
  } else if (bf_01 > 1 / 10) {
    "moderate_against_guessing"
  } else {
    "strong_against_guessing"
  }
}

# Narrowest interval of the given mass, found on a grid.
#
# Falls back to the equal-tailed interval for very concentrated or U-shaped
# posteriors, where the grid search is either pointless or wrong: a U-shaped
# density's highest-density region is two disjoint intervals, and reporting the
# narrowest single one would be a misstatement rather than an approximation.
# Ported from bmm, thresholds included.
.beta_hdi <- function(alpha, beta, credible_mass = 0.95) {
  if (alpha > 1000 || beta > 1000 || (alpha < 1 && beta < 1)) {
    tail_prob <- (1 - credible_mass) / 2
    return(list(
      lower = stats::qbeta(tail_prob, alpha, beta),
      upper = stats::qbeta(1 - tail_prob, alpha, beta)
    ))
  }

  lower_percentiles <- seq(0, 1 - credible_mass, length.out = 1000)
  lowers <- stats::qbeta(lower_percentiles, alpha, beta)
  uppers <- stats::qbeta(lower_percentiles + credible_mass, alpha, beta)
  best <- which.min(uppers - lowers)
  list(lower = lowers[best], upper = uppers[best])
}
