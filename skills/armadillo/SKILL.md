---
name: armadillo
description: Manage MOLGENIS Armadillo servers from R — projects, folders, tables and resources, uploading data, creating subsets (views), installing packages on profiles, project users, and installing, updating or migrating a server. Use whenever the user mentions Armadillo administration or data management, MolgenisArmadillo, armadillo.* functions, uploading data to Armadillo, Armadillo projects, views or profiles. For DataSHIELD analysis on Armadillo, use the datashield skill.
---

# Armadillo

Armadillo is a DataSHIELD server. This skill covers data managers' and administrators' work on
it with the MolgenisArmadillo R package and the server documentation. Analysis of the data goes
through DataSHIELD (the `datashield` skill), never through this skill.

## Hard rules

- **Log in with `armadillo.login(url)` only.** It opens a browser where the user signs in, so
  you never see their password. Never use `armadillo.login_basic` or ask for a username or
  password. If only basic login is available, stop and ask the user to log in themselves.
- **Never look at the data.** Tables uploaded to or loaded from Armadillo hold individual-level
  data. Report only names, dimensions and column names (`dim()`, `colnames()`); never print rows,
  `head()`, `summary()` or values.
- **Destructive calls need explicit confirmation.** Before `armadillo.delete_project`,
  `armadillo.delete_project_folder`, `armadillo.delete_table`, `armadillo.delete_resource`,
  `armadillo.move_table`, `armadillo.move_resource`, or `armadillo.create_project` with
  `overwrite_existing = "yes"`, show the user the exact project, folder and object and wait for
  them to confirm. Prefer `armadillo.copy_table` and check the copy before deleting the original.
- **Check before writing.** Run `armadillo.list_projects()` and `armadillo.list_tables(project)`
  first; if the target name already exists, ask the user before uploading.

## Concepts

- **Project → folder → table or resource.** A project groups the data one set of users may
  access. Tables are data frames stored as parquet; resources point to data held elsewhere.
  Objects are addressed as `project`, `folder`, `name`.
- **Subsets (views)** are tables built from selected variables of a source table, usually in a
  separate project so users get access to only those variables.
- **Profiles** are the R environments DataSHIELD runs in, each with its own installed and
  whitelisted server packages.
- **Users** are granted access per project, in the Armadillo UI or with
  `armadillo.create_project(users = )`.

## Workflows

1. **Upload:** `armadillo.login(url)` → `armadillo.create_project(project)` →
   `armadillo.upload_table(project, folder, table, name)` → `armadillo.list_tables(project)`.
2. **Create a subset:** describe it in a CSV and call
   `armadillo.subset_definition(reference_csv = )`, then
   `armadillo.subset(input_source = "subset_def", subset_def = )`. With `strict = FALSE` (the
   default) missing variables are skipped; report which were missing.
3. **Install a server package:** `armadillo.install_packages(paths, profile)`; the package is
   whitelisted automatically.
4. **Review access:** `armadillo.get_projects_info()`, `armadillo.get_project_users(project)`.
5. **Install, update or migrate a server:** follow the matching page in
   `references/docs/index.md` step by step; do not improvise.

## References

Read only what the task needs:

- `references/functions/`: one file per package (`MolgenisArmadillo.md`, `DSMolgenisArmadillo.md`),
  generated from the package documentation. Never use a function or argument that isn't there.
- `references/docs/index.md`: the Armadillo server documentation (concepts, UI, subsets,
  authentication, installation, updates and migrations), generated from the documentation site
  at the same release. Online version: https://molgenis.github.io/molgenis-service-armadillo/
