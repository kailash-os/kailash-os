# Kailash OS

[![License: BSD-3-Clause](https://img.shields.io/badge/licence-BSD--3--Clause-blue)](https://github.com/kailash-os/kailash-os/blob/master/LICENSE) [![kailash.site](https://img.shields.io/website?down_message=offline&up_message=live&url=https%3A%2F%2Fkailash.site&label=site)](https://kailash.site) [![version](https://img.shields.io/badge/version-v0.1.0-blue)](https://github.com/orgs/kailash-os/projects/1) [![GitHub commit activity](https://img.shields.io/github/commit-activity/m/kailash-os/kailash-os)](https://github.com/kailash-os/kailash-os/graphs/commit-activity) [![Libraries.io dependency status for GitHub repo](https://img.shields.io/librariesio/github/kailash-os/kailash-os)](https://libraries.io/github/kailash-os/kailash-os) [![GitHub Release](https://img.shields.io/github/v/release/kailash-os/kailash-os?include_prereleases)](https://github.com/kailash-os/kailash-os/releases)

[![pre-commit.ci status](https://results.pre-commit.ci/badge/github/kailash-os/kailash-os/master.svg)](https://results.pre-commit.ci/latest/github/kailash-os/kailash-os/master)

[![OpenSSF Scorecard](https://img.shields.io/ossf-scorecard/github.com/kailash-os/kailash-os?label=OpenSSF%20Scorecard&style=flat)](https://scorecard.dev/viewer/?uri=github.com/kailash-os/kailash-os) [![OpenSSF Best Practices](https://img.shields.io/badge/cii%20best%20practices-in%20progress-orange)](https://www.bestpractices.dev/projects/15182) [![flake-check](https://github.com/kailash-os/kailash-os/actions/workflows/flake-check.yml/badge.svg)](https://github.com/kailash-os/kailash-os/actions/workflows/flake-check.yml) [![Dependency Review](https://github.com/kailash-os/kailash-os/actions/workflows/dependency-review.yml/badge.svg)](https://github.com/kailash-os/kailash-os/actions/workflows/dependency-review.yml)

Kailash OS is a NixOS-based Linux distribution for AI security: offensive
tooling (ATTACK), defensive tooling (DEFENCE), classic security tooling
(CLASSIC) and the AI-security platform stack (OPS) in one declaratively
built environment. The distribution contract that made Kali Linux the
default environment for security work — curated tooling, category
navigation, live images — pointed at a surface Kali has never mapped:
the AI systems stack.

Four pillars, each shipping twice: **AppSec** (classic application
security assessment, CLASSIC), **APISec** (web, API and AI-endpoint
runtime assessment, DEFENCE + OPS), **MLSec** (adversarial ML: evasion,
poisoning, extraction — predictive AI, ATTACK) and **AISec** (LLM,
agentic and MCP security — prompt injection, tool-use attacks, supply
chain, ATTACK).

- **4 layers** over the CORE substrate — CLASSIC · ATTACK · DEFENCE · OPS
- **31 categories** in the generated table below
- **336 primary tool slots** across the four layers (data-packs excluded
  from counts; every number in this README is generated from the
  taxonomy's single home, never hand-maintained)

## Category table

<!-- BEGIN GENERATED CATEGORY TABLE (tools/generate-readme-table.py; KA-20.1) — do not edit -->

| # | Category | Layer | Primary tool slots |
| --- | --- | --- | --- |
| 1 | Information Gathering | CLASSIC | 38 |
| 2 | Vulnerability Analysis | CLASSIC | 7 |
| 3 | Web Application Assessment | CLASSIC | 10 |
| 4 | Database Assessment | CLASSIC | 7 |
| 5 | Password & Offline-Credential Attacks | CLASSIC | 15 |
| 6 | Reverse Engineering (software artefacts) | CLASSIC | 26 |
| 7 | Exploitation & Post-Exploitation (software) | CLASSIC | 9 |
| 8 | Forensics, IR & Reporting | CLASSIC | 21 |
| 9 | Runtime AppSec for AI Systems | CLASSIC | 8 |
| 10 | AI Reconnaissance & Target Discovery | ATTACK | 5 |
| 11 | LLM Prompt Injection & Jailbreaking | ATTACK | 8 |
| 12 | Agentic, MCP & Tool-Use Attacks | ATTACK | 9 |
| 13 | Model Supply Chain & Artefact Poisoning | ATTACK | 8 |
| 14 | Model Extraction, Inversion & MIA | ATTACK | 8 |
| 15 | Multi-modal & Physical-AI Attacks | ATTACK | 5 |
| 16 | AI System Exploitation | ATTACK | 9 |
| 17 | Data Poisoning & Dataset Attacks | ATTACK | 6 |
| 18 | MLOps & ML Engineering Suite | OPS | 18 |
| 19 | Compute & Serving Infrastructure | OPS | 13 |
| 20 | Vector Stores & Retrieval | OPS | 9 |
| 21 | Local LLM & Inference Labs | OPS | 5 |
| 22 | AI Engineering SDKs & Dev Environment | OPS | 26 |
| 23 | Documentation, Reporting & Authoring | OPS | 12 |
| 24 | Agent & MCP Operability | OPS | 8 |
| 25 | AI Runtime Defence & Guardrails | DEFENCE | 7 |
| 26 | AI Detection, Monitoring, Observability & IR | DEFENCE | 8 |
| 27 | AI Assurance, Evals & Benchmarks | DEFENCE | 6 |
| 28 | Model Provenance, Signing & Trust | DEFENCE | 10 |
| 29 | AI Threat Modelling | DEFENCE | 6 |
| 30 | AI Governance & Regulation Mapping | DEFENCE | 4 |
| 31 | Standards Verification Toolkit | DEFENCE | 5 |
| — | **Total** | 31 categories | **336** |

Per-layer primary tool slots: CLASSIC 141 · ATTACK 58 · DEFENCE 46 · OPS 91 — 31 categories, 336 tool slots across the four layers (data-packs excluded from counts, plan §3.6), generated from [`categories.yaml`](https://github.com/kailash-os/kailash-packages/blob/main/manifest/categories.yaml) — the taxonomy's single home — on the `kailash-packages` main HEAD.
<!-- END GENERATED CATEGORY TABLE -->

The table is **generated** from the Kailash packages manifest — never
hand-maintained (the no-hand-sync rule). Regenerate or verify it with:

```console
$ python3 tools/generate-readme-table.py --check          # gate: nonzero on drift
$ python3 tools/generate-readme-table.py --emit           # print the table
$ python3 tools/generate-readme-table.py --pin --emit     # snapshot: the flake.lock pin
```

## Install (from the flake, x86_64-linux / aarch64-linux)

Try the manifest CLI without installing the OS — the packages overlay is
a standalone flake:

```console
$ nix run github:kailash-os/kailash-packages#kailash -- list
$ nix run github:kailash-os/kailash-packages#kailash -- manifest validate
```

Evaluate a host configuration from the OS flake (the minimal profile —
the CORE substrate with zero categories enabled):

```console
$ nix flake show github:kailash-os/kailash-os          # surface: nixosConfigurations.kailash-minimal, nixosModules.kailash
$ nix build github:kailash-os/kailash-os#nixosConfigurations.kailash-minimal.config.system.build.toplevel
```

The manifest gate runs before any package builds in CI
(`tests/validate_manifest.py`, mirrored in the packages repo), and the
CLI carries the same validator locally:

```console
$ nix run github:kailash-os/kailash-packages#kailash -- manifest validate
manifest-wellformed: OK (32 category entries, 336 tools; primary slots: ATTACK 58, CLASSIC 141, DEFENCE 46, OPS 91; data-packs excluded from counts)
```

## Project Status:

Contact [shain.singh@owasp.org](mailto:shain.singh@owasp.org) for more information.

## Cadence and version scheme

Releases run every **6 weeks**. The lockfile is the version: a release
carries the `flake.lock` commit and a tag `vMAJOR.YYYYMM.<patch>` (for
example `v1.202611.0`) — **versionScheme: `vMAJOR.YYYYMM.<patch>`**. A
Kailash install never updates nix, nixpkgs, or tooling on its own;
source pins and flake inputs move on explicit, documented schedules and
`main` is never committed directly. The full policy:
[`docs/guide/cadence.md`](docs/guide/cadence.md). A calendar-versioning
amendment to the scheme is tracked in
[kailash-os#142](https://github.com/kailash-os/kailash-os/issues/142).

## FAQ

Q. Why the name 'Kailash'?<br>
A. The authors have been long-time users and fans of WHAX/SLAX, BackTrack/Knoppix and Kali Linux. The name "Kailash" is an acknowledgement to credit Kali Linux as the main source of inspiration.
Kailash is also the residence of Lord Shiva in Hindu scriptures.

Q. Why is Kailash based on NixOS and not {Debian|Arch}? <br>
A. The authors have only recently started learning Nix and NixOS and this project provided an opportunity to do a deep-dive.

## Acknowledgements

- [Kali Linux](https://kali.org)
- [NixOS](https://nixos.org)
- [Spectrum](https://spectrum-os.org)
- [KaliNix](https://github.com/balsoft/kalinix/)
- [Nix Security Box](https://github.com/fabaff/nix-security-box)
- [RedNix](https://github.com/redcode-labs/RedNix)
