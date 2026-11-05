# Flower FL app — disclosure audit rubric

Instantiates `attack-vectors.md` and `rubric.md` for **Flower
federated-learning apps of any data modality** (tabular, text, image, …). The
mechanisms are general; nothing here is specific to a particular task.

## Setting characteristics
- **Return channel.** Per round each client returns a reply `Message`: `arrays`
  (the full model `state_dict` — parameters *and* buffers) + `metrics` (scalars,
  incl. exact `num-examples`). The server aggregates (`FedAvg`) and releases a
  final model.
- **Interactivity:** multi-round but protocol-throttled (not freely adaptive).
- **Return dimensionality:** very high, near-lossless of the input → the
  reconstruction/inversion mechanisms (§5 of the catalogue) dominate.
- **Control model:** the app author defines the model and strategy; there is **no
  per-call vetting** of what a client returns. The malicious-app channel is wide
  open by default.

## Return-surface checklist (steps 1–2)
Open `*/client_app.py`, `*/server_app.py`, `*/task.py` and record:
- Every `@app.train()` / `@app.evaluate()` return `RecordDict` — which keys.
- Whether `arrays` is built from `model.state_dict()` (→ includes buffers).
- Model layer types: flag BatchNorm/normalisation buffers.
- Every metric key; flag `num-examples` and any count/per-class/per-record value.
- Server strategy, `min_*_nodes`, what/where the final model is persisted.
- Any custom return outside the standard `arrays`/`metrics` keys.

## Vector screen (step 3)

| Mechanism (`attack-vectors.md`) | Screening question | Evidence to cite |
|---|---|---|
| §5 Gradient/update inversion | Full parameter/gradient update returned? small batch / few local steps? | `state_dict` upload; `batch-size`, `local-epochs` |
| §5 BN-buffer prior | Normalisation running stats in the returned `state_dict`? | model layer list |
| §6 Membership inference | Per-example / per-round losses or embedding/bias components exposed? can the server alter the model per client? | metric keys; strategy |
| §7 Property inference | Do returns expose distributional properties beyond the task? | metric keys |
| §8 Memorisation | Is a final model trained on individual data released? generative/sequence? | server save path; model type |
| Malicious-app (cross-cutting) | Does the server modify weights before dispatch? first-layer sign-partition / sparse-scaled? extra / high-precision returns? | strategy code; init |
| §1 Small-N | `num-examples` unbounded? per-round loss on a small/homogeneous partition? | metric; model size |

## Mitigations — which *stop* vs *reduce* (peer-reviewed)

- **Secure aggregation** (cryptographic sum; server sees only the aggregate).
  **STOPS** passive honest-but-curious recovery of an individual update. **FAILS**
  against an active/malicious server: model-inconsistency and trap-weight attacks
  recover verbatim records regardless of client count or batch size.
  *(Bonawitz et al., CCS 2017; Pasquini et al., CCS 2022; Fowl et al., ICLR 2022;
  Boenisch et al., EuroS&P 2023.)*
- **Differential privacy / DP-SGD.** The **only** defence with a proven privacy
  floor — bounds reconstruction *and* membership. The required noise scales with
  model width (σ² = Ω(m·log(1/δ)/ε)), so a real floor costs utility; nominal /
  weak-ε DP does **not** stop attacks empirically. *(Abadi et al., CCS 2016; Tan
  et al., USENIX 2024; Liu et al., AISTATS 2025.)*
- **Gradient obfuscation** (quantization / sparsification / pruning / compression
  / clipping / sub-DP noise). **REDUCE only, never prevent** — defeated by
  adaptive attackers with auxiliary data ("false sense of security").
  *(Yue et al., USENIX 2023; Wu et al., UAI 2023.)*
- **Drop BN buffers / freeze BatchNorm / GroupNorm.** **REDUCE** — removes the
  known-BN-statistics precondition that makes honest-but-curious inversion
  tractable; not a formal prevent. *(Huang et al., NeurIPS 2021.)*
- **Aggregate-only metrics; fewer local steps; larger batches.** **REDUCE**
  fidelity only; FedAvg averaging alone does **not** protect.
  *(Geiping et al., NeurIPS 2020.)*

**Sufficient posture:** calibrated DP (for a floor) **+** secure aggregation
(against a passive server). Residual risk: active-server attacks and the DP
utility cost. **Rule of thumb:** treat any full-`state_dict` return (esp. with BN
buffers, small batches) as **High** absent DP; treat any server-side pre-dispatch
weight modification as **Critical** (trap-weights) pending review.

## Scoring & output
Use `rubric.md`.
