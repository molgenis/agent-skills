# Applying differential privacy in a Flower app

Companion to the mitigations section of `flower.md`. How to actually add DP to a
Flower FL app, and — crucially — *which configuration protects against whom*.

> Verified against a local Flower checkout at **v1.27** (message-based API).
> Flower's DP is officially **preview — "not for production with sensitive data
> without contacting Flower Labs"** (`how-to-use-differential-privacy.rst`).
> **Secure aggregation is not yet ported to the message-based strategy API**; to
> combine DP + SecAgg today you must use the legacy workflow path
> (`examples/fl-dp-sa/`).

## Two mechanisms — do not conflate them

| | Built-in DP wrappers/mods | Opacus `PrivacyEngine` |
|---|---|---|
| Granularity | **client/user-level** (one "record" = one client's whole update) | **sample-level DP-SGD** (one "record" = one training example) |
| Mechanism | clip each client update to L2 `clipping_norm`, add Gaussian noise to the **aggregate** | per-example gradient clip `max_grad_norm` + noise **inside the optimizer** |
| ε | none automatic — compute externally from (σ, sampling rate, rounds, δ) | real ε via built-in accountant (`get_epsilon(delta=…)`) |
| Protects | membership/reconstruction at the *client* granularity | membership/reconstruction of *individual rows* |

## Option A — sample-level DP-SGD (Opacus), inside `@app.train`
Strongest per-record guarantee. Server stays a plain `FedAvg`; privacy is local.

```python
from opacus import PrivacyEngine

@app.train()
def train(msg, context):
    model = Net().to(device)
    model.load_state_dict(msg.content["arrays"].to_torch_state_dict())
    optimizer = torch.optim.SGD(model.parameters(), lr=..., momentum=0.9)

    pe = PrivacyEngine()  # secure_mode=True (+torchcsprng) for real deployments
    model, optimizer, loader = pe.make_private(
        module=model, optimizer=optimizer, data_loader=train_loader,
        noise_multiplier=SIGMA,   # σ
        max_grad_norm=C,          # per-sample gradient L2 clip
    )
    # ... train over loader ...
    epsilon = pe.get_epsilon(delta=DELTA)      # ε accounting
    arrays = ArrayRecord(model._module.state_dict())   # unwrap GradSampleModule
    return Message(content=RecordDict({
        "arrays": arrays,
        "metrics": MetricRecord({"epsilon": epsilon}),
    }), reply_to=msg)
```
- **Unwrap** `model._module.state_dict()` after `make_private`, else keys won't
  match the plain model.
- Per-round ε is *local*; cross-round FL accounting needs care.
- Working example: `examples/opacus/` (`opacus==1.5.4`).

## Option B — client/user-level DP (built-in wrappers), in the ServerApp
```python
from flwr.serverapp.strategy import DifferentialPrivacyClientSideFixedClipping, FedAvg

strategy = DifferentialPrivacyClientSideFixedClipping(
    FedAvg(...), noise_multiplier=SIGMA, clipping_norm=C, num_sampled_clients=N,
)
# strategy.start(grid=grid, initial_arrays=..., num_rounds=...)
```
Client (client-side variants only):
```python
from flwr.clientapp.mod import fixedclipping_mod

@app.train(mods=[fixedclipping_mod])
def train(msg, context): ...
```
- Variants: `DifferentialPrivacyServerSideFixedClipping`,
  `...ClientSideFixedClipping`, `...ServerSideAdaptiveClipping`,
  `...ClientSideAdaptiveClipping` (adaptive learns `clipping_norm` per round via a
  noised clipped-fraction). Adaptive client mod = `adaptiveclipping_mod`.
- Noise std added to the aggregate = `noise_multiplier * clipping_norm /
  num_sampled_clients`. `num_sampled_clients` **must** match actual clients/round
  (`fraction_fit`/`min_fit_clients`).
- **No automatic ε.** Default `noise_multiplier` in examples (0.2) is *nominal*;
  docs recommend **σ ≥ 1.0**.

## The threat matrix — which config protects against whom
Central DP adds noise only to the *aggregate*, so the server transiently sees
every client's raw (clipped) update. That does **not** protect against an
honest-but-curious server.

| Configuration | Server sees raw per-client update? | Protects against |
|---|---|---|
| Central DP, server-side clip | **Yes** (unclipped) | external / downstream only |
| Central DP, client-side clip | **Yes** (clipped) | external / downstream only |
| **Central DP + Secure Aggregation** | **No** (encrypted sum) | honest-but-curious server + external |
| **Local DP** (`LocalDpMod`) | **No** (noised) | untrusted server, per client |
| **Sample-level DP-SGD** (Opacus) | sees noised local model | untrusted server, **per training record** |

`LocalDpMod(clipping_norm, sensitivity, epsilon, delta)` uses the analytic
Gaussian mechanism with a per-round ε you specify directly (no accountant; repeated
rounds consume untracked budget). DP+SecAgg reference: `examples/fl-dp-sa/`
(`SecAggPlusWorkflow` + client mods `[secaggplus_mod, fixedclipping_mod]` — **DP
clipping mods last**).

## What it does and doesn't protect
See `flower.md` and `attack-vectors.md`. In short: **bounds** membership,
reconstruction and memorisation *at the chosen granularity, with a meaningful ε*;
**does not** cover property/distribution inference, non-gradient/side channels,
weak-ε nominal settings, group privacy, or — for *central* DP — the curious server
(needs SecAgg or local/Opacus DP). Costs utility and (Opacus) per-sample-gradient
compute.

## Sources
- Flower source (github.com/adap/flower) — `framework/py/flwr/serverapp/strategy/dp_*.py`,
  `framework/py/flwr/clientapp/mod/{centraldp_mods,localdp_mod}.py`,
  `framework/py/flwr/common/differential_privacy.py`, `examples/opacus/`,
  `examples/fl-dp-sa/`, `framework/docs/source/how-to-use-differential-privacy.rst`.
- Docs: flower.ai/docs/framework/how-to-use-differential-privacy.html ·
  explanation-differential-privacy.html · opacus.ai.
- Papers: Abadi et al. CCS 2016; McMahan et al. arXiv:1710.06963; Andrew et al.
  arXiv:1905.03871. See `references.md`.
