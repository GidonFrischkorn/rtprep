## What this changes

<!-- One or two sentences. What does the package do after this that it did not
     do before, or what was wrong that is now right? -->

## Why

<!-- Link the issue if there is one (Closes #NN). If this changes behaviour a
     user could depend on, say what breaks and what replaces it. -->

## Checklist

- [ ] `devtools::check()` is clean — 0 errors, 0 warnings, 0 notes
- [ ] `devtools::test()` passes, including the `trimr` and `bmm` equivalence tests
- [ ] New behaviour has tests, and a test was watched to fail before it passed
- [ ] `devtools::document()` was run; `NAMESPACE` and `man/` are not hand-edited
- [ ] `NEWS.md` has an entry, if a user would notice this change
- [ ] Package code under `R/` uses base R plus `stats`/`utils` only
- [ ] No `set.seed()` was added to package code

## Anything the reviewer should look at first

<!-- The judgement call you are least sure about, the tradeoff you made, the
     part where a second opinion is worth most. -->
