# Recipe: Disclosure-safe descriptive plots

## Goal
Show distributions and relationships of server-side variables without exposing individual values.

## Which source to use
| Plot | Source | How disclosure is protected |
|---|---|---|
| Quick look | `ds.histogram`, `ds.scatterPlot`, `ds.boxPlot`, `ds.heatmapPlot` | small-cell suppression, k-nearest-neighbour centroids, or noise |
| Custom histogram | value returned by `ds.histogram` (`$mids`, `$counts`) | low-count bins set to 0 |
| Violin, box or density by cohort | `dh.getAnonPlotData(df, var_1)` | each value replaced by the centroid of its 3 nearest neighbours |
| Custom scatter | `dh.getAnonPlotData(df, var_1, var_2)` | same |
| Box from summary statistics | `dh.getStats()$continuous` percentiles | aggregates only |
| Category bars | `dh.getStats()$categorical` | aggregates only |
| Correlation heatmap | `ds.cor(type = "split" / "combine")` | aggregates only |

## Steps
1. Histogram data:

```r
get_histogram_data <- function(variable, conns, breaks = 10) {
  histograms <- ds.histogram(x = variable, type = "split", num.breaks = breaks,
                             datasources = conns)
  if (inherits(histograms, "histogram")) histograms <- list(histograms)
  histograms |>
    set_names(names(conns)) |>
    imap(\(h, cohort) tibble(cohort = cohort, mid = h$mids, count = h$counts)) |>
    list_rbind()
}
get_histogram_data("D$exposure", conns) |>
  ggplot(aes(mid, count)) + geom_col() + facet_wrap(vars(cohort), scales = "free_y")
```
2. Distributions by cohort from anonymised values (only query cohorts that have data):

```r
find_cohorts_with_data <- function(stats, var_name) {
  stats$continuous |>
    filter(variable == .env$var_name, cohort != "combined", valid_n > 0) |>
    pull(cohort)
}

get_anon_values <- function(df, var_name, conns) {
  dh.getAnonPlotData(df = df, var_1 = var_name, conns = conns) |>
    filter(cohort != "combined") |>
    pivot_longer(-cohort, names_to = "variable", values_to = "value")
}

plot_distribution <- function(values, y_label = NULL, limits = NULL) {
  ggplot(values, aes(x = fct_rev(cohort), y = value, fill = cohort)) +
    see::geom_violinhalf(alpha = 0.75) +
    geom_boxplot(width = 0.15, outlier.size = 0.3) +
    coord_flip(ylim = limits, expand = FALSE) +
    scale_fill_manual(values = palette_main, guide = "none") +
    labs(x = NULL, y = y_label)
}

stats <- dh.getStats(df = "D", vars = continuous_vars, conns = conns)
distribution_plots <- continuous_vars |>
  set_names() |>
  map(\(v) get_anon_values("D", v, conns[find_cohorts_with_data(stats, v)])) |>
  map(plot_distribution)
```
3. Box plots straight from percentiles (no row-level data):

```r
plot_percentile_box <- function(stats, var_name, y_label) {
  stats$continuous |>
    filter(variable == .env$var_name, cohort != "combined") |>
    ggplot(aes(x = cohort, ymin = perc_5, lower = perc_25, middle = perc_50,
               upper = perc_75, ymax = perc_95)) +
    geom_boxplot(stat = "identity") +
    labs(x = NULL, y = y_label, caption = "Whiskers: 5th and 95th percentiles")
}
```
4. Stacked category bars (`cat_labels`: variable, category, cat_label, including a "missing" row):

```r
plot_category_bars <- function(stats, var_name, cat_labels) {
  stats$categorical |>
    filter(variable == .env$var_name, cohort != "combined", valid_n > 0) |>
    left_join(cat_labels, by = c("variable", "category")) |>
    ggplot(aes(x = cohort, y = perc_total, fill = cat_label)) +
    geom_col() +
    coord_cartesian(ylim = c(0, 100), expand = FALSE) +
    scale_fill_manual(values = palette_main) +
    labs(x = NULL, y = "Percentage", fill = NULL)
}
```
5. Correlation heatmap. Build the subset with `ds.dataFrame(x = paste0("D$", vars))` so the
   column order is known:

```r
plot_correlations <- function(cor_matrix, variables) {
  dimnames(cor_matrix) <- list(variables, variables)
  GGally::ggcorr(data = NULL, cor_matrix = cor_matrix, label = TRUE, label_round = 2,
                 label_size = 2, hjust = 1, layout.exp = 2,
                 low = palette_main[2], mid = "white", high = palette_main[5]) +
    theme(legend.position = "none")
}

list_high_correlations <- function(cor_matrix, threshold = 0.9) {
  as_tibble(cor_matrix, rownames = "var_1") |>
    pivot_longer(-var_1, names_to = "var_2", values_to = "r") |>
    filter(var_1 < var_2, abs(r) > threshold)
}

cors <- ds.cor(x = "D_exposures", type = "split", datasources = conns) |> set_names(names(conns))
cor_plots <- map(cors, \(x) plot_correlations(x[["Correlation Matrix"]], exposure_vars))
```
6. Timing and sample-size dot plot: from `dh.getStats`, put `perc_50` of age per cohort on x,
   cohort on y, with `size = valid_n`.

## Pitfalls
- `dh.getAnonPlotData` appends a "combined" copy of all cohorts' rows. Drop it, or keep it on purpose.
- Anonymised values are 3-nearest-neighbour centroids, so the tails are pulled in. Never report
  min, max or extremes from them, and say "anonymised (k = 3 centroids)" in the legend.
- `dh.getAnonPlotData` fails if a cohort has no data on the variable. Subset `conns` first (step 2).
- `ds.histogram` returns one `histogram` object (not a list) for a single source or
  `type = "combine"`. Bins below the server threshold come back as 0. Use fewer breaks; don't try
  to recover them.
- `ds.histogram` and `ds.scatterPlot` draw base graphics as a side effect. Wrap them in
  `save_base_figure()` to save the plot.
- In the "combined" row of `dh.getStats`, percentiles are aggregates across cohorts, not
  pooled-data quantiles. Don't draw them as a pooled box.
- Cohorts with no data show 100% "missing". Filter on `valid_n > 0` rather than overwriting values.
- Don't index plot lists by hand (`plots[[27]]`). Use `map`, then `iwalk(save_figure)`.
