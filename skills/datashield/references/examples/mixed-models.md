# Recipe: Mixed models and fractional-polynomial trajectories

## Goal
Model repeated measures with `ds.lmerSLMA`. Choose the age shape by comparing
fractional-polynomial models, then fit exposure models on that shape.

## Steps
1. Decide which studies have repeated measures from `dh.getRmStats()`, using a rule written
   as code, not a hand-typed list.
2. Create age transformations with `dh.makeAgePolys()` (superseded but available). Default
   names are `<age>_m_2, _m_1, _m_0_5, _0_5, _2, _3` and `<age>_log`.
3. Past projects converted the ID to integer (`ds.asInteger`) before mixed models. The
   reason wasn't recorded.
4. Generate candidate formulas with `dh.makeLmerForm()`. This gives every pair of age terms
   plus each single term, so 8 terms make 36 models.
5. Compare with `dh.lmeMultPoly()`: `$fit` ranks models by log-likelihood summed over studies
   (best first) and `$convergence` flags failures.
6. Refit the chosen shape with exposure and covariates (`fixed`, plus `age_interactions` for
   different trajectories by exposure). Tidy with `dh.lmTab(type = "lmer_slma")`.
7. Studies without repeated measures get a fixed-effects model instead (see code). This is a
   modelling decision; state it in the methods.

## Code
```r
rm_stats <- dh.getRmStats(df = "outcome_long", outcome = "out_z", id_var = "child_id",
                          age_var = "age", conns = conns)
rm_studies <- rm_stats |> filter(cohort != "combined", n_meas_med > 1) |> pull(cohort)

dh.makeAgePolys(df = "outcome_long", age_var = "age", conns = conns[rm_studies])
ds.asInteger(x.name = "outcome_long$child_id", newobj = "child_id_int",
             datasources = conns[rm_studies])
ds.dataFrame(x = c("outcome_long", "child_id_int"), newobj = "outcome_long",
             datasources = conns[rm_studies])

age_terms <- c("age", paste0("age", c("_m_2", "_m_1", "_m_0_5", "_0_5", "_2", "_3", "_log")))
shape_forms <- dh.makeLmerForm(outcome = "out_z", id_var = "child_id_int",
                               age_vars = age_terms, random = "intercept")
shape_fit <- dh.lmeMultPoly(df = "outcome_long", formulae = shape_forms$formula,
                            poly_names = shape_forms$polys, conns = conns[rm_studies])
best_terms <- strsplit(shape_fit$fit$model[1], ",")[[1]]

exposure_forms <- dh.makeLmerForm(outcome = "out_z", id_var = "child_id_int",
                                  age_vars = best_terms, random = "intercept",
                                  fixed = c("exp_a", "cov_1", "cov_2"),
                                  age_interactions = "exp_a")
```

Mixing mixed and fixed models across studies (one row per study):
```r
spec <- per_study_spec |>
  mutate(model_type = if_else(cohort %in% rm_studies, "lmer", "glm"),
         formula = if_else(model_type == "lmer", paste0(formula, " + (1|child_id_int)"), formula))
fits <- spec |>
  mutate(fit = pmap(list(formula, cohort, model_type), \(formula, cohort, model_type)
                      fit_one_study(formula, cohort, model_type, "outcome_long", "gaussian", conns)))
```

```r
# functions.R
fit_one_study <- function(formula, study, model_type, data, family, conns) {
  tryCatch(
    if (model_type == "lmer") {
      ds.lmerSLMA(formula = formula, dataName = data, datasources = conns[study])
    } else {
      ds.glmSLMA(formula = formula, family = family, dataName = data,
                 datasources = conns[study])
    },
    error = function(e) {
      message("Failed: ", formula, " in ", study, ": ", conditionMessage(e))
      NULL
    })
}

is_lmer_converged <- function(fit) {
  all(stringr::str_detect(fit$Convergence.error.message, "no convergence error reported"))
}
```

For predicted trajectories use `dh.predictLmer(model, new_data, coh_names)`, then
`dh.trimPredData(pred, coh_names, age, min, max)` to cut predictions to each study's observed
age range. These weren't used in the reviewed projects.

## Pitfalls
- `ds.lmerSLMA` has no `family`; it is Gaussian only. Use `ds.glmerSLMA(family = ...)` for
  binary or count outcomes.
- For non-convergence, try `optimizer`, `control_type`/`control_value` or `REML`
  (see `?ds.lmerSLMA` Details) before dropping a study.
- With `random = "slope"`, `dh.makeLmerForm` builds the slope term from the whole `age_vars`
  vector (1.7.2 source). Print the formulas and check them before fitting.
- `dh.lmeMultPoly` fits every candidate in every study, which is slow. Run it once, save the
  result, and don't refit inside the exposure loop.
