# CRAN does not accept `:::` in documentation: an example that reaches an
# unexported object depends on something the package may change at any time.
# The 0.1.0 submission was returned for exactly this, so the check runs here
# rather than at CRAN.

help_text <- function() {
  # The namespace path is the source tree under load_all() and the installed
  # package otherwise. system.file() does not help here: under load_all() it
  # points at inst/.
  pkg <- getNamespaceInfo("rtprep", "path")
  man <- file.path(pkg, "man")
  if (dir.exists(man)) {
    # Read the Rd files as written. Parsing them would expand every \doi{}
    # into R's own tools:::Rd_expr_doi() call.
    files <- list.files(man, "\\.Rd$", full.names = TRUE)
    text <- vapply(
      files,
      function(f) paste(readLines(f, warn = FALSE), collapse = "\n"),
      character(1)
    )
    stats::setNames(text, basename(files))
  } else {
    # The installed help database, where \doi{} was rendered at install time.
    vapply(
      tools::Rd_db("rtprep"),
      function(rd) paste(as.character(rd), collapse = ""),
      character(1)
    )
  }
}

test_that("no help page reaches an unexported object with :::", {
  text <- help_text()
  expect_gt(length(text), 0)
  expect_equal(names(text)[grepl(":::", text, fixed = TRUE)], character())
})
