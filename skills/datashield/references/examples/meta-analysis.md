# Recipe: Meta-analysis and heterogeneity

## Goal
Pool cohort estimates with a stated estimator and report heterogeneity.

## Options
1. `ds.glmSLMA(combine.with.metafor = TRUE)` returns `SLMA.pooled.ests.matrix` with columns
   `pooled.ML, se.ML, pooled.REML, se.REML, pooled.FE, se.FE`. The `dh.lmTab` "combined" row uses ML.
2. `dh.metaManual(model = slma_fit, method = "REML")` returns a list with the metafor fit per
   coefficient (`model`) and a tibble of `term, coef, se` (`coefs`).
3. Models fitted separately per cohort (`dh.multGLM` output plus `model_id`):

```r
meta <- dh.metaSepModels(input = "fit", ref = fits |> filter(converged),
                         exp = FALSE, method = "REML", output = "both")
```
   This returns per-cohort rows (with `weight_scaled`) and "combined" rows with
   `est, se, lowci, uppci, i2, t2, q, q_p, k, p, n_obs, metafor_obj`. `input = "stats"` takes an
   already tidy tibble (`model_id, cohort, variable, est, se, n_obs`).
4. Direct metafor on the tidy tibble (most transparent):

```r
meta_analyse <- function(coefs, method = "REML") {
  fit <- metafor::rma.uni(yi = coefs$est, sei = coefs$se, method = method)
  tibble(cohort = "combined", est = fit$beta[1], se = fit$se,
         lowci = fit$ci.lb, uppci = fit$ci.ub, pvalue = fit$pval,
         i2 = fit$I2, tau2 = fit$tau2, q = fit$QE, q_p = fit$QEp,
         k = fit$k, n_obs = sum(coefs$n_obs))
}

pool_cohorts <- function(cohort_coefs, method = "REML") {
  pooled <- cohort_coefs |>
    group_by(analysis, outcome, variable) |>
    group_modify(\(d, key) meta_analyse(d, method)) |>
    ungroup()
  bind_rows(cohort_coefs, pooled)
}
```
5. For binomial models, pool on the log scale, then `mutate(across(c(est, lowci, uppci), exp))`.
6. Report I², τ², Q and its p-value with each pooled estimate (table columns or forest-plot title),
   and state the estimator (ML / REML / FE) in methods and captions.
7. With many exposures, estimate the effective number of tests from the exposure correlation
   matrix (e.g. the Galwey method), then apply a Bonferroni correction.

## Pitfalls
- `dh.metaManual`'s `method` may be ignored: dsHelper source hard-codes ML. Check the result's
  `method`, or use option 4 for REML or FE.
- `dh.metaSepModels`:
  - Always pass `exp` explicitly (the default `NULL` errors).
  - With `output = "meta"`, check whether `exp = TRUE` was applied; exponentiate yourself if not.
  - Use `input = "fit"` or `"stats"` only.
- Never pool odds ratios. Pool log-ORs and exponentiate afterwards.
- With k = 2 cohorts τ² is unstable. Show the fixed-effect estimate alongside, or say so.
- The combined mean and SD from `dh.getStats` are fixed-effect pools of descriptive statistics, not
  a meta-analysis of model estimates.
- Use the same pooled estimator in tables, plots and text.
