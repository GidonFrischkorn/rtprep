## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

The single NOTE comes from the CRAN incoming check on win-builder, identical on
R-devel and R-release:

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

* local macOS (Darwin 25.6.0), R 4.6.1, aarch64-apple-darwin23, 2026-09-05 and
  re-run on the submitted tree 2026-09-08: `devtools::check(cran = TRUE)` 0
  errors, 0 warnings, 0 notes (36.5 s, tests 26 s, vignettes re-built OK);
  `rcmdcheck --as-cran` with `_R_CHECK_CRAN_INCOMING_=TRUE` (remote check off)
  0/0/0; `_R_CHECK_DEPENDS_ONLY_=true` 0/0/0; `urlchecker::url_check()`
  reports only the repository, site, and CRAN pages that do not exist before
  the first release
* win-builder, R Under development (unstable) (2026-09-06 r90498 ucrt),
  x86_64-w64-mingw32, Windows Server 2022 x64, 2026-09-08: **Status: 1 NOTE**
  -- the new-submission and DESCRIPTION-spelling NOTE quoted above, no other
  finding. Installation clean, examples OK, tests OK (49 s), vignettes
  re-built OK, PDF and HTML manuals OK.
* win-builder, R version 4.6.1 (2026-06-24 ucrt), x86_64-w64-mingw32, Windows
  Server 2022 x64, 2026-09-08: **Status: 1 NOTE** -- the same new-submission
  and DESCRIPTION-spelling NOTE quoted above, word for word, no other finding.
  Installation clean, examples OK, tests OK (54 s), vignettes re-built OK, PDF
  (14 s) and HTML manuals OK.
* macOS builder (`r-release-macosx-arm64`), R 4.6.1 Patched (2026-07-27
  r90311), aarch64-apple-darwin23, macOS Tahoe 26.6 on Apple M1, 2026-09-08:
  **Status: OK** -- 0 errors, 0 warnings, 0 notes. Tests OK (14 s), vignettes
  re-built OK, PDF manual OK. This builder does not run the CRAN incoming
  check, which is why the spelling NOTE above does not appear here.
* R-hub v2, 2026-09-08, all five platforms **Status: OK** -- 0 errors, 0
  warnings, 0 notes each (these runs do not perform the CRAN incoming check,
  so the spelling NOTE above does not appear on any of them):
  * `linux`, R-devel (2026-09-07 r90504), x86_64-pc-linux-gnu, Ubuntu 24.04.4
    LTS: tests OK (29 s), vignettes re-built OK
  * `windows`, R-devel (2026-09-07 r90504 ucrt), x86_64-w64-mingw32, Windows
    Server 2022 x64: tests OK (44 s), vignettes re-built OK
  * `macos`, R-devel (2026-09-07 r90502), x86_64-apple-darwin20, macOS
    Sequoia 15.7.9: tests OK (58 s), vignettes re-built OK
  * `nold` (R built without long doubles), R-devel (2026-09-07 r90504),
    Ubuntu 22.04.5 LTS: tests OK (29 s), vignettes not re-built on this
    container image
  * `atlas` (ATLAS BLAS/LAPACK), R-devel (2026-06-21 r90185), Fedora Linux 42,
    GCC 15.2.1: tests OK (19 s), vignettes not re-built on this container
    image

  An earlier R-hub run the same day showed 1 ERROR on `nold` only. One test
  asserted that the ex-Gaussian mixture drives its `tau` parameter to the
  optimiser's lower bound, at a threshold (1e-3) that sits between where the
  parameter lands with extended precision (6.7e-05) and without it (2.0e-03).
  The threshold is now 1e-2, still well below both the value `tau` is
  initialised at (0.065) and the value that generated the data (0.15). The
  assertion that carries the claim the test encodes -- that this core reports
  no contamination at all on a tight block of fast contaminants, fitted
  proportion below 0.001 -- was not touched, and neither were the two
  assertions that the other cores do find the block.

## Notes for the reviewers

* The package has no runtime dependency beyond `stats` and `utils`. The
  `Suggests` packages support the equivalence tests and the plot method only.
* Tests that compare live against `bmm`, `trimr`, and `rtdists`, and the
  tolerance-based parameter-recovery tests, are skipped on CRAN
  (`skip_on_cran()`); they run in the package's continuous integration. The
  `trimr` comparison also runs unconditionally against a frozen fixture of
  trimr's own output, which stays on everywhere.
* The method references in the Description carry their DOIs.
