# Attack-vector reference

The core, setting-agnostic catalogue of ways individual-level data can be
disclosed through the *permitted* return channel of a privacy-preserving
distributed-analysis system. Flower (federated learning) and DataSHIELD
(federated statistics) are two instantiations of the **same** problem — release a
function of a private dataset without disclosing individuals — so each mechanism
below is given with both instantiations where it applies.

Organised by **named attack mechanism**, following the disclosure-control (SDC)
and ML-privacy literatures. See `flower.md` and `datashield.md` for
the per-setting rubrics, `thresholds.md` for concrete numeric controls, and
`rubric.md` for scoring.

## Threat model

- **Honest-but-curious coordinator.** The server/analyst sees every returned
  value and may combine them, but follows the protocol.
- **Malicious app author.** The analysis/training *code itself* is written to
  smuggle raw records out through the allowed aggregate channel — a rogue
  server-side function (DataSHIELD) or a crafted model/strategy (Flower). This is
  the decisive threat: the channel is only as safe as the code allowed to write
  to it. Its named mechanisms are in the cross-cutting section at the end. In
  cross-silo Flower deployments the app author controls node selection and the
  strategy, so every "malicious server" precondition in the literature is a
  malicious-app-author precondition.
- **Malicious client.** One data node poisons its own training data to make
  other nodes' data leak (§13). This is a single node acting alone, not
  collusion.
- **Out of scope:** multi-party collusion between data nodes.

Per-mechanism schema: *mechanism · what is disclosed · channel · preconditions ·
detection signals · severity/likelihood · mitigation · references.*

Controls are marked **STOPS** (a bound on total information released) or
**REDUCES** (raises attack cost; a published break exists) where the evidence
gives a verdict. Only differential privacy with a finite budget enforced across
every query, analyst and session STOPS reconstruction and membership inference
with a guarantee. Every per-query control only REDUCES.

---

## 1. Small-cell / minimum-frequency disclosure
- **Mechanism.** An aggregate over a group of size 1 (or few) *is* the
  individual value(s): a count-of-1 cell identifies a person; a mean of one row
  is that row. Re-identification via near-uniqueness (high-cardinality
  categoricals, quasi-identifier combinations) is the same mechanism.
- **Disclosed.** Identity and/or exact attribute values of isolated individuals.
- **Instantiations.** DataSHIELD: small cells, small subsets, tiny groups. Flower:
  exact `num-examples` and per-round loss on a small/homogeneous partition.
- **Detection signals.** Aggregates/returns whose group size is not checked
  against a minimum; count tables without suppression; high-cardinality returns.
- **Severity/likelihood.** High severity; high likelihood wherever the analyst
  controls grouping.
- **Mitigation.** Minimum cell/subset size (`nfilter.tab`, `nfilter.subset`);
  suppression; max levels / kNN caps for uniqueness (`nfilter.levels.max`, kNN).
  All REDUCE: they are defeated by trackers (§2).
- **References.** Ohm et al., J Public Health Manag Pract 2017 (PMC5409873); ONS
  *SDC* guidance, UKSA 2024 (EAP215); Hundepool et al., *Statistical Disclosure
  Control*, 2012; Sweeney, *k-anonymity*, 2002; Machanavajjhala, *l-diversity*,
  2007; Li et al., *t-closeness*, ICDE 2007.

## 2. Differencing, trackers and linked tables
- **Mechanism.** Two queries differing by one record (a subset and its
  near-complement, or a table before/after a filter) are subtracted to isolate
  that record — even though each query alone passes a min-N check. A general
  tracker exists in most databases: if the analyst can define query sets by
  predicates, query-set-size restriction does not hold (Denning et al.).
  DataSHIELD's assign functions, which build indicators, recodes and subsets
  server-side, are the tracker in modern form; Huth et al. (§4) is a concrete
  instance. Variants (inference; none tested on DataSHIELD):
  - *Subset by unique value.* Subset on `id == k`, an exact continuous value or a
    quasi-identifier conjunction: take T ∪ {k} and T, both ≥ 3, and difference
    any aggregate.
  - *Derived-indicator binary search.* The mean of `ifelse(x > c, 1, 0)` is the
    count above c; binary search over c yields order statistics (§11).
  - *Cross-site subtraction.* An analyst who is also the data holder at site A
    knows A's data, so a pooled output minus A is site B's output.
  - *Temporal differencing.* The same aggregate before and after a data refresh
    gives the added or removed records.
  - *Linked tables across function families.* A cross-tabulation, group means
    and a GLM with a factor are three views of one classification, so
    suppressing a cell in one view is undone by another.
- **Disclosed.** The differenced individual's values; order statistics.
- **Preconditions.** Analyst can issue overlapping subsets or build derived
  variables; **interactivity makes this trivial** (DataSHIELD), weaker in
  Flower's round protocol. Subsetting and recoding functions remain allowed
  under the default `privacyControlLevel` "banana" (dsBase source reading, not
  published).
- **Detection signals.** Subset functions that check their own size but not the
  size of the *difference* from a prior/complementary subset; subset or assign
  functions accepting arbitrary logical expressions; no limit on overlap with
  earlier subsets; indicator or recode builders with analyst-chosen cut points
  (`ifelse`, `cut` with user `breaks`); row-order and sequence builders
  (`seq_along`, `rep`, `cumsum`, lag/lead, sorting by a sensitive variable);
  pooled-only returns where per-site N is small; tables reloaded under the same
  name.
- **Severity/likelihood.** High severity; high likelihood wherever the analyst
  can subset or recode.
- **Mitigation.** Minimum query-set or subset size — REDUCES (weak; trackers and
  pseudo-random large subsets bypass it). Complement/difference size check —
  REDUCES. Consistent (cell-key) perturbation across linked tables, as in ABS
  TableBuilder — REDUCES (TableBuilder fell to automated search). Query
  auditing — see §12.
- **References.** Denning, Denning & Schwartz, ACM TODS 1979; Chipperfield, Gow
  & Loong, Stat J IAOS 2016 (doi:10.3233/sji-160969); Creţu et al., *QuerySnout*,
  CCS 2022 (doi:10.1145/3548606.3560581); Huth et al., Bioinformatics 2023;
  Eurostat, *Understanding output checking*; ONS EAP215; Hundepool et al. 2012.

## 3. Dominance / concentration
- **Mechanism.** In a magnitude aggregate, a few large contributors dominate the
  total, so a big respondent's value is approximable even when N is adequate.
- **Disclosed.** The dominant contributor's value.
- **Instantiations.** DataSHIELD magnitude tables (turnover, totals). Weak Flower
  analogue.
- **Detection signals.** Sums/totals of skewed quantities without a dominance
  (p% / (n,k)) rule.
- **Mitigation.** p%-rule / (n,k)-dominance suppression.
- **References.** Eurostat *Understanding output checking*; Hundepool et al. 2012.

## 4. Reconstruction from linear / aggregate queries
- **Mechanism.** A return that is a *known linear function of the private rows*
  is invertible; more generally, answering *too many* accurate aggregates
  reconstructs the dataset (the "fundamental law of information recovery"). If
  every answer to a subset-sum query has error o(√n), a polynomial-time attacker
  reconstructs almost all of a secret column, whatever the perturbation:
  rounding, bounded noise and deterministic distortion are all covered, and
  exact answers fall to about n linearly independent queries (Dinur & Nissim).
  The notes report O(n log² n) random queries for the LP attack and noise of
  about √T against T queries — verify these constants against the paper before
  quoting. Later work closed the escape routes:
  - LP decoding tolerates about **23.9% arbitrarily wrong answers** (Dwork,
    McSherry & Talwar).
  - n deterministic queries suffice, with a fixed number of queries per bit for
    low-distortion mechanisms (Dwork & Yekhanin).
  - Contingency tables, classifier error rates and M-estimators, including
    linear and logistic regression coefficients, can be linearised and attacked
    the same way (Kasiviswanathan, Rudelson & Smith). "We release only
    coefficients" does not take a system outside the theory.

  The malicious-app archetype (**seed-matrix**): the function draws a
  pseudo-random matrix `A` from a **known seed**, returns `A·x`, and the analyst
  regenerates `A` and solves for `x`. Over-parameterised model fits (parameters
  ≈ N) are a form of this — individual rows are encoded in
  coefficients/residuals.

  **DataSHIELD instance (Huth et al. 2023).** Three tools suffice: a mean, a
  covariance against a client-supplied vector, and a way to place linearly
  independent vectors on the server (`ds.mean`, `ds.cov` and `ds.dmtC2S` in
  v6.2.0). Each covariance gives one inner product with the target, so n calls
  give a solvable system. BMI for 250 records was reconstructed with a maximum
  error of 2·10⁻¹². The injected vectors passed every check then in force,
  averaging over repetitions defeated zero-mean noise, and the same attack
  worked on TensorFlow Federated. Under the default "banana" level `dmtC2SDS`, the
  function the paper used, is blocked (dsBase source reading, not published);
  whether other functions accept client-supplied vectors has to be checked per
  package. An
  exact X′X with a binary sensitive column gives many independent equations per
  call, so far fewer than n calls are needed (inference).

  Practice has followed the theory: 97 million 2010 US Census records exactly
  reconstructed (Abowd et al.); Diffix's sticky noise and ABS TableBuilder's ±5
  bounded noise removed by equivalent-query averaging (Gadotti et al.; Asghar &
  Kaafar, < 200 queries). Each vendor fix was a construct-specific patch.
- **Disclosed.** Raw per-record values.
- **Preconditions.** The function may return a many-valued / full-length /
  per-record quantity, or many exact aggregates on analyst-chosen subsets; the
  analyst knows or controls the coefficients (a fixed or exposed RNG seed
  suffices).
- **Detection signals.** Aggregate functions returning full-length/per-record
  vectors or matrices; returns whose dimensionality scales with N; RNG-seeded
  returns with a fixed/exposed seed; model fits without a params-to-N cap; exact
  sums, means, X′X, variances or coefficients on analyst-chosen subsets;
  functions that store a client-supplied vector as a reusable server object;
  functions returning a covariance or inner product between a server variable
  and a client-supplied vector.
- **Severity/likelihood.** Highest severity (exact reconstruction); likelihood
  governed by whether the control model vets what a function may return. Under
  DataSHIELD defaults no control STOPS this class.
- **Mitigation.** Per-query controls cannot stop reconstruction; the attack
  lives in the combination of individually passing answers.
  - Minimum query-set or cell size — REDUCES (weak).
  - Query-count limit without noise — REDUCES.
  - Fresh random noise, unlimited queries — REDUCES (averaging defeats it).
  - Seeded or sticky noise — REDUCES (Diffix, TableBuilder broken).
  - Rounding — REDUCES (bounded perturbation under Dinur–Nissim; inference).
  - Construct bans / `privacyControlLevel` — REDUCES.
  - Sampling — REDUCES; STOPS only with DP accounting (inference).
  - Bound number/dimensionality/precision of returns; forbid per-record returns;
    params-to-N cap (`nfilter.glm`); never expose the perturbation seed;
    consume client-supplied vectors inside a function, never store them (Huth
    et al.'s fix) — all REDUCE.
  - Global query budget T with noise of order √T per answer — STOPS the
    linear-reconstruction family.
  - DP with a finite, enforced, global ε — STOPS, to the degree ε allows
    (QuerySnout reached near-optimal inference at ε = 5 and 10). The budget must
    be global per dataset across analysts, sessions and sites.
- **References.** Dinur & Nissim, *Revealing Information while Preserving
  Privacy*, PODS 2003 (doi:10.1145/773153.773173); Dwork, McSherry & Talwar,
  *The price of privacy and the limits of LP decoding*, STOC 2007; Dwork &
  Yekhanin, CRYPTO 2008; Kasiviswanathan, Rudelson & Smith, *The power of linear
  reconstruction attacks*, SODA 2013 (arXiv:1210.2381); Huth et al.,
  Bioinformatics 2023 (doi:10.1093/bioinformatics/btad531); Abowd et al.
  (arXiv:2312.11283); Gadotti et al., USENIX Security 2019; Cohen & Nissim, JPC
  2020 (doi:10.29012/jpc.711); Asghar & Kaafar, PoPETs 2020 (arXiv:1902.06414);
  Creţu et al., CCS 2022 (arXiv:2211.05249).

## 5. Gradient / weight-update inversion (model inversion / reconstruction)
- **Mechanism.** The gradient/weight update a client returns is an invertible
  encoding of its training batch; optimising a synthetic input to match the
  observed gradient reconstructs the batch *exactly* (pixel/token-wise), no
  auxiliary data. The FL instance of §4. Labels leak deterministically from the
  last-layer gradient sign. **BatchNorm running_mean/running_var buffers** both
  leak directly and act as a strong reconstruction prior. Refinements:
  - *Multi-epoch FedAvg is no safe harbour.* Simulating local training recovers
    **> 45% of FEMNIST images** from 10-epoch updates, against < 10% for the
    baseline (Dimitrov et al. 2022).
  - *Tabular FL is not safer.* TabLeak recovers records at **> 90% accuracy at
    batch size 128** under FedSGD and FedAvg.
  - *Aggregation does not hide the batch.* The Cocktail Party Attack applies
    blind source separation to aggregated FC-layer gradients at batch sizes up
    to 1024.
  - *Closed-form inversion.* R-GAP gives recursive closed-form reconstruction
    and a rank analysis of an architecture's inherent inversion risk, usable as
    a static check.
  - *Text.* LAMP (language-model priors) and FILM recover private text from LM
    updates.
  - *BN caveat.* Returned BN buffers aid the attacker, but literature attacks
    are impractical when clients update BN statistics locally; a new baseline
    attack still works in that setting (Hatamizadeh et al.).
- **Disclosed.** Raw training records + labels.
- **Preconditions.** Full state_dict/gradient returned (a full `state_dict`
  includes normalisation buffers by default); small batch/few local steps help
  but the attack scales; FedAvg averaging does **not** prevent it.
- **Detection signals.** Full-parameter/gradient upload; normalisation buffers in
  the return; small `batch-size` / few `local-epochs`; small MLP or logistic
  models on mixed categorical/continuous features; one-hot encodings in the
  input layer; per-client batch equal to the whole local dataset (full-batch
  GD); text or embedding models.
- **Severity/likelihood.** High severity. Passive optimisation attacks are lower
  likelihood: a gradient-leakage SoK finds them "notably constrained, fragile,
  and easily defensible" in realistic local-training settings (Du et al.).
  Malicious-author attacks (cross-cutting section) are high likelihood whenever
  the author controls the model.
- **Mitigation.**
  - Secure aggregation — REDUCES passive inversion (Cocktail Party, multi-round
    disaggregation); does not stop an active server.
  - Central DP-SGD / DP-FedAvg — bounds only if the noise is applied where the
    server (app author) cannot skip it; does not protect against the server
    itself.
  - Distributed DP + SecAgg — REDUCES; bypassed by sybils.
  - Local DP — STOPS (provable), at high utility cost.
  - Larger batch, more local epochs — REDUCES.
  - Compression, sparsification, dropping BN buffers / GroupNorm — REDUCES.
  - MixUp, InstaHide, PRECODE-style modules — REDUCES (InstaHide broken; PRECODE
    alone circumvented).
  - TEE with attestation — STOPS passive inversion if the TEE is trusted
    (empirical); REDUCES against an active server (side channels not covered).
  See `flower.md`.
- **References.** Zhu et al., *Deep Leakage from Gradients*, NeurIPS 2019
  (arXiv:1906.08935); Zhao et al., *iDLG*, 2020 (arXiv:2001.02610); Geiping et
  al., *Inverting Gradients*, NeurIPS 2020; Yin et al., *GradInversion* (BN
  prior), CVPR 2021; Dimitrov et al., *SPEAR*, NeurIPS 2024; Dimitrov et al.,
  *Data Leakage in Federated Averaging* (arXiv:2206.12395); Vero et al.,
  *TabLeak* (arXiv:2210.01785; ICML venue not verified); Kariyappa et al.,
  *Cocktail Party Attack*, ICML 2023 (arXiv:2209.05578); Zhu & Blaschko, *R-GAP*
  (arXiv:2010.07733; ICLR 2021, venue not verified); Balunović et al., *LAMP*
  (arXiv:2202.08827); Gupta et al., *FILM* (arXiv:2205.08514); Hatamizadeh et
  al. (arXiv:2202.06924); Huang et al., NeurIPS 2021 (arXiv:2112.00059); Du et
  al., *SoK: On Gradient Leakage in FL* (arXiv:2404.05403; venue not verified);
  Carlini et al., instance encoding (arXiv:2011.05315); Scheliga et al.
  (arXiv:2208.04767); Mo et al., *PPFL* (arXiv:2104.14380).

## 6. Membership inference and tracing
- **Mechanism.** Whether a specific record was in the training set or dataset
  leaks from per-round loss/confidence, from the released model (shadow models),
  or from crafted components (embedding-layer gradients reveal present tokens;
  bias parameters shift on non-members). Further routes:
  - *Tracing on high-dimensional means.* An individual's presence in a pool is
    detectable from many summary means (allele frequencies), even when every
    cell passes the count threshold (Homer et al.); tracing survives noise
    (Dwork et al. 2015).
  - *Log-loss oracle.* Aggregate log-loss on an adversary-chosen labelled set
    gives **perfect membership inference for any number of points in a single
    query**, even for models that do not overfit (Aggarwal et al.).
  - *Loss trajectories.* Losses across intermediate models give **≥ 6× higher
    TPR at 0.1% FPR** than final-model attacks (Liu et al.); per-round FL global
    models are a real trajectory.
  - *Metric slopes.* The slope of performance metrics across rounds separates
    members from non-members (Chang et al.).
  - *Active membership inference.* Crafted parameters succeed "under rigorous
    local differential privacy" unless the noise "would significantly damage
    FL's model utility" (Nguyen et al.).
  - *Subject-level membership across silos.* One person's records spread over
    several silos are covered by neither item-level nor user-level DP (Suri et
    al.); relevant to multi-cohort federations.
- **Disclosed.** Membership (sensitive for sensitive cohorts).
- **Preconditions.** Scalar metrics or many means returned; for the log-loss
  oracle, the server chooses the evaluation set or weights.
- **Detection signals.** Per-example / per-round loss or accuracy returned;
  embedding/bias exposure; metric keys beyond aggregate loss/accuracy (per-class
  counts, label histograms, confusion matrices, per-epoch loss lists,
  per-sample losses, high-precision floats); exact `num-examples` per evaluate
  call on server-supplied subsets; the server pushing evaluation data, labels or
  weights through `ConfigRecord` (the log-loss oracle; inference); every round's
  global model saved or broadcast; client-ID-keyed metric logging. DataSHIELD:
  functions returning many means in one call.
- **Severity/likelihood.** High for the log-loss oracle wherever the server sets
  the evaluation spec; otherwise moderate.
- **Mitigation.**
  - DP-SGD — bounds MIA on the released model (see `thresholds.md` for the ε
    regime). DP on training does not protect evaluation-metric oracles unless
    the evaluation outputs are themselves privatised.
  - Fixing the evaluation spec in the audited app, no server-chosen evaluation
    sets — STOPS the log-loss oracle specifically (inference).
  - Rounding/coarsening metrics; dropping per-class/per-epoch returns — REDUCES.
  - Limiting means per query and per session — REDUCES tracing; thresholds do
    not stop it.
  - Secure aggregation — no effect on MIA against the released model.
  - Heuristic (non-DP) defences — REDUCES at best; none are competitive with a
    tuned DP-SGD baseline (Aerni et al.).
  - Audit metric: report TPR at low FPR (LiRA), not average accuracy.
- **References.** Shokri et al., S&P 2017; Melis et al., S&P 2019; Nasr et al.,
  S&P 2019; MIA-in-FL survey, ACM Comput. Surv. 2024 (10.1145/3704633); Homer et
  al., PLoS Genetics 2008 (doi:10.1371/journal.pgen.1000167); Dwork et al., FOCS
  2015 (doi:10.1109/focs.2015.46); Aggarwal et al., PrivateNLP 2020
  (arXiv:2009.08559); Liu et al., CCS 2022 (arXiv:2208.14933); Chang et al.,
  USENIX Security 2024; Nguyen et al., AISTATS 2023 (arXiv:2302.12685); Suri et
  al. (arXiv:2206.03317); Carlini et al., *LiRA* (arXiv:2112.03570; IEEE S&P
  2022, venue not verified); Aerni et al., CCS 2024 (arXiv:2404.17399).

## 7. Property / attribute inference
- **Mechanism.** Updates/aggregates leak properties of a node's data distribution
  (class balance, presence of a subpopulation) beyond the analysis task.
  - *Label and category inference.* Label proportions and class presence leak
    from updates (class sniffing, quantity inference; Wang et al.); gradient
    direction and magnitude reveal which labels are present (LLG; Wainakh et
    al.); which classes a client holds is not protected by SecAgg in non-IID FL
    (Gao et al.).
  - *Poisoning-based property inference.* Poisoning 9–10% of training data
    reaches > 90% attack accuracy on the prevalence of a chosen property on
    tabular Census data (Mahloujifar et al.).
  - *Imputation caveat.* Much apparent attribute-inference success is imputation
    from population data, achievable without the model (Jayaraman & Evans).
- **Disclosed.** Distributional properties of a node's data; individual
  attributes. Score *distributional* and *individual* disclosure separately.
- **Preconditions.** Updates or aggregates per node; non-IID data; for the
  poisoning variant, influence over training data.
- **Detection signals.** Per-class counts, label histograms or confusion
  matrices in metrics; last-layer gradients returned; returns beyond the
  analysis task.
- **Severity/likelihood.** Moderate for distributional disclosure; individual
  attribute claims need an imputation baseline before they are scored high.
- **Mitigation.** DP — REDUCES; item-level DP does not bound population-property
  leakage (inference). Gradient compression — REDUCES label leakage. Minimise
  returned components — REDUCES.
- **References.** Melis et al., S&P 2019; Ganju et al., CCS 2018; Wang et al.
  (arXiv:1910.06044); Wainakh et al. (arXiv:2105.09369; PETS venue not
  verified); Gao et al., IEEE TDSC 2023; Mahloujifar, Ghosh & Chase
  (arXiv:2101.11073; venue not verified); Jayaraman & Evans (arXiv:2209.01292;
  CCS venue not verified).

## 8. Memorisation, extraction and reconstruction from the released model
- **Mechanism.** The *released model* unintentionally memorises rare unique
  sequences (IDs, secrets), extractable from the final artifact — especially
  generative/sequence models. Two further routes:
  - *Informed-adversary reconstruction.* "For convex models (e.g. logistic
    regression), reconstruction attacks are simple and can be derived in
    closed-form" by an adversary who knows all records but one (Balle et al.).
    This is the final-model analogue of differencing (§2) and bears directly on
    federated GLMs.
  - *Reconstruction from trained parameters.* A significant fraction of training
    data can be reconstructed from the parameters of a trained binary MLP
    classifier (Haim et al.).
- **Disclosed.** Training records or rare sequences.
- **Preconditions.** A released model or coefficients; for the informed
  adversary, knowledge of the rest of the cohort.
- **Detection signals.** Any released model/checkpoint trained on individual-level
  data; a convex model (logistic or linear) released with exact coefficients;
  full float precision; a small cohort relative to the parameter count;
  intermediate global models released.
- **Severity/likelihood.** High severity for small cohorts and exact
  coefficients.
- **Mitigation.** DP-SGD during training — STOPS informed-adversary
  reconstruction with a bound (Balle et al.). Coefficient rounding, params-to-N
  caps — REDUCES. Dedup / canary testing; attack simulation before release
  (GRAIMATTER, see `thresholds.md`).
- **References.** Carlini et al., *The Secret Sharer*, USENIX Security 2019;
  Carlini et al., *Extracting Training Data from LLMs*, USENIX Security 2021;
  Balle, Cherubin & Hayes, *Reconstructing Training Data with Informed
  Adversaries*, IEEE S&P 2022 (arXiv:2201.04845); Haim et al. (arXiv:2206.07758;
  NeurIPS 2022, venue not verified).

## 9. Side channels
- **Mechanism.** Anything the querier observes besides the returned value is a
  channel; filters on the returned value do not close it. Timing,
  privacy-budget and global-state channels were demonstrated against PINQ and
  Airavat (Haeberlen et al.). Naive floating-point Laplace noise leaves holes
  whose low-order bits reveal the true value (Mironov); Gaussian samplers fall
  with up to 92.56% success against DP-SGD, and the discrete samplers that fix
  this leak through timing with up to 99.65% success (Jin et al.). Denying a
  query discloses information unless the deny decision depends only on past
  answers (Kenthapadi et al.). Mapped to R servers (inference; untested on
  DataSHIELD):
  - a distinguishable "count < 3" refusal acts as a binary-search oracle;
  - error and warning text echoes level names or values, or flags perfect
    separation;
  - `levels()`, `length()`, `dim()`, `names()` or `exists()` returns give N per
    subset, quasi-identifying level names, or an existence oracle;
  - data-dependent run times of IRLS or `lme4` fits;
  - full-precision noisy values expose low-order bits;
  - server objects persist between calls, so a later call reads state written
    by an earlier one.
- **Disclosed.** Membership of a subset, attribute values, level names, true
  values under noise.
- **Preconditions.** Distinguishable errors or refusals; data-derived message
  text; per-request timing visible to the client; persistent server state.
- **Detection signals.** `stop()`/`warning()` built with `paste` around
  data-derived values; `tryCatch` returning `conditionMessage(e)` to the client;
  `suppressWarnings` applied inconsistently; different messages for different
  filter failures; aggregate functions returning `levels(x)`, `unique(x)` or
  `table(x)` names without a per-level minimum count; `length()` on a subset
  without an `nfilter.subset` check; noise added as `x + rnorm(...)` returned at
  full double precision; assign functions whose objects a later aggregate can
  test for existence or length. DataSHIELD's own paper says error messages
  "should not reveal data" but describes no enforcement.
- **Severity/likelihood.** Moderate severity per call (often one bit), but
  repeatable; likelihood unknown, as no published test on DataSHIELD exists.
- **Mitigation.** One fixed message for every failure, or checks that depend
  only on public information — REDUCES (a refusal is still a 1-bit signal).
  Allowlisted message templates with server-side stripping of condition
  messages — STOPS text leaks, not the fact an error occurred (inference).
  Constant-time or padded responses — REDUCES; fixing each query's cost before
  execution closes timing channels at a latency cost (Haeberlen et al.).
  Rounding noisy outputs — REDUCES floating-point leaks.
- **References.** Haeberlen, Pierce & Narayan, USENIX Security 2011; Mironov,
  CCS 2012 (doi:10.1145/2382196.2382264); Jin et al., IEEE S&P 2022
  (arXiv:2112.05307); Kenthapadi, Mishra & Nissim, PODS 2005
  (doi:10.1145/1065167.1065183); Avraam et al. 2025.

## 10. Regression and GLMM outputs
- **Mechanism.** Coefficients alone show "no substantive disclosure risks in
  realistic environments" (Ritchie's "safe statistics"), so the risk is what
  travels with the coefficients and the analyst's control of the design matrix.
  Remote-analysis-server work treats residuals, diagnostics and multiple
  interacting regressions as the live risk (Gomatam et al.; Reiter); for
  categorical outcomes, unit-level residuals reveal each outcome (Reiter &
  Kohnen). Mechanisms (inference; none demonstrated on DataSHIELD):
  - *Isolating dummies and interactions.* One interaction cell can hold one
    person and still pass the global `nfilter.glm` = 0.33·N cap; its coefficient
    is that person's outcome contrast.
  - *Per-iteration score/Hessian returns.* In a GLORE-style Newton–Raphson
    design, an analyst-built indicator column isolates one residual in the
    score vector.
  - *Leverage and diagnostics.* Hat values, Cook's distance and studentised
    residuals are unit-level outputs with the same status as residuals.
  - *Regression differencing.* The same model on S and S∖{i} (§2 lifted to
    model outputs).
  - *BLUPs for small clusters.* Random-effect predictions for clusters of one or
    two units invert to the cluster mean. No peer-reviewed study of BLUP
    disclosure was found.
  - *Separation flags.* A perfect-separation or non-convergence warning reveals
    that a covariate pattern predicts the outcome (§9).
- **Disclosed.** Individual outcomes, residuals, cluster means.
- **Preconditions.** Analyst controls the formula, subsets or derived columns.
- **Detection signals.** Server functions returning `crossprod(X, W*X)` or score
  vectors per iteration with only an N-based check; no check that each design
  column has at least `nfilter.subset` non-zero entries; no leverage check;
  returns of residuals, hat values or diagnostics; `ranef()` or per-cluster
  conditional modes returned without a minimum cluster size; separation or
  convergence warnings passed to the client.
- **Severity/likelihood.** High severity for isolating designs; likelihood
  untested.
- **Mitigation.** Per-column minimum non-zero count and leverage checks —
  REDUCES. Residual df ≥ 10 alongside `nfilter.glm` (see `thresholds.md`) —
  REDUCES. Minimum cluster size before returning BLUPs, or variance components
  only — REDUCES. DP noise on the score — REDUCES. Pooled-only returns do not
  help with one site or a dominant site.
- **References.** Gomatam, Karr, Reiter & Sanil, Stat Sci 2005
  (doi:10.1214/088342305000000043); Reiter, Stat Comput 2003
  (doi:10.1023/A:1025623108012); Reiter & Kohnen, JSCS 2005
  (doi:10.1080/00949650412331299184); Ritchie, TDP 2019; Wu et al., *GLORE*,
  JAMIA 2012 (doi:10.1136/amiajnl-2012-000862).

## 11. Extremes, order statistics and analyst-chosen bins
- **Mechanism.** Inference control for MAX/MIN differs from that for SUM, and
  some mixed security checks are NP-hard (Chin); online auditors for max and
  mixed max/min exist at a utility cost (Nabar et al.). Specific risks
  (inference; none quantified in a remote-server study):
  - raw min/max is one person's value; varying the subset and re-querying is a
    tracker on the extreme;
  - quantiles at fine `probs` on small subsets return the sorted data;
  - overlapping histogram breaks difference bins that each pass `nfilter.tab`;
  - box-plot whiskers end on observed values, and outliers are plotted
    individually;
  - heatmap or contour grids at analyst-chosen resolution act as 2-D histograms;
  - re-running kNN-centroid plots with different k yields a linear system (§4).
- **Disclosed.** Individual values at the extremes or bin edges.
- **Preconditions.** Analyst controls `probs`, `breaks`, grid size or k.
- **Detection signals.** Quantile functions accepting arbitrary `probs` without
  a check that ≥ k units lie on each side; user-supplied `breaks`, `numints` or
  grid size without a minimum cell count and without snapping to a grid;
  min/max returned without a tie count; whiskers or outliers returned without
  kNN or noise treatment; user-controlled k allowed to vary on the same
  variable.
- **Severity/likelihood.** High severity for raw extremes; likelihood untested.
- **Mitigation.** Return only the k-th largest, or noisy or rounded extremes —
  REDUCES. Online max/min auditing — STOPS for the audited query class, at a
  utility cost. Server-side fixed or snapped breaks, merging bins below
  threshold — REDUCES. Fixing k per session — REDUCES.
- **References.** Chin, J. ACM 1986 (doi:10.1145/5925.5928); Nabar et al., VLDB
  2006.

## 12. Cross-session accumulation and auditing
- **Mechanism.** Per-query thresholds reset per call and server objects reset
  per session, but the data does not. Automated black-box search finds attack
  sequences that equal or beat hand-crafted ones (QuerySnout), so such
  sequences need not look anomalous to a log reviewer. Averaging across
  colluding users or sessions, and temporal differencing across data refreshes,
  are further routes (inference).
- **Disclosed.** Whatever §2, §4 and §11 disclose, accumulated over time.
- **Preconditions.** Unlimited sessions on an unchanged data snapshot.
- **Detection signals.** Budgets, noise or audit state held per session or per
  analyst rather than per dataset; noise reseeded per call; reliance on logs as
  the only multi-step control.
- **Severity/likelihood.** High; DataSHIELD states that one-step disclosures
  cannot be told apart from valid analysis in logs and that automatic
  multi-step monitoring is planned but not built (Avraam et al. 2025).
- **Mitigation.** Naive online auditing with denials — REDUCES, and denials
  leak. Simulatable auditing — STOPS only for the audited query class (sum,
  max); no proof found for regression or cross-product queries. Per-dataset
  budget with DP — STOPS (see §4). Logging and post hoc review — neither STOPS
  nor REDUCES at query time; deterrence only.
- **References.** Creţu et al., *QuerySnout*, CCS 2022
  (doi:10.1145/3548606.3560581); Kenthapadi, Mishra & Nissim, PODS 2005; Avraam
  et al. 2025; DataSHIELD disclosure-controls statement, 2022.

## 13. Malicious-client poisoning and vertical / split-FL leakage
- **Mechanism.**
  - *Poisoning for leakage.* A client that poisons under 0.1% of the training
    set boosts membership, attribute and extraction attacks on other parties'
    data by 1–2 orders of magnitude (Truth Serum).
  - *Vertical FL.* An active party can perfectly reconstruct a passive party's
    single feature knowing only the signs of the parameters (Rassouli et al.);
    a malicious participant infers another party's labels from the bottom model
    and gradients (Fu et al.).
  - *Split learning.* A malicious server drives the model into an insecure state
    that enables reconstruction and defeats proposed defences (FSHA).
- **Disclosed.** Other parties' records, features or labels.
- **Preconditions.** A client that controls its training data; a vertical or
  split setup exposing predictions, embeddings or cut-layer gradients.
- **Detection signals.** A client app that ingests externally supplied training
  rows; vertical or split model partitions; predictions, embeddings or cut-layer
  gradients exchanged between parties.
- **Severity/likelihood.** High severity; likelihood depends on whether any one
  data node is untrusted.
- **Mitigation.** DP-SGD with user-level accounting bounds the Truth Serum
  amplification (inference from the DP definition). In vertical FL, releasing
  only labels or coarsened predictions, or prediction perturbation — REDUCES.
- **References.** Tramèr et al., *Truth Serum* (arXiv:2204.00032; CCS venue not
  verified); Rassouli et al. (arXiv:2207.11788); Fu et al., USENIX Security 2022;
  Pasquini et al., *Unleashing the Tiger* (arXiv:2012.02670; CCS 2021, venue not
  verified).

---

## Cross-cutting: malicious-app / active-adversary mechanisms
A malicious author strengthens every mechanism above: craft bins/precision or
emit many aggregates (§1–§4), use negative weights to invert an aggregation, or
embed the §4 seed-matrix. **Secure aggregation does not stop passive attacks
either.** Across rounds, the server can rebuild the participant matrix from
device-analytics telemetry and disaggregate individual updates with up to
thousands of participants (Lam et al.); random client selection leaks
individual models within a number of rounds linear in the number of users (So
et al.); linear models fitted to aggregates of different client compositions
infer client properties and membership passively (Kerkouche et al.); and blind
source separation inverts aggregated FC-layer gradients (§5). Leakage falls
with the number of users but grows with the number of rounds (Elkordy et al.).
Per-round SecAgg STOPS single-round passive inversion only. Multi-round-aware
structured selection (So et al.) STOPS participant-matrix disaggregation under
that protocol's model.

### Model inconsistency
- **Mechanism.** The server sends different models to different clients so that
  their updates stay separable through aggregation (Pasquini et al.). LOKI sends
  customised convolutional parameters per client and leaks **76–86% of samples
  across 100 clients** through SecAgg; Mandrake matches Robbing the Fed's 77%
  leakage at 1,000 clients with over 327× less model-size overhead. A BN
  "fishing" variant recovers labels with 100% accuracy by changing only one BN
  layer's parameters per client. SEER uses a secret decoder trained with the
  shared model and evades principled consistency checks.
- **Detection signals.** A strategy that builds a different `ArrayRecord` per
  node; BN parameters overwritten server-side; an injected FC layer directly on
  the input; unusually wide or sparse layers; server-side training of an
  auxiliary decoder model.
- **Mitigation.** Client-side checks that every node received an identical
  model — REDUCES only (SEER evades them). Local DP — STOPS, at large utility
  cost. Code review of the strategy — STOPS only if review is complete.

### Sybil cohort control
- **Mechanism.** The server adds sybil devices so that one honest user's data is
  exposed, defeating SecAgg plus distributed DP (Boenisch et al. 2023).
- **Detection signals.** Fixed or targeted node sampling; a node list fixed
  across rounds; `min_*_nodes` or fraction settings low enough that some rounds
  aggregate 1–2 nodes; per-round participant IDs logged alongside aggregates.
- **Mitigation.** Distributed DP + SecAgg does not stop it. Local DP — STOPS
  (provable), at large utility cost. Not logging participation telemetry —
  REDUCES disaggregation.

### Parameter-only fishing and trap weights
- **Mechanism.** Initialise weights so gradients echo inputs ("trap weights",
  recovering > 50% of a batch of 100), make minimal architecture changes
  (Robbing the Fed), or change only the *parameters* sent to clients to magnify
  one target's gradient in a large batch (fishing), which architecture audits
  miss.
- **Detection signals.** Server-built tensors: `arrays` constructed from
  non-random, hand-crafted or loaded tensors rather than plain initialisation or
  aggregation; embedding or positional parameters altered server-side; the
  server pushing evaluation data or weights through `ConfigRecord` (§6).
- **Mitigation.** Larger batches — no effect. Local DP — STOPS, at large utility
  cost. Code review — STOPS only if complete.

- **References.** Boenisch et al., *When the Curious Abandon Honesty*, IEEE
  EuroS&P 2023 (arXiv:2112.02918); Boenisch et al., *Reconstructing Individual
  Data Points in FL Hardened with DP and SecAgg* (arXiv:2301.04017; EuroS&P
  venue not verified); Pasquini, Francati & Ateniese, *Eluding Secure
  Aggregation*, CCS 2022 (arXiv:2111.07380); Fowl et al., *Robbing the Fed*
  (arXiv:2110.13057); Lam et al., *Gradient Disaggregation* (arXiv:2106.06089;
  ICML venue not verified); So et al., AAAI 2023 (arXiv:2106.03328); Kerkouche,
  Ács & Fritz, WPES 2023 (arXiv:2303.03908); Elkordy et al. (arXiv:2208.02304;
  PETS venue not verified); Zhao et al., *LOKI* (arXiv:2303.12233; S&P venue not
  verified); Zhao et al., *Mandrake* (arXiv:2303.14868); Wang et al., BN fishing
  (arXiv:2406.15731; venue not verified); Garov et al., *SEER*
  (arXiv:2306.03013; ICLR 2024, venue not verified); Wen et al., *Fishing for
  User Data* (arXiv:2202.00580; ICML 2022, venue not verified).

## Coverage notes
- §4 (reconstruction / seed-matrix) and the malicious-app mechanisms are the
  load-bearing threats for the malicious-author model. In per-function / whitelist
  control models they are commonly undefended, because no *generic* control bounds
  what an arbitrary function may return. On present DataSHIELD and default Flower
  configurations no catalogued control STOPS them; every one is a cost-raiser.
  For a malicious app author, code review is the only control outside the
  author's control, so the audit's own completeness is the security boundary.
- Huth et al. 2023 is the only peer-reviewed attack on DataSHIELD found. No
  independent security audit or penetration test of DataSHIELD, Opal or
  Armadillo was found, and no statistical attack on Vantage6, the Personal
  Health Train or OHDSI.
- §9–§12 rest largely on inference from general query-system results; none of
  their specific mechanisms has been tested on DataSHIELD.
- FL evidence (§5–§8, §13, cross-cutting) comes from primary sources; venues
  marked "not verified" need a publisher-page check before final citation.
  Counter-evidence (Du et al.; Jayaraman & Evans) lowers the likelihood of
  passive optimisation and attribute-inference attacks, not of malicious-author
  attacks.
- Open questions with no published study: the number of DataSHIELD calls needed
  to reconstruct a column through a GLM or subset-and-mean trackers under
  "banana"; whether Flower's SecAgg+ checks model consistency across nodes;
  reconstruction from a federated GLMM.
