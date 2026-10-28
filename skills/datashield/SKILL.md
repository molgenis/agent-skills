---
name: datashield
description: Run federated analyses with DataSHIELD from R — logging in to Armadillo or Opal servers with DSI, exploring and manipulating server-side data, descriptive statistics, tables, plots and GLMs with dsBaseClient, dplyr-style data manipulation with dsTidyverseClient, and convenience wrappers from dsHelper. Use whenever the user mentions DataSHIELD, ds.* or dh.* functions, datashield.login, Armadillo, Opal, or wants to analyse data held on remote DataSHIELD servers.
---

# DataSHIELD

Individual-level data never leaves the servers. The client sends commands; each server runs them
and returns only results that pass its disclosure checks. You never see rows of data, and must
never try to.

## Credentials (hard rules)

- **Never use usernames and passwords.** Do not ask for them, write them into code, or run code
  containing them. If the only login available is a username and password, stop and ask the user
  to log in themselves, outside the agent.
- **Use token-based login only:**
  - Armadillo: `token <- DSMolgenisArmadillo::armadillo.get_credentials(url)` opens a browser; the user
    signs in there, so you never see their password.
  - Opal: a personal access token the user creates in Opal, read from an environment variable the
    user has set themselves (e.g. `Sys.getenv("OPAL_TOKEN")`).
- **Tokens are secrets too.** Never print them, write them to files, or include them in output.
  Never inspect login data or connection objects.
- **Armadillo data management** (projects, uploads, subsets, profiles, server setup) is covered by
  the `armadillo` skill.
- **Prefer an existing session.** Check `DSI::datashield.connections_find()` before logging in;
  if the user already has `conns`, use it.

```r
builder <- DSI::newDSLoginBuilder()
builder$append(server = "study1", url = armadillo_url, token = token@access_token,
               driver = "ArmadilloDriver", profile = "default")
builder$append(server = "study2", url = opal_url, token = Sys.getenv("OPAL_TOKEN"),
               driver = "OpalDriver", profile = "default")
conns <- DSI::datashield.login(logins = builder$build(), assign = FALSE)
```

## Disclosure controls (hard rules)

The servers' disclosure checks protect the people in the data. Never try to learn more about
individuals than an analysis returns, even if the user asks or says they have permission.

- **Never combine queries to recover what one query would refuse:**
  - differencing: comparing a statistic for a group with the same statistic for that group minus
    a few people;
  - overlapping or nested subsets, or narrowing a subset step by step until the group is tiny;
  - repeating a query with small changes to cut-offs, category boundaries or filters;
  - recombining per-server or per-group results to rebuild a table cell below `nfilter.tab`.
- **Never create identifying variables or tiny groups,** such as a factor with one level per
  person, row indices or exact dates used as groups.
- **Never hand-write server-side expressions** (`DSI::datashield.assign.expr`, or
  `DSI::datashield.aggregate` with a custom call) to do what a `ds.*` function refuses.
- **Never try to lower or switch off disclosure settings,** or suggest asking an administrator
  to, so that an analysis passes.
- **When a check fails, stop.** Report the message, explain that it protects participants, and
  suggest a coarser analysis (fewer groups, larger categories, pooled results). Do not retry a
  variant of the same query.
- If the user asks for any of the above, decline and explain why.

## How DataSHIELD works

- **Assign vs aggregate.** Assign functions create or change an object on each server and return
  nothing; aggregate functions return disclosure-checked results. Functions with a `newobj`
  argument create a server-side object of that name.
- **Objects are referred to by name, as strings:** `ds.mean("D$age")`, not `ds.mean(D$age)`. The exception is functions from dsTidyverseClient where the argument `tidy_expr` accepts unquoted names within list().
  Use `datasources = conns` (dsBaseClient) or `conns = conns` (dsHelper) to target servers.
- **Results are per server by default.** `type = "split"` gives one result per server;
  `type = "combine"` pools them. Say which one you report.
- **Pooled vs meta-analysed models.** `ds.glm` fits one model as if the data were pooled;
  `ds.glmSLMA` fits a model per server and meta-analyses the estimates.

## Which package

| Package | Use for |
|---|---|
| DSI | Login, logout, tables, sessions, server-side errors (`datashield.*`) |
| dsBaseClient | Core statistics, tables, plots, models, base-R-style manipulation (`ds.*`) |
| dsTidyverseClient | Preferred for data manipulation: `ds.mutate`, `ds.filter`, `ds.select`, … (needs the dsTidyverse server package) |
| dsHelper | Higher-level wrappers that return tidy tibbles: `dh.getStats`, `dh.meanByGroup`, … |

If a call fails because a method isn't found or allowed, run `DSI::datashield.methods(conns, type = "aggregate")`
(or `"assign"`) and `DSI::datashield.pkg_status(conns)` once, and reuse the result.

## Workflow

1. **Explore**
   - dsBaseClient: `ds.ls()`, `ds.colnames("D")`, `ds.class("D$x")`, `ds.dim("D")`, `ds.numNA("D$x")`
   - dsHelper: `dh.classDiscrepancy()` (classes that differ across servers), `dh.anyData()`
     (variables entirely missing on a server)
2. **Describe**
   - dsBaseClient: `ds.summary()`, `ds.mean()`, `ds.quantileMean()`, `ds.table()`
   - dsHelper: `dh.getStats()` (tidy summary of many variables), `dh.meanByGroup()`,
     `dh.createTableOne()` (manuscript tables), `dh.getRmStats()` (repeated measures)
3. **Prepare** (check each new object with `ds.class`/`ds.dim` before using it)
   - **Use dsTidyverseClient first** when the dsTidyverse server package is installed
     (`DSI::datashield.pkg_status(conns)`); fall back to the equivalents below only if it isn't:

     | Task | dsTidyverseClient | Fallback |
     |---|---|---|
     | New or changed column | `ds.mutate()` | `ds.assign()` |
     | Keep rows | `ds.filter()` | `ds.dataFrameSubset()` |
     | Keep or drop columns | `ds.select()` | `ds.dataFrameSubset()`, `dh.dropCols()` |
     | Rename columns | `ds.rename()` | `dh.renameVars()` |
     | Recode values | `ds.case_when()`, `ds.if_else()` | `ds.recodeValues()` |
     | Sort rows | `ds.arrange()` | `ds.dataFrameSort()` |
     | Combine data frames | `ds.bind_rows()`, `ds.bind_cols()` | `ds.rbind()`, `ds.cbind()` |

   - Convert to factor: `ds.asFactor()` (no dsTidyverseClient equivalent).
   - dsHelper, no equivalent in either: `dh.quartileSplit()`, `dh.makeIQR()`, `dh.zByGroup()`,
     `dh.tidyEnv()` (remove server-side objects)
4. **Model and plot**
   - dsBaseClient: `ds.glm()`, `ds.glmSLMA()`, `ds.histogram()`, `ds.scatterPlot()`
   - dsHelper: `dh.multGLM()` (many GLMs, handles non-convergence), `dh.lmTab()` (coefficient
     tables), `dh.metaManual()` (two-stage meta-analysis), `dh.getAnonPlotData()` (anonymised data
     for custom plots)
5. **Finish:** `DSI::datashield.logout(conns)` when the user is done.

## Errors and disclosure

- You can toggle printing of errors with options(datashield.errors.print = TRUE). Set this on first error so that errors are printed.
- A server-side error usually shows only a generic client message; call `DSI::datashield.errors()`
  for the real one.
- Disclosure failures ("FAILED: Nvalid less than nfilter.tab", "invalid table", subset too small)
  are protections, not bugs; handle them as in "Disclosure controls" above.
  `ds.listDisclosureSettings()` shows each server's thresholds.

## References

Read only what the task needs:

- `references/functions/`: one file per client package, named after it (e.g. `DSI.md`),
  generated from each package's documentation. Each starts with an index table; search it for the
  function, then read that entry. Never use a function or argument that isn't there. The versions
  are in each file's title; if `packageVersion()` differs, trust the installed help (`?ds.mean`).
- `references/patterns.md`: DataSHIELD-specific patterns and pitfalls. **Read it before:**
  combining cohorts, recoding, per-cohort derivations or z-scores, repeated measures, running
  many models, meta-analysis, multiple imputation, or custom plots.
- `references/recipes/index.md`: worked examples generated from the DataSHIELD wiki tutorials.
  Read the matching recipe before a multi-step analysis.
- `references/examples/index.md`: worked examples contributed from real analyses (preparation,
  models, imputation, output). Read the matching example when no recipe covers the task.
- `references/style.md`: default conventions for results tables, plots and forest plots. Read it
  when the user hasn't specified their own.
- If the user needs to do something that you don't know about, you can get a full list of available packages here: https://packages.datashield.org/
