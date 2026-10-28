# Contributing

To add knowledge the skill is missing, open a
[New example](https://github.com/molgenis/agent-skills/issues/new?template=new-example.yml)
issue. A maintainer turns it into a file under `skills/datashield/references/examples/`.

To open a pull request directly instead:

1. Add `skills/datashield/references/examples/<task>.md` with sections for the goal, when to
   use it, steps, code and the package versions it was tested with.
2. Link it from `skills/datashield/references/examples/index.md`.
3. Run `Rscript tools/check-skill.R skills/datashield`. It fails on functions that do not exist
   or are defunct, and on username or password arguments; it warns on deprecated functions.

Do not edit `references/functions/` or `references/recipes/` by hand: they are generated (see the
README). Fix recipes in the DataSHIELD wiki tutorials instead.
