## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Test environments

* local macOS (Darwin 25.6.0), R 4.6, 2026-09-05: `devtools::check(cran =
  TRUE)` 0 errors, 0 warnings, 0 notes; `rcmdcheck --as-cran` with
  `_R_CHECK_CRAN_INCOMING_=TRUE` (remote check off) 0/0/0;
  `_R_CHECK_DEPENDS_ONLY_=true` 0/0/0; `urlchecker::url_check()` reports only
  the repository, site, and CRAN pages that do not exist before the first
  release
* win-builder (devel, release), macOS builder, R-hub (linux, windows, macos,
  nold, atlas): to be run before submission; results go here

## Notes for the reviewers

* The package has no runtime dependency beyond `stats` and `utils`. The
  `Suggests` packages support the equivalence tests and the plot method only.
* Tests that compare live against `bmm`, `trimr`, and `rtdists`, and the
  tolerance-based parameter-recovery tests, are skipped on CRAN
  (`skip_on_cran()`); they run in the package's continuous integration. The
  `trimr` comparison also runs unconditionally against a frozen fixture of
  trimr's own output, which stays on everywhere.
* The method references in the Description carry their DOIs.
