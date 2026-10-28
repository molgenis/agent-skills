# Recipe: Model result tables

## Goal
Manuscript tables with terms as rows (including the reference category), cohorts and pooled as
columns, and cells "est (lowci, uppci)". Optionally add N and p-values.

## Steps
1. Start from the numeric tidy results tibble. `format_estimate()` is defined in forest-plots.md.
2. Make the table:

```r
make_results_table <- function(results, term_labels, digits = 2) {
  results |>
    inner_join(term_labels, by = "variable") |>
    mutate(cell = format_estimate(est, lowci, uppci, digits),
           term_label = factor(term_label, levels = term_labels$term_label)) |>
    arrange(term_label) |>
    select(term_label, cohort_label, cell) |>
    pivot_wider(names_from = cohort_label, values_from = cell)
}

add_reference_row <- function(table, reference_label, text = "Ref") {
  reference <- table |>
    slice(1) |>
    mutate(term_label = reference_label, across(-term_label, \(x) text))
  bind_rows(reference, table)
}
```
3. Strata or subgroups: build one table per stratum with the same function, combine with
   `list_rbind(names_to = "stratum")`, and use `kableExtra::pack_rows()` in the report.
4. Estimate and p-value per cohort: `pivot_wider(names_from = cohort, values_from = c(est, pvalue),
   names_glue = "{cohort}_{.value}")`, then put the columns in an explicit order.
5. Count columns (e.g. N with the outcome per exposure category) come from `dh.getStats` or
   `ds.table`. Where the server refuses a cell, write `"<k"`, with k = `nfilter.tab` from
   `ds.listDisclosureSettings()`.
6. Interaction tables: keep `direction = "wide"` and filter rows with `str_detect(variable, ":")`.

## Pitfalls
- Format at the end. `round()` drops trailing zeros (1.10 → 1.1); `sprintf()` keeps them.
- `dh.lmTab(ci_format = "paste")` turns `est` into a string that can't be sorted, plotted or
  exponentiated. Use `"separate"` and format yourself.
- Don't copy the reshaping block per stratum; write one function and map it.
- `select(order(colnames(.)))` interleaves cohorts and statistics alphabetically. List the columns explicitly.
- `write.csv(x)` without `file` prints to the console and writes nothing.
- Filtering cohort-specific results to p < 0.05 is for screening, not reporting.
