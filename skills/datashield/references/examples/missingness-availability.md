# Recipe: Availability, missingness and sample-flow tables

## Steps
1. Which cohorts have which variables:

```r
availability <- dh.anyData(df = "D", vars = all_vars, conns = conns)
```
   This gives variable × cohort logicals. Count cohorts per variable with
   `rowSums(across(-variable))`, or draw a `geom_tile` heatmap.
2. Class discrepancies across cohorts: `dh.classDiscrepancy(df = "D", vars = all_vars, conns = conns)`.
3. High-missingness list:

```r
list_high_missingness <- function(stats, threshold = 30) {
  bind_rows(
    stats$continuous |> select(variable, cohort, missing = missing_perc),
    stats$categorical |> distinct(variable, cohort, missing = perc_missing)
  ) |>
    filter(cohort != "combined", missing >= threshold, missing < 100)
}
```
4. Small-cell check before modelling: in `stats$categorical`, list rows with
   `value < nfilter.tab` by cohort (threshold from `ds.listDisclosureSettings()`), then collapse
   those categories.
5. Complete-case N matching the model sample:

```r
count_complete_cases <- function(df, vars, conns) {
  dh.defineCases(df = df, vars = vars, type = "all", new_obj = "cc_flag", conns = conns)
  ds.dataFrameSubset(df.name = df, V1.name = "cc_flag", V2.name = "1",
                     Boolean.operator = "==", newobj = paste0(df, "_cc"), datasources = conns)
  ds.dim(paste0(df, "_cc"), type = "both", datasources = conns)
}
```
6. Flowchart numbers: run `ds.dim(x, type = "combine")` on each successive data frame and subtract.
7. Selection check: regress a complete-case indicator on the outcome (plus cohort indicators) with
   `ds.glm`, and show the ORs in a forest plot (forest-plots.md).

## Pitfalls
- `dh.anyData` TRUE means "at least one value", not "enough to model". Also check `valid_n`.
- Subtracting released counts can produce a published number below the disclosure threshold.
  Report differences under `nfilter.tab` as "<k".
- Don't work around refused small cells with overlapping subsets.
- Use one function with a `threshold` argument rather than copy-pasted blocks per threshold.
