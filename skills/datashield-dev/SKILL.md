---
name: datashield-dev
description: Develop DataSHIELD R packages — paired client-side and server-side functions, aggregate and assign methods, the DATASHIELD exports file, disclosure checks and settings (nfilter.*), testing with DSLite and testthat, documentation, releases and CRAN, and auditing a function's disclosure risk. Use whenever the user writes, reviews, tests or releases DataSHIELD package code, server-side *DS functions, or asks whether a function is disclosive. For running analyses use the datashield skill; for Armadillo servers use the armadillo skill.
---

# DataSHIELD package development

A DataSHIELD package is two R packages that talk to each other: a client package the analyst
calls (e.g. dsBaseClient, functions named `ds.*`) and a server package installed on each data
server (e.g. dsBase, functions named `*DS`). The server functions are the only code that touches
individual-level data, so they are where disclosure is controlled.

## Hard rules (disclosure)

- **The server decides what leaves.** Every aggregate function must return only results that pass
  disclosure checks on the server. Never rely on client-side checks: the client can be bypassed.
- **Use the server's settings, not your own numbers.** Read thresholds with
  `dsBase::listDisclosureSettingsDS` (`nfilter.tab`, `nfilter.subset`, `nfilter.glm`,
  `nfilter.string`, `nfilter.stringShort`, `nfilter.kNN`, `nfilter.levels.density`,
  `nfilter.levels.max`, `nfilter.noise`) and respect `datashield.privacyControlLevel`
  (`dsBase::checkPermissivePrivacyControlLevel`). Document any new setting a function introduces.
  `references/code/` shows how dsBase applies each kind of check.
- **Check before `eval`.** Any client-supplied value that is parsed or evaluated on the server
  must be validated first.
- **Declare only intended methods** under `AggregateMethods` and `AssignMethods` in
  `inst/DATASHIELD` (or DESCRIPTION). Anything listed there is callable by every analyst.
- **Leave nothing behind.** Remove intermediate server-side objects that the result doesn't need,
  and when a function wraps another package's function, review everything that function returns.
- When reviewing someone else's function, work through
  `references/docs/opmanag-disclose-audit-checklist.md` item by item.

## How a function pair works

1. The client function validates arguments, builds a call to the server function, and sends it
   with `DSI::datashield.aggregate` (returns a result) or `DSI::datashield.assign` (creates or
   changes a server-side object and returns nothing).
2. The server function (`nameDS`) does the work on the data, applies disclosure checks, and
   returns only the safe result.
3. The server function is listed in `inst/DATASHIELD` under the matching method type.

## Workflow

Follow `references/docs/index.md` in order: R package basics, repositories, documentation,
client function, server function, exports, trying it with DSLite, `devtools::check`, server and
client unit tests (testthat, DSLite), vignettes, site, GitHub release, CRAN.
`references/docs/getting-started-developer-checklist.md` is the short version.

## Engineering practice

- Keep functions small and single-purpose; split long functions into named helpers
  (`references/docs/getting-started-developer-refactoring.md`).
- Fix causes, not symptoms: trace a failure to its root cause before changing code, and do not
  add workarounds that hide errors.
- Start a bug fix with a failing test that reproduces it.
- Change only what the task needs; leave unrelated code and formatting alone.
- If a general coding-standards skill is available, follow it as well.

## References

Read only what the task needs:

- `references/functions/`: dsBase (server functions and helpers such as
  `listDisclosureSettingsDS`) and DSI (`datashield.aggregate`, `datashield.assign`), generated from
  each package's documentation. Never use a function or argument that isn't there.
- `references/code/index.md`: verbatim source from the latest releases. The dsExample package
  template (client, server, exports file, DSLite tests) and dsBase function pairs that each show
  one disclosure check: settings, table cell counts, subset size, GLM saturation, levels density.
  Start new packages from the template and copy the check pattern that fits.
- `references/docs/index.md`: the DataSHIELD developer guide and disclosure control pages,
  generated from the DataSHIELD wiki. `opmanag-disclosure-control-dsBase-checks.md` lists the
  automated disclosure checks in each dsBase function; `opmanag-disclosure-control.md` explains
  each setting.
