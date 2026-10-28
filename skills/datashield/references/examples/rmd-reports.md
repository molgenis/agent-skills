# Recipe: Rmd reports

## Steps
1. The report reads saved results (`readRDS`) and never calls the servers, so it can be rendered
   anywhere.
2. Setup chunk:

```r
knitr::opts_chunk$set(echo = FALSE, message = FALSE, warning = FALSE, fig.pos = "H")
options(datashield.progress = FALSE)
```
   In the YAML, indent `latex_engine: xelatex` correctly under `output: pdf_document:`.
3. Render from `run-all.R`:
   `rmarkdown::render(here::here("R", "report.Rmd"), output_file = here::here("output", "report.pdf"))`.
   If the report relies on session objects instead of files, pass `envir = globalenv()` explicitly.
4. One table-styling function, not copied chunks:

```r
kable_by_cohort <- function(table, cohort_labels, group_labels, caption = NULL) {
  n_groups <- length(group_labels)
  knitr::kable(table, caption = caption,
               col.names = c("Variable", "Category", rep(group_labels, length(cohort_labels))),
               align = c("l", rep("c", ncol(table) - 1))) |>
    kableExtra::add_header_above(c(" " = 2, set_names(rep(n_groups, length(cohort_labels)), cohort_labels))) |>
    kableExtra::collapse_rows(columns = 1, valign = "top") |>
    kableExtra::kable_styling(font_size = 9) |>
    kableExtra::column_spec(1, width = "4cm")
}
```
   For grouped rows, add `kableExtra::pack_rows("Group A", 1, 4)`.
5. Figures: set `fig.width` / `fig.height` per chunk. Inline numbers with `` `r numbers$n_cohorts` ``
   (manuscript-numbers.md).
6. End with a short section on caveats and unavailable variables.

## Pitfalls
- Keep a single report file. A stale copy next to the real one, or a `render()` call pointing at
  the wrong name, produces outdated reports.
- Absolute template paths in the YAML break for everyone else.
- `collapse_rows()` only merges adjacent identical values; sort the table first.
