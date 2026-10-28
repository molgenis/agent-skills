# Recipe: Organising the output stage

## Goal
Build every table, figure and in-text number from saved client-side aggregate results, so outputs
can be rebuilt without re-querying the servers.

## Steps
1. Split the work in three: analysis scripts (talk to servers, save results with `saveRDS()`),
   output scripts (`tables.R`, `figures.R`, `text.R`) and `report.Rmd`, which only read those files.
2. Keep labels in reference CSVs, not in `case_when()` blocks: `variables.csv` (variable, var_label,
   family, order) and `cohorts.csv` (cohort, cohort_label, …).
3. Give every result tibble the same columns:
   `analysis, model_id, outcome, cohort, variable, est, se, lowci, uppci, pvalue, n_obs`
   (`cohort == "combined"` is the pooled row). All tables and plots consume this one shape.
4. Add labels and ordering once:

```r
add_labels <- function(results, var_labels, cohort_labels) {
  results |>
    left_join(var_labels, by = "variable") |>
    left_join(cohort_labels, by = "cohort") |>
    mutate(
      var_label = factor(var_label, levels = unique(var_labels$var_label)),
      cohort_label = factor(cohort_label, levels = cohort_labels$cohort_label)
    )
}
```
5. Round and format only at the last step (table cell or plot label).
6. A `run-all.R` sources the scripts in order with `here::here()` paths and renders the report last.

## Pitfalls
- Don't use `save.image()`: it writes `conns` and any login objects (tokens) to `.RData`. Save only
  named result objects with `saveRDS()`.
- `datashield.workspace_save()` saves the *server* workspace; it does not replace saving client results.
- Hard-coded `~/project/...` paths and `source()` names that don't match the actual file names break
  the pipeline for anyone else.
- Copy shared theme or label files into the project rather than sourcing them from a remote URL at
  runtime, or figures change when that file changes.
