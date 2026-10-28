# Lists the latest GitHub release of each given repo, in the format build-all-references.R reads.
# Usage: Rscript list-releases.R <output.csv> <owner/repo>...

library(purrr)

script_dir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
source(file.path(script_dir, "github.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("Usage: Rscript list-releases.R <output.csv> <owner/repo>...")
releases <- map_dfr(args[-1], find_package_version)
readr::write_csv(releases[!is.na(releases$tag), ], args[[1]])
