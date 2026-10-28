# Lists the DataSHIELD client packages whose function references the skill ships.
# packages.datashield.org supplies the GitHub repos; the latest release and whether
# a package is a client are read from GitHub, because the site's own fields can be
# stale.
# Set GITHUB_TOKEN to avoid the unauthenticated API rate limit.
# Usage: Rscript list-client-packages.R <output.csv>

library(dplyr)
library(httr2)
library(purrr)
library(rvest)
library(stringr)

script_dir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
source(file.path(script_dir, "github.R"))

packages_url <- "https://packages.datashield.org/packages.html"

# Not on the site: DSI, and the Armadillo DSI driver (its exports are armadillo.*, not ds.*).
unlisted_repos <- c("datashield/DSI", "molgenis/molgenis-r-datashield")

read_site_repos <- function() {
  rows <- html_elements(read_html(packages_url), "tr")
  labels <- html_text2(html_element(rows, "td.label"))
  github_links <- html_element(rows[labels == "GitHub link"], "td.left a")
  str_remove(html_attr(github_links, "href"), "^https://github.com/")
}

is_client_package <- function(repo, tag) {
  namespace <- request("https://raw.githubusercontent.com") |>
    req_url_path_append(repo, tag, "NAMESPACE") |>
    req_perform() |>
    resp_body_string()
  str_detect(namespace, "(^|\n)export\\((ds|dh|datashield)\\.")
}

list_client_packages <- function() {
  site_packages <- read_site_repos() |>
    map_dfr(find_package_version) |>
    filter(!is.na(tag)) |>
    filter(map2_lgl(repo, tag, is_client_package))
  bind_rows(site_packages, map_dfr(unlisted_repos, find_package_version))
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) stop("Usage: Rscript list-client-packages.R <output.csv>")
readr::write_csv(list_client_packages(), args[[1]])
