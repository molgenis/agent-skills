# Recipe: Derive variables

**Goal:** Compute new variables (indices, unit conversions, cohort-harmonised versions, cohort dummies) and split one server into sub-cohorts.

## Pattern
1. Arithmetic: `ds.mutate(df, list(bmi = weight / (height / 100)^2), newobj = df)`. The older form is `ds.assign(toAssign = "df$w/((df$h/100)^2)", newobj = "bmi")` and then `ds.dataFrame`.
2. Unit conversion works the same way (days → months: `age_d / 30.4375`).
3. **Harmonise across cohorts** when cohorts store a concept in different source variables. Assign the same target name from a different source per cohort subset, then join:
```r
ds.mutate("df", list(ga = ga_lmp), newobj = "df", datasources = conns[names(conns) != "cohort_b"])
ds.mutate("df", list(ga = ga_us),  newobj = "df", datasources = conns["cohort_b"])
```
4. Cohort dummies come from the cohort-code variable. Get the codes from `dh.getStats(df, "cohort_code")$categorical` (rows with `value > 0`), then:
```r
codes |> pwalk(function(dummy, value) {
  ds.Boole(V1 = "df$cohort_code", V2 = value, Boolean.operator = "==",
           numeric.output = TRUE, na.assign = "0", newobj = dummy)
})
ds.dataFrame(c("df", codes$dummy), newobj = "df")
```
5. Sub-cohorts: when one server hosts several sub-studies (logged in once per sub-study name), filter each connection by its area or centre code (see prep-workflow).
6. Rename with `ds.rename(df, list(new = old), newobj = df)`. Use it for cohort-specific prefixes and auto-generated reshape names.

## Pitfalls
- When harmonising by cohort subset, cohorts with no source get no column. Run `ds.dataFrameFill` afterwards.
- `ds.make` / `ds.assign` produce standalone vectors that must be joined back. `ds.mutate` avoids that step.
- `ds.Boole(na.assign = )` takes a string: `"NA"`, `"1"` or `"0"`.
- Renaming 100 columns one by one is slow and error-prone. Build the `new = old` list programmatically (e.g. strip a prefix) rather than writing it out.
