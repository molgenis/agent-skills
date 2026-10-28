# Recipe: Specifying models as data

## Goal
Describe every model as one row of a tibble: outcome, exposure, covariate set, data frame,
studies and formula. Code loops over the rows; nothing is copied per model.

## Steps
1. Put exposures, outcomes and named covariate sets in `config.R`.
2. Find which studies have any data on each variable with `dh.anyData()`.
3. Cross the dimensions with `tidyr::expand_grid()`, then derive the formula, studies and a
   unique `model_id` per row.
4. Use one set of studies for crude and adjusted versions of the same model, so they can be
   compared.
5. Keep study exclusions (disclosure, non-convergence) in a separate tibble with a reason.
   Apply it to the spec; never edit the study list by hand.

## Code
```r
exposures <- c("exp_a", "exp_b")
outcomes  <- c("out_x")
covariate_sets <- list(
  crude    = character(0),
  adjusted = c("cov_1", "cov_2", "cov_3")
)

availability <- dh.anyData(
  df = "analysis_df",
  vars = unique(c(exposures, outcomes, unlist(covariate_sets))),
  conns = conns)

model_spec <- expand_grid(
  outcome = outcomes, exposure = exposures,
  adjustment = names(covariate_sets), data = "analysis_df") |>
  mutate(
    covariates = unname(covariate_sets[adjustment]),
    formula = pmap_chr(list(outcome, exposure, covariates), make_formula),
    studies = map2(outcome, exposure, \(outcome, exposure) find_studies_with_data(
      availability, c(outcome, exposure, covariate_sets$adjusted))),
    model_id = paste(outcome, exposure, adjustment, data, sep = "__"))

study_exclusions <- tribble(
  ~pattern,              ~study,    ~reason,
  "out_x__exp_b",        "study_c", "disclosure: fewer than 3 cases in one exposure level"
)
model_spec <- model_spec |>
  mutate(studies = map2(model_id, studies, drop_excluded_studies, exclusions = study_exclusions))
```

```r
# functions.R
make_formula <- function(outcome, exposure, covariates) {
  paste(outcome, "~", paste(c(exposure, covariates), collapse = " + "))
}

find_studies_with_data <- function(availability, vars) {
  availability |>
    filter(variable %in% vars) |>
    select(-variable) |>
    select(where(all)) |>
    names()
}

drop_excluded_studies <- function(id, studies, exclusions) {
  excluded <- exclusions |> filter(stringr::str_detect(id, pattern)) |> pull(study)
  setdiff(studies, excluded)
}
```

### Alternative: one model per study with `dh.buildModels`
Use this to fit each study separately and meta-analyse afterwards (exposome-wide designs).
```r
per_study_spec <- dh.buildModels(
  avail_exp = dh.anyData(df = "analysis_df", vars = exposures, conns = conns),
  avail_cov = dh.anyData(df = "analysis_df", vars = covariate_sets$adjusted, conns = conns),
  avail_out = dh.anyData(df = "analysis_df", vars = outcomes, conns = conns))
# columns: cohort, exposure, outcome, covariates, formula ("out ~1+ exp + cov...")
```

## Pitfalls
- `dh.buildModels` adds every covariate that study has data on. The adjustment set can
  therefore differ between studies; check `covariates` before fitting.
- `dh.buildModels` pairs exposure and outcome availability by list position, not by study
  name (read from the 1.7.2 source). Make sure every study has at least one exposure, one
  outcome and one covariate available, or rows can be misattributed.
- Crude models computed on "studies with data on exposure and outcome" include more studies
  and participants than adjusted ones. Fix the studies (and ideally the complete-case sample,
  see `sensitivity-analyses.md`) before comparing.
- Formulas are character strings. A study missing a variable makes the whole SLMA call fail,
  so filter on availability first.
- Don't use nested lists of lists per model (`mod$crude$covariates`). Changing one field then
  needs a helper like `list_modify`. A tibble row can be changed with `mutate()`.
