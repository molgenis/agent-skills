# Recipe: Multiple imputation with ds.mice

**Goal:** Impute missing covariates within each cohort with `ds.mice`, keeping the exposure and outcome definitions intact.

## Pattern
1. **Prepare one data frame** holding only the imputation-model variables: id (kept for re-merging), covariates, exposures/auxiliaries. Factors must be harmonised first (classes decide the methods). Run `ds.dataFrameFill` so the columns are identical across cohorts.
```r
ds.select("analysis_df", list(id, !!cov_vars, !!aux_vars), newobj = "imp_in")
ds.dataFrameFill("imp_in", "imp_in")
```
2. **Dry run** to get the default method and predictor matrix per server:
```r
init <- ds.mice(data = "imp_in", maxit = 0)
init$cohort_a$method; init$cohort_a$predictorMatrix
```
   Defaults: `pmm` numeric, `logreg` binary factor, `polyreg` multi-level factor, `""` for complete columns.
3. **Edit per cohort:** only covariates are imputed, and the id is never a predictor.
```r
setup <- names(conns) |> set_names() |> map(function(coh) {
  meth <- init[[coh]]$method
  pred <- init[[coh]]$predictorMatrix
  meth[!names(meth) %in% cov_vars] <- ""   # do not impute non-covariates
  pred[, "id"] <- 0                         # id is not a predictor
  list(method = meth, pred = pred)
})
```
4. **Impute per cohort** (each server gets its own setup), with a fixed seed:
```r
imap(setup, ~ ds.mice(data = "imp_in", m = 5, maxit = 5,
                      method = .x$method, predictorMatrix = .x$pred,
                      seed = "fixed",
                      newobj_mids = "imp_mids", newobj_df = "imp_df",
                      datasources = conns[.y]))
datashield.workspace_save(conns, "proj_imputed")
```
   Output: `imp_mids` plus `imp_df.1` … `imp_df.m` on each server.
5. **Diagnostics:**
   - No missing values left in imputed covariates: `dh.getStats("imp_df.1", cov_vars)$categorical |> filter(is.na(category), cohort != "combined")`.
   - Imputed versus observed distributions: get `dh.getStats` per imputation, average across imputations, and lay the result next to the original table from `dh.createTableOne`:
```r
imp_stats <- map(1:5, ~ dh.getStats(paste0("imp_df.", .x), cov_vars))
avg <- list(
  categorical = map(imp_stats, "categorical") |> bind_rows() |>
    group_by(cohort, variable, category) |>
    summarise(across(where(is.numeric), mean), .groups = "drop"),
  continuous = map(imp_stats, "continuous") |> bind_rows() |>
    group_by(cohort, variable) |>
    summarise(across(where(is.numeric), mean), .groups = "drop"))
```
   - Non-covariate columns are unchanged (compare `missing_n` with the input).

## Pitfalls
- **Zeroing a variable's predictorMatrix row does not stop it being imputed.** Set `method[var] <- ""`. As a safety net, keep only `id` + covariates from each imputed set and re-merge the original non-covariates.
- Leaving `id` in the data with its predictorMatrix column at 1 makes the ID a predictor. Zero the column, or leave the ID out and re-merge by row order only if you are sure the order is kept.
- No `seed` means the imputations can't be reproduced. `seed = "fixed"` gives a study-specific fixed seed.
- `maxit = 0` is not an imputation. The default is 5.
- Impute before restricting to the outcome sample only if that matches your missing-data assumptions. One workable strategy: impute covariates on the complete-exposure sample, then inner-join to each complete-outcome dataset.
