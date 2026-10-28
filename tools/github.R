# GitHub release lookups shared by the package-listing tools.
# Set GITHUB_TOKEN to avoid the unauthenticated API rate limit.

library(httr2)

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
  tibble::tibble(repo = repo, tag = tag)
}
