# Recipe: Stratified, interaction and sensitivity analyses

## Goal
Derive each secondary analysis from the main model spec by changing one column, so it reuses
the same fitting and tidying code.

## Steps
1. **Strata.** Create one data frame per level with `ds.filter` (strata as a tibble, iterated
   with `pwalk`). Cross with the spec, remove the stratifying variable from the covariates, and
   recompute the studies per stratum, because small cells cause disclosure failures there.
2. **Interaction.** Replace the modifier covariate with `exposure*modifier`.
3. **Leave studies out.** Use `map(studies, setdiff, ...)`.
4. **Same-sample comparison.** Fit crude models on the complete-case sample of the adjusted
   model, so the N doesn't change with adjustment.
5. **Missingness.** Past projects regressed a complete-case indicator on outcome and
   covariates with `ds.glm(family = "binomial")`. They built the indicator with
   `dh.defineCases(type = "all")`, which is now deprecated; check it exists before relying on it.
6. Bind every variant into one spec with an `analysis` column, then fit with
   `running-models.md`.

## Code
```r
strata <- tibble(level = c("level_1", "level_2"), data = c("analysis_l1", "analysis_l2"))
strata |>
  pwalk(\(level, data) ds.filter(df.name = "analysis_df",
          tidy_expr = list(strat_var == !!level), newobj = data, datasources = conns))

model_vars <- unique(c(outcomes, exposures, covariate_sets$adjusted))
ds.select(df.name = "analysis_df", tidy_expr = list(!!!model_vars),
          newobj = "analysis_sel", datasources = conns)
ds.completeCases(x1 = "analysis_sel", newobj = "analysis_cc", datasources = conns)

stratified <- strata |>
  select(stratum = level, data) |>
  cross_join(model_spec |> select(-data)) |>
  mutate(covariates = map(covariates, setdiff, "strat_var"))

interaction <- model_spec |>
  filter(adjustment == "adjusted") |>
  mutate(covariates = map2(covariates, exposure, \(covariates, exposure)
                             c(setdiff(covariates, "strat_var"), paste0(exposure, "*strat_var"))))

all_spec <- bind_rows(
  main          = model_spec,
  stratified    = stratified,
  interaction   = interaction,
  drop_study_c  = model_spec |> mutate(studies = map(studies, setdiff, "study_c")),
  complete_case = model_spec |> mutate(data = "analysis_cc"),
  .id = "analysis") |>
  mutate(formula = pmap_chr(list(outcome, exposure, covariates), make_formula),
         model_id = paste(analysis, coalesce(stratum, "all"), outcome, exposure,
                          adjustment, data, sep = "__"))
```

## Pitfalls
- Removing the stratifying variable has to happen in the spec. Leaving it in a stratum model
  gives a constant term and an error.
- Strata usually need fewer studies than the main analysis. Re-run `dh.anyData` on each
  stratum data frame and add the disclosure exclusions to `study_exclusions`.
- Every variant needs its own `model_id`; otherwise results overwrite each other when joined.
- The study list of the main analysis must not silently differ from a sensitivity analysis.
  Report which studies each analysis used.
