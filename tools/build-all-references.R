# Builds a function reference for every package in the list written by
# list-client-packages.R, from the source of each package's release tag.
# Usage: Rscript build-all-references.R <packages.csv> <output-dir>

library(purrr)

download_release_source <- function(repo, tag) {
  extract_dir <- tempfile("source-")
  archive <- tempfile(fileext = ".tar.gz")
  download.file(paste0("https://github.com/", repo, "/archive/refs/tags/", tag, ".tar.gz"),
                archive, quiet = TRUE)
  untar(archive, exdir = extract_dir)
  list.dirs(extract_dir, recursive = FALSE)[[1]]
}

build_package_reference <- function(repo, tag, output_dir) {
  source_dir <- download_release_source(repo, tag)
  if (!dir.exists(file.path(source_dir, "man"))) {
    message(repo, " ", tag, ": no man/ directory, skipped")
    return(invisible(NULL))
  }
  package <- read.dcf(file.path(source_dir, "DESCRIPTION"))[1, "Package"]
  output_file <- file.path(output_dir, paste0(package, ".md"))
  status <- system2("Rscript", c(build_script, source_dir, output_file))
  if (status != 0) stop(repo, " ", tag, ": build-references.R failed")
}

build_script <- file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))),
                          "build-references.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("Usage: Rscript build-all-references.R <packages.csv> <output-dir>")
packages <- readr::read_csv(args[[1]], show_col_types = FALSE)
dir.create(args[[2]], recursive = TRUE, showWarnings = FALSE)
pwalk(packages, \(repo, tag) build_package_reference(repo, tag, args[[2]]))
