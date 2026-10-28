# Recipe: Transformations, z-scores and IQR scaling

**Goal:** Transform skewed variables, standardise within cohort, and scale exposures by IQR for comparable effect sizes.

## Pattern
1. **Skew:** square root is `x^0.5`, not `x*0.5`.
```r
ds.mutate("df", list(x_t = x^0.5), newobj = "df")
ds.histogram("df$x_t", num.breaks = 20)
```
2. **Within-cohort z-score:** get cohort means and SDs, then assign per cohort. The proven version uses `ds.assign` with a pasted formula:
```r
st <- dh.getStats(df = "df", vars = "x_t")$continuous |>
  filter(cohort != "combined", !is.na(mean))
st |> pwalk(function(cohort, mean, std.dev, ...) {
  ds.assign(toAssign = paste0("(df$x_t-", mean, ")/", std.dev),
            newobj = "x_z", datasources = conns[cohort])
  ds.dataFrame(c("df", "x_z"), newobj = "df", datasources = conns[cohort])
})
```
   Tidyverse version (untested): `ds.mutate("df", list(x_z = (x_t - !!mean) / !!std.dev), newobj = "df", datasources = conns[cohort])`.
   For z-scores within age bands there is `dh.zByGroup(df, out_var, age_var, low_band, upp_band, conns, new_obj)`.
3. **IQR scaling:** `dh.makeIQR(df, vars, type = "combine", new_obj)` scales by the pooled IQR; `type = "split"` uses the within-cohort IQR. New columns are named `<var>_iqr_c` for `type = "combine"` and `<var>_iqr_s` for `type = "split"`. Run variables that are absent in some cohorts in a separate call with `conns` restricted. Then keep only the IQR columns: `ds.select(list(-all_of(!!orig_vars)))`.
4. **Non-linear sensitivity analysis:** `dh.quartileSplit(df, var, new_obj, band_action, type)`.

## Pitfalls
- `x*0.5` followed by z-scoring gives exactly the z-score of `x`, so the "transformation" does nothing.
- `dh.getStats` rounds to `digits = 2` by default, which feeds rounded means and SDs into z-scores. Pass `digits` explicitly if precision matters.
- `dh.makeIQR` leaves helper objects (`<var>_iqr_c` / `<var>_iqr_s` vectors, `<new_obj>_1`). Remove them.
