# Recipe: One theme, one palette, one way to save

## Goal
Define the look of every figure once and save figures in consistent sizes and formats.

## Steps
1. Create `R/theme.R` and source it from every output script:

```r
palette_main <- c("#264653", "#2a9d8f", "#e9c46a", "#f4a261", "#e76f51",
                  "#9e7682", "#aba9c3", "#8b2635", "#ec9192", "#553739")
colour_pooled <- "#800000"
page_cm <- list(width = 21 - 2 * 2.54, height = 29.7 - 2 * 2.54)

theme_paper <- function(base_size = 10) {
  theme_classic(base_size = base_size) +
    theme(
      axis.line = element_line(linewidth = 0.2),
      axis.ticks = element_line(colour = "black"),
      strip.background = element_rect(colour = "black", fill = "white", linewidth = 0.5),
      plot.title = element_text(hjust = 0.5),
      legend.position = "bottom"
    )
}
theme_set(theme_paper())
```
2. Save ggplot figures through one function (`svg` needs `svglite`):

```r
save_figure <- function(plot, name, width = page_cm$width, height = 12,
                        formats = c("png", "svg")) {
  walk(formats, \(ext) ggsave(
    filename = here::here("figures", paste0(name, ".", ext)),
    plot = plot, width = width, height = height, units = "cm", dpi = 300
  ))
}
iwalk(plots, \(plot, name) save_figure(plot, name))
```
3. Many plots on the pages of one PDF:

```r
save_figure_pages <- function(plots, name, nrow = 2, ncol = 2) {
  ggsave(here::here("figures", paste0(name, ".pdf")),
         gridExtra::marrangeGrob(plots, nrow = nrow, ncol = ncol),
         width = 29.7, height = 21, units = "cm")
}
```
4. Base-graphics output (`metafor::forest`, plots drawn by `ds.histogram` / `ds.scatterPlot`):

```r
save_base_figure <- function(draw, name, width = page_cm$width, height = 12) {
  png(here::here("figures", paste0(name, ".png")),
      width = width, height = height, units = "cm", res = 300)
  on.exit(dev.off())
  draw()
}
save_base_figure(\() ds.histogram("D$exposure", datasources = conns), "exposure_hist")
```

## Pitfalls
- In current ggplot2 use `linewidth` (not `size`) for lines, `guide = "none"` (not `guide = FALSE`),
  and `geom_errorbar(orientation = "y")` instead of `geom_errorbarh()` (deprecated in ggplot2 4.0).
- Set fixed values outside `aes()` (`geom_violinhalf(alpha = 0.75)`); inside, they add a stray legend.
- `scale_colour_discrete(palette)` does not apply your colours; use `scale_colour_manual(values = palette)`.
- The palette must be at least as long as the number of groups (cohorts, families), or some get NA colours.
- `element_text(family = "Arial")` fails or warns on servers without the font; check with
  `systemfonts::system_fonts()` or use showtext.
- Name files from list names, not from `plot$labels$title` (titles contain spaces and symbols).
- 1200-dpi PNGs are huge; for print use svg/pdf, or 300-dpi PNG.
- On headless Linux servers without X11, use a cairo or ragg PNG device.
