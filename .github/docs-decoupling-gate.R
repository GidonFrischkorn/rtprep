# Gate: the package documentation carries package behaviour, not the
# manuscript's findings.
#
# Run from the package root: Rscript .github/docs-decoupling-gate.R
#
# Fails (exit status 1) when any hard pattern appears in the documentation
# sources or, when a built site exists under docs/, in the built pages and
# their indexes. Prints a review list for softer phrases without failing, so
# the pointers that are allowed to stay ("a tutorial article is in
# preparation") are seen rather than hidden. Base R only, so the CI step needs
# nothing installed.
#
# Nothing is excluded from the scan: every source file is read whole. The gate
# still asserts that no page references gt-residual, the one section that used
# to read the archived summaries, so that it cannot come back unnoticed.

list_under <- function(dir, pattern) {
  if (!dir.exists(dir)) {
    return(character())
  }
  list.files(dir, pattern, recursive = TRUE, full.names = TRUE)
}

sources <- c(
  list_under("vignettes", "\\.Rmd$"),
  list_under("vignettes/articles", "\\.R$"),
  list_under("R", "\\.R$"),
  "NEWS.md"
)
review_only <- c("README.Rmd", "inst/CITATION")
site <- c(
  list_under("docs", "\\.(html|md)$"),
  file.path("docs", c("search.json", "llms.txt"))
)
sources <- sources[file.exists(sources)]
review_only <- review_only[file.exists(review_only)]
site <- site[file.exists(site)]

accessors <- c(
  "s1_J", "s1_best", "s1_cell", "s1_gap", "s1_trigger", "s1_mix", "s1_S",
  "s1_ez", "s1_guess", "s2_bias", "s2_par", "s2_shift", "s3_r", "s3_range",
  "s3_mcse_max", "s3_rpf", "tab_s1_1_body", "tab_s1_2_body", "tab_s2_1_body",
  "tab_s3_1_body", "run_core_hours", "res_read"
)

hard <- c(
  "manuscript/results",
  "manuscript_numbers",
  paste0("\\b(", paste(accessors, collapse = "|"), ")\\s*\\("),
  "\\bStudy [123]\\b",
  "200 replications",
  "core-hours",
  "\\bcompanion\\b",
  "simulation-studies\\.html"
)
# The design record is not package documentation; nothing on the site or in
# the vignettes may point at it.
hard_pages_only <- "DESIGN\\.(md|html)"

soft <- c(
  "the manuscript", "the tutorial", "the simulation", "in preparation",
  "the paper", "AMPPS"
)

read_scannable <- function(path) {
  readLines(path, warn = FALSE, encoding = "UTF-8")
}

scan <- function(files, patterns) {
  hits <- list()
  for (path in files) {
    lines <- read_scannable(path)
    for (pattern in patterns) {
      idx <- grep(pattern, lines, perl = TRUE)
      for (i in idx) {
        text <- trimws(lines[i])
        if (nchar(text) > 100) text <- paste0(substr(text, 1, 100), "...")
        hits[[length(hits) + 1L]] <- sprintf("%s:%d: %s", path, i, text)
      }
    }
  }
  unlist(hits)
}

report <- function(title, hits) {
  cat(sprintf("\n%s (%d)\n", title, length(hits)))
  if (length(hits)) cat(paste0("  ", hits), sep = "\n")
}

pages <- c(sources[startsWith(sources, "vignettes")], site)
hard_hits <- c(
  scan(c(sources, site), hard),
  scan(pages, hard_pages_only)
)
residual_refs <- scan(
  sources[startsWith(sources, "vignettes") & grepl("\\.Rmd$", sources)],
  c("\\{r gt-residual", "label:\\s*gt-residual")
)
soft_hits <- scan(c(sources, review_only, site), soft)

report("Hard hits", hard_hits)
report("Pages referencing the excluded chunk", residual_refs)
report("Review list (allowed pointers, not failures)", soft_hits)

cat(sprintf(
  "\nScanned %d source files, %d site files.\n",
  length(sources), length(site)
))
if (length(hard_hits) || length(residual_refs)) {
  cat("FAIL: the documentation still carries manuscript coupling.\n")
  quit(status = 1L)
}
cat("OK: no hard pattern found.\n")
