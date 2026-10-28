# MOLGENIS agent skills

Agent skills for MOLGENIS products and federated analysis with
[DataSHIELD](https://www.datashield.org). They follow the [Agent Skills](https://agentskills.io)
format, so any agent that supports skills can use them.

| Skill | For |
|---|---|
| `datashield` | Analysts running federated analyses with DataSHIELD |
| `datashield-dev` | Developers writing or auditing DataSHIELD packages |
| `armadillo` | Data managers and administrators of Armadillo servers |

## Install

Claude Code, one plugin per skill:

```
/plugin marketplace add molgenis/agent-skills
/plugin install datashield@molgenis
/plugin install datashield-dev@molgenis
/plugin install armadillo@molgenis
```

Other agents (Codex, Cursor, Gemini CLI, GitHub Copilot and others), with the
[skills CLI](https://github.com/vercel-labs/skills):

```
npx skills add molgenis/agent-skills --skill datashield
npx skills add molgenis/agent-skills --skill datashield-dev
npx skills add molgenis/agent-skills --skill armadillo
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
- `skills/datashield-dev/SKILL.md`: disclosure rules and workflow for developing DataSHIELD
  packages.
- `skills/datashield-dev/references/docs/`: the DataSHIELD wiki developer guide and disclosure
  control pages.
- `skills/datashield-dev/references/functions/`: dsBase and DSI references.
- `skills/datashield-dev/references/code/`: released source of the dsExample template and dsBase
  function pairs that show each kind of disclosure check (listed in
  `tools/datashield-dev-code.csv`).
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

Rscript tools/build-wiki-guide.R <datashieldWiki> tools/datashield-dev-pages.txt skills/datashield-dev/references/docs
Rscript tools/list-releases.R dev.csv datashield/dsBase datashield/DSI
Rscript tools/build-all-references.R dev.csv skills/datashield-dev/references/functions
Rscript tools/build-code-examples.R tools/datashield-dev-code.csv skills/datashield-dev/references/code
```

`build-wiki-guide.R` needs pandoc for the wiki's HTML pages. Set `GITHUB_TOKEN` to avoid GitHub's API rate limit.

## Checks

`tools/check-skill.R` runs on every pull request. It checks that each `SKILL.md` has valid
frontmatter and that the files it points to exist. Across `SKILL.md` and the reference files
(except external documentation and source in `references/docs/` and `references/code/`, which
are checked for credentials only), it
fails on calls to `ds.*`, `dh.*`, `datashield.*` or `armadillo.*` functions missing from
`references/functions/`, on defunct functions and on
username or password arguments, and warns on deprecated or superseded functions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
