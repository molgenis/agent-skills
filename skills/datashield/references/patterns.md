# DataSHIELD patterns and pitfalls

Only what can't be inferred from general R knowledge or the function references: how
DataSHIELD behaves across servers, the workarounds, and known bugs. Checked against DSI 1.7.1,
dsBaseClient 6.3.5, dsTidyverseClient 1.1.1 and dsHelper 1.7.5.

## Targeting servers

- Select servers by name: `conns[names(conns) != "study_b"]`. `conns[!conns %in% x]` compares
  connection objects and selects the wrong servers.
- Run outcome- or variable-specific steps only on servers that have the data, otherwise the
  call fails everywhere. Find them from `dh.anyData()` or `dh.getStats()` (`valid_n > 0`).
- Save a workspace on all servers. `datashield.workspace_save(conns[subset], ws)` saves only
  that subset, and restoring all servers from that name later gives the rest nothing.

## Harmonising variables across cohorts

- `dh.classDiscrepancy(df, vars)` returns `variable`, `discrepancy`, then one class column per
  cohort. Class `NULL` means the variable is absent on that server.
- `ds.dataFrameFill(df, df)` adds missing columns as all-NA, but does **not** give factors the
  same levels. After filling, rebuild every factor with `ds.asFactor()`, which collects levels
  from all servers. Then drop the old column and join the new one:

```r
walk(factor_vars, \(v) ds.asFactor(input.var.name = paste0("D$", v), newobj.name = v))
ds.select("D", list(-all_of(!!factor_vars)), newobj = "D")
ds.dataFrame(x = c("D", factor_vars), newobj = "D")
```

- `ds.dataFrame(c("D", "x"))` when `D` already has `x` duplicates or renames the column, so
  always drop it first.
- Fill before any summary over all servers: `dh.getStats` and `ds.summary` fail if one server
  lacks the variable.

## Recoding into categories

`as.factor` isn't on dsTidyverse's default list of permitted functions, so `ds.mutate()` can't
create a factor. The pattern is case_when → asFactor → join:

```r
ds.case_when(list(D$age < 30 ~ "lt30", D$age >= 30 & D$age < 35 ~ "30_35", D$age >= 35 ~ "ge35"),
             newobj = "age_tmp")
ds.asFactor("age_tmp", "age_cat")
ds.changeRefGroup(x = "age_cat", ref = "30_35", newobj = "age_cat", reorderByRef = FALSE)
ds.dataFrame(x = c("D", "age_cat"), newobj = "D")
```

Write it once as a helper; projects repeat this block for every variable. `ds.asFactor` works on
the character output of `ds.case_when`. Collapse sparse levels before modelling, since small
cells cause disclosure failures later.

## Per-cohort derivations

- When cohorts hold the same concept in different source variables, create the target name
  per subset of servers, then fill:

```r
ds.mutate("D", list(ga = ga_lmp), newobj = "D", datasources = conns[names(conns) != "study_b"])
ds.mutate("D", list(ga = ga_us), newobj = "D", datasources = conns["study_b"])
ds.dataFrameFill("D", "D")
```

- Within-cohort z-scores need a round trip: get each cohort's mean and SD with `dh.getStats`,
  then assign per server. Pass `digits` explicitly: the default `digits = 2` feeds rounded
  values into the z-scores. For z-scores within age bands use `dh.zByGroup`.

```r
dh.getStats(df = "D", vars = "x", digits = 10)$continuous |>
  filter(cohort != "combined") |>
  pwalk(\(cohort, mean, std.dev, ...) ds.mutate("D", list(x_z = (x - !!mean) / !!std.dev),
                                                newobj = "D", datasources = conns[cohort]))
```

- `ds.Boole(na.assign = "0")` takes a string: `"NA"`, `"1"` or `"0"`.
- `dh.makeIQR` names new columns `<var>_iqr_c` (`type = "combine"`, pooled IQR) or
  `<var>_iqr_s` (`type = "split"`, within-cohort IQR).

## Repeated measures

- First or last measure per person within a band (`dh.makeStrata` is deprecated in favour of this):

```r
ds.filter("rep", list(age >= 0 & age <= 17), newobj = "rep_band")
ds.arrange("rep_band", list(desc(age)), newobj = "rep_band")   # drop desc() for the first
ds.group_by("rep_band", list(id), newobj = "rep_band")
ds.slice("rep_band", list(1), newobj = "out_last")
```

- `ds.reShape(v.names = )` must not include `timevar.name`, and `idvar.name` is the id only.
- `dh.getRmStats(df, outcome, id_var, age_var)` describes repeated data per cohort; its age
  range is the 5th–95th percentile, not the true min and max.
- For mixed models, convert the id to integer first (`ds.asInteger`). `ds.lmerSLMA` is Gaussian
  only; use `ds.glmerSLMA(family = )` otherwise. Fractional-polynomial shape selection:
  `dh.makeAgePolys` → `dh.makeLmerForm` → `dh.lmeMultPoly` (`$fit` ranks models by summed
  log-likelihood; it fits every candidate on every server, so run it once and save the result).

## Running models

- One failing server fails the whole `ds.glmSLMA` call. Wrap each fit in `tryCatch`, and on
  failure refit server by server (`datasources = conns[s]`) to find the server, then read
  `DSI::datashield.errors()`. Fix the cause or drop the server, and record why.
- `dh.multGLM` returns the ref columns plus `fit` and `converged`. `converged = FALSE` means
  the call errored or was refused as disclosive, not that iterations failed to converge.
- Use the same servers (and ideally the same complete-case sample) for crude and adjusted
  models, so they can be compared.
- Strata and sensitivity subsets need their own availability and disclosure checks: a server
  that works for the main model may fail for a stratum.
- `ds.glmSLMA` already pools: `SLMA.pooled.ests.matrix` has ML, REML and FE columns, and the
  `dh.lmTab` "combined" row uses ML.

## Meta-analysis

- `dh.metaManual` ignores `method` and always uses ML. For REML or FE, run
  `metafor::rma.uni(yi = est, sei = se, method = )` on the per-cohort estimates.
- `dh.metaSepModels` errors unless `exp` is given; always pass `exp = TRUE` or `FALSE`. `input`
  must be `"fit"` or `"stats"`.
- Pool log-odds and exponentiate afterwards.

## Multiple imputation with `ds.mice`

1. Build one data frame with only the imputation variables, harmonised as above.
2. Dry run to get each server's default `method` and `predictorMatrix`: `ds.mice(data, maxit = 0)`.
3. Edit them per server. **Only `method[var] <- ""` stops a variable being imputed**; zeroing
   its predictor row does not. Zero the id column so the id is never a predictor.
4. Impute each server with its own setup and `seed = "fixed"` (study-specific fixed seed; the
   default `NA` isn't reproducible). Outputs are `<newobj_df>.1` … `.m` (default
   `imputationSet.1…`) and a mids object.

```r
init <- ds.mice(data = "imp_in", maxit = 0)
setup <- names(conns) |> set_names() |> map(\(s) {
  method <- init[[s]]$method; method[!names(method) %in% cov_vars] <- ""
  pred <- init[[s]]$predictorMatrix; pred[, "id"] <- 0
  list(method = method, pred = pred)
})
iwalk(setup, \(x, s) ds.mice(data = "imp_in", m = 5, method = x$method,
                             predictorMatrix = x$pred, seed = "fixed",
                             newobj_df = "imp", datasources = conns[s]))
datashield.workspace_save(conns, "proj_imputed")
```

5. Analyse: fit per imputation, pool **within each cohort** with
   `dh.pool(type = "glm_slma", coh_names = <servers in fit order>)`, then meta-analyse across
   cohorts. Pool only models that succeeded in every imputation. `dh.pool(type = "glm_slma")`
   is broken before dsHelper 1.7.5.

## Disclosure-safe plots

- Plot from aggregates: `ds.histogram` return values (`$mids`, `$counts`; low-count bins come
  back as 0), percentiles from `dh.getStats`, or `ds.cor`.
- For custom distribution plots use `dh.getAnonPlotData`, whose values are 3-nearest-neighbour
  centroids. It appends a "combined" copy of all rows, so drop it. Never report min, max or
  extremes from these values, because the tails are pulled in. It fails if a server has no
  data on the variable, so subset `conns` first.
- `ds.histogram` returns one `histogram` object, not a list, for a single server or
  `type = "combine"`.
