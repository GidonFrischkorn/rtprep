#' @keywords internal
#'
#' @description
#' Tools for the decisions made about response times before a model is fitted:
#' which trials to keep, how to summarise the ones that survive, and how to
#' check what either choice did.
#'
#' The screening rules come from families that were never built to be compared:
#' absolute cutoffs, criteria based on a centre and a spread, the recursive
#' criteria, a control chart on accuracy, a fitted contaminant mixture. Every
#' published implementation returns something different. Here they all
#' return one row per trial with the same four columns, so swapping one for
#' another is a one-word change and the difference between them can be measured.
#'
#' @section The four layers:
#' \describe{
#'   \item{Screening}{[rt_screen()] applies a rule and returns the keep
#'     decision, the probability behind it, and the reason. [rt_keep()] gives
#'     the decision alone for `filter()`; [screen_fits()] gives the per-group
#'     diagnostics. The rules are in [rules], and [rule_all()] and its
#'     companions combine them.}
#'   \item{Aggregation}{[rt_summary()] turns surviving trials into the mean,
#'     variance and accuracy the EZ-diffusion equations take, by sample moments,
#'     robust moments, trimming, or a fitted mixture. [ez_ddm()] inverts them
#'     into parameters; [adjust_accuracy()] corrects the counts.}
#'   \item{Comparison}{[screen_compare()] applies several rules at once and
#'     reports how much each removed and how far they disagree.
#'     [check_guessing()] asks whether the fast trials a rule removed were
#'     really guesses.}
#'   \item{Ground truth}{[r_contaminated()] generates response times with
#'     contaminants labelled, and [rule_oracle()] removes exactly those, which
#'     is the ceiling every real rule is read against.}
#' }
#'
#' @section Two things that hold everywhere:
#' `.prob` is always the probability that a trial came from the decision
#' process, never the probability that it is a contaminant, and the keep
#' decision is a separate step. A deterministic rule returns 0 and 1; a mixture
#' returns a posterior; both can feed `rt_summary(weights = )` without a
#' threshold being chosen.
#'
#' A rule that cannot be evaluated removes nothing: too few trials, zero spread
#' or a fit that did not converge keeps every trial in the group and records why
#' in [screen_fits()]. [extending] states the contract that follows from.
#'
#' @section Terms:
#' See [rtprep-glossary] for *contaminant*, *drift*, *bound*, *ndt*,
#' *leading edge*, and the difference between screening, trimming and
#' aggregation.
#'
#' @seealso `vignette("rtprep")` for the whole chain on one data set;
#'   [extending] to add a rule of your own.
"_PACKAGE"

#' Terms used in rtprep
#'
#' The vocabulary the rest of the documentation assumes, defined once.
#'
#' @section Response times and what contaminates them:
#' \describe{
#'   \item{Contaminant}{A trial not produced by the decision process the
#'     experiment is about: a response made before the stimulus was read, one
#'     delayed by something outside the task, one made without using the
#'     evidence. The word is used for the *trial*, not for the statistical
#'     criterion that might catch it; "outlier" is kept for the criterion and
#'     for literature that uses it that way. `rtprep` names three processes,
#'     and [r_contaminated()] generates each: **leading-edge anticipations**,
#'     **delayed start-ups**, and **informationless responses**.}
#'   \item{Leading edge}{The fast rising flank of a response time
#'     distribution, the short climb from the fastest response to the mode. It
#'     matters because a right-skewed distribution has almost no mass there, so
#'     a trial that arrives early sits well inside a criterion built around the
#'     mean and is not removed by one.}
#' }
#'
#' @section What the package does to them:
#' \describe{
#'   \item{Screening}{Classifying trials, deciding which came from the
#'     decision process. [rt_screen()] screens.}
#'   \item{Trimming}{Screening that then removes what it flagged. Every
#'     trimming rule screens; not every screening rule trims, since a
#'     probability can be carried forward as a weight instead.}
#'   \item{Aggregation}{Turning the surviving trials into summary statistics.
#'     [rt_summary()] aggregates. Kept separate from the two above because a
#'     screen and a summary fail in different ways, and the choice between them
#'     is a real one.}
#' }
#'
#' @section The model the summaries feed:
#' \describe{
#'   \item{Evidence accumulation model (EAM)}{A model of choice and response
#'     time in which a decision is made by gathering evidence over time until
#'     enough has arrived to commit. The **diffusion model (DDM)** is one
#'     member, a racing accumulator another.}
#'   \item{Drift}{How fast evidence arrives, on average; the rate of the
#'     accumulation. Higher drift means faster and more accurate responding.}
#'   \item{Bound}{How much evidence is required before committing, also called
#'     boundary separation. A wider bound means slower and more accurate
#'     responding, which is where speed-accuracy trade-offs live.}
#'   \item{Non-decision time (ndt)}{Everything in a response time that is not
#'     evidence accumulation: encoding the stimulus at one end, executing the
#'     movement at the other.}
#'   \item{EZ-diffusion}{A closed-form inversion from the mean response time,
#'     its variance, and accuracy to drift, bound and ndt, so no fitting is
#'     needed. [rt_summary()] produces the three inputs and [ez_ddm()] does the
#'     inversion.}
#' }
#'
#' @seealso [rtprep-package] for what the package is for.
#' @name rtprep-glossary
#' @aliases glossary
NULL
