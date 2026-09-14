## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

The single NOTE comes from the CRAN incoming check and is identical on all
three win-builder versions (R-devel, R-release, R-oldrelease, 2026-09-14);
quoted here from the R-devel run:

```text
Maintainer: 'Gidon T. Frischkorn <gfrischkorn@icloud.com>'

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

* local macOS 26.6.2 (Darwin 25.6.0), R 4.6.1 (2026-06-24),
  aarch64-apple-darwin23, 2026-09-14: `devtools::check(cran = TRUE)` 0 errors,
  0 warnings, 0 notes (48 s); `rcmdcheck --as-cran` with
  `_R_CHECK_DEPENDS_ONLY_=true` 0 errors, 0 warnings, 1 note (the
  new-submission part of the NOTE above, 44.6 s); `urlchecker::url_check()`
  reports only the two CRAN badge URLs in `README.md`, which do not resolve
  before the first release (`README.md` is not part of the built package)
* win-builder, Windows Server 2022 x64 (build 20348), x86_64-w64-mingw32,
  2026-09-14, each **Status: 1 NOTE** -- the NOTE quoted above, word for word,
  no other finding; installation clean, examples OK, vignettes re-built OK,
  PDF and HTML manuals OK:
  * R-devel (2026-09-13 r90534 ucrt): tests OK (76 s)
  * R-release, R 4.6.1 (2026-06-24 ucrt): tests OK (76 s)
  * R-oldrelease, R 4.5.3 (2026-03-11 ucrt): tests OK (84 s)
* R-hub v2, 2026-09-14, all five platforms **Status: OK** -- 0 errors, 0
  warnings, 0 notes each (these runs do not perform the CRAN incoming check,
  so the NOTE above does not appear on any of them). All five report the
  identical test summary, 0 failures and 0 warnings over 2165 passing
  expectations, with the 25 `skip_on_cran()` tests skipped on each:
  * `linux`, R-devel (2026-09-13 r90534), x86_64-pc-linux-gnu, Ubuntu 24.04.5
    LTS: vignettes re-built OK
  * `windows`, R-devel (2026-09-13 r90534 ucrt), x86_64-w64-mingw32, Windows
    Server 2022 x64 (build 26100): tests OK (57 s), vignettes re-built OK
  * `macos`, R-devel (2026-09-13 r90534), x86_64-apple-darwin20, macOS
    Sequoia 15.7.9: vignettes re-built OK
  * `nold` (R built without long doubles), R-devel (2026-09-12 r90533),
    Ubuntu 22.04.5 LTS: vignettes not re-built on this container image
  * `atlas` (ATLAS BLAS/LAPACK), R-devel (2026-06-21 r90185), Fedora Linux 42:
    vignettes not re-built on this container image
* GitHub Actions, 2026-09-14, `R CMD check` passing on ubuntu-latest (R-devel,
  release, oldrel-1), windows-latest (release) and macos-latest (release)
* The macOS builder (mac.r-project.org) could not be used: its submission
  endpoint returned HTTP 502 on 2026-09-11 and again on 2026-09-14. macOS is
  covered by the local check, R-hub `macos` and GitHub Actions macos-latest
  above.

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
