# Recipe: Analyse imputed data

**Goal:** Build analysis data frames for every imputation, fit the models, pool with Rubin's rules within cohort, then meta-analyse across cohorts.

## Pattern
1. **Naming:** carry the `.i` suffix through every derived object: `imp_df.i`, `imp_full.i`, `imp_<outcome>.i`.
2. **Per-imputation merges:**
```r
imp <- as.character(1:5)
walk(imp, ~ ds.merge(x.name = paste0("imp_df.", .x), y.name = "exposures",
                     by.x.names = "id", by.y.names = "id",
                     all.x = FALSE, all.y = FALSE,
                     newobj = paste0("imp_full.", .x)))
walk(imp, ~ ds.merge(x.name = "outcome_cc", y.name = paste0("imp_full.", .x),
                     by.x.names = "id", by.y.names = "id",
                     newobj = paste0("imp_out.", .x)))
```
   Check that every imputation has the same dims and that `missing_n == 0` for analysis variables.
3. **Fit per imputation**, either all cohorts in one `ds.glmSLMA`, or per cohort and model with `dh.multGLM` (dh.buildModels output, handles failures):
```r
fits <- map(imp, ~ ds.glmSLMA(formula = "y ~ x + c1 + c2",
                              dataName = paste0("imp_out.", .x), family = "gaussian"))
```
4. **Pool within cohort:**
```r
pooled <- dh.pool(imputed_glm = fits, type = "glm_slma",
                  coh_names = names(conns), family = "gaussian", exponentiate = FALSE)
```
   With `dh.multGLM` output: bind the per-imputation tibbles with `.id = "imputation"`, keep `converged == TRUE`, `group_split` by cohort × model, then call `dh.pool(.x$fit, type, coh_names = .x$cohort[[1]], family)` on each group.
5. **Meta-analyse** the pooled estimates (`pooled_mean`, `pooled_se`) with `metafor::rma` per variable (see the worked example), or `dh.metaSepModels`. Exponentiate only at the end.
6. **Imputed descriptives:** average `dh.getStats` across imputations (see multiple-imputation).

## Pitfalls
- Pool only fits that converged in **every** imputation. Partial sets bias the between-imputation variance. If pooled rows come out `p_value = NaN`, check that each group has all m fits.
- `dh.multGLM` flags disclosure refusals (`"POTENTIALLY DISCLOSIVE"`) as `converged = FALSE`. Filter on that, don't assume success.
- `coh_names` must match the order of cohorts in the fit.
