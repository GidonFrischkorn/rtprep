## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

The single NOTE comes from the CRAN incoming check on win-builder, quoted here
from the R-oldrelease run of 2026-09-11:

```text
Maintainer: 'Gidon T. Frischkorn <gidon.frischkorn@psychologie.uzh.ch>'

New submission

Possibly misspelled words in DESCRIPTION:
  EZ (15:31, 22:39)
  Grasman (23:22)
  Jolicoeur (19:45)
  Maas (23:13)
  Ratcliff (21:25)
  Selst (19:35)
  Tuerlinckx (21:38)
  Wagenmakers (22:62)
  der (23:9)
```

All nine are spelled as intended. Eight are author surnames from the three
method references cited in the Description -- Van Selst and Jolicoeur (1994),
Ratcliff and Tuerlinckx (2002), and Wagenmakers, van der Maas and Grasman
(2007), where "der" is the particle in "van der Maas". "EZ" is the established
name of the EZ-diffusion model of that third reference. Eight of the nine are
listed in `inst/WORDLIST`; "der" is not flagged by the dictionary the package's
own `spelling` test uses and so needs no entry there. That test passes on every
platform below.

## Test environments

> **Two re-runs outstanding.** The results below are current for the submitted
> tree except for win-builder R-devel and R-release, which have not been run
> since the API revision of 2026-09-11, and the macOS builder, whose submission
> endpoint returned HTTP 502 on 2026-09-11. Delete this block once both have
> been re-run.

* local macOS 26.6.2 (Darwin 25.6.0), R 4.6.1 (2026-06-24),
  aarch64-apple-darwin23, 2026-09-11: `devtools::check(cran = TRUE)` 0 errors,
  0 warnings, 0 notes (48.8 s, tests 36 s, vignettes re-built OK); `rcmdcheck
  --as-cran` with `_R_CHECK_CRAN_INCOMING_=TRUE` (remote check off) 0/0/0
  (36.3 s); `_R_CHECK_DEPENDS_ONLY_=true` 0/0/0 (36.9 s);
  `urlchecker::url_check()` reports only the two CRAN badge URLs in
  `README.md`, which do not resolve before the first release
* win-builder, R version 4.5.3 (2026-03-11 ucrt), x86_64-w64-mingw32, Windows
  Server 2022 x64 (build 20348), 2026-09-11: **Status: 1 NOTE** -- the
  new-submission and DESCRIPTION-spelling NOTE quoted above, word for word, no
  other finding. Installation clean, examples OK, tests OK (89 s), vignettes
  re-built OK, PDF (13 s) and HTML manuals OK.
* R-hub v2, 2026-09-11, all five platforms **Status: OK** -- 0 errors, 0
  warnings, 0 notes each (these runs do not perform the CRAN incoming check,
  so the spelling NOTE above does not appear on any of them). All five report
  the identical test summary, 0 failures and 0 warnings over 2165 passing
  expectations, with the 25 `skip_on_cran()` tests skipped on each:
  * `linux`, R-devel (2026-09-10 r90519), x86_64-pc-linux-gnu, Ubuntu 24.04.5
    LTS: tests OK (47 s), vignettes re-built OK
  * `windows`, R-devel (2026-09-10 r90519 ucrt), x86_64-w64-mingw32, Windows
    Server 2022 x64 (build 26100): tests OK (57 s), vignettes re-built OK
  * `macos`, R-devel (2026-09-10 r90519), x86_64-apple-darwin20, macOS
    Sequoia 15.7.9: tests OK (73 s), vignettes re-built OK
  * `nold` (R built without long doubles), R-devel (2026-09-10 r90519),
    Ubuntu 22.04.5 LTS: tests OK (45 s), vignettes not re-built on this
    container image
  * `atlas` (ATLAS BLAS/LAPACK), R-devel (2026-06-21 r90185), Fedora Linux 42:
    tests OK (30 s), vignettes not re-built on this container image

  One tolerance in the test suite is set wider than it looks like it needs to
  be, and an R-hub run of 2026-09-08 is the reason. A test asserts that the
  ex-Gaussian mixture drives its `tau` parameter to the optimiser's lower
  bound; the original threshold (1e-3) sat between where the parameter lands
  with extended precision (6.7e-05) and without it (2.0e-03), so it passed
  everywhere except `nold`. The threshold is now 1e-2, still well below both
  the value `tau` is initialised at (0.065) and the value that generated the
  data (0.15). The assertion that carries the claim the test encodes -- that
  this core reports no contamination at all on a tight block of fast
  contaminants, fitted proportion below 0.001 -- was not touched, and neither
  were the two assertions that the other cores do find the block.

## Notes for the reviewers

* The package has no runtime dependency beyond `graphics`, `stats` and
  `utils`, all base. `graphics` is used only by the base-graphics fallback in
  `plot.rtprep_comparison()`, which runs when the suggested `ggplot2` is not
  installed. The `Suggests` packages support the equivalence tests, the test
  suite's own scaffolding (`testthat`, `withr`), the vignette and the ggplot2
  plot path only. The package checks clean under
  `_R_CHECK_DEPENDS_ONLY_=true`.
* Tests that compare live against `bmm`, `trimr`, and `rtdists`, and the
  tolerance-based parameter-recovery tests, are skipped on CRAN
  (`skip_on_cran()`); they run in the package's continuous integration. The
  `trimr` comparison also runs unconditionally against a frozen fixture of
  trimr's own output, which stays on everywhere.
* The method references in the Description carry their DOIs.
