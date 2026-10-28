# Recipe: Collecting and saving model results

## Goal
Turn fits into one tidy long table that tables, figures and meta-analysis read from disk.

## Steps
1. Tidy each fit with `dh.lmTab(model, type, coh_names, direction, ci_format, family,
   digits, exponentiate)`. Use `type` "glm_ipd", "glm_slma" or "lmer_slma"; `coh_names` must
   be the studies in the order they were fitted.
2. Keep the spec columns (model_id, analysis, outcome, exposure, adjustment, stratum) and
   unnest. Filter out intercepts and covariates only when making tables, not here.
3. Save the spec, the raw fits, the tidy table and a table of failures (model_id, study,
   reason) with `saveRDS()` in `results/`. Write CSV copies of the tidy table for co-authors.
4. Tables, figures and the report start with `readRDS()`. They never depend on objects left
   in the global environment.

## Code
```r
tidy_results <- model_fits |>
  filter(!failed) |>
  mutate(coefs = map2(fit, studies, \(fit, studies) dh.lmTab(
    model = fit, type = "glm_slma", coh_names = studies, direction = "wide",
    ci_format = "separate", family = "binomial", exponentiate = TRUE))) |>
  select(model_id, analysis, outcome, exposure, adjustment, coefs) |>
  unnest(coefs)

save_result(list(spec = model_spec, fits = model_fits, failures = failed_studies),
            "08-models")
save_result(tidy_results, "08-models-tidy")
write_csv(tidy_results, here("results", "08-models-tidy.csv"))
```

```r
# functions.R
save_result <- function(object, name) {
  dir.create(here("results"), showWarnings = FALSE)
  saveRDS(object, here("results", paste0(name, ".rds")))
}
```

## Pitfalls
- The `dh.lmTab` output for SLMA fits includes a `cohort == "combined"` row (the pooled
  estimate). Keep it in the saved table and filter it when needed.
- When fits are imputation-specific, pool with `dh.pool(imputed_glm, type, coh_names, family,
  exponentiate)` before tidying (see the imputation recipe).
- An Rmd rendered from the driver silently reads the caller's objects. Read results in its
  setup chunk so it renders on its own.
