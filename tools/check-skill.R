# Checks that a skill's SKILL.md is consistent with the files it points to:
# valid frontmatter, every referenced path present, and every DataSHIELD function
# it calls documented in references/functions/, so an agent is never sent to a
# missing file or told to use a function that does not exist.
# Usage: Rscript check-skill.R <skill-dir>

library(purrr)
library(stringr)

read_frontmatter <- function(lines) {
  fences <- which(lines == "---")
  if (length(fences) < 2 || fences[[1]] != 1) return(list())
  yaml::yaml.load(paste(lines[2:(fences[[2]] - 1)], collapse = "\n"))
}

find_frontmatter_problems <- function(frontmatter, skill_dir) {
  name <- frontmatter$name
  description <- frontmatter$description
  c(
    if (is.null(name)) "frontmatter has no name",
    if (!is.null(name) && !str_detect(name, "^[a-z0-9-]{1,64}$")) "name must be 1-64 lowercase letters, digits or hyphens",
    if (!is.null(name) && name != basename(skill_dir)) "name does not match the skill's folder name",
    if (is.null(description)) "frontmatter has no description",
    if (!is.null(description) && nchar(description) > 1024) "description is longer than 1024 characters"
  )
}

find_missing_paths <- function(text, skill_dir) {
  paths <- unique(str_match_all(text, "`((references|scripts)/[^`]+)`")[[1]][, 2])
  missing <- paths[!file.exists(file.path(skill_dir, paths))]
  map_chr(missing, \(path) paste0("referenced path does not exist: ", path))
}

read_documented_functions <- function(skill_dir) {
  files <- list.files(file.path(skill_dir, "references", "functions"), "\\.md$", full.names = TRUE)
  index_rows <- unlist(map(files, readLines))
  str_match(index_rows, "^\\| `([^`]+)` \\|")[, 2] |> discard(is.na)
}

find_undocumented_functions <- function(text, skill_dir) {
  called <- str_match_all(text, "(?<![\\w.])((ds|dh|datashield)\\.[\\w.]*\\w)(?=\\(|`)")[[1]][, 2]
  undocumented <- setdiff(unique(called), read_documented_functions(skill_dir))
  map_chr(undocumented, \(name) paste0("function not in references/functions/: ", name))
}

check_skill <- function(skill_dir) {
  lines <- readLines(file.path(skill_dir, "SKILL.md"))
  text <- paste(lines, collapse = "\n")
  problems <- c(
    find_frontmatter_problems(read_frontmatter(lines), skill_dir),
    find_missing_paths(text, skill_dir),
    find_undocumented_functions(text, skill_dir)
  )
  walk(problems, \(problem) message("::error file=", file.path(skill_dir, "SKILL.md"), "::", problem))
  length(problems) == 0
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) stop("Usage: Rscript check-skill.R <skill-dir>")
if (!check_skill(args[[1]])) quit(status = 1)
