# Client-side results and plots

Defaults for client-side output. Follow the user's or project's existing conventions where they
differ.

- **Prefer tibbles** to data frames for client-side results (`tibble()` / `as_tibble()`).
- **Prefer ggplot2** for plots, except forest plots.
- **For forest plots, a tested starting point is `metafor::forest` on a fitted `rma` model,**
  written once as a function and reused. Passing the model draws the pooled diamond, sizes the
  study squares by weight, and heads the count column (`ilab.lab`), so nothing is placed by hand:

```r
# coefs: one row per cohort (no "combined" row), with label, est, se and n_obs;
# est on the model scale (log odds for logistic models).
draw_forest <- function(coefs, title, ratio = TRUE, label_header = "Cohort", method = "REML") {
  ticks <- pretty(c(0, coefs$est - 2 * coefs$se, coefs$est + 2 * coefs$se))
  fit <- metafor::rma(yi = est, sei = se, data = coefs, slab = label, method = method)
  metafor::forest(
    fit, atransf = if (ratio) exp else NULL, refline = 0, xlab = title,
    at = ticks, alim = range(ticks),
    xlim = range(ticks) + c(-1.6, 1.1) * diff(range(ticks)),
    header = c(label_header, if (ratio) "OR [95% CI]" else "Estimate [95% CI]"),
    ilab = n_obs, ilab.lab = "N", digits = c(3, 2), cex = 0.8,
    mlab = paste0(method, " random-effects model (I² = ", round(fit$I2), "%)"))
}

png(here::here("figures", "forest.png"), width = 16, height = 7, units = "cm", res = 300)
par(mar = c(5, 4, 0, 2))
draw_forest(coefs, "Odds ratio of survival, male vs female")
dev.off()
```

  - Take `est` and `se` per cohort from `dh.lmTab(..., exponentiate = FALSE)` (drop the
    "combined" row) or from `ds.glmSLMA`'s `betamatrix.valid` / `sematrix.valid`.
  - Ratios are plotted on a log scale (`atransf = exp`, `refline = 0` on the model scale). Use
    `ratio = FALSE` for linear models.
  - The axis ticks span 0 and every interval, and `xlim` is derived from them, so the reference
    line is always drawn and nothing overlaps the estimate column.
  - `method = "ML"` matches `ds.glmSLMA`'s own pooled row; `"REML"` is metafor's default.
  - A one-stage pooled (IPD) estimate isn't a meta-analysis. To show it alongside, add it with
    `metafor::addpoly()`.
  - Open the saved PNG and check the layout before handing it over.
