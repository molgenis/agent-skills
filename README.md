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
- `skills/datashield/references/patterns.md`: DataSHIELD-specific patterns and pitfalls.
- `skills/datashield/references/style.md`: default conventions for results and plots.

## Regenerating references

```
Rscript tools/list-client-packages.R packages.csv
Rscript tools/build-all-references.R packages.csv skills/datashield/references/functions
Rscript tools/build-recipes.R <datashieldWiki>/analysis-tutorials skills/datashield/references/recipes
```

Set `GITHUB_TOKEN` to avoid GitHub's API rate limit.

## Checks

`tools/check-skill.R` runs on every pull request and checks that each `SKILL.md` has valid
frontmatter, that the files it points to exist, and that every DataSHIELD function it names is in
`references/functions/`.
