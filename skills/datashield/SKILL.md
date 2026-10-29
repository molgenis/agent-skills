---
name: datashield
description: Run federated analyses with DataSHIELD from R — logging in to Armadillo or Opal servers with DSI, exploring and manipulating server-side data, descriptive statistics, tables, plots and GLMs with dsBaseClient, dplyr-style data manipulation with dsTidyverseClient, and convenience wrappers from dsHelper. Use whenever the user mentions DataSHIELD, ds.* or dh.* functions, datashield.login, Armadillo, Opal, or wants to analyse data held on remote DataSHIELD servers.
---

# DataSHIELD

Individual-level data never leaves the servers. The client sends commands; each server runs them
and returns only results that pass its disclosure checks. You never see rows of data, and must
never try to.

## Logging in

- **Never use usernames and passwords.** Do not write them into code or run code containing
  them. If a user pastes a password, tell them to change it, and give the token login below.
- **Armadillo:** `armadillo.get_token` is defunct. Use
  `DSMolgenisArmadillo::armadillo.get_credentials(url)`, which opens a browser for the user to sign
  in, and pass `token@access_token` to the login builder.
- **Opal:** a personal access token the user created, read from an environment variable they set
  (e.g. `Sys.getenv("OPAL_TOKEN")`).
- **Tokens are secrets.** Never print them or write them to files. Reuse an existing session
  (`DSI::datashield.connections_find()`) before logging in again.
- **Armadillo data management** (projects, uploads, subsets, profiles, server setup) is covered by
  the `armadillo` skill.

```r
token <- DSMolgenisArmadillo::armadillo.get_credentials(armadillo_url)
builder <- DSI::newDSLoginBuilder()
builder$append(server = "study1", url = armadillo_url, token = token@access_token,
               driver = "ArmadilloDriver", profile = "default")
conns <- DSI::datashield.login(logins = builder$build(), assign = FALSE)
```

## Disclosure controls

- A failed check ("FAILED: Nvalid less than nfilter.tab", "invalid table", subset too small)
  protects participants; it is not a bug. Report it, and suggest a coarser analysis: fewer or
  larger categories, pooled results, or a model instead of a table. Report suppressed cells as
  "<threshold"; `ds.listDisclosureSettings()` shows each server's thresholds.
- If the user asks for a way round a check (differencing, narrowing subsets, recombining results,
  hand-written server calls, lowering thresholds), decline and explain why. Don't list these
  techniques unless the user asked for a workaround.

## Things to know

- **Objects are named as strings** (`ds.mean("D$age")`). Results are per server
  (`type = "split"`) or pooled (`type = "combine"`); say which you report.
- **`ds.glm`** fits one model as if the data were pooled; add a study indicator when baseline risk
  may differ. **`ds.glmSLMA`** fits one model per server and meta-analyses them; if any server
  fails, the whole call fails.
- **Target one server** with `datasources = conns["study1"]`, e.g. to harmonise a variable that is
  named differently there.
- **Errors:** run `options(datashield.errors.print = TRUE)` once; otherwise call
  `DSI::datashield.errors()` straight after a failure to see the server's message.
- **dsTidyverse is usually faster and shorter than dsBase for data manipulation.** Check it is
  installed with `DSI::datashield.pkg_status(conns)`, then use dsTidyverseClient. Its `tidy_expr`
  argument takes unquoted names inside `list()`:

  | Task | dsTidyverseClient | dsBase fallback |
  |---|---|---|
  | New or changed column | `ds.mutate(df.name = "D", tidy_expr = list(bmi2 = bmi^2), newobj = "D")` | `ds.assign()` + `ds.dataFrame()` |
  | Keep rows | `ds.filter(df.name = "D", tidy_expr = list(sex == 1), newobj = "D_f")` | `ds.dataFrameSubset(..., keep.NAs = TRUE)` |
  | Keep or drop columns | `ds.select()` | `ds.dataFrameSubset()` |
  | Rename columns | `ds.rename(tidy_expr = list(new = old))` | `ds.assign()` + `ds.dataFrame()` |
  | Recode values | `ds.case_when()`, `ds.if_else()` | `ds.Boole()`, `ds.recodeValues()` |
  | Sort, group, first row per person | `ds.arrange()`, `ds.group_by()`, `ds.slice()` | `ds.dataFrameSort()` |
  | Combine data frames | `ds.bind_rows()`, `ds.bind_cols()` | `ds.rbind()`, `ds.cbind()` |

- **Pitfalls:**
  - `ds.dataFrameSubset` drops rows with a missing value in *any* column unless `keep.NAs = TRUE`.
  - `dh.getStats` silently drops a variable that fails a disclosure check, and
    `dh.createTableOne` then errors; compare the variables returned with those requested.
  - Convert categorical variables with `ds.asFactor` before summarising or modelling them.
  - Remove server-side objects you no longer need with `ds.rm`.

## References

- `references/lifecycle.md`: deprecated, defunct and superseded functions. Check it before using a
  function you are unsure about.
- `references/functions/dsTidyverseClient.md`: dsTidyverseClient arguments.
- `references/patterns.md`: pitfalls when combining cohorts, recoding, repeated measures, many
  models, meta-analysis and multiple imputation.
- For other functions, trust the installed help (`?ds.mean`).
