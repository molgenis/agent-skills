# References

Consolidated citations for the framework: recommended reviews to start from, the
primary source per attack mechanism (`attack-vectors.md`), mitigation sources,
and the threshold/standards sources (`thresholds.md`). Citations verified to
resolve to real papers; a few key reviews sit just outside 2020–2025 and are
flagged by year rather than omitted. Venues marked "venue not verified" come
from arXiv preprints and need a publisher-page check before final citation;
items marked "search summary only" were not read in full.

## Recommended reviews / surveys — start here
1. Zhao et al., **The Federation Strikes Back: A Survey of FL Privacy Attacks,
   Defenses, Applications, and Policy**, ACM Computing Surveys 2025 —
   doi:10.1145/3724113 · arXiv:2405.03636. One-stop FL attack/defense taxonomy.
2. Huang, Gupta, Song, Li, Arora, **Evaluating Gradient Inversion Attacks and
   Defenses in Federated Learning**, NeurIPS 2021 — arXiv:2112.00059. The rigorous
   attack-vs-defense empirical benchmark.
3. Garfinkel, Abowd, Martindale, **Understanding Database Reconstruction Attacks
   on Public Data**, CACM 2019 — dl.acm.org/doi/10.1145/3287287. Plain-language
   explainer of Dinur–Nissim / the fundamental law of information recovery. *(pre-2020)*
4. Dwork, Smith, Steinke & Ullman, **Exposed! A survey of attacks on private
   data**, Annual Review of Statistics 2017 —
   doi:10.1146/annurev-statistics-060116-054123. Reconstruction and tracing
   attacks on aggregate statistics. *(pre-2020)*

## FL privacy attacks & defenses (surveys)
- Carletti et al., **SoK: Gradient Inversion Attacks in FL**, USENIX Security 2025.
- Bai et al., **Membership Inference Attacks and Defenses in FL: A Survey**, ACM
  CSUR (to appear) — arXiv:2412.06157 · doi:10.1145/3704633.
- Shi et al., **Dealing Doubt: Threat Models in Gradient Inversion**, arXiv:2405.10376 (2024).
- **On the security and privacy of FL**, Computer Science Review (Elsevier) 2026.
- Du et al., **SoK: On Gradient Leakage in FL**, arXiv:2404.05403 (venue not
  verified). Counter-evidence on passive attack practicality.
- Salem et al., **SoK: Let the Privacy Games Begin!**, arXiv:2212.10986 (IEEE S&P
  2023, venue not verified). Game-based definitions of inference attacks.

## SDC / output-checking / DataSHIELD
- Avraam, Wilson, … Cadman, … Burton, **DataSHIELD: mitigating disclosure risk in
  a multi-site federated analysis platform**, Bioinformatics Advances 5(1), 2025 —
  doi:10.1093/bioadv/vbaf046. Authoritative DataSHIELD disclosure model (methods
  paper; written by the developers).
- Huth et al., **Accessibility of covariance information creates vulnerability
  in Federated Learning frameworks**, Bioinformatics 2023 —
  doi:10.1093/bioinformatics/btad531 (PMC10516515). The only peer-reviewed
  attack on DataSHIELD found.
- DataSHIELD, **Statement: DataSHIELD disclosure controls and mitigation**,
  forum, 2022 (datashield.discourse.group).
- Preen, Albashir, Davy & Smith, **A Multi-Language Toolkit for the
  Semi-Automated Checking of Research Outputs** (ACRO/SACRO), arXiv:2212.02935.
- Bond, Brandt & de Wolf, **Guidelines for Output Checking**, DwB (Eurostat
  CROS PDF, 2024).
- Elliot & Domingo-Ferrer, **The future of statistical disclosure control**,
  arXiv:1812.09204 (2018). *(pre-2020)*
- Ritchie, Green et al., **Handbook on SDC for Outputs** (Secure Data Group / UK
  Data Service). De facto output-checking reference.
- **Review of SDC Techniques in Web-Based Query Systems**, 2016 (PMC5409873).
  *(pre-2020)*
- Hundepool et al., **Statistical Disclosure Control**, Wiley 2012.
- Ritchie, **"Safe statistics"** for regression coefficients, Transactions on
  Data Privacy 12(2), 2019.
- Chipperfield, Gow & Loong, ABS TableBuilder, Statistical Journal of the IAOS
  2016 — doi:10.3233/sji-160969.

## Reconstruction / fundamental law of information recovery
- Dinur & Nissim, **Revealing Information while Preserving Privacy**, PODS 2003
  — doi:10.1145/773153.773173. Constants for query counts: verify against the
  paper before quoting.
- Dwork, McSherry & Talwar, **The price of privacy and the limits of LP
  decoding**, STOC 2007.
- Dwork & Yekhanin, **New Efficient Attacks on Statistical Disclosure Control
  Mechanisms**, CRYPTO 2008.
- Kasiviswanathan, Rudelson & Smith, **The power of linear reconstruction
  attacks**, SODA 2013 — arXiv:1210.2381.
- Garfinkel, Abowd, Martindale, CACM 2019 (above).
- Abowd et al., **Database reconstruction does compromise confidentiality**, PNAS
  120(8), 2023 — doi:10.1073/pnas.2300976120.
- Abowd et al., **A simulated reconstruction and reidentification attack on the
  2010 U.S. Census**, arXiv:2312.11283. Counter-view: Ruggles & Van Riper, PRPR
  2021 — doi:10.1007/s11113-021-09674-3.
- Gadotti et al., **When the signal is in the noise: exploiting Diffix's sticky
  noise**, USENIX Security 2019 — arXiv:1804.06752.
- Cohen & Nissim, **Linear program reconstruction in practice**, JPC 2020 —
  doi:10.29012/jpc.711.
- Asghar & Kaafar, **Averaging attacks on bounded noise-based disclosure control
  algorithms**, PoPETs 2020 — arXiv:1902.06414.
- Creţu et al., **QuerySnout**, CCS 2022 — doi:10.1145/3548606.3560581 ·
  arXiv:2211.05249.

## Primary sources by attack mechanism (`attack-vectors.md`)
- **§1 Small-cell / re-identification** — Ohm et al., J Public Health Manag Pract
  2017 (PMC5409873); ONS/UKSA *SDC*, 2024 (EAP215); Hundepool et al. 2012;
  Sweeney, *k-anonymity*, 2002; Machanavajjhala et al., *l-diversity*, 2007; Li et
  al., *t-closeness*, ICDE 2007.
- **§2 Differencing, trackers and linked tables** — Denning, Denning &
  Schwartz, ACM TODS 1979; Chipperfield et al. 2016; Huth et al. 2023; Eurostat,
  *Understanding output checking*; ONS EAP215.
- **§3 Dominance** — Eurostat, *Understanding output checking*; Hundepool et al. 2012.
- **§4 Reconstruction / seed-matrix** — Dinur & Nissim, PODS 2003; Dwork,
  McSherry & Talwar, STOC 2007; Dwork & Yekhanin, CRYPTO 2008; Kasiviswanathan,
  Rudelson & Smith, SODA 2013; Huth et al. 2023; Garfinkel et al., CACM 2019;
  Abowd et al., PNAS 2023.
- **§5 Gradient/update inversion** — Zhu, Liu, Han, *Deep Leakage from Gradients*,
  NeurIPS 2019 (arXiv:1906.08935); Zhao et al., *iDLG*, 2020 (arXiv:2001.02610);
  Geiping et al., *Inverting Gradients*, NeurIPS 2020 (arXiv:2003.14053); Yin et
  al., *GradInversion*, CVPR 2021 (arXiv:2104.07586); Dimitrov et al., *SPEAR*,
  NeurIPS 2024; Dimitrov et al., *Data Leakage in Federated Averaging*
  (arXiv:2206.12395); Vero et al., *TabLeak* (arXiv:2210.01785; ICML venue not
  verified); Kariyappa et al., *Cocktail Party Attack*, ICML 2023
  (arXiv:2209.05578); Zhu & Blaschko, *R-GAP* (arXiv:2010.07733; ICLR 2021, venue
  not verified); Balunović et al., *LAMP* (arXiv:2202.08827); Gupta et al.,
  *FILM* (arXiv:2205.08514); Hatamizadeh et al., *Do Gradient Inversion Attacks
  Make FL Unsafe?* (arXiv:2202.06924).
- **§6 Membership inference and tracing** — Shokri et al., S&P 2017; Melis et
  al., S&P 2019; Nasr et al., S&P 2019; Bai et al. survey (arXiv:2412.06157);
  Homer et al., PLoS Genetics 2008 (doi:10.1371/journal.pgen.1000167); Dwork et
  al., FOCS 2015 (doi:10.1109/focs.2015.46); Aggarwal et al., *On Primes,
  Log-Loss Scores and (No) Privacy*, PrivateNLP 2020 (arXiv:2009.08559); Liu et
  al., CCS 2022 (arXiv:2208.14933); Chang et al., *Efficient Privacy Auditing in
  FL*, USENIX Security 2024; Nguyen et al., AISTATS 2023 (arXiv:2302.12685); Suri
  et al., subject-level membership (arXiv:2206.03317); Carlini et al., *LiRA*
  (arXiv:2112.03570; IEEE S&P 2022, venue not verified).
- **§7 Property/attribute inference** — Melis et al., S&P 2019; Ganju et al., CCS
  2018; Wang et al., label composition (arXiv:1910.06044); Wainakh et al., *LLG*
  (arXiv:2105.09369; PETS venue not verified); Gao et al., category inference,
  IEEE TDSC 2023; Mahloujifar, Ghosh & Chase (arXiv:2101.11073; venue not
  verified); Jayaraman & Evans, *Are Attribute Inference Attacks Just
  Imputation?* (arXiv:2209.01292; CCS venue not verified).
- **§8 Memorisation / extraction / released-model reconstruction** — Carlini et
  al., *The Secret Sharer*, USENIX Security 2019; Carlini et al., *Extracting
  Training Data from LLMs*, USENIX Security 2021; Balle, Cherubin & Hayes,
  *Reconstructing Training Data with Informed Adversaries*, IEEE S&P 2022
  (arXiv:2201.04845); Haim et al. (arXiv:2206.07758; NeurIPS 2022, venue not
  verified).
- **§9 Side channels** — Haeberlen, Pierce & Narayan, USENIX
  Security 2011; Mironov, CCS 2012
  (doi:10.1145/2382196.2382264); Jin et al., IEEE S&P 2022 (arXiv:2112.05307);
  Kenthapadi, Mishra & Nissim, PODS 2005 (doi:10.1145/1065167.1065183).
- **§10 Regression and GLMM outputs** — Gomatam, Karr, Reiter & Sanil, Stat Sci
  2005 (doi:10.1214/088342305000000043); Reiter, Stat Comput 2003
  (doi:10.1023/A:1025623108012); Reiter & Kohnen, JSCS 2005
  (doi:10.1080/00949650412331299184); Ritchie, TDP 2019; Wu et al., *GLORE*,
  JAMIA 2012 (doi:10.1136/amiajnl-2012-000862).
- **§11 Extremes and order statistics** — Chin, J. ACM 1986
  (doi:10.1145/5925.5928); Nabar et al., VLDB 2006.
- **§12 Cross-session accumulation and auditing** — Creţu et al., *QuerySnout*,
  CCS 2022; Kenthapadi, Mishra & Nissim, PODS 2005; Avraam et al. 2025.
- **§13 Malicious-client poisoning and vertical/split FL** — Tramèr et al.,
  *Truth Serum* (arXiv:2204.00032; CCS venue not verified); Rassouli et al.
  (arXiv:2207.11788); Fu et al., USENIX Security 2022; Pasquini et al.,
  *Unleashing the Tiger* (FSHA, arXiv:2012.02670; CCS 2021, venue not verified).
- **Malicious-app / active adversary** — Boenisch et al., *When the Curious
  Abandon Honesty*, IEEE EuroS&P 2023 (arXiv:2112.02918); Boenisch et al.,
  *Reconstructing Individual Data Points in FL Hardened with DP and SecAgg*
  (arXiv:2301.04017; EuroS&P venue not verified); Pasquini et al., *Eluding
  Secure Aggregation*, CCS 2022 (arXiv:2111.07380); Fowl et al., *Robbing the
  Fed*, ICLR 2022; Lam et al., *Gradient Disaggregation* (arXiv:2106.06089; ICML
  venue not verified); So et al., AAAI 2023 (arXiv:2106.03328); Kerkouche, Ács &
  Fritz, WPES 2023 (arXiv:2303.03908); Elkordy et al. (arXiv:2208.02304; PETS
  venue not verified); Zhao et al., *LOKI* (arXiv:2303.12233; S&P venue not
  verified); Zhao et al., *Mandrake* (arXiv:2303.14868); Wang et al., BN fishing
  (arXiv:2406.15731; venue not verified); Garov et al., *SEER*
  (arXiv:2306.03013; ICLR 2024, venue not verified); Wen et al., *Fishing for
  User Data* (arXiv:2202.00580; ICML 2022, venue not verified).

## Mitigations
- Secure aggregation — Bonawitz et al., CCS 2017.
- DP-SGD — Abadi et al., *Deep Learning with Differential Privacy*, CCS 2016
  (arXiv:1607.00133); DP definition: Dwork et al., TCC 2006.
- Provable DP floor / information-theoretic bound — Tan et al., USENIX 2024; Liu
  et al., AISTATS 2025.
- Reconstruction bounds under DP-SGD — Hayes, Mahloujifar & Balle, NeurIPS 2023
  (arXiv:2302.07225).
- Auditing DP — Nasr et al., *Tight Auditing of DP ML* (arXiv:2302.07956;
  USENIX venue not verified). Heuristic MIA defences — Aerni et al., CCS 2024
  (arXiv:2404.17399).
- Practical ε guidance — Ponomareva et al., *How to DP-fy ML*
  (arXiv:2303.00654; JAIR venue not verified); Gboard deployment — Xu et al.,
  ACL 2023 (arXiv:2305.18465); empirical medical-imaging reconstruction — Ziller
  et al., Nature Machine Intelligence 2024 (doi:10.1038/s42256-024-00858-y).
- Gradient-obfuscation defenses only reduce (defeated by adaptive attackers) —
  Yue et al., USENIX 2023; Wu et al., UAI 2023; InstaHide broken — Carlini et
  al. (arXiv:2011.05315); PRECODE alone circumvented — Scheliga et al.
  (arXiv:2208.04767).
- TEE — Mo et al., *PPFL* (arXiv:2104.14380).
- BatchNorm-statistics assumption weakens inversion when relaxed — Huang et al.,
  NeurIPS 2021 (arXiv:2112.00059).
- User-level DP-FedAvg / clipping — McMahan et al., arXiv:1710.06963; adaptive
  clipping — Andrew et al., NeurIPS 2021, arXiv:1905.03871.
- Query auditing — Kenthapadi, Mishra & Nissim, PODS 2005; Nabar et al., VLDB
  2006.

## Thresholds / standards (`thresholds.md`)
- DataSHIELD `nfilter.*` — dsBase; DataSHIELD wiki *Disclosure control*;
  Bioinformatics Advances 2025 (vbaf046).
- Small-cell / rounding / dominance — Ohm et al. 2017; ONS EAP215; Eurostat;
  sdctools *Handbook on SDC*.
- TRE output checking — Bond, Brandt & de Wolf, DwB *Guidelines for Output
  Checking* (CROS, 2024); SDAP *Handbook on SDC for Outputs* v2.0, 2024; ACRO
  `default.yaml`; UK LLC Guidebook, *SDC*; ABS DataLab training, Module 3
  (search summary only).
- Trained-model release — Jefferson et al., *GRAIMATTER Green Paper*,
  arXiv:2211.01656.
- k-anonymity (Sweeney 2002); l-diversity (Machanavajjhala 2007); t-closeness (Li
  et al. 2007); DP-SGD (Abadi et al., CCS 2016).
