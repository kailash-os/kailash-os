---
title: "Kailash OS — Specification"
lang: en
---

# Kailash OS — Specification

**Status: revision 2.3 · 11 October 2026. This document is the normative record for the Kailash OS taxonomy, architecture, packaging, release engineering and safety doctrine.**

This document is the public implementation blueprint for Kailash OS. The
project planning master is the revision source. Repo docs, guides, and issues
cite the §-numbering here. Normative *prose* lives here. Normative *data*
lives in the
[`kailash-packages` manifest](https://github.com/kailash-os/kailash-packages/tree/main/manifest).
Each fact has one home. Tool facts and category facts live in the manifest.

Companion documents:

- [`docs/guide/releases.md`](https://github.com/kailash-os/kailash-os/blob/master/docs/guide/releases.md)
  gives the release story in user form.
- The [paper](https://kailash.site/#paper) carries the narrative framing
  (Revision 1.3).
- [`docs/responsible-use.md`](https://github.com/kailash-os/kailash-os/blob/master/docs/responsible-use.md)
  renders the safety doctrine.
- [The canon map, kailash-os#61](https://github.com/kailash-os/kailash-os/issues/61)
  records the dependency graph. It maps the sections of this spec to the
  roadmap.

---

# Chapter 1 — Mission, Scope & Deliverables

## 1.1 Vision

Kailash OS is a **NixOS-based Linux distribution** for security professionals and AI engineers. Its scope covers AI-native offence, defence, and platform work. Nix flakes build the distribution declaratively. Kailash OS keeps the integrated Kali experience: curated tools, desktop-menu categories, a live ISO, and generated docs. It points that experience at the four pillars: **appsec, apisec, mlsec, aisec**. Kailash OS is deliberately **not** Kali-for-networks. It carries no Active Directory or lateral-movement arsenal and no social-engineering pack. **No hardware/RF/radio hacking toolset** ships beyond the opt-in SDR niche of §2.2.

## 1.2 Scope

**In scope:**

- The full AI-security workstream: adversarial ML (evasion, poisoning, extraction, privacy), LLM red teaming (jailbreaks, prompt injection, multi-turn), agentic and MCP security, the model supply chain, defence tooling, assurance/evals, monitoring, trust and provenance.
- The platform to build, train, test, and serve models: MLOps (MLflow, DVC), data & vector stores, compute orchestration (k3s, podman), AI engineering SDKs, local inference (ollama, llama.cpp, vLLM).
- A curated Kali-heritage classic security foundation layer — **software-only**: recon, vulnerability assessment, web/API, password/offline-credential attacks, software reverse engineering, forensics/IR. The layer holds ~141 primary slots across 10 categories (§2.2). Kali ships ~300 tools. Kailash OS ships a smaller, curated subset.
- **Software-defined radio is the one carve-out kept** (C-7, opt-in; see §2.2). SDR is the substrate for AI/ML signal research: radio-based ML datasets, signal-capture corpora for audio/voice-model work, and the GNURadio DSP ecosystem that feeds ML pipelines. Everything else RF **does not ship**: wifi attack tooling (aircrack/airgeddon/wifite/kismet/reaver/hcxdumptool/wifiphisher…), Bluetooth stacks (ubertooth/bluelog/bluesnarfer/btscanner/blueranger/spooftooph/rfcat/fern…), and the classic RF utilities (chirp/fang).
- Documentation, reports, and **the website**: Quarto, pandoc, typst/mdBook, generated report templates, and `kailash-website`. `kailash-website` is the public site repo; it hosts the generated docs and the governance pages (§5.3).

**Out of scope:**

- A hard-fork of nixpkgs — Kailash is a consumer + overlay, not a fork.
- Every nix-security-box / Kali tool — the build is curated, not exhaustive.
- **Hardware hacking, wifi/RF/Bluetooth attack tooling, and radio stacks beyond the SDR carve-out** — Kali Nethunter territory. The four pillars do not need it. Software DSP (gnuradio/sox/librosa) serves the audio/voice-clone research needs; RF hardware serves none of them.
- Network-infrastructure exploitation (AD/lateral movement arsenal) and social-engineering tooling.
- A commercial product — this is a community/individual project.
- Mobile / ARM-Nethunter variants — a roadmap item, not core work.

## 1.3 Operating principles

**Declarative, flakes, no state outside the store.** Nix flakes express every surface: OS, tools, menu, docs, site, tests, release process. Users import each per-category module file as a NixOS module and run it as a `nix develop` shell. No apt install, no pip install outside the store. No state drifts between environments.

**Categories are the navigation system.** The five-layer taxonomy (CORE + CLASSIC/ATTACK/DEFENCE/OPS) gives the map. Kali-style desktop-menu categories organise the tooling. Per-category tool manifests, per-category docs, and per-category tests all generate from one manifest.

**Nothing ships untested.** Per-category VM smoke tests run in CI. A CI pipeline builds all categories and images on every push. The release process produces verified artefacts, the site, and a changelog. A documented policy covers the automation and review of bespoke package updates.

**Two repos, clean contract, no drift.** The OS repo never contains tool derivations. The packages repo never contains OS modules. The manifest is the single hand-maintained registry; it lives in the packages repo. Every other view (modules, menu, docs, site, CLI) generates from it.

**Never commit `master`/`main` directly.** All work lands via branch, conventional commit, and PR. PRs squash-merge. PR body templates carry safety confirmations for Layer ATTACK entries. Signed commits everywhere.

## 1.4 What we build

- [`kailash-os`](https://github.com/kailash-os/kailash-os) — root flake, the module tree (categories), CLI, images, tests, CI, and a minimal `pkgs/` only for things the OS itself needs.
- [`kailash-packages`](https://github.com/kailash-os/kailash-packages) — every bespoke tool derivation, the manifest, the auto-call harness, and its own CI. Users consume it independently. `kailash-os` pins it via a flake input.
- [`kailash-website`](https://github.com/kailash-os/kailash-website) — the Quarto-based public docs & governance site. The build deploys to GitHub Pages.
- [`kailash-references`](https://github.com/kailash-os/kailash-references) — the 2023 submodules (RedNix, nix-security-box, kalinix). They stay frozen as historical reference.
- The `kailash` CLI — the manifest-aware front-end (`list`, `search`, `info`, `shell`, `enable`, `doctor`, `report new`, `manifest validate`).
- Desktop menu integration generated from the manifest.
- ISO / OVA / AMI / Proxmox images via nixos-generators and disko, with CI-enforced size budgets.
- Tests (flake check + per-category VM smoke tests + integration tests + golden-image diff), CI (GitHub Actions + Cachix), and release automation.
- Safety and governance — responsible-use statement, licensing posture, `KAILASH_LAB_MODE` gating, capability grants for agent-operated sessions.

# Chapter 2 — The Kailash Taxonomy: Categories

## 2.1 Design rationale: why CORE + four named tool layers, not 1 flat list

The single Kali menu list works because one coherent discipline covers its domain: classical pentest. AI security is not one coherent discipline. The attack-tool populations, the defence populations, and the build/platform populations barely overlap. A single flat menu across them gives a 60-folder list. So Kailash uses a **five-layer taxonomy: the CORE substrate + 31 tool categories across CLASSIC / ATTACK / DEFENCE / OPS**:

- **CORE** — the substrate itself: kernel, base userland, hardening, safety defaults, the desktop(s), the CLI and menu engines. No tool categories live under CORE; every image inherits it. Platform components appear in the taxonomy only where they are lab targets (OPS) or security tools. The distro's structural parts are CORE build-time content, never menu entries.
- **Layer CLASSIC (C-1…C-10)** — this layer serves a traditional software security assessment. Kali heritage, software-only: 10 categories, ~141 tool slots (plus the opt-in C-7 SDR data pack).
- **Layer ATTACK (A-1…A-8)** — this layer attacks or red-teams an AI system. 8 categories, ~59 tools; ATLAS-mapped.
- **Layer DEFENCE (D-1…D-7)** — this layer defends or assures one. 7 categories, ~46 tools; standards-mapped.
- **Layer OPS (O-1…O-7)** — this layer builds and deploys the systems the attack layer targets. 7 categories, ~91 tools; the builder/dev layer.

One tool = one primary category. Genuine dual-use lands as secondary tags (a `o-05` primary tool can carry `secondary: [a-08]`). The manifest enforces this rule.

## 2.2 Layer CLASSIC — software-only (10 categories, ~141 tool slots + the opt-in C-7 SDR pack)

### C-1. Information Gathering (~38)
Passive/active recon of network/domain/public footprint + the AI-surface lead-in. *(nmap, masscan, rustscan, amass, subfinder, sublist3r, recon-ng, the-harvester, dmitry, fierce, dnsrecon, dnsenum, dnsmap, massdns, assetfinder, findomain, gobuster, dirb, dirsearch, feroxbuster, ffuf, wfuzz, whatweb, wafw00f, arjun, uro, photon, sherlock, spiderfoot, httpx, gospider, hakrawler, katana, puredns, maltego-community, zenmap, arp-scan, netdiscover)* — the last two stay: they are ethernet/ARP, not RF tooling. **nixpkgs profile: High** (~30/38 packaged; katana/findomain/subfinder/httpx/puredns need fresh overlay builds).

### C-2. Vulnerability Analysis (~7)
CVE/misconfig scanning: nikto, lynis, wapiti, legion, searchsploit, nuclei (stale-override), gvm (the dedicated service module). **Profile: Medium** (GVM is the known hard packaging case → `services.kailash.gvm`).

### C-3. Web Application Assessment (~10)
Burp (free edition pinned, unfree), zaproxy, caido, graphw00f, clairvoyance, inql, kiterunner, gopherus, commix, sstimap. (Burp and ZAP pin exact versions in the flake lock; two installs get identical builds.) **Profile: Medium-High.**

### C-4. Database Assessment (~7)
sqlmap (primary, cross-tagged C-3), mssql-cli, psql, redis-cli, mongosh, sqlitebrowser, mycli. (Dropped as duplicate-scope: sqlninja, sqlsus, jsql, tnscmd10g, oscanner — all unmaintained or duplicative. sqlmap covers the class with maintained depth. This follows the §2.7 duplicate-scope rule.) **Profile: High.**

### C-5. Password & Offline-Credential Attacks (~16)
Offline only — online brute-forcing stays out. That is live-target attack territory; the four pillars do not need it. hashcat, john + johnny, ophcrack, crunch, cewl, maskgen, policygen, statsgen, hashid, hash-identifier, bopscrk, rsmangler, twofi, plus the wordlist packs (seclists behind `kailash-data.wordlists-mega`). Excluded: medusa/hydra/ncrack/patator/crowbar/kerbrute/legba — **all online/offline-LAN credential attack tooling**, out of scope under the AD/lateral-movement rule. **Profile: High.**

### C-6. Reverse Engineering — software & app artefacts (~26)
ghidra, radare2, rizin, cutter, iaito, gdb + gef/pwndbg/peda, capstone, cstool, checksec, binwalk (**stays**: firmware-image analysis is appsec), jadx, apktool, dex2jar, javasnoop, jd-gui, smali, bytecode-viewer, unicorn, angr, qiling, unipacker, pyinstaller-extractor, edb-debugger. **No RF/wireless/hardware RE tooling.** **Profile: Very High.**

### C-7. Signal & SDR Analysis — the one carve-out (~6, opt-in)
**Kept deliberately narrow, by design:** the SDR toolset supports AI/ML signal research (GNURadio-driven DSP for ML training corpora; audio/signal-based ML work; an A-6 voice-clone/audio-LM attack tool needs software DSP, not RF hardware, and its rebuild follows the registry entry). Shipped: gnuradio, gqrx, hackrf-tools, sox, librosa, pysox-as-data — **opt-in via `kailash-data.sdr-tools` toggle, never on an ISO default profile.** Everything else RF (rfcat, spooftooph, ubertooth stack, chirp, fang, and friend) **does not ship**. Revisit only if a specific engagement proves otherwise.

### C-8. Exploitation & Post-Exploitation — software-only (~9)
metasploit-framework (pinned; web/API module selection documented), msfvenom, beef-xss, weevely, laudanum, peass-ng (linpeas/winpeas), unix-privesc-check, pspy. **Nothing network-infrastructure: no impacket suite, no mimikatz/rubeus/bloodhound/sharphound/responder/netexec/smbmap/enum4linux/evil-winrm/kerberoast/krbrelayx/pypykatz/certipy/mitm6/pywsus/dsniff/fragrouter/sniffjoke/evilgrade/veil/shellter/backdoor-factory/armitage** — dropped as a set vs Kali (the AD/lateral-movement arsenal is out by §1.2). **Profile: Medium.**

### C-9. Forensics, IR & Reporting (~21)
autopsy, sleuthkit, volatility3, hashdeep, chkrootkit, rkhunter, dc3dd, ewfacquire, guymager, regripper, testdisk, photorec, bulk_extractor, chainsaw, hayabusa, sigma-cli, plaso/log2timeline, timesketch (module), faraday (module), pwndoc-ng, sysmon-modular rules (data). libimobiledevice is dropped (mobile-device forensics is hardware-adjacent scope growth; revisit on demand). **Profile: Medium-High.**

### C-10. Runtime AppSec for AI Systems (~1)
mitmproxy — zaproxy is cross-tagged: primary C-3, secondary C-10. The pre-purge AI-scanner/toolkit rows were phantom-upstream and are removed. Aspirational names live in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210) until built for real. **Profile: Medium.**

**Layer CLASSIC summary: 10 categories, ~134 tool slots (plus the opt-in C-7 pack, ~6 more; [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) purge basis — the pre-purge ~141 counted phantom rows).**

## 2.3 Layer ATTACK — offensive-AI (8 categories)

Kali maps none of the AI-native offensive categories. The mapping follows MITRE ATLAS tactics and the OWASP LLM Top 10 risks. The design invents nothing ad hoc.

### A-1. AI Reconnaissance & Target Discovery (~1)
The "which AI surfaces does this target expose?" step. trufflehog (leaked AI-provider keys; primary A-1, secondary C-8). The four pre-purge bespoke recon rows were phantom-upstream and are removed. Aspirational names live in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: Very Low.**

### A-2. LLM Prompt Injection & Jailbreaking (~8)
garak (flagship), pyrit, promptfoo, plus the payload/data packs: jailbreak-payloads, libertas-prompts (L1B3RT-4S), llm-jailbreak-bench. The pre-purge injection-harness row was phantom-upstream and is removed. One pre-purge data-pack row was also phantom-upstream and is removed. Aspirational names live in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: Low-Medium.**

### A-3. Agentic, MCP & Tool-Use Attacks (~9)
mcp-scan, mcp-guardian, mcp-remote/proxy, mcpoison, agent-dojo — mcp-inspector is cross-tagged: primary O-7, secondary A-3. The pre-purge phantom rows are removed; aspirational names in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: Very Low — the most novel packaging surface in the spec.**

### A-4. Model Supply Chain & Artefact Poisoning (~8)
guarddog, picklescan, modelscan. The pre-purge supply-chain inspector rows were phantom-upstream and are removed — aspirational names in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: Very Low.**

### A-5. Model Extraction, Inversion & MIA (~8)
counterfit (pinned, archived, reference), knockoffnets (one pre-purge extraction row was phantom-upstream and is removed), adversarial-robustness-toolbox, foolbox, cleverhans, tf-privacy, privacy-meter. **Profile: Medium** (heavy Python; one environment per tool, §4.3).

### A-6. Multi-modal & Physical-AI Attacks (aspirational-only, 0 built)
The category is EMPTY at this revision. Every pre-purge A-6 row claimed a kailash-os upstream repo; no such repo was ever created. The [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) audit removed all rows. Aspirational names live in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). The voice-clone/audio-LM research pairing with C-7 software DSP stays valid as a concept. No RF transmission tooling ever: the category covers ML/semantic attacks on AI systems, not radio hardware. **Profile: n/a until rebuilt.**

### A-7. AI System Exploitation (aspirational-only, 0 built)
A-7 is the platform-exploit pairing target. Every pre-purge A-7 row claimed a kailash-os upstream repo; no such repo was ever created. The [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) audit removed all rows; their names live in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). The §5.5 attack/defence pairing thesis drives the rebuild: each name returns only with a real, verified upstream. The §7.2 acceptance lab (MLflow unauth posture) is REAL and runs the protocol transparently. **Profile: n/a until rebuilt.**

### A-8. Data Poisoning & Dataset Attacks (~6)
trojai-toolkit (upstream trojai/trojai). The pre-purge poisoning-workbench rows were phantom-upstream and are removed — aspirational names in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: Very Low.**

## 2.4 Layer DEFENCE — defensive-AI & assurance (7 categories)

### D-1. AI Runtime Defence & Guardrails (~7)
nemo-guardrails, llm-guard, guardrails-ai, rebuff. The pre-purge first-party guard rows were phantom-upstream and are removed — aspirational names in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: Low.**

### D-2. AI Detection, Monitoring, Observability & IR (~8)
langfuse (module), phoenix, whylogs, evidently, otel-ai, giskard. The pre-purge detector + canary-token rows were phantom-upstream and are removed — aspirational names in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: Low** (langfuse is the heavy one).

### D-3. AI Assurance, Evals & Benchmarks (~6)
lm-eval-harness, deepeval, robustbench, huggingface-evaluate, fairlearn, aif360. promptfoo is cross-tagged: primary A-2, secondary D-3. **Profile: Medium.**

### D-4. Model Provenance, Signing & Trust (~10)
cosign, syft, grype, trivy, cyclonedx-cli, cdxgen, modelsign, model-card-toolkit. The pre-purge sigstore-helper and auditor rows were phantom-upstream and are removed; the real sigstore client is cosign itself. Aspirational names live in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: Medium-High.**

### D-5. AI Threat Modelling (~6)
maestro (upstream agentic-threat-modeling/MAESTRO). The pre-purge template/visualiser rows were phantom-upstream and are removed — aspirational names in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: Very Low** (data + small CLIs).

### D-6. AI Governance & Regulation Mapping (aspirational-only, 0 built)
Every pre-purge D-6 row was a phantom-origin template pack; no real upstream exists anywhere. The [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) audit removed all rows; their names live in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). **Profile: n/a until rebuilt.**

### D-7. Standards Verification Toolkit (aspirational-only, 0 built)
The standards-verification surface is aspirational-only. The OWASP/NIST STANDARDS are real: AISVS 1.0 exists at OWASP/AISVS; the LLM Top 10 is published. None of the claimed toolkit repos or CLI were ever created. The [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) audit removed all rows; names live in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). The verifier CLI returns via the rebuild contract once built. **Profile: n/a until rebuilt.**

## 2.5 Layer OPS — platform (7 categories)

### O-1. MLOps & ML Engineering Suite (~18)
mlflow (module — the pairing-thesis lab target), dvc, git-lfs, bentoml, feast, kedro + kedro-datasets, clearml (module), wandb-cli, airflow (module), prefect (module), pandas, polars, scikit-learn, numpy, scipy, xgboost, lightgbm, evidently/whylogs (shared with D-2). **Profile: High.**

### O-2. Compute & Serving Infrastructure (~11)
vllm, tgi, torchserve, triton-inference-server (docker-wrapper), kserve, ray (module), k3s, minikube, kind, podman, nvidia-container-toolkit (ollama + llama.cpp primary in O-4, secondary here). **Profile: Medium.**

### O-3. Vector Stores & Retrieval (~9)
chromadb, qdrant, weaviate, milvus (docker-wrapper), pgvector, elasticsearch (module), faiss, txtai, jina-embeddings-cli. **Profile: Medium.**

### O-4. Local LLM & Inference Labs (~5)
ollama (primary home + documented tiny test model), llama.cpp, text-generation-webui, open-webui. One pre-purge GGUF-helper row was a phantom first-party row (removed — the real GGUF quantisation tooling is llama.cpp's own). The name lives in the registry. **Profile: Medium-High.**

### O-5. AI Engineering SDKs & Dev Environment (~26)
langchain, langgraph, llama-index, openai-python, anthropic-python, google-genai, autogen, crewai, pytorch (cpu/cuda variants), torchvision, torchaudio, tensorflow, jax, onnxruntime, transformers, datasets, peft, trl, vscode/code-server, neovim, python-lsp-server, uv, ruff, mypy, python313 + a curated extras set. **Profile: Very High**. The nixvital/ml-pkgs torch-family/jax-family overlays carry the fresh upstream versions Kailash depends on. Kailash uses the pinned overlay for them and does not carry the local rebuild work.

### O-6. Documentation, Reporting & Authoring (~10)
quarto, pandoc, typst, mdbook, drawio, excalidraw, mermaid-cli, obsidian, texlive-full (opt-in data), dradis (pwndoc-ng/faraday primary in C-9, secondary here). **Profile: High.**

### O-7. Agent & MCP Operability (~4)
hexstrike-ai (third-party deliverable, exp), mcp-kali-server (deliverable, exp), kailash-mcp (first-party, generated from manifest), mcp-inspector (dogfood duty). The pre-purge O-7 rows were phantom-upstream and are removed — aspirational names live in [the phantom-upstream registry (kailash-os#210)](https://github.com/kailash-os/kailash-os/issues/210). The `headless-agent` IMAGE profile is a separate, real deliverable. **Profile: mixed** — two Flask-derivable third-party deliverables plus first-party work: grants and schema stability. The grant system: short-lived human-minted capability grants scope the enable-able categories, service start, and exp execution. Unsupervised agents list/search/read only. The log records grant-scoped actions. The CI dogfood loop runs the A-3 scanner suite against the distro's own kailash-mcp.

## 2.6 The full category table (post-purge census)

| Layer | Cat | Name | Tools (≈) | nixpkgs coverage | Notes |
|---|---|---|---|---|---|
| **CORE** | — | System substrate: kernel, base userland, hardening, safety defaults, desktop(s), CLI & menu engines | — | — | every image inherits CORE; hosts no tool categories |
| CLASSIC | C-1 | Information Gathering | 38 | High | classic; AI-surface lead-in |
| CLASSIC | C-2 | Vulnerability Analysis | 7 | Medium | gvm = service module |
| CLASSIC | C-3 | Web Application Assessment | 10 | Medium-High | Burp/ZAP/Caido pinned |
| CLASSIC | C-4 | Database Assessment | 7 | High | trivial |
| CLASSIC | C-5 | Password & Offline-Credential Attacks | 16 | High | wordlist/pw packs land as data rows; online brute-forcing out |
| CLASSIC | C-6 | Reverse Engineering (software) | 26 | Very High | no hardware/RF RE |
| CLASSIC | C-7 | Signal & SDR (opt-in carve-out) | 6 | Medium | `kailash-data.sdr-tools` toggle; never on default ISOs |
| CLASSIC | C-8 | Exploitation & Post-Exploitation (software) | 8 | Medium | no AD/lateral-movement arsenal |
| CLASSIC | C-9 | Forensics, IR & Reporting | 21 | Medium-High | faraday/timesketch as modules |
| CLASSIC | C-10 | Runtime AppSec for AI Systems | 1 | Medium | ASVS toolkit data deriv shared with D-7 |
| ATTACK | A-1 | AI Reconnaissance & Target Discovery | 1 | Very Low | all bespoke |
| ATTACK | A-2 | LLM Prompt Injection & Jailbreaking | 6 | Low-Medium | garak/PyRIT/promptfoo core |
| ATTACK | A-3 | Agentic, MCP & Tool-Use Attacks | 5 | Very Low | most novel; ATLAS 2026.07 |
| ATTACK | A-4 | Model Supply Chain & Artefact Poisoning | 3 | Very Low | guarddog/picklescan/modelscan core |
| ATTACK | A-5 | Model Extraction, Inversion & MIA | 7 | Medium | counterfit/ART research stack |
| ATTACK | A-6 | Multi-modal & Physical-AI Attacks | 0 | Very Low | aspirational-only — every row was phantom-upstream; names live in the registry ([kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) until rebuilt for real |
| ATTACK | A-7 | AI System Exploitation | 0 | Very Low | aspirational-only — every row was phantom-upstream; names live in the registry ([kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) until rebuilt for real |
| ATTACK | A-8 | Data Poisoning & Dataset Attacks | 1 | Very Low | upstream-of-model attacks |
| DEFENCE | D-1 | AI Runtime Defence & Guardrails | 4 | Low | NeMo/LLM Guard/Guardrails AI |
| DEFENCE | D-2 | AI Detection, Monitoring, Observability, IR | 6 | Low | langfuse module heavy |
| DEFENCE | D-3 | AI Assurance, Evals & Benchmarks | 6 | Medium | lm-eval-harness core |
| DEFENCE | D-4 | Model Provenance, Signing & Trust | 8 | Medium-High | sigstore/cosign/modelsign |
| DEFENCE | D-5 | AI Threat Modelling | 1 | Very Low | templates + small tooling |
| DEFENCE | D-6 | AI Governance & Regulation Mapping | 0 | n/a | aspirational-only — template packs were phantom-origin; names live in the registry ([kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| DEFENCE | D-7 | Standards Verification Toolkit | 0 | n/a | aspirational-only — toolkit packs + verifier CLI not built; names live in the registry ([kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| OPS | O-1 | MLOps & ML Engineering Suite | 18 | High | MLflow module (pairing target) |
| OPS | O-2 | Compute & Serving Infrastructure | 11 | Medium | k3s/podman/vLLM; ollama + llama.cpp primary O-4 |
| OPS | O-3 | Vector Stores & Retrieval | 9 | Medium | chromadb/qdrant/pgvector |
| OPS | O-4 | Local LLM & Inference Labs | 4 | Medium-High | ollama documented here |
| OPS | O-5 | AI Engineering SDKs & Dev Environment | 26 | Very High | the dev layer |
| OPS | O-6 | Documentation, Reporting & Authoring | 10 | High | quarto/pandoc/typst; texlive opt-in; pwndoc-ng/faraday primary C-9 |
| OPS | O-7 | Agent & MCP Operability | 4 | mixed | grants + kailash-mcp + rig deliverables |

**Totals: 31 tool categories across four tool layers — 10 + 8 + 7 + 7 — and 270 primary tool slots.** The declared basis is CLASSIC 134 · ATTACK 23 · DEFENCE 25 · OPS 82. Data categories stay excluded from the counts. The opt-in C-7 SDR pack is the one data-pack census category and is excluded by the same rule. The four tool layers sit on CORE, the substrate layer; CORE hosts no tool categories. Counts are per-primary-category; each distinct tool counts once. The counts match the manifest validator's census. **[kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) correction (2026-10-14):** the previous 337-slot sheet counted 66 phantoms. Those rows claimed upstream GitHub repositories; no such repository was ever created. The manifest now carries verified-upstream rows only; the `kailash-packages` validator's upstream-realism gate refuses phantom rows. The aspirational names live in the [kailash-os#210 registry](https://github.com/kailash-os/kailash-os/issues/210) until built for real.

## 2.7 Deliberate exclusions

- **Hardware & RF & radio (explicit):** all wifi attack tooling (aircrack-ng suite, airgeddon, wifite, kismet, reaver, bully, pixiewps, hcxdumptool, hcxtools, wifiphisher, fern, asleap, cowpatty, crackle, wifi-honey, wash), Bluetooth stacks (ubertooth, bluelog, bluesnarfer, btscanner, blueranger, spooftooph, rfcat, fang, chirp), general hardware-hacking categories (Kali's 14-Hardware Hacking), USB/pcap device tooling, and RF transmission tooling. **Exception: the C-7 SDR carve-out** (gnuradio/gqrx/hackrf + DSP/audio libs; opt-in only, for AI/ML signal work and A-6 research needs).
- Commercial/licensed: Nessus, Cobalt Strike, paid IDA. `kailash doctor <tool>` points at legitimate licensing.
- Unmaintained: truecrack, paros, pre-2015 webshell collections.
- Cloud-only SaaS (exceptions: CLI-only deliverables such as wandb-cli).
- Duplicate-scope: keep the maintained one, and document the supersession (netexec→crackmapexec precedent; the dropped sqlninja/jsql/sqlsus/tnscmd10g group of C-4).
- Classic-network attack tooling: AD/lateral-movement arsenal, online password brute-forcing against live services, social engineering, C2 frameworks — Kali-for-networks territory, not the four pillars.

## 2.8 The three-navigation-modes rule

1. **Layer-first (menu).** Desktop menu + docs site navigate Layer → Category → Tool.
2. **Tactic-first (matrix).** Docs render the MITRE ATLAS tactic view for Layer ATTACK: AML.TA0002 Reconnaissance → which tools. The adversary-doctrine mode.
3. **Standard-first (verification).** Docs render the ASVS 5.0 / AISVS 1.0 / MLSVS / LLM Top 10 (both epochs) evidence-matrix view. `kailash verifier --standard aisvs --level 2` drives it from the CLI. The assurance-doctrine mode; this view earns D-7 its place.

All three generate from the same manifest (`atlas_tactics`, `owasp_llm`, `asvs`, `aisvs`, `mlsvs` fields per tool).


# Chapter 3 — Architecture: Layout & Flake Design

## 3.1 Two repos, two jobs

| Repo | Name | Job | CI posture |
|---|---|---|---|
| `kailash-os/kailash-os` | the OS | root flake, nixosConfigurations, image generation, the category module tree, the CLI, the website build wiring, tests, and a minimal `pkgs/` only for what the OS itself needs | manifest + packages + VM tests + images |
| `kailash-os/kailash-packages` | the overlay | every bespoke tool derivation, the manifest (`tools.yaml` + `categories.yaml`), the auto-call harness, its own CI | manifest-wellformed + per-package build |
| `kailash-os/kailash-website` | the site | the Quarto-based public docs & governance site; consumes the manifest via a build-time fetch from a pinned packages-rev; deploys to GitHub Pages | site build + link check |
| `kailash-os/kailash-references` | history | 2023 submodules (RedNix, nix-security-box, kalinix), frozen | none |

Dependency direction (strict): `kailash-packages` ← pinned by ← `kailash-os`; `kailash-os` ← manifest-source-of ← `kailash-website` (the site build reads the manifest of a pinned packages rev; the site content is generated, not hand-written; see §5.3). No cycles: the packages repo never imports the OS repo.

## 3.2 The kailash-os repo layout

```
kailash-os/
├── flake.nix                     # root flake: nixosConfigurations, images, devShells, checks
├── flake.lock
├── modules/
│   ├── default.nix               # folds categories into one importable module list
│   ├── classic/ … (10 files)      # c-01-information-gathering … c-09-forensics-ir, c-10-runtime-appsec-ai
│   ├── attack/ … (8 files)      # a-01-ai-recon … a-08-data-poisoning
│   ├── defence/ … (7 files)      # d-01-runtime-defence … d-07-standards-verification
│   ├── ops/ … (7 files)      # o-01-mlops … o-07-agent-mcp
│   └── base/                     # kernel, fonts, terminal, desktop-{kde,gnome,xfce},
│                                 # user, hardening, safety-defaults, website.nix
├── menu/generate.sh              # manifest → freedesktop files
├── cli/                          # the kailash CLI
├── packages/                     # small pkgs the OS itself needs (kailash CLI, kailash-menu)
├── images/                       # nixos-generators + disko configs per target
├── profiles/                     # minimal, full, redteam-ai, blue-team-ai, platform
├── tests/                        # per-category VM tests + integration tests
├── docs/                         # guide pages, ADRs, responsible-use (dev-facing)
├── report-templates/             # llm-redteam / adversarial-ml / supply-chain-audit
├── .github/workflows/{build,release}.yml + renovate.json
└── README.md
```

Module naming note: the landed tree carries no Wireless & RF category. Its surviving software content is exactly the C-7 opt-in pack (`c-07-signal-sdr`). Reverse engineering is software-only (`c-06-reverse-engineering`).

## 3.3 The kailash-packages repo layout

```
kailash-packages/
├── flake.nix                     # overlay + packages outputs + checks
├── flake.lock
├── manifest/
│   ├── tools.yaml                # THE manifest: every tool, status, source, safety, mappings
│   └── categories.yaml           # the census categories (31 shippable + 1 data-pack), aliases, ATLAS/ASVS/AISVS/MLSVS maps
├── pkgs/                         # one dir per package, auto-called
│   ├── garak/default.nix
│   ├── pyrit/default.nix
│   └── … (bespoke dirs, one per manifest-listed bespoke tool)
├── nvfetcher/{config.toml,_sources/}
├── tests/                        # per-package build + smoke checks
├── .github/workflows/build.yml   # build every deriv, push to Cachix
└── README.md
```

Rules: the manifest is the only hand-maintained registry. The harness auto-calls the `pkgs/` dirs (a tool is packaged iff it is manifest-listed). `nvfetcher/_sources/` is committed. Branch protection on `main`: PRs required, checks required, signed commits required.

## 3.4 The root flake — the input & posture contract

```nix
{
  description = "Kailash OS - NixOS for AI Security";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    kailash-packages = {
      url = "github:kailash-os/kailash-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    sops-nix.url = "github:Mic92/sops-nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # optional inputs, commented: determinate (nix.nixosModules), nixified-ai (GPU variants)
  };

  outputs = { self, nixpkgs, kailash-packages, flake-parts, nixos-generators
            , disko, sops-nix, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowInsecurePredicate = p: true;  # pentest tooling posture (RedNix heritage)
        };
        overlays = [ kailash-packages.overlays.default ];
      };
    in {
      nixosConfigurations = {
        kailash-minimal = nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [ ./profiles/minimal.nix ./modules/base/safety-defaults.nix ];
        };
        kailash-full = nixpkgs.lib.nixosSystem {
          inherit system pkgs;
          modules = [ ./profiles/full.nix self.nixosModules.kailash ];
        };
      };
      nixosModules.kailash = { config, lib, pkgs, ... }: { imports = [ ./modules ]; };
      # devShells per category, images via nixos-generators, checks per §7
    };
}
```

Notes: **no bare `cudaSupport = true`**. GPU support is per-variant/per-profile (§4.3/§7.10): the nixified-ai variant-suffix practice is the model, not a flipped global bool. The `checks.<system>` shape follows the NixOS-wiki convention. The sketch shows the shape; the landed flake is flake-parts-based and uniform across both repos.

## 3.5 The category module contract

```nix
# modules/classic/c-01-information-gathering.nix (the shape every category module copies)
{ config, lib, pkgs, ... }:
let
  # generated from manifest/tools.yaml — never hand-edited
  toolList = import ../../generated/classic-c-01.nix;
in {
  options.kailash.layers.classic.categories.c-01-information-gathering = {
    enable = lib.mkEnableOption "Layer CLASSIC - Information Gathering toolset";
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = toolList;   # the manifest-driven default; users can ++ extend
    };
  };
  config = lib.mkIf config.kailash.layers.classic.categories.c-01-information-gathering.enable {
    environment.systemPackages = config.kailash.layers.classic.categories.c-01-information-gathering.packages;
  };
}
```

The contract gives: **opt-in by default** (nothing installs until enabled), **extendable tool sets** (users append), **one derivation per tool** (the category carries a tool list, not packaging logic), and **generated lists** (`make gen-categories` — the manifest is the only hand-maintained registry). Cross-references (a tool whose primary is elsewhere) resolve via secondary tags. No duplicate installs.

## 3.6 Design decisions logged

| # | Decision | Rationale |
|---|---|---|
| D1 | Two repos (OS / packages), not one | The overlay is independently consumable (§3.1); mirrors nixpkgs↔NixOS; matches the org's existing repo names |
| D2 | Manifest lives in the packages repo | The derivations and the manifest belong together. The packages-repo CI then validates one against the other in-repo |
| D3 | The website is its own repo (`kailash-website`) | The site builds and deploys independently of the image pipelines. Users who want only docs do not clone the OS repo |
| D4 | `allowUnfree` + `allowInsecurePredicate` at the root config, documented | RedNix heritage; logged per §9.3 (the manifest records unfree entries) |
| D5 | flake-parts for both repos' flake outputs | Uniform output shape (packages/checks/devShells) across repos |
| D6 | Never a bare global `cudaSupport = true` | GPU variants are per-package/per-profile (§4.3) |
| D7 | The C-7 SDR carve-out is a data-pack toggle, not a category of record | Tool-category count stays 31; CORE hosts no tool categories; the pack is excluded from ISO budgets by construction |


# Chapter 4 — Packaging Strategy

## 4.1 The three populations of packages

- **nixpkgs-native** — already in nixpkgs at a recent-enough version. The lockfile pins it; no derivation work. The CLASSIC and OPS layers are mostly this population.
- **nixpkgs-native, stale** — in nixpkgs but behind for a fast-moving tool. An override wraps it; the manifest documents it as `stale`.
- **bespoke** — not in nixpkgs at all: one package dir in kailash-packages, an nvfetcher pin, a build derivation, a smoke test.

The bespoke work is the real cost (~85–90 derivations planned). The per-phase budget (§8) carries it; the caching strategy (§7.4) amortises it.

## 4.2 The tool manifest — the single source of truth

```yaml
tools:
  - id: garak
    layer: ATTACK
    category: A-2
    secondary_categories: [D-3]      # optional cross-refs; one primary only
    name: garak
    description: "LLM vulnerability scanner — probes for jailbreaks, prompt injection, data leakage"
    source:
      vcs_owner: NVIDIA
      repo: garak
      vcs_url: git+https://github.com/NVIDIA/garak
    license: Apache-2.0
    packaging:
      status: bespoke                # native | stale | bespoke | module | data
      derivation: pkgs/garak/default.nix
    safety:
      level: requires-target         # safe | requires-target | exp
      target-required: true
    nixos-menu:
      icon: garak.svg
      exec: garak
      category: A-2
    atlas_tactics: [AML.T0051, AML.T0054]
    owasp_llm: {2026: LLM01, v2: LLM01}   # both epochs, per §1.4
    docs: layers/a-02/garak.md
    tags: [scanner, offensive, llm, nvidia]
```

Every tool lands once: exactly one primary category, and secondary tags where dual-use is real. This one file drives six views: (1) the overlay's derivations, (2) the category modules' package lists, (3) the desktop menu, (4) the CLI, (5) the repo guide docs, (6) the website's generated sections. Six views, one truth.

## 4.3 Bespoke derivations — the patterns

Four shapes cover everything:

- **Shape 1 — pure python (pip):** `buildPythonPackage` inside its own python package-set; one package-set **per tool** (one-package-set-per-tool: garak's torch/transformers pins stay in garak's derivation; PyRIT's pins stay in PyRIT's derivation). `doCheck = false` (no GPU/tests in the build sandbox); `pythonImportsCheck` as the smoke gate.
- **Shape 2 — system build (Rust/Go/C):** `buildRustPackage`/`buildGoModule`/`mkDerivation` with cargoLock/goSum pinned. The checkPhase is skipped (VM tests cover behaviour).
- **Shape 3 — docker-backed (heavy platform services, honest wrappers):** triton, milvus, and weaviate-by-docker for cases where native packaging of the vendor stack is impractical. The derivation ships the compose manifest + a wrapper; the lab boot pulls the image. Attack-surface tooling (A-7) is **never** in this shape — it stays natively derived.
- **Shape 4 — GPU-variant packs, from nixified-ai:** for the handful of O-2/O-4/O-5 tools where GPU acceleration matters (torch family, vllm, onnxruntime, whisper-family…). Kailash follows the nixified-ai naming pattern: a **non-GPU default derivation plus explicit variant outputs** (`garak-nvidia`, `torch-cuda`), not a flipped global `cudaSupport` bool. Variants are flake outputs, built only by the labelled CI job, never pulled by default. Kailash avoids the "Torch not compiled with CUDA enabled / half-pinned CUDA stack in main" failure mode and still offers the GPU path.

For **torch-family / jax-family under nixpkgs**, Kailash also carries a **fallback overlay import of `nixvital/ml-pkgs`** (torch-family, jax-family, data-utils). When the nixpkgs variants do not package cleanly, the pinned nixvital overlay provides maintained versions. Preference order: nixpkgs-native → nixvital overlay pin → bespoke derivation. The manifest records which path applies; staleness stays visible either way.

## 4.4 The nvfetcher update loop

```bash
nvfetcher update                                    # fetch latest source revs per config.toml
nvfetcher --output-directory nvfetcher/_sources gen # materialise rev+sha256; commit
nix build ./pkgs/<tool>                             # verify build after update
git commit; gh pr create                            # the update PR carries the build status
```

Each bespoke tool has an nvfetcher entry pinning a rev. Research-grade tools pin to commit revs, **not tags**; docs state the pin date. CI runs `nvfetcher --dry-run` on cadence (§7.6) and opens PRs. Auto-merge needs passing checks **plus** one approval; the flow is never fully unattended.

## 4.5 Overlay composition (the packages flake's outputs)

```nix
outputs = { self, flake-parts, nixpkgs, ... }:
  flake-parts.lib.mkFlake { inherit self; } {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    flake.overlays = {
      default   = composeManyExtensions [ self.overlays.tools self.overlays.services ];
      tools     = auto-called from pkgs/ via the manifest;
      services  = the module-typed deliverables (kailash-mcp, etc.);
    };
    flake.packages = per-system package outputs (one per bespoke tool);
    flake.checks   = manifest-wellformed + per-package smoke checks;
  };
```

Overlays compose by family — not one giant overlay; the nixvital pattern is the model. A downstream user who wants just the AI-security tooling takes `overlays.tools` alone onto their own NixOS.


# Chapter 5 — Website, Menu, Docs & the Dual Navigation

## 5.1 What the Kali experience actually is, mechanically

Three artefacts agree: the desktop menu (category folders generated from `.directory` files), the per-category website page, and the per-tool page. Kailash reproduces all three from the manifest — no manual duplication, no drift.

## 5.2 Desktop menu (kailash-menu)

`menu/generate.sh` (inside a `kailash-menu` derivation) walks the manifest and emits `$out/share/desktop-directories` + `$out/share/applications`: one `.directory` per layer, one per category, one `.desktop` per tool with `Exec=`/`Icon=` from the manifest. Categories appear nested only when a tool installs into them. **Empty categories still show as empty folders (the Kali behaviour)**. Icons start as placeholders (layer letter on coloured disc). The manifest's icon field exists from the start; icon upgrades are data-only.

## 5.3 The website (`kailash-website`, Quarto) — the public face

The site is **the Kali kali.org/tools equivalent: generated from the manifest and published via Quarto**. The tree shows the target shape; the landed site is flat `qmd` pages and grows into that shape:

```
kailash-website/
├── _quarto.yml
├── index.qmd                      # the mission + pillars + status
├── pages/
│   ├── about.qmd                  # project story, heritage, governance summary
│   ├── getting-started/           # install, first rebuild, the nix learning track
│   ├── layers/                    # generated: 31 category pages (layers/→categories→tools)
│   ├── tools/                     # generated: per-tool pages (description, usage, safety, ATLAS tags)
│   ├── tactics/                   # generated: ATLAS matrix pages (Layer ATTACK)
│   ├── standards/                 # generated: ASVS/AISVS/MLSVS/LLM-Top-10 evidence matrices (D-7)
│   ├── governance/                # page version of Chapter 9 (responsible use, licensing posture, reporting)
│   └── roadmap.qmd                # generated from the project board state
├── styles/                        # brand: layer colours ATTACK grey/OPS red/CLASSIC blue/DEFENCE green, mountain iconography
├── data/                          # fetched manifest snapshot (pinned rev of the packages repo)
└── .github/workflows/deploy.yml   # build → gh-pages deploy + link-check fail
```

**Build/deploy pipeline:** CI fetches `manifest/tools.yaml` from `kailash-packages` at a pinned rev → `quarto render` generates the layers/tools/tactics/standards sections + stub-check → GitHub Pages deploy on merge to `main`. The site build refuses to pass if a Layer ATTACK tool page is a bare stub at release time. The human-review gate is mechanised. The website is the public-facing set; the repo guides are the dev-facing set. Both generate from the same manifest.

**Domains.** The project holds two domains. **kailash.site** is the primary site: this website, the generated docs (layers/tools/tactics/standards), and governance. GitHub Pages serves it via CNAME. **kailash.tools** is reserved for the tooling plane: the future binary-cache front-end (a Cachix custom domain or the self-hosted Attic, §7.4) and any tool-facing services. Roles split across the domains without architecture changes. The deploy target and the flake's `nixConfig` substituter URLs point at whichever domain serves each role.

**Why a separate repo:** the site deploys without a rebuild of the OS. Content generation is data-driven from the packages repo's manifest. Docs-truth and package-truth never hand-sync.

## 5.4 Report templates (Quarto) — three engagement types

`report-templates/{llm-redteam, adversarial-ml, supply-chain-audit}` — each with `_quarto.yml`, pre-structured `index.qmd`, `findings/` stubs, and a `repro/` pin of the manifest hash. `kailash report new <type> <name>` scaffolds + pins.

## 5.5 The pairing thesis (why A-7 ships attack tools whose targets ship in OPS)

This design decision makes Kailash OS more than "Kali with extra tools". The platform targets (MLflow, vLLM, TorchServe, Triton, Ray, and the vector DBs) ship in the OPS layer. Their documented configs are lab-accurate and vulnerable by default. A-7 ships the attack probes. Each A-7 tool's docs pair with the OPS-layer config that validated the tool. Deployment and attack share one declared environment; the distro is its own verification harness.


# Chapter 6 — The kailash CLI

## 6.1 What it is

The CLI is the manifest-aware front-end over real nix invocations — **not** a second source of truth. It is Python 3.13, packaged in the packages repo, and driven by the same `tools.yaml`. Every command reads the manifest; everything else shells out to nix. The flake stays the only evaluation engine.

## 6.2 Command surface

The landed slice (KA-14.1, [kailash-packages#52](https://github.com/kailash-os/kailash-packages/pull/52)): `list`, `search`, `info`, `profile list`, `manifest validate` + `manifest check`. The remaining verbs land per the roadmap.

```
kailash list [--layer CLASSIC|ATTACK|DEFENCE|OPS] [--category <cat-id>] [--status native|stale|bespoke|module|data]
kailash search <query>            # names, descriptions, tags, tactics
kailash info <tool-id>            # full manifest record incl. ATLAS + docs pointer
kailash shell <category>          # nix develop wrapper for the category devShell
kailash enable <category>         # emits the NixOS config snippet
kailash doctor <tool-id>          # installed? version? smoke? — reports store-path provenance
kailash profile list             # OS profiles (landed slice)
kailash manifest check           # loader self-inventory (test aid)
kailash image build <target>      # nixos-generators wrapper
kailash report new <type> <name>  # scaffold a Quarto report
kailash update [tool]             # nvfetcher update + PR (with approvals)
kailash manifest validate         # the CI gate, runnable locally
kailash verifier --standard <std> [--level N]   # the D-7 standards-evidence view (CLI)
```

## 6.3 The manifest-baked path (the drift killer)

The CLI derivation bakes `KAILASH_MANIFEST`/`KAILASH_CATEGORIES` to store paths (`wrapProgram`). The CLI hash changes whenever the manifest changes, so `kailash list` never disagrees with the installed system. `kailash manifest validate` re-runs the invariants locally before any push.


# Chapter 7 — Build Pipelines, Tests, CI & Release Engineering

## 7.1 The image matrix

| Target | Profile | Format | Budget | Use |
|---|---|---|---|---|
| iso-standard | minimal + KDE | ISO | ≤4 GB | install/live |
| iso-lite | minimal + Xfce | ISO | ≤2.5 GB | lightweight live |
| iso-full | full | ISO | ≤10 GB | the "kali-everything" live |
| headless-agent | base + CLI, no desktop | ISO/VM | ≤1.5 GB | boot-to-agent |
| ova-redteam-ai | redteam-ai | OVA | ≤8 GB | lab VM |
| ova-blueteam-ai | blue-team-ai | OVA | ≤6 GB | defence lab |
| aws-ai-lab | platform | AMI | ≤15 GB | cloud lab |
| proxmox-platform | platform | VMA | ≤12 GB | homelab |
| rpi-ai-edge | minimal subset | aarch64 SD | ≤2 GB | edge |

All images come via nixos-generators + disko; each target is a flake output. The landed matrix — qemu/ISO pairs over minimal/full/redteam-ai/headless-agent on x86_64 + aarch64; the OVA/AMI/Proxmox/RPi targets are still roadmap — lives in [`docs/guide/images.md`](https://github.com/kailash-os/kailash-os/blob/master/docs/guide/images.md). CI-enforced size budgets force the heavy packages (texlive, gnuradio, wordlists, SDR pack) into opt-in `kailash-data.*` derivations. **The C-7 SDR pack and the wordlist packs are excluded from every default ISO by construction.**

## 7.2 The VM test harness

Per-category VM tests run one per category: a booted VM plus a
`--help` smoke across the tool list, from the manifest. Three integration
tests exist:

- `integration-full.nix` — full profile boots, menu landed, CLI healthy,
  sampled tools exec.
- `integration-mlflow-attack.nix` — O-1 MLflow unauth lab-default + the A-7
  MLflow-exploit probe pair → asserted listing; the pairing thesis executed.
  The aspirational tool name lives in the
  [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) registry.
- `integration-garak-local.nix` — O-4 tiny local model + A-2 garak, one
  probe class; nightly flag, not per-push.

## 7.3 The CI pipeline (build.yml)

```yaml
jobs:
  manifest:        # nix build .#checks.x86_64-linux.manifest-wellformed
  build-packages:  # matrix GENERATED FROM THE MANIFEST; cachix push
  vm-tests:        # matrix: c-01, a-03, a-07, d-03, integration-full (selected by phase)
  images:          # hosted image-matrix job (arm slice local) — size-budget check
```

Gate order respects dependency: manifest → packages → VM tests → images. The build matrix comes from the manifest via a committed tiny generator. A tool that enters the manifest is automatically in CI. Image jobs need the runners with the largest attached disks. The landed posture is hosted runners plus the arm-local slice (the arch strategy recorded on [kailash-os#198](https://github.com/kailash-os/kailash-os/pull/198)). Self-hosted big-disk runners remain the fall-back if hosted budgets bind.

## 7.4 Caching

The public Cachix cache `kailash` holds everything nixpkgs does not already carry (CI pushes; users pull). nixpkgs-native artefacts come from the standard cache. A self-hosted Attic is the documented fallback if the Cachix free-tier limits hit (same nix.conf lines). When self-hosted, it advertises at **cache.kailash.tools** — the reserved tooling domain (§5.3). The flake's `nixConfig` carries `extra-substituters` + trusted keys, so a fresh checkout's `nix build` pulls transparently (the nixified-ai pattern).

## 7.5 Update automation & dependency policies — the cadences, pinned

**This chapter answers one question directly: how often do packages update, and how often does nix "need" updating? Kailash never wants newest-version churn. The lockfile is the product. Updates arrive as reviewed PRs on explicit cadences.**

**Tool-source updates (nvfetcher) — by staleness class, recorded per tool in the manifest:**

| Class | Tools | Update cadence | Who |
|---|---|---|---|
| fast-moving (weekly upstream change) | garak, PyRIT, promptfoo, subfinder, katana, httpx, findomain, nuclei, mcp-inspector | check **weekly** (Monday CI dry-run); PR only when the new rev passes its smoke check | nvfetcher CI + author merge |
| steady | guarddog, picklescan, modelscan, ART, chainsaw, hayabusa, qdrant, ollama, llama.cpp | check **fortnightly** | nvfetcher CI |
| slow/locked | everything else (nixpkgs-native, pinned big frameworks) | follow the nixpkgs refresh only | Renovate |
| stale-native overrides | tools with documented nixpkgs overrides | re-evaluate at each release, before the lock bump | author |

**Flake-input updates (Renovate):**

| Input | Cadence |
|---|---|
| nixpkgs (nixos-unstable lock) | **monthly**, scheduled first Monday of the month, PR-gated |
| flake-parts, disko, nixos-generators, sops-nix, home-manager | monthly; batched into the nixpkgs PR when practical |
| kailash-packages (in the OS repo) | **on the packages repo's tagged releases**, not continuously — see below |

**What "nix needing constant updating" actually means, and the answer:** the OS does *not* update nix or nixpkgs continuously. The nixpkgs *lock* stays put between monthly refreshes. Tools pinned inside the lock do not move. The lock versions the distro. Users pull updated tool versions at their own cadence via `kailash update` or by pulling a newer lock or release. Nothing re-links, re-installs, or re-downloads in the background.

## 7.6 Release versioning & cadence — how a release version is created

- **The lockfile is the version.** A Kailash release is a **flake.lock commit** (the packages-repo tag + the OS-repo lock bump), a signed tag, and a CHANGELOG generated from the lock delta. No hand edits, no invented versions: the version is the calendar scheme below, applied to the reviewed lock state.
- **The versioning scheme: calendar `YYYY.NN` — the RELEASE-INDEX form (`versionScheme: 2026.xx`), decided and recorded on [kailash-os#142](https://github.com/kailash-os/kailash-os/issues/142); stated canonically in this chapter, rendered for users in [`docs/guide/releases.md`](https://github.com/kailash-os/kailash-os/blob/master/docs/guide/releases.md).** NN is the release's index **within the year's train sequence**, not the calendar month. The year's first release is `2026.01`; the second is `2026.02`. `2026.02` still names the 2026 train even when it ships in January 2027. The tag says which train; the release date says when. No gaps, no renames: a slipping RC renumbers nothing, and the numbering never collides, however many releases a year holds.
- **The three-stage ladder (one scheme family):**

  | Stage | Tag form | Meaning |
  |---|---|---|
  | Staged development cut | `2026.xx-<stage>.<n>` | pre-GA milestones off the main track (`2026.01-alpha.1`, `2026.01-rc.1`) — stage + increment visible in `git tag -v` output |
  | GA | `2026.xx` (bare) | the general-availability release for that train index — **full Phase-8 acceptance** (two-machine reproducibility, golden-image diff, the complete artefact matrix, site deploy, release automation) |
  | Material re-cut of a shipped GA | `2026.xx.1` | only when a shipped GA artefact actually changes; changelog-notes-only re-cuts keep the original tag |

  **The bare tag is RESERVED:** `2026.01` exists only at GA. Staged cuts carry the suffix — a `2026.01-alpha.1` tag never reads as GA.
- **The first staged cut is `2026.01-alpha.1`** — manifest-complete, flagship stack, safety gates, profiles, CLI, CI — with the ladder `alpha.1 → alpha.2 → … → rc.1` as waves land (cut only what is verifiable). GA (`2026.01`, bare) is the full §7.9 acceptance, not a date. **No `v0.x`-style tag ever lands anywhere in the repos** (package `pname`-version fields are packaging metadata, not tags).
- **CHANGELOG organisation:** grouped by train — `## 2026.01 — <date>` — matching the pinned six-week release cadence. The changelog is generated from the lock delta between the previous train's lock and this one (no silent removals).
- **Every 6 weeks** (Kali-like, deliberately paced away from the newest upstream state): tagged releases produce the artefact matrix (§7.9) + a signed changelog. The release PR (the lock bump) IS the release review — evaluated sizes + golden-image diff inline.
- **Branch policy (standing rule):** never commit `master`/`main` directly — branch + conventional commits (`type(scope): subject`) + PR + squash-merge. PRs require green CI + one approval. nvfetcher and renovate PRs also require one approval (the standing approval-gated-auto-merge preference). Both repos enforce signed commits.
- **Rolling `main` between releases:** merges land daily if needed. The lock only moves monthly (inputs) or on reviewed tool-update PRs. The ISO a user booted last month keeps rebuilding reproducibly until the user deliberately pulls the new lock.
- **Where the scheme is stated (single-source discipline):** the canonical statement is §7.6 of this chapter. The user-facing rendering is [`docs/guide/releases.md`](https://github.com/kailash-os/kailash-os/blob/master/docs/guide/releases.md) — one URL for the whole release story. README `versionScheme` lines and GitHub Release-notes templates cite it. No other surface derives a scheme of its own.

**The consequence:** a Kailash install does not "update nix" on its own, ever. A user's system updates at the user's own cadence: a `nixos-rebuild switch` to a newer lock, or a release upgrade. This is the anti-churn posture: **the lockfile is the product.**

## 7.7 The per-tool build pipeline (how each tool actually gets built)

The non-negotiables apply to every tool regardless of shape:

- **Pin everything** — source rev, deps, toolchain, through the lock. No floating master/latest/unpinned fetchers.
- **No network in the build sandbox** (fixed-output fetcher hashes aside). Fetches materialise as separate input derivations.
- **No mutable state in the store** — cache/config go to the user's XDG dirs via wrappers.
- **The build hash is the version** — two machines run the same tool iff they resolve the same store path. `kailash doctor` reports provenance.
- **Build-time discipline** — the slow path (big Python envs, texlive) runs exactly once. The gate for shipping is one successful CI build + cache push; users never compile it again.

## 7.8 Adding a tool (the complete runbook)

decide primary category → nvfetcher entry → derivation (Shape 1/2/3/4) → smoke-check → manifest entry → `make gen` (regenerate module lists, menu, docs stubs, site sections) → checks → PR (safety acknowledgement for Layer ATTACK) → merge policy: green CI + approval. Removing a tool requires a supersession note (no silent removals).

## 7.9 What a full release looks like (the artefact manifest)

*The reduced first-cut set is stated per the staged-cut rule; the 14-artefact list remains the GA acceptance.*

The first staged cuts (the [KA-46](https://github.com/kailash-os/kailash-os/issues/141) release lane) take the REDUCED set: signed tag (`2026.01-alpha.1`), CHANGELOG, release notes, and ISO artefacts only where the image pipeline exists at tag time (else none, with reasons stated) — the staged cut is manifest-complete but pre-GA precisely because the full matrix is not yet produced. The 14-artefact release list stands (ISOs, OVAs, AMI, Proxmox, RPi, checksum sheet, docs site, changelog, AI-BOM, signed release notes). The GA acceptance adds: the two-machine reproducibility gate, the golden-image diff, the A-3 dogfood scan, and the site stub-check rules.

## 7.10 The two workflows (build.yml and release.yml)

Per §7.3, the build matrix is generated from the manifest. release.yml additionally builds the `kailash-website` staging site (content pinned to the releasing packages rev) and deploys on publish. The image job runs on hosted runners with the arm slice local.


# Chapter 8 — The Phase-by-Phase Build Plan

Every phase ends with a **verifiable state** — a command that demonstrably works. "Done" means the verification command passes, not that code exists.

## Phase 0 — Repo bootstrap

1. `kailash-packages`: flake.nix skeleton, `manifest/{tools,categories}.yaml` (validated, empty-of-tools), `pkgs/`, `nvfetcher/`, tests/, build.yml; branch protection on `main` (PR + checks + signed).
2. `kailash-os`: layout per §3.2, root flake (nixpkgs + kailash-packages inputs), `profiles/minimal.nix` (boots, no categories), build.yml.
3. `kailash-website`: `_quarto.yml` skeleton, `index.qmd`, governance stub page, deploy.yml (gh-pages) — pipeline tested with a placeholder manifest fetch.
4. Cachix `kailash` cache + secrets. Convention commits: `.editorconfig`, `CONTRIBUTING.md` (packaging gates + safety policy), `.gitignore` (`result*`; `nvfetcher/_sources/` committed).

**Verify:** `nix build .#checks.x86_64-linux.manifest-wellformed` OK on the two manifest stubs; `nixos-rebuild build --flake .#kailash-minimal` produces a system closure; the website scaffold renders locally.

## Phase 1 — Baseline NixOS host

`modules/base/`: kernel + networking (systemd-networkd, iwd), the `kailash` user (wheel), terminal substrate (alacritty/kitty, zsh, tmux, starship), fonts, desktop-kde/-gnome/-xfce (light ISO uses Xfce), `hardening.nix` (sysctl, firewall default-deny, sudo policy), `safety-defaults.nix` (`KAILASH_LAB_MODE=0` env, responsible-use motd, dangerous-tool wrapper hook). Home-manager integration for dotfiles.

**Verify:** VM boots to KDE login; `kailash doctor` stub reports substrate healthy; `nixos-rebuild switch` on real hardware lands the same config.

## Phase 2 — Layer CLASSIC: all 10 classic categories

Write the 10 module files; manifest grows to ~141 entries; the ~12 stale-override derivations for the fast movers (subfinder, katana, httpx, findomain, nuclei via nvfetcher); gvm as service module (backlog placement is allowed without blocking the phase gate); `profiles/full.nix` enables all 10; VM smoke tests per category (`tests/c-01.nix`…), CI green.

**Verify:** `nix build .#checks.x86_64-linux.c-01` etc. pass; full-profile VM boots with `which nmap` resolving; `kailash list --layer CLASSIC` prints all Layer-CLASSIC tools.

## Phase 3 — Layer OPS: platform base

O-1/O-2/O-3/O-5/O-6 modules (native-first: pandas, scikit-learn, k3s, podman, ollama); pip-heavy derivs (chromadb, faiss, langfuse, phoenix, langchain/langgraph); `services.kailash.mlflow` (lab-default unauth **documented, not defaulted**); O-4 + ollama tiny-test-model; O-6 with quarto/pandoc/typst/mdbook; report templates scaffolded; devShells per shipped category. GPU-variant derivations start here for the torch family (Shape 4). When the nixpkgs variants do not package cleanly, pin the nixvital/ml-pkgs torch-family overlay and document the choice.

**Verify:** platform-profile VM boots with a working ollama (tiny model completes a prompt); mlflow reachable on :5000; quarto renders `report-templates/llm-redteam/index.qmd`; `nix develop .#o-03-vector-stores-retrieval` opens a working shell.

## Phase 4 — Layer ATTACK core: the flagship offensive stack

The flagship five: garak, PyRIT, promptfoo, ART, counterfit — pinned revs, smoke-checked; A-2 module + payload-pack data derivs; A-1 module + trufflehog cross-listed; VM tests a-01/a-02.

**Verify:** `nix build .#checks.x86_64-linux.a-02` passes; VM `garak --list-probes` prints the probe index; `kailash info garak` shows ATLAS tags.

## Phase 5 — Layer ATTACK long tail

A-3 (mcp-inspector + mcp-scan real derivs; novel probes as documented starter set), A-4 (guarddog/picklescan/modelscan + gguf/safetensors inspectors), A-5/A-6/A-7/A-8 modules; `integration-mlflow-attack.nix` activates; redteam-ai + blue-team-ai profiles land, OVAs build.

**Verify:** redteam-ai OVA boots; the MLflow-exploit integration test passes (real protocol; the [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) note); `kailash list --layer ATTACK` complete.

## Phase 6 — Layer DEFENCE

D-1 guardrails; D-2 langfuse/phoenix modules activated; D-3 evals (lm-eval-harness, deepeval, robustbench, giskard); D-4 provenance (cosign/sigstore/modelsign/cdxgen + AI-BOM flow); D-5/D-6/D-7 content + standards-data packs; `kailash report new` end-to-end.

**Verify:** blue-team-ai OVA boots; report new + render produces HTML; sign-with-modelsign-verify-with-cosign test passes; `kailash verifier --standard aisvs --level 2` renders the evidence matrix.

## Phase 7 — Website, menus, CLI, images, docs

`kailash-menu` + generation; CLI feature-complete (including verifier, doctor's provenance depth, --json); the C-7 SDR pack + wordlist packs wired as `kailash-data.*` opt-ins; image matrix (all 9 targets) with size budgets enforced; `kailash-website` full build: manifest fetched from the releasing packages rev, all four generated sections + stub-check, governance pages, deploy to gh-pages; the dev-facing guide docs generated too.

**Verify:** on hardware the KDE menu shows Kailash / Offensive-AI / LLM Prompt Injection & Jailbreaking / garak; `kailash list` matches the menu; every image inside budget; the live website renders with all TOC/section links resolving + CI stub-check green.

## Phase 8 — Quality, tests, release, GA

`nix flake check` as the single gate; release workflow per §7.10 (artefact matrix + signed changelog + site deploy); responsible-use review across the manifest; golden-image diff vs previous release (documented delta, no silent removals); the two-machine reproducibility test; tag per the §7.6 scheme; publish.

**Verify (the actual GA acceptance):** `nix flake check` green locally and in CI; ISO-full VM fresh boot: menu navigable, `kailash list` consistent with menu, garak + promptfoo `--help`-able; the MLflow-exploit pairing test passes on the released image; the live website TOC links resolve; two machines from the same lock agree bit-for-bit.



# Chapter 9 — Safety, Governance & Licensing

## 9.1 The responsible-use statement (framing text for every Layer ATTACK page)

Kailash OS ships offensive AI-security tooling for **authorised security work only**: red-team engagements with written authorisation, academic research, and defender-validation exercises. The operator is responsible for two duties: know the law in their own jurisdiction, and hold the authorisation to test systems they do not own. Australia: Cyber Security Act 2024 and Telecommunications Act 1997; elsewhere: the local equivalent. Kailash's safety defaults exist because this tooling is dual-use.

**Australia-specific framing:** Cyber Security Act 2024 (Cth) gives the security-legislation environment. Criminal Code Act 1995 (Cth) Division 474 carries the unauthorised access/impairment provisions. IRAP/ISM AI-relevant controls inform D-6's governance pack.

## 9.2 Safety defaults module (base/safety-defaults.nix)

- **The double-key gate is the mechanism** ([kailash-os#144, KA-18.1](https://github.com/kailash-os/kailash-os/pull/144)). The only install path for exp-class tooling is a generated gate wrapper. Every executable in the package's `bin/` refuses to run (exit 126) unless BOTH keys pass. Key 1: the host key `kailash.labMode = true` — a NixOS option, default **false**, baked into the gate script at build time. Key 2: the shell key `KAILASH_LAB_MODE=1` on the individual invocation. The refusal message names both keys and cites `docs/responsible-use.md`. A lab-off host refuses even with the shell key set. Neither key alone is ever sufficient; no default-on path exists. Layer CLASSIC non-exp tooling runs freely as in Kali.
- **The gate's data flows from the manifest (never a hand-copy).** The eval scan reads the exp-id list from the declared `tools.yaml` surfaces (`kailash.safety.manifests` through the flake input). Packaging-side, the generator emits the wrapper for every `safety.level: exp` manifest row — the manifest row IS the routing record.
- **Gated install + state.** Only the gate wrappers reach the system PATH (the bare exp derivation never does). The host's gate state commits to the closure at `/etc/kailash/safety/wrapped-exp-tools.json` (per wrapped id: id, program, gate package). The parity validator (`tools/safety-exp-wrap.py`) consumes it: an independent PyYAML parse of the manifest, a coverage requirement, and a per-wrap behavioural probe. The negative case (a broken fixture refused) is proven in CI by construction.
- **Distro variants.** There is no separate "lab-mode distro". The same image carries both postures. The gate, not the package set, is what differs. Exp tooling is absent from any default-profile PATH regardless. A non-lab (default-safe) install is simply `kailash.labMode = false` — the default. The host operator who wants the lab posture makes the deliberate, reviewable configuration change and rebuilds. The per-invocation shell key remains the second, in-the-moment opt-in. (The image-variant axis that DOES matter is the artefact matrix in §7.9.)
- **No auto-starting services** ([kailash-os#145, KA-18.2](https://github.com/kailash-os/kailash-os/pull/145)). Every D-layer service module is `mkEnableOption`-off. The standing audit scans every host's declarative `systemd.services` for exp-tool auto-starts or pre-set lab keys. The hostile-fixture negative case is proven in CI on every PR. The docs record the lab-default weaknesses (never defaults). The hardening appendix carries the production posture.
- **Secrets hygiene** ([kailash-os#145, KA-18.2](https://github.com/kailash-os/kailash-os/pull/145)). sops-nix manages keys (`kailash.secrets.sopsFile`, explicitly wired, nothing defaulted). Model API keys read at runtime from `~/.config/kailash/keys/`, never from the store (store paths are world-readable). The posture is stated store-side at `/etc/kailash/secrets-policy`.
- **Responsible-use statement as data** ([kailash-os#145, KA-18.2](https://github.com/kailash-os/kailash-os/pull/145)). [`docs/responsible-use.md`](https://github.com/kailash-os/kailash-os/blob/master/docs/responsible-use.md) carries the authorised-work-only framing. The Australian provisions are named (Cyber Security Act 2024 (Cth); Criminal Code Act 1995 (Cth) Division 474; IRAP/ISM governance mapping). The file carries no legal text beyond the names and a neutral description. Profiles, gates and site pages render from the file.
- **Agent capability grants.** Autonomous operator sessions hold short-lived human-minted grants. The grants scope the enable-able categories, service start, exp execution, and the live-target query budget. Unsupervised agents can list/search/read only. The log records grant-scoped actions. The A-3 scanner suite runs against kailash-mcp itself in CI — the in-distro dogfood loop.

## 9.3 Licence posture

Kailash's own artefacts are **MIT**. Bundled tools keep their upstream licences (garak Apache-2.0, PyRIT MIT, promptfoo MIT; ART AGPL-class — verify + record at packaging time). Burp is unfree; the manifest records it unfree; `allowUnfree` is documented. Data packs carry upstream licences and the matching use restrictions.

## 9.4 Contribution & review workflow

PRs to either repo need the CI gates + one maintainer approval. Layer ATTACK additions additionally require the safety-level confirmation in the PR body. The manifest is the only hand-maintained registry. CI rejects PRs that hand-add tools to module/package files without a manifest entry. Standing convention requires signed commits. The home-manager module pins `user.signingkey` + `commit.gpgsign true`.

## 9.5 Name and brand guidelines

Name, logo, the layer colour scheme (ATTACK=grey, OPS=red, CLASSIC=blue, DEFENCE=green), the mountain iconographic theme (Kailash-as-residence-of-Shiva), desktop wallpaper, and **the website's visual identity** (the same four-layer colour system, applied to the site's layer/category navigation). The manifest only reserves the fields. The visible brand assets are a Phase-7 deliverable.


# Appendix A — Full Tool Inventory (the manifest seed)

Legend: **status** = native (nixpkgs, lockfile pin) / stale (native + override) / bespoke (kailash-packages deriv) / module (service) / data (data-only pack). **safety** = free / target / exp. These tables are the planning seed. The live manifest is the census of record (§2.6).

**Layer CLASSIC rows** (status overwhelmingly native; safety free):

| Cat | Tool(s) | Status |
|---|---|---|
| C-1 | nmap, masscan, rustscan, zenmap, the-harvester, amass, sublist3r, recon-ng, maltego-community, dmitry, fierce, dnsrecon, dnsenum, dnsmap, massdns, assetfinder, findomain, gobuster, dirb, dirsearch, feroxbuster, ffuf, wfuzz, whatweb, wafw00f, arjun, uro, photon, sherlock, spiderfoot, httpx, gospider, hakrawler, arp-scan, netdiscover | native |
| C-1 | katana, subfinder, puredns | stale |
| C-2 | nikto, lynis, wapiti, legion, searchsploit | native |
| C-2 | nuclei | stale |
| C-2 | gvm | module |
| C-3 | burpsuite (unfree), zaproxy, caido | native |
| C-3 | graphw00f, clairvoyance, inql, kiterunner, gopherus, commix, sstimap | native/overlay |
| C-4 | sqlmap, mssql-cli, psql, redis-cli, mongosh, sqlitebrowser, mycli | native |
| C-5 | hashcat, john, johnny, ophcrack, crunch, cewl, maskgen, policygen, statsgen, hashid, hash-identifier, bopscrk, rsmangler, twofi | native |
| C-5 | seclists, pw-packs | data |
| C-7 | gnuradio, gqrx, hackrf-tools, sox, librosa, pysox | data/opt-in |
| C-7 (deliberately absent) | ALL wifi/bt/rf attack tooling | **not shipped** |
| C-6 | ghidra, radare2, rizin, cutter, iaito, gdb, gef, pwndbg, peda, capstone, cstool, checksec, jadx, bytecode-viewer, apktool, dex2jar, javasnoop, jd-gui, smali, unicorn, angr, edb-debugger, binwalk, unipacker, qiling, pyinstaller-extractor | native |
| C-8 | metasploit-framework, msfvenom, beef-xss, weevely, laudanum, peass-ng, unix-privesc-check, pspy | native/pinned (a pre-purge data-pack row was removed: phantom-origin, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| C-9 | autopsy, sleuthkit, volatility3, hashdeep, chkrootkit, rkhunter, dc3dd, ewfacquire, guymager, regripper, testdisk, photorec, bulk_extractor | native |
| C-9 | chainsaw, hayabusa, sigma-cli, sysmon-modular | native/data |
| C-9 | plaso | native |
| C-9 | timesketch, faraday, pwndoc-ng | module |
| C-10 | mitmproxy (zaproxy primary C-3, C-10 secondary) | native (the four bespoke scanner rows were phantom-upstream, removed per [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| C-10 | — (the ASVS toolkit data row was phantom-upstream, removed; aspirational names live in the [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) registry) | — |

**Layer ATTACK rows** (the bespoke core):

| Cat | Tool(s) | Status | Licence | Safety | Map |
|---|---|---|---|---|---|
| A-1 | — (the four bespoke recon rows were phantom-upstream; removed, names live in the [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) registry) | — | — | — | AML.TA0002 |
| A-1 | trufflehog | native | GPL | free | AML.TA0002 |
| A-2 | garak | bespoke | Apache-2.0 | target | AML.T0051, T0054; LLM01 |
| A-2 | pyrit | bespoke (pip) | MIT | target | AML.T0051; LLM01 |
| A-2 | promptfoo | bespoke | MIT | target | LLM01 |
| A-2 | — (a phantom-upstream row was removed; [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) registry) | — | — | — | LLM01 |
| A-2 | jailbreak-payloads, libertas-prompts, llm-jailbreak-bench | data | varies | n/a (a pre-purge fourth data row was removed: phantom-upstream, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | LLM01 |
| A-3 | mcp-inspector (primary O-7, A-3 secondary/dogfood) | native/overlay | Apache-2.0 | free | AML agentic set |
| A-3 | mcp-scan | bespoke | new | free | AML.T0051 |
| A-3 | mcp-guardian, mcp-remote/proxy | bespoke | new | free | AML agentic |
| A-3 | — (a phantom-upstream probe row was removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML agentic |
| A-3 | — (two phantom-upstream scanner/fuzzer rows were removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML agentic |
| A-3 | mcpoison | bespoke | new | exp | AML agentic |
| A-3 | agent-dojo | bespoke | new | free | AML agentic |
| A-3 | — (a phantom-upstream data row was removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML agentic |
| A-4 | guarddog, picklescan, modelscan | bespoke | MIT etc | free | LLM03; AML.T0010 |
| A-4 | — (the four inspector rows were phantom-upstream; removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML.T0010 |
| A-4 | — (a phantom-upstream PoC row was removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML.T0010 |
| A-5 | counterfit | pinned | MIT | target | AML.T0024 |
| A-5 | knockoffnets | bespoke | new | target | AML.T0024 (a pre-purge extraction row removed: phantom-upstream, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| A-5 | adversarial-robustness-toolbox | bespoke (pip) | AGPL-class | target | AML toolkit |
| A-5 | foolbox, cleverhans, tf-privacy | bespoke (pip) | MIT/Apache | target | AML toolkit |
| A-5 | privacy-meter | bespoke | new | target | AML.TA0000 |
| A-6 | — (all three were phantom-upstream; removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML physical |
| A-6 | — (phantom-origin data row; removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML physical |
| A-6 | — (phantom-upstream; removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML multi-modal |
| A-7 | — (all eight were phantom-upstream; removed — names live in the [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) registry until rebuilt) | — | — | — | AML.T0010 |
| A-7 | — (a phantom-upstream row was removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML case study |
| A-8 | — (all four were phantom-upstream; removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — | AML.T0020 |
| A-8 | trojai-toolkit | bespoke | MIT/research | free | AML.T0020 (a pre-purge replay row removed: phantom-upstream, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |

**Layer DEFENCE rows:**

| Cat | Tool(s) | Status | Licence | Safety |
|---|---|---|---|---|
| D-1 | nemo-guardrails, llm-guard, guardrails-ai, rebuff | bespoke (mostly pip) | Apache/MIT | free (three pre-purge guard rows removed: phantom-upstream, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| D-2 | langfuse (module), phoenix, whylogs, evidently, otel-ai, giskard | bespoke/module | Apache etc | free (detector-bert + canary rows removed: phantom-upstream, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| D-3 | lm-eval-harness, deepeval, robustbench, huggingface-evaluate, fairlearn, aif360 | bespoke/native mix | Apache/MIT | free |
| D-4 | cosign, syft, grype, trivy, cyclonedx-cli | native (pinned) | Apache etc | free |
| D-4 | modelsign, cdxgen, model-card-toolkit | bespoke | new | free (two pre-purge helper rows removed: phantom-upstream, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| D-5 | maestro | bespoke/data | CC-BY-SA | free (the five template/visualiser rows removed: phantom-upstream, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| D-6 | — (all four were phantom-origin template packs; removed, names live in the [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) registry) | — | — | — |
| D-7 | — (all five aspirational-only; removed, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) | — | — | — |

**Layer OPS rows:**

| Cat | Tool(s) | Status | Licence | Safety |
|---|---|---|---|---|
| O-1 | mlflow (module), dvc, git-lfs, bentoml, feast, kedro (+datasets), clearml (module), wandb-cli | native/overlay | Apache etc | free |
| O-1 | airflow (module), prefect (module) | module | Apache | free |
| O-1 | pandas, polars, scikit-learn, numpy, scipy, xgboost, lightgbm | native | per-tool | free |
| O-2 | vllm, tgi, torchserve, kserve, ray (module) | bespoke | Apache | free |
| O-2 | triton-inference-server | docker module | Apache | free |
| O-2 | k3s, minikube, kind, podman | native (pinned) | MIT etc | free |
| O-2 | nvidia-container-toolkit | native | unfree-class | free |
| O-3 | chromadb, qdrant, faiss, txtai, jina-embeddings-cli | native/overlay | Apache etc | free |
| O-3 | weaviate, pgvector, elasticsearch | module | etc | free |
| O-3 | milvus | docker module | etc | free |
| O-4 | ollama (primary, + llama.cpp secondary O-2), text-generation-webui, open-webui | native/overlay | MIT etc | free (a pre-purge helper row removed: phantom first-party, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |
| O-5 | langchain, langgraph, llama-index, openai-python, anthropic-python, google-genai, autogen, crewai | native (pinned) | etc | free |
| O-5 | pytorch (cpu default, cuda variant), torchvision, torchaudio, tensorflow, jax, onnxruntime | native/variant/overlay | etc | free |
| O-5 | transformers, datasets, peft, trl | native (pinned) | etc | free |
| O-5 | vscode, code-server, neovim, python-lsp-server, uv, ruff, mypy, python313 | native | MIT etc | free |
| O-6 | quarto, pandoc, typst, mdbook, drawio, excalidraw, mermaid-cli, obsidian | native | per-tool | free |
| O-6 | texlive-full | data/opt-in | GPL-class | free |
| O-6 | dradis (module; pwndoc-ng + faraday primary C-9) | module | GPL etc | free |
| O-7 | hexstrike-ai, mcp-kali-server | bespoke (deliverable) | Apache-2.0 etc | exp (grant-gated) |
| O-7 | — (two phantom-upstream lab-pack rows were removed; [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) registry) | — | — | — |
| O-7 | kailash-mcp, mcp-inspector(dogfood) | first-party | MIT | exp/mixed (two pre-purge first-party deliverable rows were removed: phantom-upstream, [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210)) |

**Post-purge total: 270 primary slots.** Bespoke-declared rows name their overlay derivations; the rest are native/pinned. (Corrected census at §2.6; the [kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210) phantom purge re-based it.)


# Appendix B — Glossary

- **ATLAS** — MITRE's Adversarial Threat Landscape for AI Systems (ATT&CK-style for AI; 16 tactics in 2026.05).
- **AI security / AISec / MLSec** — synonyms here: defending and attacking AI systems.
- **Agentic security** — LLM-agent security: tool-use attacks, MCP security, agent-to-agent protocols, sandbox escapes.
- **MCP** — Model Context Protocol.
- **MLOps** — the ML-operations toolchain (MLflow, DVC, orchestration, serving, vector stores).
- **Nix flakes** — declarative, locked, reproducible packaging on Nix.
- **Layers** — CORE (substrate, no tool categories); CLASSIC (C-1…C-10, Kali heritage); ATTACK (A-1…A-8); DEFENCE (D-1…D-7); OPS (O-1…O-7).
- **Lab mode** — `KAILASH_LAB_MODE=1`, the explicit opt-in state for exp-gated tooling.
- **AI-BOM** — CycloneDX-flavoured bill of materials for AI artefacts (models, datasets, tools).
- **Pairing thesis** — ship the platform (OPS) and its attack tooling (A-7) in one pinned, declared environment.
- **The lockfile is the version** — releases are flake-lock commits; the build hash is the version; the lockfile is the product.
