# Recipe: Exporting tables

## Steps
1. CSV is the default deliverable:

```r
write_tables <- function(tables) {
  iwalk(tables, \(table, name) readr::write_csv(table, here::here("tables", paste0(name, ".csv"))))
}
write_tables(list(table_1 = table_1, table_2 = table_2))
```
2. LaTeX:

```r
table |>
  kableExtra::kbl(format = "latex", booktabs = TRUE, longtable = TRUE, linesep = "",
                  col.names = c("Variable", "Category", cohort_labels)) |>
  kableExtra::kable_styling(latex_options = "repeat_header") |>
  kableExtra::collapse_rows(1, valign = "top") |>
  write(here::here("tables", "table_s1.tex"))
```
3. PDF: see reports.md.
4. Word (check the package is installed first):
   `flextable::flextable(table) |> flextable::save_as_docx(path = "table_1.docx")`.

## Pitfalls
- `write_csv(path = )` is deprecated; use `file =`.
- Symbols such as ±, ≤ and ≥ need UTF-8 handling. Use xelatex for PDF.
- Exported tables should hold only aggregate results. Still check for small cells (suppressed
  values show as NA or "Failed") before publishing.
- Only write objects that the script actually creates. Writing an object defined in
  commented-out code errors or writes stale content.
