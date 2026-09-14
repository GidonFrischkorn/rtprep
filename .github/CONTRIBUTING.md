# Contributing to rtprep

Thanks for your interest in the package. This file covers how changes get into
`main`, and the few conventions that are load-bearing enough that a pull
request will be asked to change if it breaks them.

Bug reports and feature requests go through the [issue
templates](https://github.com/GidonFrischkorn/rtprep/issues/new/choose). For a
bug, a [reprex](https://reprex.tidyverse.org/) is worth more than a
description. Please do not paste identifiable participant data into a public
issue — `r_contaminated()` will generate response times with contaminants of a
known type, which usually reproduces a screening bug just as well.

## What this repository is

`rtprep` is an R package that lives at the root of a research compendium. What
this repository publishes is the package: `R/`, `man/`, `tests/`, `data/`,
`vignettes/`, plus `data-raw/`. The tutorial manuscript the package was written
for, and the simulation studies reported in it, are held back until the paper is
published, so they are not in the repository and a change to the package does
not need them.

One consequence is worth knowing before you open a pull request: the package's
defaults and the answers its rules give were fixed by that simulation. A change
that alters what a rule returns is a change to a published result, not only to
code, so it needs a rationale in the pull request and will usually be asked to
land behind a new argument rather than by moving a default.

## Getting set up

```r
install.packages("devtools")
devtools::install_dev_deps()   # installs Suggests too
devtools::load_all()
devtools::test()
```

Some tests compare `rtprep` against `trimr` and `bmm`. Those are `Suggests`,
and the tests skip cleanly if the packages are absent — but see the note on
equivalence below before assuming a skip is a pass.

## The workflow

Two branches are long-lived and protected:

- **`main`** is what is on CRAN. It changes only when a release or a hotfix is
  merged into it.
- **`develop`** is the default branch: reviewed work that is not on CRAN yet.
  Installing from GitHub (`remotes::install_github("GidonFrischkorn/rtprep")`)
  gives you this version.

Everything else is a short-lived branch that arrives through a pull request:

| Branch | Cut from | Pull request into | Merged by |
| --- | --- | --- | --- |
| `feat/*`, `fix/*`, `docs/*`, `test/*`, `chore/*` | `develop` | `develop` | squash |
| `release/X.Y.Z` | `develop` | `main` | merge commit |
| `hotfix/X.Y.Z` | `main` | `main` | merge commit |
| `sync/vX.Y.Z` | `develop` (then merge `main` in) | `develop` | merge commit |

Squash merges keep `develop` at one commit per unit of work. Merge commits are
used wherever `main` and `develop` meet, so that `develop` always contains
`main`: a squashed or rebased release or sync copies the changes without the
commits, and every later release then conflicts. The `branch-policy` check
rejects a pull request into `main` from any other kind of branch.

For a change to the package:

1. Branch off `develop`. Names like `feat/ez-support-screen`,
   `fix/mixture-maxit`, `docs/aggregation-article` keep the branch list
   readable.
2. Commit in the repository's style: a type prefix and a short imperative
   subject: `feat:`, `fix:`, `docs:`, `test:`, `perf:`, `chore:`, `data:`.
3. Open a pull request into `develop` and fill in the template.
4. Wait for the required checks (below), resolve every review thread, then
   squash-merge. The branch is deleted on merge.

### Who can merge

Each protected branch has two rulesets in `.github/rulesets/`:

- a **gate** (`main-gate.json`, `develop-gate.json`): pull request required,
  required checks passing on an up-to-date branch, review threads resolved,
  the allowed merge method, no force-push, no deletion. Nobody can bypass it.
- a **review** (`main-review.json`, `develop-review.json`): one approving
  review, from a code owner.

GitHub does not let anyone approve their own pull request, so while the
package has a single developer, that developer merges by bypassing the review
ruleset, which the repository-admin role may do on a pull request and nowhere
else. The gate still applies to that merge. This is a stated exception, not
the intended state: once a second person has push access, the bypass stops
being used and the approval requirement becomes real, without any change to
the rulesets.

### Checks that must pass

Five checks gate a merge into `main` or `develop`:

| Check | What it covers |
| --- | --- |
| `ubuntu-latest (release)` | `R CMD check` on the reference platform |
| `macos-latest (release)` | `R CMD check` on macOS |
| `windows-latest (release)` | `R CMD check` on Windows |
| `test-coverage` | the suite under `covr`, reported to Codecov |
| `branch-policy` | the pull request's source branch is allowed to merge into its target |

The `ubuntu-latest (devel)` and `ubuntu-latest (oldrel-1)` legs run on every
pull request but do not block a merge. They are the early warning for the next
R release and the trailing one; a failure there is worth an issue, and is
often not caused by anything in this package. The R-hub workflow is manual
(`workflow_dispatch`) and is run on a release branch before a CRAN submission,
not per pull request.

**If you rename a job or a matrix leg that is a required check, update
`.github/rulesets/main-gate.json` and `develop-gate.json` in the same pull
request.** The required checks are matched by name, for `R CMD check` in the
form `os (r)`, e.g. `macos-latest (release)`. Rename one without updating the
rulesets and every subsequent pull request waits forever for a check that no
longer reports.

### Requesting a Claude review

A pull request can be reviewed by Claude on request: comment `@claude review`
on it (the comment has to start with those words), or add the `claude-review`
label. Only people with write access can start a review. Claude checks the
changed code for correctness and against the rules in `.claude/CLAUDE.md`,
posts inline comments on what it finds and one summary comment, and on a
repeated request reports only what is new and which earlier findings have
been addressed.

The review is advisory. It is not a required check, but its inline comments
are review threads, and the gate requires every thread to be resolved (or
answered and resolved) before a merge. The procedure is
`.claude/commands/review-pr.md`; both files are read from `develop`, never
from the pull request under review. A pull request that edits
`.github/workflows/claude-review.yaml` cannot be reviewed this way: the action
declines to run a workflow that differs from the default branch's copy.

Reviews run on the maintainer's Claude subscription, which is why they are
requested rather than automatic.

## Conventions that reviews enforce

**Package code is base R.** `Imports` is `stats` and `utils`, and that is
deliberate: the screening functions take vectors and return data frames so they
compose inside `dplyr::mutate()` and `reframe()`, but the package must not
require the tidyverse to work. `dplyr`, `tibble` and `ggplot2` are `Suggests`,
for tests, vignettes and examples only. Scripts outside the package are under
no such constraint.

**Generated files are regenerated, never hand-edited.** `NAMESPACE` and
everything in `man/` come from `devtools::document()`; `README.md` comes from
`devtools::build_readme()` and is generated from `README.Rmd`. A pull request
that edits one of them directly will be asked to run the generator instead.

**No `set.seed()` in package code.** Reproducibility for the simulations comes
from SimDesign's seed handling and the archived results in `output/`. A seed
inside an exported function silently makes it non-random for the caller.

**The equivalence tests are insurance and must stay green.**
`tests/testthat/test-equivalence.R` checks `rtprep` against `trimr` and `bmm`,
which implement some of the same published algorithms. The package
reimplements rather than depends on them, so nothing else would catch a silent
divergence from the published rule. Do not "fix" a failure there by relaxing a
tolerance or regenerating the fixture until you know which of the two
implementations moved.

The two layers are not equally safe. The `trimr` comparison has a frozen
fixture — `tests/testthat/fixtures/trimr-reference.rds`, trimr 1.1.1's own
answers — that runs on every machine, with a live comparison on top of it that
skips when `trimr` is absent. The `bmm` comparisons are live only: without
`bmm` installed they skip entirely and assert nothing. A green local run is
therefore not evidence that the `bmm` layer passed. Check that `bmm` is
installed, or read the CI log.

**Tests should be watched failing.** A test that encodes a substantive claim
is easy to write so that it cannot fail. Break the implementation, confirm the
test goes red, then restore it.

**Style.** Tidyverse style guide; `styler` and `lintr` must both run clean.
`.lintr` disables `object_name_linter` and `object_usage_linter` for reasons
given in that file — a pull request should not re-enable them in passing.
Documentation and prose are en-GB (`Language: en-GB`); new technical terms may
need an entry in `inst/WORDLIST`.

**Terminology.** These distinctions carry the package's argument, so the
documentation keeps them:

- **contaminant** for a trial not generated by the decision process;
  **outlier** only for the statistical criterion, or when discussing prior
  literature that uses the word.
- **screening** for any rule that classifies trials, **trimming** only for
  rules that remove them, **aggregation** for the summary-statistic step.
- parameters are **drift**, **bound**, **ndt**, **zr**.
- the three contaminant processes are **leading-edge anticipations**,
  **delayed start-ups**, and **informationless responses**.

## New user-facing behaviour

Add a `NEWS.md` entry under a development heading. Exported functions need
roxygen documentation with a runnable `@examples` block, and a new screening
rule needs a reference to the published algorithm it implements — the DOI goes
in the roxygen and, if it is a new source, in `manuscript/references.bib`.

## Releasing

A release moves `develop` onto `main` and CRAN. The maintainer runs these
steps.

1. **Cut the release branch.** `git switch -c release/X.Y.Z origin/develop`,
   then `usethis::use_version()` to set `X.Y.Z` and the `NEWS.md` heading.
   Update `cran-comments.md`. Run `devtools::check(cran = TRUE)`,
   `devtools::check_win_devel()` and the R-hub workflow on the branch.
2. **Merge into `main`.** Open a pull request from `release/X.Y.Z` into
   `main` and merge it with a merge commit once the checks pass.
3. **Submit.** Locally, with `main` identical to `origin/main`:
   `devtools::submit_cran()`. It writes `CRAN-SUBMISSION` with the submitted
   commit; leave any change to that file uncommitted, since `main` only takes
   merges.
4. **If CRAN asks for changes**, cut `hotfix/X.Y.Z` from `main`, fix, merge
   the pull request into `main` with a merge commit, and submit again from
   `main`.
5. **On acceptance**, with `main` still identical to `origin/main`:
   `usethis::use_github_release()`. It tags `vX.Y.Z` at the commit recorded in
   `CRAN-SUBMISSION`, publishes the GitHub release, and deletes the file.
6. **Bring `main` back into `develop`.** Keep the deletion of
   `CRAN-SUBMISSION` in the working tree and:

   ```sh
   git switch -c sync/vX.Y.Z origin/develop
   git merge --no-ff origin/main
   ```

   Resolve conflicts in `DESCRIPTION` to `main`'s version, run
   `usethis::use_dev_version()` so the version reads `X.Y.Z.9000`, check that
   `NEWS.md` starts with a single `# rtprep (development version)` heading,
   and commit (including the `CRAN-SUBMISSION` deletion, if that file was
   tracked). Open a pull request into `develop` and merge it with a **merge
   commit**. If it is squashed by mistake, the `sync-ancestry` workflow fails
   on the merge; repeat this step with a new `sync/` branch.

A hotfix follows steps 4 to 6: merge into `main`, submit, release, sync.

Tags matching `v*` cannot be moved or deleted (`release-tags.json`).

## When a required check is broken

If a required check fails for reasons outside the package (a runner image, a
CRAN mirror, a Codecov outage) and a merge cannot wait for it to be fixed or
re-run, a repository admin sets the gate ruleset's enforcement to *Disabled*
in Settings → Rules, merges, and sets it back to *Active* straight away. Say
in the pull request that this was done and why.

## Repository administration

`.github/rulesets/` holds the branch and tag protection as JSON, and
`.github/apply-repo-protection.sh` applies it, together with the merge
settings, the default branch and the `claude-review` label. The remote
configuration is therefore reviewable in a diff rather than only clickable in
Settings. Run the script after changing a ruleset file; `--dry-run` shows what
would change.

The Claude review needs two things that live outside the repository: the
Claude GitHub App installed on it, and a repository secret
`CLAUDE_CODE_OAUTH_TOKEN` created with `claude setup-token`. When the token
expires, reviews fail at authentication; generate a new one and replace the
secret.
