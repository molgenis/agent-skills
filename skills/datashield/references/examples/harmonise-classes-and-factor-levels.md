# Recipe: Harmonise classes and factor levels

**Goal:** Make every categorical variable a factor with the same levels in every cohort, so models and tables work.

## Pattern
1. Find the variables to fix from `dh.classDiscrepancy` output. It returns `variable`, `discrepancy`, then one class column per cohort, named by cohort. Filter on a reference cohort's column, e.g. `filter(cohort_a == "factor")`.
2. Rebuild each one with `ds.asFactor("df$x", "x")`. With `forced.factor.levels = NULL` it collects the levels across **all** studies.
3. Drop the old columns and join the rebuilt ones back.
4. Set the reference level with `ds.changeRefGroup(x, ref, newobj, reorderByRef = FALSE)`, then join back.

```r
avail <- dh.classDiscrepancy(df = "df", vars = vars)
fix <- avail |> filter(cohort_a == "factor") |> pull(variable)
walk(fix, ~ ds.asFactor(input.var.name = paste0("df$", .x), newobj.name = .x))
ds.select("df", list(-all_of(!!fix)), newobj = "df")
ds.dataFrame(x = c("df", fix), newobj = "df")

ds.changeRefGroup(x = "df$binary", ref = "0", newobj = "binary", reorderByRef = FALSE)
```

## Pitfalls
- `dh.columnCast(target_class = "factor")` is deprecated in favour of `ds.mutate`, but neither one harmonises levels across studies. For factors, use `ds.asFactor`.
- `ds.dataFrame(c("df", "x"))` when `df` already has `x` duplicates or renames the column. Drop the old column first. The older code did this with `dh.dropCols(type = "remove")`; current form: `ds.select(list(-x))`.
- If a cohort only observes some levels, analyses can still fail for disclosure or empty cells. Collapse levels (see recode-and-categorise).
- Indicator variables built separately per cohort (e.g. complete-case flags) need fill → `ds.asFactor` per column → rebuild before `dh.getStats`.
