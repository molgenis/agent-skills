# Recipe: Assign tables and check variable availability

**Goal:** Load the same harmonised tables in every cohort, find variables that are missing or have a different class, and make every cohort's columns identical.

## Pattern
1. Build a tibble: cohort × table × target symbol × variables.
2. Assign each row with `datashield.assign.table(conns[cohort], symbol, table, variables)`.
3. Run `dh.classDiscrepancy(df, vars)` and look at rows where `discrepancy == "yes"`. A class of `NULL` means the variable is absent in that cohort.
4. Run `ds.dataFrameFill(df, df)` to add all-NA columns where they are missing.
5. Re-run `dh.classDiscrepancy` to confirm.
6. Use `dh.anyData(df, vars)` to find variables that exist but are entirely NA in a cohort. Its output feeds `dh.buildModels`.
7. If a cohort holds a variable that must not be used (e.g. a known-bad derivation), drop it, then add it back as NA so the columns still match.

```r
tables <- tibble(cohort = rep(c("cohort_a", "cohort_b"), each = 2),
                 table = c("<a_nonrep>", "<a_rep>", "<b_nonrep>", "<b_rep>"),
                 symbol = rep(c("nonrep", "rep"), 2)) |>
  mutate(vars = if_else(symbol == "nonrep", list(nonrep_vars), list(rep_vars)))

tables |> pwalk(function(cohort, table, symbol, vars) {
  datashield.assign.table(conns = conns[cohort], symbol = symbol,
                          table = table, variables = vars)
})

avail <- dh.classDiscrepancy(df = "nonrep", vars = nonrep_vars)
avail |> filter(discrepancy == "yes")
ds.dataFrameFill("nonrep", "nonrep")
dh.anyData(df = "nonrep", vars = c("exposure", "outcome"))

# Fill one variable for chosen cohorts only
ds.mutate(df.name = "nonrep", tidy_expr = list(x = NA), newobj = "nonrep",
          datasources = conns[c("cohort_a")])

# Replace a bad variable with NA in chosen cohorts
ds.select("rep", list(-x), newobj = "rep", datasources = conns[bad])
ds.mutate("rep", list(x = NA), newobj = "rep", datasources = conns[bad])
```

## Pitfalls
- `ds.dataFrameFill` **does not give factors the same levels everywhere**. Follow it with the factor-repair recipe (harmonise-classes-and-factor-levels).
- Before filling, `ds.summary` / `dh.getStats` fail if any cohort lacks the variable. So fill first, or restrict `conns`.
- Keep the old `datashield.assign(value=)` only for legacy code. The reference prefers `datashield.assign.table`.
- A variable can sit in a separate table for one cohort. Assign that table under its own symbol and `ds.merge` it in for that cohort only.
- A cohort may use a name prefix, or a different name for the same concept. Fix it with `ds.rename(df.name, list(new = old), datasources = conns[cohort])` before filling.
- Column names that won't parse can be dropped by position with `ds.dataFrameSubset(..., rm.cols = <index>)` and an always-true condition (`V1.name = V2.name = "df$age"`, `"=="`).
