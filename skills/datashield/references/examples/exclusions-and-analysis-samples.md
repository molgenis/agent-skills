# Recipe: Exclusions and analysis samples

**Goal:** Define who is in the analysis (complete cases, valid cases, strata), and build the sensitivity datasets.

## Pattern
1. **Complete cases on chosen variables:**
   - `ds.filter("df", list(x == x & y == y), newobj = "df_cc")`. `x == x` is FALSE for NA, so incomplete rows are dropped.
   - `dh.defineCases(df, vars, type = "all", new_obj = "cc_flag")` followed by `ds.dataFrameSubset(df, V1.name = "cc_flag", V2.name = "1", Boolean.operator = "==", newobj = "df_cc")`. `dh.defineCases` is deprecated in favour of `ds.filter`.
   - `ds.completeCases(x1, newobj)` drops rows with NA in *any* column. Select the columns first.
2. **Valid case** (≥1 exposure and the outcome):
```r
dh.defineCases("df", exp_vars, type = "any", new_obj = "any_exp")
dh.defineCases("df", out_vars, type = "any", new_obj = "any_out")
ds.filter("df", list(any_exp == 1 & any_out == 1), newobj = "analysis_df")  # modern
```
   The older form used `ds.make("any_exp+any_out")` → `ds.Boole(== 2)` → `dh.findVarsIndex` → `ds.dataFrameSubset(keep.cols = idx)` per cohort. `ds.select` replaces the index juggling.
3. **Strata and subgroups:** `ds.filter("merged", list(parity == "nulli" & out == "no"), newobj = "nulli_no_out")`. Ensure complete cases on the stratifying variables so the Ns are right.
4. **Exposure-wide exclusions:** keep a client-side list of excluded variables with the reason (low variance, no info, collinear, missing) and select with `!variable %in% excluded`.
5. **Excluded sample** (for comparing included and excluded participants): `dh.makeExcludedDf(original_df, final_df, id_var, new_obj, type)` (deprecated, in the reference).
6. **Sensitivity datasets to build alongside the main one:** unadjusted model on the full sample, the complete-case sample (pre-imputation covariates restricted to the analysis sample), and restricted exposure ranges (e.g. per-cohort overlapping range via `ds.filter(list(x >= lo & x <= hi))`).

## Pitfalls
- Restrict cohorts lacking an outcome (`datasources = conns[have_it]`). Otherwise the filter errors or returns 0 rows.
- Very small subsets trigger disclosure refusals in later models. Check `ds.dim` per cohort.
