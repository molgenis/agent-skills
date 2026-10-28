# Recipe: From model objects to one tidy results tibble

## Goal
Get consistent rows (cohort × term × model) out of `ds.glm`, `ds.glmSLMA`, `ds.lmerSLMA`,
`dh.multGLM` and multiply imputed fits.

## Steps
1. Build formulas with one helper:

```r
make_formula <- function(outcome, exposure, covariates = character()) {
  paste(outcome, "~", paste(c(exposure, covariates), collapse = " + "))
}
```
2. Single model:

```r
slma_fit <- ds.glmSLMA(formula = make_formula("outcome", "exposure", c("covariate1")),
                       family = "binomial", dataName = "D", datasources = conns)
slma_tab <- dh.lmTab(model = slma_fit, type = "glm_slma", coh_names = names(conns),
                     direction = "wide", ci_format = "separate",
                     family = "binomial", digits = 10)
```
   - `ds.glm` (one-stage pooled): use `type = "glm_ipd"`. Add cohort indicator covariates for
     cohort fixed effects.
   - `ds.lmerSLMA`: use `type = "lmer_slma"`. With `extract_random = TRUE` the result is a list
     of coefficients and random effects.
   - Columns: `cohort, variable, est, se, pvalue, lowci, uppci, n_obs` (`n_coh` on the "combined"
     row). The intercept is renamed `"intercept"`.
3. Many models with different covariates per cohort:

```r
avail <- map(list(exp = exposures, out = outcomes, cov = covariates),
             \(v) dh.anyData(df = "D", vars = v, conns = conns))
models <- dh.buildModels(avail_exp = avail$exp, avail_cov = avail$cov, avail_out = avail$out) |>
  ungroup() |>
  mutate(model_id = paste(exposure, outcome, sep = "__"))
fits <- dh.multGLM(df = "D", ref = models, family = "gaussian", conns = conns)

tidy_fits <- function(fits, digits = 10) {
  fits |>
    filter(converged) |>
    mutate(coefs = map2(fit, cohort, \(f, coh) dh.lmTab(
      model = f, type = "glm_slma", coh_names = coh, direction = "wide",
      ci_format = "separate", digits = digits))) |>
    select(model_id, exposure, outcome, coefs) |>
    unnest(coefs) |>
    filter(cohort != "combined")
}
```
   Keep `filter(!converged)` as a "failed models" supplementary table.
4. Manual extraction from `ds.glmSLMA`, when you need the REML or FE pooled row, or the matrices:

```r
matrix_to_long <- function(m, cohorts, value_name) {
  as_tibble(as.matrix(m), rownames = "variable", .name_repair = "minimal") |>
    set_names(c("variable", cohorts)) |>
    pivot_longer(-variable, names_to = "cohort", values_to = value_name)
}

extract_slma_estimates <- function(fit, cohorts, estimator = "REML") {
  stopifnot(fit$num.valid.studies == length(cohorts))
  per_cohort <- left_join(matrix_to_long(fit$betamatrix.valid, cohorts, "est"),
                          matrix_to_long(fit$sematrix.valid, cohorts, "se"),
                          by = c("variable", "cohort"))
  pooled <- as_tibble(fit$SLMA.pooled.ests.matrix, rownames = "variable") |>
    transmute(variable, cohort = "combined",
              est = .data[[paste0("pooled.", estimator)]],
              se = .data[[paste0("se.", estimator)]])
  bind_rows(per_cohort, pooled) |>
    mutate(lowci = est - qnorm(0.975) * se, uppci = est + qnorm(0.975) * se)
}
```
   Per-study N: `fit$output.summary[[paste0("study", i)]]$Nvalid`; for `ds.glm`, `fit$Nvalid`.
5. Multiple imputation: fit each imputed data frame, group by `cohort, model_id`, and pool with
   Rubin's rules:

```r
pooled_imp <- fits_all_imputations |>
  filter(converged) |>
  group_by(cohort, model_id) |>
  group_map(\(d, key) dh.pool(imputed_glm = d$fit, type = "glm_slma",
                              coh_names = key$cohort, family = "gaussian"))
```
   Rename `pooled_mean` → `est` and `pooled_se` → `se`, then meta-analyse (meta-analysis.md).

## Pitfalls
- `dh.lmTab` `type` must be `"glm_ipd"`, `"glm_slma"` or `"lmer_slma"`. Rounding is `digits`
  (default 2).
- `coh_names` must follow the datasources order. Studies that fail disclosure drop out of
  `betamatrix.valid`, so names shift silently; check `num.valid.studies`.
- A factor level absent in one cohort makes the coefficient vectors differ, and SLMA pooling
  fails. Check with `ds.table` / `dh.anyData`, or fit per cohort (`dh.multGLM`) and use
  `dh.metaSepModels`.
- The returned element is `SLMA.pooled.ests.matrix` (some docs say `SLMA.pooled.estimates.matrix`).
- `dh.buildModels` with covariates may return a rowwise tibble; `ungroup()` it.
- Don't rely on `dh.multGLM(vary_df = TRUE)` to use a different data frame per row; check that it
  does in your installed version, or run one call per data frame.
- Use one set of CI column names (`lowci` / `uppci`) throughout.
- Select models by a condition, never by position (`fits[c(1:435, 437:443)]`).
