## Organising analysis code

Run the analysis as numbered stage scripts. A driver script sources them in order. Anything done
twice becomes a function. Anything that describes the study (variables, tables, models, labels)
is data, and code loops over it.

- **Layout**
  ```
  R/
    run-all.R          driver: libraries, functions.R, config.R, then stages in order
    functions.R        every project helper; nothing else
    config.R           variable lists, study→table tibble, covariate sets, labels
    01-assign.R  02-exposures.R  03-outcomes.R  04-covariates.R  05-merge.R
    06-subsets.R 07-descriptives.R 08-models.R 09-sensitivity.R 10-tables.R
    11-report.Rmd
  reference/           var-ref.csv, study-info.csv (configuration kept as files)
  results/             .rds written by analysis stages
  tables/  figures/    outputs written by 10-tables.R / plots
  ```
  Use zero-padded prefixes with no spaces (`01-assign.R`, not `2. getvars.R`). Build every path
  with `here::here()`, never `~/...`. The user logs in; no stage script contains login code.
- **Header.** Each script opens with a header of no more than 8 lines: project, script purpose,
  what it needs (server objects, `results/*.rds`) and what it produces. Mark sections with
  `####` banners and `## ---- sub-step ----` lines.
- **Libraries go in the driver only.** Never put `install.packages()`, `install_github()` or
  `system("conda ...")` in an analysis script. Do installs once, in setup or with renv.
- **Configuration is data.** Variable lists, the study→table map, covariate sets, model specs,
  strata and exclusion reasons live as tibbles or vectors in `config.R` or `reference/*.csv`.
  Code iterates over them with `pwalk` for side effects on the servers and `map`/`pmap` for
  results. Never define in a stage a list that a later stage needs; restarting mid-way would
  lose it.
- **Helpers go in `functions.R`.** Name them with verbs and keep them to 30 lines or fewer. Pass
  `conns` as an argument; never read a global. Never redefine a package function under its own
  name (e.g. a local `dh.multGLM`). Name the local version differently, or fix it upstream.
- **Checkpoint the server side.** End each stage that changes server objects with
  `datashield.workspace_save(conns, "<project>_<NN>_<stage>")`, saved on all `conns`. Resume
  with `datashield.workspace_restore(conns, ws)`. Use one name per stage, never one overwritten
  name. Clear temporary objects with `ds.rm()` before saving. List workspaces with
  `datashield.workspaces(conns)` and remove old ones with `datashield.workspace_rm(conns, ws)`.
- **Checkpoint the client side.** A workspace holds only server objects. Write client results
  with `saveRDS()` to `results/`. Tables and the report read them back with `readRDS()`, so
  they run without re-fitting. Don't use `save.image()` as the hand-off.
- **Turn checks into assertions.** Write a check as code that stops on failure, not as a
  commented-out `print`.

### Driver

```r
## Project: <project>
## Purpose: run every stage in order; resume from any stage with start_from
## Needs: `conns` from the user's own login (see Credentials)
library(DSI); library(dsBaseClient); library(dsTidyverseClient); library(dsHelper)
library(dplyr); library(tidyr); library(purrr); library(readr); library(here)

source(here("R", "functions.R"))
source(here("R", "config.R"))

stages <- tribble(
  ~script,               ~workspace,
  "01-assign.R",         "proj_01_assign",
  "02-exposures.R",      "proj_02_exposures",
  "03-outcomes.R",       "proj_03_outcomes",
  "04-covariates.R",     "proj_04_covariates",
  "05-merge.R",          "proj_05_merge",
  "06-subsets.R",        "proj_06_subsets",
  "07-descriptives.R",   NA,
  "08-models.R",         NA,
  "09-sensitivity.R",    NA,
  "10-tables.R",         NA
)

run_stages(stages, conns, start_from = 1)
rmarkdown::render(here("R", "11-report.Rmd"), output_dir = here("tables"))
```

```r
# functions.R
run_stages <- function(stages, conns, start_from = 1) {
  earlier <- stages$workspace[seq_len(start_from - 1)]
  last_saved <- tail(earlier[!is.na(earlier)], 1)
  if (length(last_saved) == 1) datashield.workspace_restore(conns, last_saved)
  stages |>
    slice(start_from:n()) |>
    pwalk(\(script, workspace) {
      source(here("R", script))
      if (!is.na(workspace)) datashield.workspace_save(conns, workspace)
    })
}
```

### Configuration iterated with `pwalk`

```r
# config.R
nonrep_vars  <- c("child_id", "exp_a", "out_x", "cov_1", "cov_2")
yearrep_vars <- c("child_id", "age_years", "cov_3")

study_tables <- tribble(
  ~study,    ~symbol,   ~table,
  "study_a", "nonrep",  "<study_a nonrep table>",
  "study_a", "yearrep", "<study_a yearrep table>",
  "study_b", "nonrep",  "<study_b nonrep table>",
  "study_b", "yearrep", "<study_b yearrep table>"
) |>
  mutate(variables = if_else(symbol == "nonrep", list(nonrep_vars), list(yearrep_vars)))

# 01-assign.R
study_tables |>
  filter(study %in% names(conns)) |>
  pwalk(\(study, symbol, table, variables) {
    datashield.assign.table(conns = conns[study], symbol = symbol,
                            table = table, variables = variables)
  })
stop_if_class_differs("nonrep", nonrep_vars, conns)
```

### A helper replacing a repeated block

Copy-pasted `ds.filter` calls, one per subgroup, become one row each in a tibble:

```r
subsets <- tribble(
  ~newobj,          ~group,    ~outcome_level,
  "group1_no_out",  "group1",  "no",
  "group1_out",     "group1",  "yes",
  "group2_no_out",  "group2",  "no",
  "group2_out",     "group2",  "yes"
)
subsets |>
  pwalk(\(newobj, group, outcome_level) {
    ds.filter(df.name = "merged",
              tidy_expr = list(group_var == !!group & out_label == !!outcome_level),
              newobj = newobj, datasources = conns)
  })
```

```r
# functions.R
stop_if_class_differs <- function(df, vars, conns) {
  differing <- dh.classDiscrepancy(df = df, vars = vars, conns = conns) |>
    filter(discrepancy == "yes")
  if (nrow(differing) > 0) {
    print(differing)
    stop("Variable classes differ across studies in ", df, call. = FALSE)
  }
}
```
