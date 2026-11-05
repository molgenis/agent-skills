# Audit methodology & scoring

The shared, deterministic procedure for categorising an app's disclosure risk.
`flower.md` and `datashield.md` instantiate the per-setting steps;
this file defines the scoring that both use, so the same app in → the same tier
out regardless of who (or which AI) runs it.

## Procedure (per app)

1. **Enumerate the return surfaces.** List every value the app sends back through
   the permitted channel (Flower: each `@app.train`/`@app.evaluate` reply and the
   released final model; DataSHIELD: every server-side function the app calls and
   what it returns). Record the exact keys/objects.
2. **Classify each returned object.** For each: is it an *aggregate over a group*
   (small-cell / differencing / dominance mechanisms) or a *per-record /
   high-dimensional / model quantity* (reconstruction / inversion mechanisms), or
   both?
3. **Screen against every vector** in `attack-vectors.md`. One question per
   vector, answered **Yes / No / Unknown**, each with a `file:line` evidence
   pointer. `Unknown` is a first-class answer and **escalates likelihood**
   (precautionary).
4. **Check the controls.** For each applicable vector, is there a control present
   (min-N gate, precision/size bound, DP noise, whitelist)? Record it or its
   absence with `file:line`.
5. **Confirm by running, where safe.** For each High or Critical finding, source the function
   into a local R session, set the disclosure options to the platform defaults, build toy
   data, and run the attack. Never run attacks against a live server or real data. Mark each
   finding **Confirmed** (attack ran and leaked) or **Reasoned** (from reading only), and drop
   or downgrade findings the run disproves.
6. **Try to break each recommended control** before recommending it, and report how it can
   still be bypassed.
7. **Score and record** using the tables below.

Run steps 3–4 twice, independently, and merge the findings before step 5.

## Scoring

For each **applicable** vector:

- **Severity (1–4)** — what a successful attack discloses:
  - 1 = aggregate only, non-reidentifying
  - 2 = membership / a property of an individual
  - 3 = a sensitive attribute value of an individual
  - 4 = full raw-record reconstruction / direct identifier
- **Likelihood (1–4)** — driven by the vector's preconditions and the threat
  model (honest-but-curious + malicious app; interactivity; whether a control is
  present):
  - 1 = precondition absent or fully controlled
  - 2 = precondition partially present, control reduces it
  - 3 = precondition present, no effective control (**default for `Unknown`**)
  - 4 = precondition present and trivially exploitable
- **Vector risk = Severity × Likelihood**, mapped to tiers:
  - **Low 1–3 · Medium 4–7 · High 8–11 · Critical 12–16**
- **App risk = max over vectors**, reported with the count of High/Critical
  vectors (so a many-Medium app is visible).
- **Order within a tier** by, in turn: works at the platform's default settings and privacy
  level; fewer calls needed; Confirmed before Reasoned.

## Determinism guardrails
- Fixed files/paths to open (given per setting).
- Closed answer set (Yes/No/Unknown) + fixed scoring tables.
- **No score without a cited `file:line`.**
- `Unknown` never scores as safe.

## Thoroughness (mandatory)
- **Open and classify EVERY return surface** — every whitelisted function /
  every returned value. No triage, no sampling, no "highest-signal only".
- A function may be rated **only after its source has been read**. `Unknown` is
  reserved for genuinely undecidable cases *after* reading — never for "not opened
  yet / ran out of time".
- If coverage must be bounded, **explicitly list every function not opened** so
  the gap is visible; a bounded pass is not complete until a follow-up closes it.
- Cross-check the whitelist against the source: flag any whitelisted method with
  **no source file**.

## Output template

```
# Audit: <app> @ <commit>
Setting: flower | datashield
Return surfaces: <table from step 1>

## Findings
| vector | applicable? | evidence (file:line) | control? | severity | likelihood | risk | tier | default settings? | calls | Confirmed/Reasoned |
|--------|-------------|----------------------|----------|----------|------------|------|------|-------------------|-------|--------------------|

## App risk: <tier>  (High: n, Critical: m)
## Top findings & recommended controls
## Residual risk / Unknowns
```
