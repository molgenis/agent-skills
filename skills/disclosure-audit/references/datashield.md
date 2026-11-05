# DataSHIELD app — disclosure audit rubric

Instantiates `attack-vectors.md` and `rubric.md` for **DataSHIELD apps**
(server-side functions returning aggregates over remote individual-level data).

## Setting characteristics
- **Return channel.** Whitelisted server-side functions return aggregate
  statistics; assign functions write server-side objects (no client return).
- **Interactivity:** fully interactive/adaptive → **amplifies differencing (§2)
  and linear reconstruction (§4)**, which accumulate over many queries.
- **Return dimensionality:** low (tabular) → the small-cell / subsetting
  mechanisms (§1–§3) dominate in practice, but reconstruction (§4) is the
  dangerous blind spot.
- **Control model:** an allow-list of vetted functions, each responsible for its
  *own* checks. Safe only if every deployed function is individually vetted — the
  assumption the malicious-app threat denies. A whitelist model typically has **no
  generic guard** on what an arbitrary function may return, so §4/malicious-app is
  defended only function-by-function, if at all.

## Return-surface checklist (steps 1–2)
- Enumerate every server-side function the app calls and what it returns to the
  client (versus assign, which stays server-side).
- For each return: is it an **aggregate over a group** (§1–§3) or a
  **per-record / full-length / high-dimensional** quantity (§4)?
- Flag any return whose size/dimensionality scales with N, and any RNG-seeded
  return.

## Mechanism screen

Look each section up in `attack-vectors.md` when a question is answered Yes or Unknown.

| Mechanism (`attack-vectors.md`) | Screening question |
|---|---|
| §1 Small-cell / minimum-frequency | Every returned aggregate gated by a min-N / cell-suppression check? high-cardinality returns capped? |
| §2 Differencing, trackers, linked tables | Does the function check the *complement/difference* size, not just the subset? Can derived indicators or two overlapping calls isolate one record? |
| §3 Dominance | Do magnitude aggregates apply a dominance (p% / n,k) rule? |
| §4 Reconstruction / seed-matrix | Can the function return a full-length / per-record / high-dim vector or matrix? Is any return RNG-seeded, and is the seed fixed or exposed to the client? Model fits capped by params-to-N? Can the analyst inject vectors that turn exact sums or cross-products into linear equations? |
| §9 Side channels | Do errors, refusals, warnings, levels, lengths or existence checks reveal data or answer a predicate? |
| §10 Regression and GLMM outputs | Per-iteration score/information, isolating dummies, diagnostics or random effects returned? |
| §11 Extremes, order statistics, bins | Min/max, quantiles, box-plot whiskers or analyst-chosen breaks returned? |
| §12 Cross-session accumulation | Can repeated or varied calls accumulate to a disclosure that no single call makes? |
| Malicious-app (cross-cutting) | Return precision/size bounded? negative weights that could invert an aggregation? |

## Controls that guard each mechanism
- **§1–§3 (small-cell / differencing / dominance):** minimum cell/subset sizes;
  complement/difference checks; dominance rules; level / kNN caps. Concrete
  guideline values in `thresholds.md`.
- **§4 (reconstruction) + malicious-app:** bound the number / dimensionality /
  precision of returned values; forbid per-record or full-length returns from
  aggregate functions; a **generic return-inspection guard** closes the gap that
  per-function checking leaves; params-to-N cap for model fits; never expose a
  perturbation seed (fresh secret, not a shared/discoverable option); calibrated
  noise / DP for residual risk.

## Scoring & output
Use `rubric.md`.
