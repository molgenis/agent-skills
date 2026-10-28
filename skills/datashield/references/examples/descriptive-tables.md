# Recipe: Descriptive tables (Table 1, per-cohort, by group, sample comparison)

## Steps
1. Get statistics once per sample, in a named list:

```r
samples <- c(all = "D", group_a = "D_a", group_b = "D_b")
stats <- map(samples, \(df) dh.getStats(df = df, vars = table_vars, conns = conns))
```
2. Labels come from CSV files:
   - `var_labs`: variable, var_label.
   - `cat_labs`: variable, category, cat_label. Every category present must be covered, or the
     call errors.
   - `coh_labs`: cohort, cohort_labs. Cover every cohort *including* "combined"; put "(n = …)" in
     these labels.
3. Table 1:

```r
make_table_one <- function(stats, vars, var_labs, cat_labs, type = "combined") {
  dh.createTableOne(stats = stats, vars = vars, var_labs = var_labs, cat_labs = cat_labs,
                    type = type, coh_direction = "cols", cont_format = "mean_sd",
                    inc_missing = TRUE, sig_digits = 3, perc_denom = "valid")
}
```
   With `coh_direction = "cols"` the columns are `variable, category, <one per cohort>`. Continuous
   rows have a category label such as "Mean ± SD", and missing rows have category NA. When
   `var_labs` is given, `variable` holds the *label*.
4. Table by group (e.g. outcome yes/no), with cohorts × groups as columns:

```r
make_group_table <- function(stats_by_group, cohorts, ...) {
  stats_by_group |>
    map(\(s) make_table_one(s, ..., type = "cohort")) |>
    list_rbind(names_to = "group") |>
    pivot_wider(names_from = group, values_from = all_of(cohorts),
                names_glue = "{.value}_{group}")
}
```
5. Custom formats straight from `dh.getStats` (median (p5, p95), n (%), missing n (%)):

```r
format_continuous <- function(stats, digits = 1) {
  stats$continuous |>
    transmute(variable, cohort,
      value = sprintf("%.*f (%.*f, %.*f)", digits, perc_50, digits, perc_5, digits, perc_95),
      missing = paste0(missing_n, " (", round(missing_perc, 1), ")"))
}

format_categorical <- function(stats, percent = "perc_valid") {
  stats$categorical |>
    transmute(variable, cohort, category,
              value = paste0(value, " (", round(.data[[percent]], 1), ")"))
}
```
   Then `pivot_wider(names_from = cohort, values_from = value)` for per-cohort supplementary
   tables. Split wide tables into two sets of cohort columns.
6. Sample comparison (original vs analysis vs excluded vs imputed):

```r
compare_samples <- function(stats_list, ...) {
  stats_list |>
    map(\(s) make_table_one(s, ..., type = "combined")) |>
    map(\(t) select(t, variable, category, combined)) |>
    list_rbind(names_to = "sample") |>
    pivot_wider(names_from = sample, values_from = combined)
}
```
   Make the excluded sample server-side with
   `dh.makeExcludedDf(original_df = "D_full", final_df = "D", id_var = "id", new_obj = "D_excluded")`.
7. Imputed data: run `dh.getStats` per imputation, then average `value:perc_total` (categorical)
   and `mean:missing_perc` (continuous) by cohort, variable and category.

## Pitfalls
- `sig_digits` may be applied as significant figures (`signif()`), not decimal places. Check the
  output.
- Don't recode the continuous category label yourself before checking what your dsHelper version
  returns (e.g. "Mean ± SD").
- The `coh_labs` columns must be named `cohort` and `cohort_labs`.
- State the percentage denominator (`perc_denom = "valid"` vs `"total"`) in the footnote.
- In `dh.getStats`, categorical missingness is `perc_missing` and continuous missingness is
  `missing_perc`. The names differ.
