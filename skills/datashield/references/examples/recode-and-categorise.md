# Recipe: Recode and categorise variables

**Goal:** Turn coded or continuous variables into labelled factor categories, collapse sparse levels, and build composite indicators.

## Pattern
Create a temporary vector → factor → join back.

1. `ds.case_when(list(df$x == 1 ~ "a", df$x == 2 ~ "b", ...), newobj = "x_tmp")`. For a two-way split, use `ds.if_else(list(df$x > k), "hi", "lo", newobj = "x_tmp")`.
2. `ds.asFactor("x_tmp", "x_cat")`.
3. Optionally `ds.changeRefGroup("x_cat", "<ref>", newobj = "x_cat")`.
4. Join all new vectors to the data frame at once with `ds.dataFrame(x = c("df", new_vars), newobj = "df")`.
5. Check with `ds.table("df$x_cat")`.

```r
ds.case_when(list(
  df$age_m <  30                 ~ "lt30",
  df$age_m >= 30 & df$age_m < 35 ~ "30_35",
  df$age_m >= 35                 ~ "ge35"),
  newobj = "age_m_tmp")
ds.asFactor("age_m_tmp", "age_m_cat")

# Collapse levels: codes 1-4 -> "multi"
ds.case_when(list(df$parity == 0 ~ "nulli", df$parity >= 1 ~ "multi"), newobj = "parity_tmp")

# Collapse levels of an existing factor
ds.recodeLevels(x = "df$noise_cat", newCategories = c(1, 2, 3, 4, 5, 5), newobj = "noise_cat")

# Composite "any condition" with explicit missing handling
ds.case_when(list(
  df$cond_a == 1 | df$cond_b == 1 ~ "yes",
  df$cond_a == 0 & df$cond_b == 0 ~ "no"),
  newobj = "any_cond_tmp")         # all-missing stays NA
```

Helper worth writing: `recode_to_factor(df, rules, name, ref = NULL)`, wrapping case_when → asFactor → changeRefGroup. This block tends to be repeated once per covariate.

## Pitfalls
- **Leave no gaps between bands.** Use half-open intervals (`>= a & < b`). Writing `>= 37*7 & <= 38*7` followed by `>= 39*7` leaves days 267–272 (and 281–286) as NA, and everything under 37 weeks as NA. Likewise `<= 30` then `>= 31` misses ages 30–31 on a continuous scale.
- **Check units** (e.g. gestational age in days vs weeks: `37*7`, not `37*4`).
- `TRUE ~ "no"` as the last case turns *missing* into "no". Wrapping conditions in `if_else(cond, TRUE, FALSE, NA)` changes nothing, because NA stays NA. Add an explicit rule for the "no" group instead.
- Collapse sparse or ordinal levels before modelling: ordinal parity and small area-deprivation cells have caused disclosure failures, fixed by binarising or merging levels.
- `ds.asFactor` is documented for numeric input, but it has worked on the character output of `ds.case_when`.
- `ds.recodeValues(var.name, values2replace.vector, new.values.vector, newobj)` does the same job in dsBaseClient. Prefer `ds.case_when`.
