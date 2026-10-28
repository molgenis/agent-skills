# Recipe: Sensitivity analyses and comparisons

## Goal
Run the main and sensitivity analyses through one pipeline, then compare them in one table and one plot.

## Steps
1. Describe the analyses as data:

```r
analyses <- tribble(
  ~analysis,                    ~df,           ~covariates,
  "Main (adjusted)",            "D",           list(c("covariate1", "covariate2")),
  "Unadjusted, complete cases", "D_complete",  list(character()),
  "Unadjusted, full sample",    "D_full",      list(character())
)

run_analysis <- function(df, covariates, conns, outcome = "outcome", exposure = "exposure") {
  fit <- ds.glmSLMA(formula = make_formula(outcome, exposure, covariates),
                    family = "binomial", dataName = df, datasources = conns)
  dh.lmTab(model = fit, type = "glm_slma", coh_names = names(conns), direction = "wide",
           ci_format = "separate", family = "binomial", digits = 10)
}

results <- analyses |>
  mutate(coefs = map2(df, covariates, \(d, covs) run_analysis(d, unlist(covs), conns))) |>
  select(analysis, coefs) |>
  unnest(coefs)
```
2. Leave one cohort out:

```r
leave_one_out <- function(df, covariates, conns) {
  names(conns) |>
    set_names() |>
    map(\(left_out) run_analysis(df, covariates, conns[names(conns) != left_out])) |>
    list_rbind(names_to = "left_out")
}
```
3. Strata: subset server-side (`ds.filter` / `ds.dataFrameSubset`), run per stratum, and bind with
   `names_to = "stratum"`. Alternatively, fit interaction terms and report the `exposure:modifier` rows.
4. One-stage pooled (`ds.glm` with cohort indicators) vs two-stage (`ds.glmSLMA`): tag each with
   `analysis = "One-stage"` / `"Two-stage"`.
5. Compare in a table (`pivot_wider(names_from = analysis, values_from = cell)`) and with
   `plot_forest_comparison()` (forest-plots.md).

## Pitfalls
- Report `n_obs` and `n_coh` per analysis. Differences can come from a changed cohort mix rather
  than the method.
- Use the same pooled estimator in every analysis.
- Stratum subsets may fail disclosure in small cohorts. Use `tryCatch`, record the failure, and
  don't hide it.
- Interaction-term names depend on factor coding (e.g. `exposure2:sex2`). Check with `ds.levels`
  before filtering.
