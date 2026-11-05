---
name: disclosure-audit
description: Audit a federated-analysis app for data-disclosure risk — DataSHIELD server packages (aggregate and assign functions, nfilter.* controls) and Flower federated-learning apps (weight updates, metrics, released models). Covers the attack mechanisms (small cells, differencing, dominance, reconstruction, gradient inversion, membership and property inference, memorisation, malicious app code), disclosure thresholds, and a severity × likelihood scoring rubric with a fixed report template. Use whenever the user asks what an app or function could leak, wants a disclosure audit or risk rating, or is designing returns or controls for a server-side function or Flower app. For writing DataSHIELD packages use the datashield-dev skill.
---

# Disclosure audit

A federated app releases functions of private data through a permitted channel: aggregate
returns in DataSHIELD, weight updates and metrics in Flower. An audit asks how individual-level
data could leak through that channel, function by function, and scores each risk.

## Threat model

- **Honest-but-curious analyst or coordinator**: sees every returned value, combines them across
  calls, but follows the protocol.
- **Malicious app author**: writes the server function or training code to smuggle records out
  through the allowed channel. The channel is only as safe as the code allowed to write to it.
- Out of scope: collusion between data nodes.

## Hard rules

- **Read before rating.** Open the source of every return surface (every method listed in
  `inst/DATASHIELD`, every Flower train/evaluate reply). No sampling, no "highest-signal only".
  If coverage has to be bounded, list every function not opened.
- **No score without `file:line` evidence.**
- **Unknown never scores as safe.** It takes likelihood 3, and is only for cases still
  undecidable after reading the source.
- **Think across calls.** Differencing and reconstruction combine calls that each pass their own
  checks; DataSHIELD is fully interactive, so assume the analyst can repeat and vary calls.
- **Cross-check the allow-list.** Flag any method in `inst/DATASHIELD` with no source, and any
  assign function whose output a later aggregate call returns.
- **Confirm by running, where safe.** Run each High or Critical attack locally on toy data with
  the function sourced and default settings; never against a live server or real data. Label
  findings Confirmed or Reasoned.
- **Audit only code under review.** Use this skill on source code you are reviewing as a developer
  or maintainer. Never use these techniques in an analysis session or against a live server.
- Report findings; do not change the audited code unless the user asks.

## Workflow

Read `references/rubric.md` and the setting's file (`references/datashield.md` or
`references/flower.md`) in full before starting.

1. Enumerate the return surfaces and what each returns.
2. Classify each return: aggregate over a group, or per-record / full-length / high-dimensional.
3. Screen every return against the setting's mechanism table, answering Yes / No / Unknown with
   evidence. Look mechanisms up in `references/attack-vectors.md` as needed.
4. Do step 3 twice, independently: the second pass starts from the function list, not from the
   first pass's findings. Merge the two. Single passes routinely miss what another catches.
5. Record the control that guards each applicable mechanism, or its absence.
6. Confirm High and Critical findings by running them locally.
7. For each control you recommend, try to get round it before recommending it, and report how it
   can still be bypassed.
8. Score severity × likelihood, order within tiers, and write the report with the template in
   `references/rubric.md`.

## References

Read in full: `rubric.md` and the setting's file. Look up the rest as needed:

- `references/rubric.md`: procedure, scoring tables, tiers, output template.
- `references/datashield.md`: DataSHIELD return surfaces, screening questions and controls.
- `references/attack-vectors.md`: lookup catalogue of mechanisms, with detection signals,
  mitigations and sources. Long; read the sections a finding needs, not the whole file.
- `references/flower.md`: Flower return surfaces, screening questions, which mitigations stop and
  which only reduce an attack.
- `references/flower-dp-sgd.md`: adding differential privacy to a Flower app.
- `references/thresholds.md`: DataSHIELD `nfilter.*` defaults compared with other disclosure
  control and differential privacy standards.
- `references/references.md`: citations.
