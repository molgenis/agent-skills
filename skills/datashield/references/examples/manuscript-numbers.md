# Recipe: Numbers for manuscript text

## Steps
Collect every number quoted in the text into one named list, built from saved results, and use it
inline in the Rmd:

```r
collect_text_numbers <- function(stats, results, dims) {
  list(
    n_cohorts = n_distinct(results$cohort[results$cohort != "combined"]),
    n_total = dims$analysis,
    n_excluded = dims$baseline - dims$analysis,
    n_range = range(stats$continuous$valid_n[stats$continuous$cohort != "combined"]),
    n_significant = sum(results$cohort == "combined" & (results$lowci > 0 | results$uppci < 0))
  )
}
dims <- map(c(baseline = "D_full", analysis = "D"),
            \(df) ds.dim(df, type = "combine", datasources = conns)[[1]][1])
```
- Repeated measures (age range as p5–p95, observations, participants, measurements per person):
  `dh.getRmStats(df = "D_long", outcome = "outcome", id_var = "id", age_var = "age", conns = conns)`.
- Instruments per cohort: rows of `stats$categorical` with `value > 0`, by cohort.
- Number of variables: `length(ds.colnames("D")[[1]]) - 1` (minus the id column).

## Pitfalls
- Count cohorts from the results (`n_coh`), not from `names(conns)`; not every cohort contributes
  to every analysis.
- `ds.dim(type = "both")` returns split and combined dimensions together; index the one you mean.
- Significance from CIs: for ratios, test whether the CI excludes 1 (ratio scale) or 0 (log scale).
- Check derived differences against the disclosure threshold before quoting them.
