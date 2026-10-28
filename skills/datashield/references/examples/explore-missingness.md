# Recipe: Explore missingness

**Goal:** Describe missingness per cohort before choosing complete-case analysis or imputation, and compare included with excluded participants.

## Pattern
1. `stats <- dh.getStats(df, vars)`, then `dh.createTableOne(stats, vars, type = "cohort", coh_direction = "cols", inc_missing = TRUE, cont_format = "med_iqr", perc_denom = "total")`. Filter `is.na(category)` for missing rows. Do this separately for exposures, covariates and outcomes.
2. Per model, build a complete-case flag (`dh.defineCases(type = "all")`) over exposure + outcome + covariates, restricted to the cohorts in that model. Collect the flags per cohort with `ds.dataFrame`, `ds.dataFrameFill`, `ds.asFactor` each column, then `dh.getStats` on the flags.
3. Optionally regress the outcome or covariates on the missingness flag.

## Pitfalls
- Very wide `dh.getStats` calls can be split into chunks of variables and recombined with `pmap(bind_rows)`.
- Keep a list of data queries for cohorts (variables entirely missing, instrument recorded for fewer rows than the score). These can be upload problems, not true missingness.
