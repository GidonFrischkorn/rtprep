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

`rtprep` is an R package that lives at the root of a research compendium. The
package is `R/`, `man/`, `tests/`, `data/`, `vignettes/`; the sibling
directories `manuscript/`, `scripts/`, `output/`, `functions/`, `data-raw/`
and `local/` belong to the tutorial the package was written for and are all
listed in `.Rbuildignore`. A change to the package should not need to touch
them.

The simulation design those scripts implement is fixed in `DESIGN.md`, which is
authoritative and changes only by adding a numbered decision-log entry — never
by editing an earlier one. If a code change would alter what a study measures,
that entry comes first.

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

`main` is protected. Every change arrives as a pull request from a branch, and
the merge is a squash, so `main` keeps one commit per unit of work and stays
linear.

1. Branch off `main`. Names like `feat/ez-support-screen`, `fix/mixture-maxit`,
   `docs/aggregation-article` keep the branch list readable.
2. Commit in the repository's style: a type prefix and a short imperative
   subject — `feat:`, `fix:`, `docs:`, `test:`, `perf:`, `chore:`, `data:`.
3. Open a pull request and fill in the template.
4. Wait for the required checks (below), get a review, then squash-merge.

While the package has a single developer, that developer merges using the
repository-admin bypass, because GitHub does not let anyone approve their own
pull request. That is a stated exception, not the intended state: as soon as a
second person has push access, the bypass stops being used and the approval
requirement becomes real. Nothing in the ruleset needs to change for that to
happen.

### Checks that must pass

Four checks gate a merge:

| Check | What it covers |
| --- | --- |
| `ubuntu-latest (release)` | `R CMD check` on the reference platform |
| `macos-latest (release)` | `R CMD check` on macOS |
| `windows-latest (release)` | `R CMD check` on Windows |
| `test-coverage` | the suite under `covr`, reported to Codecov |

The `ubuntu-latest (devel)` and `ubuntu-latest (oldrel-1)` legs run on every
pull request but do not block a merge. They are the early warning for the next
R release and the trailing one; a failure there is worth an issue, and is
often not caused by anything in this package. The R-hub workflow is manual
(`workflow_dispatch`) and is run before a CRAN submission, not per pull
request.

**If you change the `R-CMD-check` matrix, update
`.github/rulesets/main-protection.json` in the same pull request.** The
required checks are matched by name — `os (r)`, e.g. `macos-latest (release)`.
Rename a matrix leg without updating the ruleset and every subsequent pull
request waits forever for a check that no longer reports.

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

## Repository administration

`.github/rulesets/` holds the branch and tag protection as JSON, and
`.github/apply-repo-protection.sh` applies it. The remote configuration is
therefore reviewable in a diff rather than only clickable in Settings. Run the
script after changing a ruleset file; `--dry-run` shows what would change.
