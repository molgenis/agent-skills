# Recipe: Running models across studies

## Goal
Fit every row of a model spec, keep going when one model or study fails, and record why.

## Which function
| Need | Function |
|---|---|
| Per-study estimates + random-effects pooled estimate | `ds.glmSLMA(formula, family, dataName, datasources)` |
| One model on virtually pooled data | `ds.glm(formula, data, family, datasources)`; include a study term |
| Different formula per study (one row per study) | `dh.multGLM(df, ref, family, conns)` |
| Linear mixed model | `ds.lmerSLMA(formula, dataName, datasources)`; see `mixed-models.md` |
| Binary/count mixed model | `ds.glmerSLMA(formula, dataName, family, datasources)` |

Note the argument names: `ds.glm` takes `data =`, the SLMA functions take `dataName =`.

## Steps
1. Fit each spec row inside `tryCatch` so one failure doesn't stop the loop. Store `NULL`
   and the message.
2. For a failed SLMA model, refit study by study to find which study fails. Call
   `DSI::datashield.errors()` for the server-side message.
3. Fix the cause: collapse sparse categories, raise `maxit`, or drop the study. Record the
   exclusion in `study_exclusions` with a reason, then rerun from the spec.
4. Save the spec and the fits with `saveRDS()` (see `collecting-results.md`).

## Code
```r
model_fits <- model_spec |>
  mutate(fit = pmap(list(formula, data, studies), \(formula, data, studies)
                      fit_slma_safely(formula, data, studies, "binomial", conns)),
         failed = map_lgl(fit, is.null))

failed_studies <- model_fits |>
  filter(failed) |>
  mutate(per_study = pmap(list(formula, data, studies), \(formula, data, studies)
                            fit_by_study(formula, data, studies, "binomial", conns)),
         failing = map(per_study, \(fits) names(keep(fits, is.null)))) |>
  select(model_id, failing)
```

```r
# functions.R
fit_slma_safely <- function(formula, data, studies, family, conns) {
  tryCatch(
    ds.glmSLMA(formula = formula, family = family, dataName = data,
               datasources = conns[studies]),
    error = function(e) {
      message("Failed: ", formula, " on ", data, ": ", conditionMessage(e))
      NULL
    })
}

fit_by_study <- function(formula, data, studies, family, conns) {
  studies |>
    set_names() |>
    map(\(study) fit_slma_safely(formula, data, study, family, conns))
}
```

### Per-study spec with `dh.multGLM`
```r
per_study_fits <- dh.multGLM(df = "analysis_df", ref = per_study_spec,
                             family = "gaussian", conns = conns)
per_study_fits |> filter(!converged) |> select(cohort, exposure, outcome)
```

### Virtually pooled model with a study term
```r
tibble(study = names(conns), study_id = seq_along(names(conns))) |>
  pwalk(\(study, study_id) ds.mutate(df.name = "analysis_df",
          tidy_expr = list(study_id = !!study_id), newobj = "analysis_df",
          datasources = conns[study]))
ds.asFactor(input.var.name = "analysis_df$study_id", newobj.name = "study_f", datasources = conns)
ds.dataFrame(x = c("analysis_df", "study_f"), newobj = "analysis_df", datasources = conns)
pooled_fit <- ds.glm(formula = "out_x ~ exp_a + cov_1 + study_f", data = "analysis_df",
                     family = "binomial", datasources = conns)
```

## Pitfalls
- In `dh.multGLM`, `converged = FALSE` means only that the call errored or returned
  "POTENTIALLY DISCLOSIVE". It does not inspect iterative convergence (1.7.2 source).
  Check the fits too.
- `dh.multGLM` in dsHelper 1.7.0/1.7.2 has no `type` argument and fits only `ds.glmSLMA`.
  For mixed models write a separately named helper (see `mixed-models.md`).
- One study's error fails the whole `ds.glmSLMA` call, so find the study rather than
  guessing.
- Disclosure blocks (small cells, saturated models) are protections. Respond with coarser
  categories or by dropping the study, with the reason recorded. Never work around them.
- Fitting many models takes a long time. Save fits after each block so a dropped connection
  doesn't lose them.
