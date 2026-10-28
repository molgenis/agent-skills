# Builds the function reference for one DataSHIELD client package from its
# Rd files, so the skill's reference matches the documented API exactly.
# Usage: Rscript build-references.R <package-source-dir> <output.md>
# The source dir needs DESCRIPTION, NAMESPACE, R/ and man/ (e.g. from
# `git archive <release-tag> DESCRIPTION NAMESPACE R man`).

library(purrr)
library(stringr)

# Lifecycle badges are \ifelse{html}{<image>}{<text>}; keep only the text branch.
convert_rd_to_text <- function(x) {
  tag <- attr(x, "Rd_tag")
  if (identical(tag, "\\ifelse")) return(convert_rd_to_text(x[[3]]))
  if (identical(tag, "\\if") || identical(tag, "\\figure")) return("")
  if (is.list(x)) return(paste(map_chr(x, convert_rd_to_text), collapse = ""))
  as.character(x)
}

read_rd_text <- function(rd, tag) {
  section <- keep(rd, \(x) identical(attr(x, "Rd_tag"), tag))
  if (length(section) == 0) return("")
  str_squish(convert_rd_to_text(section[[1]]))
}

read_rd_usage <- function(rd) {
  section <- keep(rd, \(x) identical(attr(x, "Rd_tag"), "\\usage"))
  if (length(section) == 0) return("")
  str_trim(convert_rd_to_text(section[[1]]))
}

read_rd_arguments <- function(rd) {
  section <- keep(rd, \(x) identical(attr(x, "Rd_tag"), "\\arguments"))
  if (length(section) == 0) return(character(0))
  items <- keep(section[[1]], \(x) identical(attr(x, "Rd_tag"), "\\item"))
  map_chr(items, \(item) {
    name <- str_squish(convert_rd_to_text(item[[1]]))
    text <- shorten_text(str_squish(convert_rd_to_text(item[[2]])), 220)
    paste0("- `", name, "`: ", text)
  })
}

shorten_text <- function(text, max_chars) {
  first_sentences <- str_extract(text, "^.*?[.!?](\\s.*?[.!?])?(?=\\s|$)")
  text <- if (is.na(first_sentences)) text else first_sentences
  if (nchar(text) > max_chars) paste0(str_sub(text, 1, max_chars - 3), "...") else text
}

read_function_code <- function(function_name, r_dir) {
  bodies <- map(list.files(r_dir, "\\.[Rr]$", full.names = TRUE), \(file) {
    exprs <- tryCatch(parse(file, keep.source = FALSE), error = \(e) list())
    keep(exprs, \(e) is.call(e) && is.name(e[[1]]) && as.character(e[[1]]) %in% c("<-", "=") &&
      identical(as.character(e[[2]]), function_name))
  })
  paste(unlist(map(unlist(bodies), deparse)), collapse = "\n")
}

find_server_call_type <- function(code) {
  calls_assign <- str_detect(code, "datashield\\.assign")
  calls_aggregate <- str_detect(code, "datashield\\.aggregate")
  if (calls_assign && calls_aggregate) "assign + aggregate"
  else if (calls_assign) "assign" else if (calls_aggregate) "aggregate" else ""
}

# Packages mark lifecycle in the code (.Deprecated, lifecycle::deprecate_*), in an
# Rd badge, or both; the code wins because it decides what a call actually does.
find_lifecycle <- function(code, rd_text) {
  if (str_detect(code, "\\.Defunct\\(|deprecate_stop\\(")) return("defunct")
  if (str_detect(code, "\\.Deprecated\\(|deprecate_(warn|soft)\\(")) return("deprecated")
  if (str_detect(rd_text, fixed("[Deprecated]"))) return("deprecated")
  if (str_detect(rd_text, fixed("[Superseded]"))) return("superseded")
  ""
}

read_exported_names <- function(source_dir) {
  ns <- parseNamespaceFile(basename(source_dir), dirname(source_dir))
  ns$exports
}

describe_rd_file <- function(rd_file, exported, r_dir) {
  rd <- tools::parse_Rd(rd_file)
  name <- read_rd_text(rd, "\\name")
  if (!name %in% exported || read_rd_text(rd, "\\docType") %in% c("package", "data")) {
    return(NULL)
  }
  title <- read_rd_text(rd, "\\title")
  description <- read_rd_text(rd, "\\description")
  code <- read_function_code(name, r_dir)
  list(
    name = name,
    title = title,
    description = shorten_text(description, 400),
    usage = read_rd_usage(rd),
    arguments = read_rd_arguments(rd),
    type = find_server_call_type(code),
    lifecycle = find_lifecycle(code, paste(title, description))
  )
}

format_function_entry <- function(entry) {
  type_line <- if (nzchar(entry$type)) paste0("Server call: ", entry$type, "\n\n") else ""
  lifecycle_line <- if (nzchar(entry$lifecycle)) paste0("Lifecycle: ", entry$lifecycle, "\n\n") else ""
  usage_block <- if (nzchar(entry$usage)) paste0("```r\n", entry$usage, "\n```\n\n") else ""
  paste0(
    "## ", entry$name, "\n\n", entry$title, ". ", entry$description, "\n\n",
    type_line, lifecycle_line, usage_block, paste(entry$arguments, collapse = "\n"), "\n"
  )
}

format_index_table <- function(entries) {
  rows <- map_chr(entries, \(e) paste0("| `", e$name, "` | ", e$type, " | ", e$lifecycle, " | ", e$title, " |"))
  paste(c("| Function | Server call | Lifecycle | Purpose |", "|---|---|---|---|", rows), collapse = "\n")
}

write_reference <- function(source_dir, output_file) {
  description <- read.dcf(file.path(source_dir, "DESCRIPTION"))
  package <- description[1, "Package"]
  version <- description[1, "Version"]
  exported <- read_exported_names(source_dir)
  rd_files <- list.files(file.path(source_dir, "man"), "\\.Rd$", full.names = TRUE)
  entries <- compact(map(rd_files, describe_rd_file, exported, file.path(source_dir, "R")))
  header <- paste0(
    "# ", package, " ", version, " function reference\n\n",
    "Generated by `tools/build-references.R` from the ", package, " ", version,
    " Rd files. Do not edit by hand; regenerate instead.\n"
  )
  body <- map_chr(entries, format_function_entry)
  writeLines(c(header, format_index_table(entries), "", body), output_file)
  message(package, " ", version, ": ", length(entries), " functions -> ", output_file)
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) stop("Usage: Rscript build-references.R <package-source-dir> <output.md>")
write_reference(args[[1]], args[[2]])
