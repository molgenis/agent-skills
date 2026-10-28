# Recipe: Merge data frames

**Goal:** Combine non-repeated, wave-derived, outcome and exposure data frames.

## Pattern
1. Trim each side to the needed columns first: `ds.select("nonrep", list(!!!keep_vars), newobj = "nonrep_sub")`. `!!!` splices a character vector; `list(id, !!vec)` and `any_of(!!vec)` also work.
2. Left join onto the base sample:
```r
ds.merge(x.name = "nonrep_sub", y.name = "wave_sub",
         by.x.names = "id", by.y.names = "id",
         all.x = TRUE, all.y = FALSE, newobj = "merged")
```
3. Long + long on id and age: use `by.x.names = c("id", "age")` with full join (`all.x = all.y = TRUE`), e.g. outcome tables that arrive separately.
4. Inner join (`all.x = all.y = FALSE`) when the analysis sample needs both sides complete.
5. Compare `ds.dim` before and after (x, y, merged). Check per-variable `missing_n` with `dh.getStats`.
6. Data frames that already share rows and order can be column-bound with `ds.dataFrame(c("df", vecs))` / `ds.cbind`. Row-binding across sources: `ds.bind_rows` (dsTidyverseClient).

## Pitfalls
- Columns present on both sides get `.x` / `.y` suffixes (e.g. `age.730.x`). Drop duplicates before merging, or rename afterwards.
- A cohort lacking the y-table needs a different branch: merge where it exists, `ds.mutate(list(y = NA))` where it doesn't.
- Merging per imputation or per outcome repeats the same call. Use `map` over a names vector (see analyse-imputed-data).
