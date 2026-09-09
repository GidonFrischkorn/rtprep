# NA

## What this changes

## Why

## Checklist

`devtools::check()` is clean — 0 errors, 0 warnings, 0 notes

`devtools::test()` passes, including the `trimr` and `bmm` equivalence
tests

New behaviour has tests, and a test was watched to fail before it passed

`devtools::document()` was run; `NAMESPACE` and `man/` are not
hand-edited

`NEWS.md` has an entry, if a user would notice this change

Package code under `R/` uses base R plus `stats`/`utils` only

No [`set.seed()`](https://rdrr.io/r/base/Random.html) was added to
package code

## Anything the reviewer should look at first
