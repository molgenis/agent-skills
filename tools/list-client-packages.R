# Lists the DataSHIELD client packages whose function references the skill ships.
# packages.datashield.org supplies only the GitHub repos (plus DSI, which it does
# not list); the latest release and whether a package is a client are read from
# GitHub, because the site's own fields can be stale.
# Set GITHUB_TOKEN to avoid the unauthenticated API rate limit.
# Usage: Rscript list-client-packages.R <output.csv>

library(dplyr)
library(httr2)
library(purrr)
library(rvest)
library(stringr)

packages_url <- "https://packages.datashield.org/packages.html"

read_site_repos <- function() {
  rows <- html_elements(read_html(packages_url), "tr")
  labels <- html_text2(html_element(rows, "td.label"))
  github_links <- html_element(rows[labels == "GitHub link"], "td.left a")
  str_remove(html_attr(github_links, "href"), "^https://github.com/")
}

# A missing release is a 404, which callers treat as "none" rather than an error.
perform_github_request <- function(path) {
  request <- request("https://api.github.com") |>
    req_url_path_append(path) |>
    req_error(is_error = \(response) resp_status(response) >= 400 && resp_status(response) != 404)
  token <- Sys.getenv("GITHUB_TOKEN")
  if (nzchar(token)) request <- req_auth_bearer_token(request, token)
  req_perform(request)
}

read_latest_release <- function(repo) {
  response <- perform_github_request(paste0("repos/", repo, "/releases/latest"))
  if (resp_status(response) == 404) return(NA_character_)
  resp_body_json(response)$tag_name
}

find_package_version <- function(repo) {
  tag <- read_latest_release(repo)
  if (is.na(tag)) message(repo, ": no release, skipped")
  tibble(repo = repo, tag = tag)
}

is_client_package <- function(repo, tag) {
  namespace <- request("https://raw.githubusercontent.com") |>
    req_url_path_append(repo, tag, "NAMESPACE") |>
    req_perform() |>
    resp_body_string()
  str_detect(namespace, "(^|\n)export\\((ds|dh|datashield)\\.")
}

list_client_packages <- function() {
  c(read_site_repos(), "datashield/DSI") |>
    map_dfr(find_package_version) |>
    filter(!is.na(tag)) |>
    filter(map2_lgl(repo, tag, is_client_package))
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) stop("Usage: Rscript list-client-packages.R <output.csv>")
readr::write_csv(list_client_packages(), args[[1]])
