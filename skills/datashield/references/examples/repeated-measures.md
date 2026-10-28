# Recipe: Repeated measures

**Goal:** Get analysis variables from long data: a specific wave, the first or last measure in an age band, a per-subject mean, the correct instrument, and wide reshapes.

## Pattern
1. **Specific wave:** `ds.filter("rep", list(age_years == 0), newobj = "rep_0")`. Variables derived from it go back via `ds.dataFrame(c("rep_0", ...))`, then merge to the non-repeated data by id.
2. **First or last measure in a band:** dsHelper marks `dh.makeStrata` as replaced by arrange → group_by → slice.
```r
ds.filter("rep", list(age >= 0 & age <= 17), newobj = "rep_band")
ds.arrange("rep_band", list(desc(age)), newobj = "rep_band")   # desc = latest; drop for earliest
ds.group_by("rep_band", list(id), newobj = "rep_band")
ds.slice("rep_band", list(1), newobj = "outcome_last")
ds.select("outcome_last", list(id, age_last = age, outcome_last = outcome), newobj = "outcome_last")
```
3. **Per-subject mean:** `ds.group_by` → `ds.mutate(list(x_mean = mean(x, na.rm = TRUE)))` → `ds.slice(list(1))`. Compare `ds.mean` before and after.
4. **Instrument selection:** keep, per cohort, the rows measured with the agreed instrument (a tibble of cohort × outcome × instrument code + `pwalk` filter). Check that each cohort/outcome has exactly one instrument left: from `dh.getStats(...)$categorical`, count categories with `value > 0` per cohort.
5. **Wide reshape:**
```r
ds.reShape(data.name = "rep_0", timevar.name = "age_years", idvar.name = "id",
           v.names = c("x_", "y_"), direction = "wide", drop = "z_", newobj = "rep_wide")
ds.rename("rep_wide", list(x0 = x_.0, y0 = y_.0), newobj = "rep_wide")
```
6. **Descriptives for repeated data:** `dh.getRmStats(df, outcome, id_var, age_var)` (number of subjects, measures per subject, age range).

## Pitfalls
- Run outcome-specific steps only on cohorts with that outcome. Derive the list from `dh.getStats` (`!is.na(mean)`, `cohort != "combined"`) and pass `conns[those]`.
- In `ds.reShape`, `v.names` must not include `timevar.name`. Passing `v.names = "age_years", timevar.name = "age_years", idvar.name = c("id", "age_years")` doesn't produce a usable wide frame.
- `ds.mutate` with an unnamed expression produces an unusable column name. Always name it.
- Grouped tibbles: `ds.ungroup` exists if a later dsBase call rejects grouped input (untested).
- For the deprecated `dh.makeStrata`, `band_action` and `mult_action` need care (`"g_le"`, `"latest"`). The tidyverse chain makes the band edges explicit.
