# Checks that a skill's SKILL.md and reference files are consistent: valid
# frontmatter, every path SKILL.md points to present, every function called
# documented in references/functions/ or <functions-dir>, and no username or password
# arguments, so an agent is never sent to a missing file, told to use a function
# that does not exist, or shown credentials.
# Usage: Rscript check-skill.R <skill-dir> <functions-dir>

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

# Returns each documented function's lifecycle ("" when stable), named by function.
read_function_lifecycles <- function(skill_dir, functions_dir) {
  files <- list.files(c(file.path(skill_dir, "references", "functions"), functions_dir), "\\.md$", full.names = TRUE)
  index_rows <- str_match(unlist(map(files, readLines)), "^\\| `([^`]+)` \\|[^|]*\\| *([a-z]*) *\\|")
  index_rows <- index_rows[!is.na(index_rows[, 1]), , drop = FALSE]
  set_names(index_rows[, 3], index_rows[, 2])
}

# Only calls count: backticked names such as armadillo.conf are files and hosts, not functions.
find_called_functions <- function(text) {
  unique(str_match_all(text, "(?<![\\w.])((ds|dh|datashield|armadillo)\\.[\\w.]*\\w)\\(")[[1]][, 2])
}

find_undocumented_functions <- function(names, lifecycles) {
  undocumented <- setdiff(names, names(lifecycles))
  map_chr(undocumented, \(name) paste0("function not in the function references: ", name))
}

find_functions_in_lifecycle <- function(names, lifecycles, stages) {
  matching <- intersect(names, names(lifecycles)[lifecycles %in% stages])
  map_chr(matching, \(name) paste0(name, " is ", lifecycles[[name]]))
}

check_functions <- function(text, lifecycles) {
  names <- find_called_functions(text)
  list(
    errors = c(find_undocumented_functions(names, lifecycles),
               find_functions_in_lifecycle(names, lifecycles, "defunct")),
    warnings = find_functions_in_lifecycle(names, lifecycles, c("deprecated", "superseded"))
  )
}

find_credentials <- function(text) {
  if (str_detect(text, regex("\\b(password|user)\\s*=", ignore_case = TRUE))) {
    "contains a username or password argument"
  }
}

check_skill_file <- function(skill_dir, lifecycles) {
  lines <- readLines(file.path(skill_dir, "SKILL.md"))
  text <- paste(lines, collapse = "\n")
  functions <- check_functions(text, lifecycles)
  list(
    errors = c(
      find_frontmatter_problems(read_frontmatter(lines), skill_dir),
      find_missing_paths(text, skill_dir),
      functions$errors,
      find_credentials(text)
    ),
    warnings = functions$warnings
  )
}

# The function references and the lifecycle list are excluded: they document the functions, so
# they are the yardstick, and the lifecycle list names defunct functions on purpose.
list_reference_files <- function(skill_dir) {
  files <- list.files(file.path(skill_dir, "references"), "\\.md$", recursive = TRUE, full.names = TRUE)
  discard(files, \(file) str_detect(file, "/references/(functions/|lifecycle\\.md$)"))
}

# references/docs/ and references/code/ hold external documentation and verbatim package source
# that call functions documented elsewhere, so only their credentials are checked.
check_reference_file <- function(file, lifecycles) {
  text <- paste(readLines(file), collapse = "\n")
  if (str_detect(file, "/references/(docs|code)/")) return(list(errors = find_credentials(text), warnings = NULL))
  functions <- check_functions(text, lifecycles)
  list(errors = c(functions$errors, find_credentials(text)), warnings = functions$warnings)
}

# Deprecated functions are warnings, not errors: they still run, and a file may mention one
# only to point to its replacement.
report_problems <- function(file, problems) {
  walk(problems$errors, \(problem) message("::error file=", file, "::", problem))
  walk(problems$warnings, \(problem) message("::warning file=", file, "::", problem))
  length(problems$errors)
}

check_skill <- function(skill_dir, functions_dir) {
  lifecycles <- read_function_lifecycles(skill_dir, functions_dir)
  reference_files <- list_reference_files(skill_dir)
  n_errors <- report_problems(file.path(skill_dir, "SKILL.md"), check_skill_file(skill_dir, lifecycles)) +
    sum(map_int(reference_files, \(file) report_problems(file, check_reference_file(file, lifecycles))))
  n_errors == 0
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("Usage: Rscript check-skill.R <skill-dir> <functions-dir>")
if (!check_skill(args[[1]], args[[2]])) quit(status = 1)
