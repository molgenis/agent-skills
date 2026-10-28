# DataSHIELD skills

Agent skills for federated analysis with [DataSHIELD](https://www.datashield.org). They follow the
[Agent Skills](https://agentskills.io) format, so any agent that supports skills can use them.

## Install

Claude Code:

```
/plugin marketplace add molgenis/datashield-skills
/plugin install datashield@datashield-skills
```

Other agents (Codex, Cursor, Gemini CLI, GitHub Copilot and others), with the
[skills CLI](https://github.com/vercel-labs/skills):

```
npx skills add molgenis/datashield-skills
```

Add `-g` to install for all projects rather than the current one.

## Contents

- `skills/datashield/SKILL.md`: rules and workflow for DataSHIELD analysis from R.
- `skills/datashield/references/functions/`: function references for each DataSHIELD client
  package with a GitHub release, generated from the package documentation.
- `skills/datashield/references/recipes/`: worked examples generated from the DataSHIELD wiki
  tutorials.
- `skills/datashield/references/examples/`: worked examples contributed from real analyses.
- `skills/datashield/references/patterns.md`: DataSHIELD-specific patterns and pitfalls.
- `skills/datashield/references/style.md`: default conventions for results and plots.
- `skills/armadillo/SKILL.md`: rules and workflows for managing Armadillo servers and their data.
- `skills/armadillo/references/functions/`: MolgenisArmadillo and DSMolgenisArmadillo references.
- `skills/armadillo/references/docs/`: the Armadillo server documentation, generated from the
  latest molgenis-service-armadillo release.

## Regenerating references

```
Rscript tools/list-client-packages.R packages.csv
Rscript tools/build-all-references.R packages.csv skills/datashield/references/functions
Rscript tools/build-recipes.R <datashieldWiki>/analysis-tutorials skills/datashield/references/recipes

Rscript tools/list-releases.R armadillo.csv molgenis/molgenis-r-armadillo molgenis/molgenis-r-datashield
Rscript tools/build-all-references.R armadillo.csv skills/armadillo/references/functions
Rscript tools/build-armadillo-docs.R <molgenis-service-armadillo at its release tag> <version> skills/armadillo/references/docs
```

Set `GITHUB_TOKEN` to avoid GitHub's API rate limit.

## Checks

`tools/check-skill.R` runs on every pull request. It checks that each `SKILL.md` has valid
frontmatter and that the files it points to exist. Across `SKILL.md` and the reference files
(except the external documentation in `references/docs/`, which is checked for credentials only), it
fails on calls to `ds.*`, `dh.*`, `datashield.*` or `armadillo.*` functions missing from
`references/functions/`, on defunct functions and on
username or password arguments, and warns on deprecated or superseded functions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
