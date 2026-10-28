# Recipe: Preparation workflow

**Goal:** Structure a multi-cohort preparation pipeline so it can be re-run, resumed and checked.

## Pattern
1. Split the work into numbered scripts: assign → exposures → outcome → covariates → merge → subsets → (impute) → analysis.
2. Declare variable lists as client-side vectors near the top, and reuse them for assigning, checking, selecting and table-making.
3. Store per-cohort details (table, which data frame, value codes) in a tibble and loop over it with `purrr::pwalk` / `pmap`. Don't copy-paste a call per cohort.
4. Target cohort-specific operations with `datasources = conns[<names>]` (dsBaseClient / dsTidyverseClient) or `conns = conns[<names>]` (dsHelper). Select by **names**: `conns[names(conns) != "cohort_a"]`.
5. Checkpoint slow steps with `datashield.workspace_save(conns, "<ws>")`. Resume with `datashield.login(logindata, restore = "<ws>")`.
6. After each block, check the result: `ds.dim`, `ds.colnames`, `dh.getStats(...)$continuous |> select(variable, cohort, valid_n, missing_n)`.
7. Clean up intermediate objects with `ds.rm(c(...))` before saving a workspace.

```r
cohort_ref <- tibble(cohort = c("cohort_a", "cohort_b"), value = c("101", "102"))
cohort_ref |>
  pwalk(function(cohort, value) {
    ds.filter(df.name = "df", tidy_expr = list(area_id == !!value),
              newobj = "df", datasources = conns[cohort])
  })
datashield.workspace_save(conns, "proj_step_3")
```

## Pitfalls
- `conns[!conns %in% c(...)]` compares connection objects, not names, so it selects the wrong servers. Use `names(conns)`.
- Leftovers such as `ONES`, `*_aux_nobj` and per-variable temporaries pile up. Remove them, or use `dh.tidyEnv(obj, type = "keep")` (deprecated, still in the reference).
- Saving a workspace on a subset (`workspace_save(conns[subset], ws)`) only saves those servers. If you then restore all servers from that name, the rest get nothing or a stale copy.
