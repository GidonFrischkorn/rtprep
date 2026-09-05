# Builds tests/testthat/fixtures/screen-engine-reference.rds, the frozen output
# of the screening engine for the whole rule roster. See test-engine.R for what
# the fixture is for and when it may be regenerated.
#
# Run from the repository root with the package loaded by devtools, sourcing
# this file.

source(file.path("tests", "testthat", "helper-engine.R"))

d <- .engine_data()
roster <- .engine_roster()

screens <- lapply(roster, function(spec) {
  scr <- .engine_screen(d, spec)
  list(
    .keep = scr$.keep, .prob = scr$.prob,
    .rule = scr$.rule, .reason = scr$.reason,
    fits = attr(scr, "fits")
  )
})

cmp <- .engine_comparison(d)

saveRDS(
  list(
    data = d,
    screens = screens,
    comparison = cmp[c("keep", "prob", "reason", "drops", "agreement", "fits")],
    built_under = list(
      rtprep = as.character(utils::packageVersion("rtprep")),
      r = R.version.string,
      date = Sys.Date()
    )
  ),
  file.path("tests", "testthat", "fixtures", "screen-engine-reference.rds"),
  compress = "xz"
)
