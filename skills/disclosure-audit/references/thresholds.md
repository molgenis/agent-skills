# Disclosure-control threshold reference

Concrete numeric controls, to seed guideline values for the audit rubrics. The
DataSHIELD `nfilter.*` set is the working baseline; external standards are given
for comparison and to justify deviations.

## DataSHIELD `nfilter.*` (dsBase baseline)

dsBase declares the defaults as `default.*` options in `inst/DATASHIELD`; the
platform (Opal / Armadillo) sets them per profile at session start, and admins
can override them. dsBase reads them with `listDisclosureSettingsDS`. Defaults:

| Control | Default | Guards (class) | Meaning |
|---|---|---|---|
| `nfilter.tab` | **3** | subsetting | min non-zero cell count in returned tables / min valid N for summaries |
| `nfilter.subset` | **3** | subsetting | min subset size (and min complement/difference size) |
| `nfilter.glm` | **0.33** | subsetting (over-param) | max params as a fraction of N in model fits |
| `nfilter.kNN` | **3** | subsetting | min neighbourhood size for plot anonymisation |
| `nfilter.levels.max` | **40** | subsetting | max distinct factor levels (absolute) |
| `nfilter.levels.density` | **0.33** | subsetting | max distinct values as a fraction of length |
| `nfilter.string` | **80** | inference (code-hiding) | max argument-string length |
| `nfilter.stringShort` | **20** | inference (code-hiding) | shorter arg-string cap (matrix/name args) |
| `nfilter.noise` | **0.25** | inference | min perturbation level for plot returns (anti-denoise) |
| `datashield.privacyControlLevel` | **banana** | gate | each restricted function lists the levels that allow it (`permissive`, `avocado`, `banana`, `carrot`); under the default `banana`, functions that allow only `permissive`/`avocado` are blocked |
| `privacyLevel` (legacy) | **5** | subsetting | superseded by `nfilter.*` |

Notes: `nfilter.tab` = 3 is the dsBase default; **5** replicates the most common
worldwide releaser threshold and **10** the direction census providers are
moving. Avraam et al. 2025 say custodians commonly choose 5 or 10. Every TRE
output-checking standard below uses 10. Values are stored as strings and
coerced with `as.numeric`.

- `nfilter.tab` checks only **non-zero** cells; zero cells are not checked.
- No dominance, group-disclosure or zero-cell control is documented for
  DataSHIELD (Avraam et al. 2025; Preen et al.).
- The 0.33 values (`nfilter.glm`, `nfilter.levels.density`) have no published
  derivation.
- `privacyControlLevel` modes in Avraam et al. 2025: `permissive` (allows
  everything), `non-permissive` (blocks known-inference and
  subsetting/difference functions), `avocado` (blocks subsetting/difference
  functions) and `banana` (blocks known-inference functions; the default). The
  dsBase code also has `carrot`, which the paper does not list. Only the dsBase
  test harness sets `permissive`. Under `banana`, `dmtC2SDS`, `cDS`, `rNormDS`,
  `rUnifDS`, `rBinomDS`, `rPoisDS`, `seqDS` and `setSeedDS` are blocked, but
  subsetting and recoding functions stay allowed (source reading, not
  published). A gate on named functions does not close a mechanism: whether
  other functions let the client supply vectors or seeds has to be checked per
  package.

## External SDC / statistical-standards comparison

TRE output-checking standard (DwB/Eurostat guidelines on CROS, SDAP Handbook
v2.0, ACRO `default.yaml`, UK LLC guidebook) against the DataSHIELD default:

| Output | Standard | DataSHIELD default |
|---|---|---|
| Minimum cell | **10** units per cell or statistic | `nfilter.tab` = 3 |
| Zero cells | disclosive (ACRO); counted as a low count (UK LLC) | not checked |
| Regression | residual **df ≥ 10** and ≥ 10 units (CROS, ACRO) | parameters ≤ 0.33·N |
| Means, SD, variance | ≥ **10** observations (UK LLC) | n > 3 for means, n > 6 for covariances in v6.2.0 (Huth et al.) |
| Group disclosure | no cell > **90%** of its row or column (CROS) | none documented |
| Dominance | largest contributor < **50%** (CROS); ACRO (n,k) = **(2, 90%)** and p = **10%**; ABS reportedly 50% and 67% (search summary only) | none documented |
| Min, max, percentiles | unsafe by default; release only with ≥ 10 tied units, rounding or banding | Preen et al. say DataSHIELD "allows min/max"; not checked against code |
| Residuals | individual residuals never released (SDAP) | not returned by regression functions |
| Trained models | attack simulation before release (GRAIMATTER) | no control documented |

The regression rules are not equivalent. With N = 12 and 3 parameters the
0.33·N rule passes but df = 9 fails df ≥ 10, so for small N DataSHIELD's rule is
the looser; for large N it is stricter than needed. The standards rely on a
human checker for dominance and differencing; ACRO cannot check differencing
across outputs automatically.

Other rules for comparison:

| Standard | Threshold | Notes |
|---|---|---|
| Prominent guidelines (web query systems) | suppress cells **< 5** | Ohm et al. 2017 fault systems using less |
| National statistics (small-cell rounding) | round to **0 or 3**, remove 1s and 2s | Norway/Estonia/Australia/NZ/Netherlands (ONS review) |
| US Cancer Statistics / stricter agencies | suppress **< 16** / **< 10** | more conservative variants |
| k-anonymity | each record indistinguishable among **k** | Sweeney 2002 |
| l-diversity | **l** well-represented sensitive values per class | Machanavajjhala 2007 |
| t-closeness | class distribution within **t** (EMD) of global | Li et al., ICDE 2007 |

## Differential privacy (information-bounding, class 2)

- **DP-SGD** — per-example gradient clipping (norm bound `C`) + Gaussian noise,
  accounted with the moments accountant (Abadi et al., CCS 2016).
- **ε (epsilon)** is the privacy-loss budget; smaller is stronger. DP with a
  finite, enforced budget is the only control that STOPS reconstruction and
  membership inference; everything else REDUCES.
- **Provable regime.** User-level ε ≤ ~1–4, with noise multiplier σ ≥ ~1–3 for
  low reconstruction bounds. Bounds are prior-dependent: against a prior of 10
  candidates (10% by guessing) the reconstruction bound is 0.737 at σ = 0.5,
  0.322 at σ = 1 and 0.080 at σ = 3 (Hayes et al.). For membership, TPR ≤
  e^ε·FPR + δ caps TPR at 0.1% FPR at about 0.27% for ε = 1 and 5.5% for ε = 4,
  and is vacuous at ε ≥ 8 (the notes' calculation). A server that can insert
  gradient canaries is the threat model under which audits are tight, so read ε
  close to literally for FL (Nasr et al.).
- **ε ≤ 10 only with auditing evidence.** Above 10 the guarantee "cannot be
  taken on as sufficient evidence" without auditing (Ponomareva et al.).
- **ε alone does not fix risk.** At ε = 4 the reconstruction bound is about 0.20
  at sampling rate q = 0.01 and about 0.35 at q = 0.99 (Hayes et al.). Report
  (ε, δ, q, σ, T, C, accounting unit). Prefer user-level accounting: a
  20-example cap turns example-level ε = 2 into user-level ε = 40 (Ponomareva
  et al.).
- **Clipping norm.** No clip-norm value confers privacy. C sets sensitivity and
  utility; the privacy level comes from σ with q and T. "There is no good a
  priori setting of the clipping norm" (Andrew et al.). Adaptive clipping must
  itself be DP, or the clip value leaks update norms (inference).
- **Where the noise is added.** Central DP does not protect against a malicious
  app author: the noise must be local, or applied outside the author's control.
- **Empirical safety is not a guarantee.** Ziller et al. found 0% realistic
  reconstruction in medical imaging even at ε = 10⁹, yet 39% of liver images
  became reconstructable under a looser criterion at ε = 10¹⁵. Treat safety at
  ε ≥ 10³ as "not demonstrated", not "infeasible".
- **Budget scope.** The budget must be global per dataset, across analysts,
  sessions and sites; if it resets per session, analyst or site, composition
  does not hold. Seeded deterministic noise, proposed so repeated calls agree,
  puts a system in the Diffix/TableBuilder class that equivalent-query averaging
  broke.
- **Deployment reference.** Gboard production FL uses user-level zCDP with ρ
  between 0.2 and 2 (Xu et al.), roughly ε 4.5–15.6 at δ = 10⁻¹⁰ (the notes'
  conversion).

## Guideline-value stance for the framework

- **Class 1 (subsetting):** adopt the DataSHIELD `nfilter.*` defaults as the
  working minimum; recommend `nfilter.tab`/`subset` ≥ 5 where the deployment
  follows census-grade practice, and 10 to match TRE output checking.
  - Add a residual df ≥ 10 check alongside `nfilter.glm`.
  - Add a per-column minimum non-zero count for dummy and interaction columns
    (inference).
  - Treat min/max/quantile outputs as unsafe unless ≥ `nfilter.tab` units tie.
  - Before citing Preen et al.'s claim that DataSHIELD "allows min/max", check it
    against dsBase.
- **Class 2 (inference):** thresholds alone are insufficient — the control is
  *structural* (bound what may be returned; add DP noise; whitelist functions),
  not a single number. Per-query thresholds REDUCE; only a global DP budget
  STOPS. See `rubric.md`.

## Sources
- dsBase source (github.com/datashield/dsBase), `tests/testthat/disclosure/set_disclosure_settings.R`,
  DataSHIELD wiki *Disclosure control*.
- DataSHIELD, *mitigating disclosure risk in a multi-site federated analysis
  platform*, Bioinformatics Advances 2025 (vbaf046).
- Ohm et al., J Public Health Manag Pract 2017 (PMC5409873).
- ONS/UKSA, *Statistical Disclosure Control and Differential Privacy*, 2024
  (EAP215); Eurostat, *Understanding output checking*; sdctools *Handbook on SDC*.
- Sweeney 2002 (k-anonymity); Machanavajjhala 2007 (l-diversity); Li et al. 2007
  (t-closeness); Abadi et al., CCS 2016 (DP-SGD).
- Bond, Brandt & de Wolf, *Guidelines for Output Checking* (DwB; CROS PDF,
  2024); SDAP *Handbook on SDC for Outputs* v2.0, 2024; ACRO `default.yaml`
  (github.com/AI-SDC/ACRO); UK LLC Guidebook, *SDC*; ABS DataLab Safe
  Researcher Training, Module 3 (search summary only).
- Preen et al., ACRO/SACRO, arXiv:2212.02935; Jefferson et al., *GRAIMATTER
  Green Paper*, arXiv:2211.01656; Huth et al., Bioinformatics 2023.
- Hayes, Mahloujifar & Balle, NeurIPS 2023 (arXiv:2302.07225); Nasr et al.,
  *Tight Auditing of DP ML*, arXiv:2302.07956 (USENIX venue not verified);
  Ponomareva et al., *How to DP-fy ML*, arXiv:2303.00654 (JAIR venue not
  verified); Andrew et al., *Adaptive Clipping*, NeurIPS 2021
  (arXiv:1905.03871); Ziller et al., Nature Machine Intelligence 2024
  (doi:10.1038/s42256-024-00858-y); Xu et al., ACL 2023 (arXiv:2305.18465).
- Gadotti et al., USENIX Security 2019; Asghar & Kaafar, PoPETs 2020
  (arXiv:1902.06414).
