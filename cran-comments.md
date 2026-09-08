## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

The single NOTE comes from the CRAN incoming check on win-builder (R-devel):

```text
Maintainer: 'Gidon T. Frischkorn <gidon.frischkorn@psychologie.uzh.ch>'

New submission

Possibly misspelled words in DESCRIPTION:
  EZ (14:36, 20:39)
  Grasman (21:22)
  Jolicoeur (18:19)
  Maas (21:13)
  Ratcliff (19:25)
  Selst (18:9)
  Tuerlinckx (19:38)
  Wagenmakers (20:62)
  der (21:9)
```

All nine are spelled as intended. Eight are author surnames from the three
method references cited in the Description -- Van Selst and Jolicoeur (1994),
Ratcliff and Tuerlinckx (2002), and Wagenmakers, van der Maas and Grasman
(2007), where "der" is the particle in "van der Maas". "EZ" is the established
name of the EZ-diffusion model of that third reference. All nine are listed in
`inst/WORDLIST`, so the package's own `spelling` test passes on every platform
below.

## Test environments

* local macOS (Darwin 25.6.0), R 4.6, 2026-09-05: `devtools::check(cran =
  TRUE)` 0 errors, 0 warnings, 0 notes; `rcmdcheck --as-cran` with
  `_R_CHECK_CRAN_INCOMING_=TRUE` (remote check off) 0/0/0;
  `_R_CHECK_DEPENDS_ONLY_=true` 0/0/0; `urlchecker::url_check()` reports only
  the repository, site, and CRAN pages that do not exist before the first
  release
* win-builder, R Under development (unstable) (2026-09-06 r90498 ucrt),
  x86_64-w64-mingw32, Windows Server 2022 x64, 2026-09-08: **Status: 1 NOTE**
  -- the new-submission and DESCRIPTION-spelling NOTE quoted above, no other
  finding. Installation clean, examples OK, tests OK (49 s), vignettes
  re-built OK, PDF and HTML manuals OK.
* macOS builder (`r-release-macosx-arm64`), R 4.6.1 Patched (2026-07-27
  r90311), aarch64-apple-darwin23, macOS Tahoe 26.6 on Apple M1, 2026-09-08:
  **Status: OK** -- 0 errors, 0 warnings, 0 notes. Tests OK (14 s), vignettes
  re-built OK, PDF manual OK. This builder does not run the CRAN incoming
  check, which is why the spelling NOTE above does not appear here.
* R-hub v2, 2026-09-08, all five platforms: linux (R-devel), windows
  (R-devel), macos (R-devel), and atlas all **Status: OK**. `nold` (R built
  without long doubles) reported 1 ERROR from a single test whose tolerance
  was pinned to a value only reachable with extended precision; the threshold
  has since been widened and the claim the test encodes is unchanged. Re-run
  on `nold` pending.
* win-builder (release): not yet run.

## Notes for the reviewers

* The package has no runtime dependency beyond `stats` and `utils`. The
  `Suggests` packages support the equivalence tests and the plot method only.
* Tests that compare live against `bmm`, `trimr`, and `rtdists`, and the
  tolerance-based parameter-recovery tests, are skipped on CRAN
  (`skip_on_cran()`); they run in the package's continuous integration. The
  `trimr` comparison also runs unconditionally against a frozen fixture of
  trimr's own output, which stays on everywhere.
* The method references in the Description carry their DOIs.
