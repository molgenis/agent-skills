# Recipe: Forest plots of model results

## Goal
Plot per-cohort and pooled estimates with confidence intervals, for one term, many terms
(exposome-wide) or several analyses side by side.

## Input
A tidy tibble with `cohort, variable, est, lowci, uppci, n_obs`, where `cohort == "combined"` is
the pooled row. Get it from `dh.lmTab(..., ci_format = "separate", digits = 10)` or from the
meta-analysis recipe. Exponentiate odds ratios before plotting, once only.

## Steps
1. Format labels and set the order (cohorts alphabetical, pooled at the bottom):

```r
format_estimate <- function(est, lowci, uppci, digits = 2) {
  sprintf("%.*f (%.*f, %.*f)", digits, est, digits, lowci, digits, uppci)
}

order_cohorts <- function(labels, pooled_label = "Pooled") {
  factor(labels, levels = rev(c(sort(setdiff(unique(labels), pooled_label)), pooled_label)))
}

prepare_forest_data <- function(results, term, cohort_labels) {
  results |>
    filter(variable == .env$term) |>
    left_join(cohort_labels, by = "cohort") |>
    mutate(
      is_pooled = cohort == "combined",
      cohort_label = order_cohorts(if_else(is_pooled, "Pooled", cohort_label)),
      est_ci = format_estimate(est, lowci, uppci)
    )
}
```
2. Plot (for ratios use `ref_line = 1, log_x = TRUE`):

```r
plot_forest <- function(data, x_label, ref_line = 0, log_x = FALSE) {
  plot <- ggplot(data, aes(x = est, y = cohort_label, xmin = lowci, xmax = uppci)) +
    geom_vline(xintercept = ref_line, linetype = "dashed", linewidth = 0.3) +
    geom_errorbar(width = 0.15, orientation = "y") +
    geom_point(aes(shape = is_pooled, size = is_pooled, colour = is_pooled)) +
    geom_text(aes(x = Inf, label = est_ci), hjust = -0.1, size = 3) +
    coord_cartesian(clip = "off") +
    theme(plot.margin = margin(5.5, 90, 5.5, 5.5)) +
    scale_shape_manual(values = c(`FALSE` = 15, `TRUE` = 18), guide = "none") +
    scale_size_manual(values = c(`FALSE` = 2, `TRUE` = 4), guide = "none") +
    scale_colour_manual(values = c(`FALSE` = "black", `TRUE` = colour_pooled), guide = "none") +
    labs(x = x_label, y = NULL)
  if (log_x) plot <- plot + scale_x_log10()
  plot
}
```
3. Optional annotations:
   - N in the label: `cohort_label = paste0(cohort_label, " (n = ", n_obs, ")")`.
   - Heterogeneity in the title: `labs(title = paste0(term_label, ", I² = ", round(i2), "%"))`.
4. Exposome-wide plot, terms as rows coloured by family. Order the rows first:
   `arrange(family, var_label)`, then `var_label = factor(var_label, unique(var_label))`.

```r
plot_exposure_forest <- function(data, x_label, ref_line = 0) {
  ggplot(data, aes(x = est, y = fct_rev(var_label), xmin = lowci, xmax = uppci, colour = family)) +
    geom_vline(xintercept = ref_line, linetype = "dashed", linewidth = 0.3) +
    geom_errorbar(width = 0.1, orientation = "y") +
    geom_point() +
    scale_colour_manual(values = palette_main) +
    labs(x = x_label, y = NULL, colour = NULL)
}
pooled |> plot_exposure_forest("Mean difference per IQR") + facet_wrap(vars(outcome_label), nrow = 1)
per_cohort |> plot_exposure_forest("Mean difference per IQR") + facet_wrap(vars(cohort_label), ncol = 2)
```
5. Several analyses or strata side by side (main vs sensitivity, one-stage vs two-stage, by sex):

```r
plot_forest_comparison <- function(data, x_label, ref_line = 0) {
  dodge <- position_dodge(width = 0.5)
  ggplot(data, aes(x = var_label, y = est, ymin = lowci, ymax = uppci, colour = analysis)) +
    geom_hline(yintercept = ref_line, linetype = "dashed", linewidth = 0.3) +
    geom_errorbar(width = 0.2, position = dodge) +
    geom_point(position = dodge) +
    coord_flip() +
    scale_colour_manual(values = palette_main, guide = guide_legend(reverse = TRUE)) +
    labs(x = NULL, y = x_label, colour = NULL)
}
```
   After `coord_flip()` the dodge order runs bottom to top. To change it, reverse the factor levels
   of `analysis`, not the dodge width.
6. Classic journal layout with annotation columns: use `metafor::forest`.

```r
draw_metafor_forest <- function(data, x_label, ref_line = 0, ...) {
  metafor::forest(x = data$est, ci.lb = data$lowci, ci.ub = data$uppci,
                  slab = data$label, refline = ref_line, xlab = x_label,
                  header = c("Cohort", "Estimate [95% CI]"), cex = 0.8, ...)
}
save_base_figure(\() draw_metafor_forest(d, "Odds ratio", ref_line = 1,
  ilab = d$n_obs, ilab.xpos = -1), "forest_slma")
```
7. Quick look only: `ds.forestplot(mod = slma_fit, variable = "exposure", method = "REML")`. It takes
   `ds.glmSLMA` / `ds.lmerSLMA` output and needs the `meta` package. Not for publication.

## Pitfalls
- `dh.lmTab` rounds to 2 digits by default. Set `digits = 10` and round only in labels.
- `mutate(across(est:uppci, exp))` also exponentiates `se` and `pvalue`, which sit between those
  columns. Use `across(c(est, lowci, uppci), exp)`.
- The `dh.lmTab` "combined" row is the ML random-effects estimate. If the text reports REML, take
  the pooled row from the meta-analysis recipe instead.
- Zoom with `coord_cartesian(xlim =)`. Scale limits (`scale_x_continuous(limits =)`) silently drop
  intervals that cross them.
- Interval columns are 2.5% and 97.5%; don't name them `ci_5` / `ci_95`.
- Get the number of studies from `n_coh` or `fit$num.valid.studies`, not `length(fit$disclosure.risk)`.
- In `metafor::forest`, group headers placed by hand with `text(x, y)` and hand-typed `rows =`
  break when the number of cohorts changes. Prefer ggplot facets, or compute the rows.
- Plot ratios on a log axis (in metafor, pass log estimates with `atransf = exp`).
