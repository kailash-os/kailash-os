# Kailash OS

[![License: BSD-3-Clause](https://img.shields.io/badge/licence-BSD--3--Clause-blue)](https://github.com/kailash-os/kailash-os/blob/master/LICENSE) [![kailash.site](https://img.shields.io/website?down_message=offline&up_message=live&url=https%3A%2F%2Fkailash.site&label=site)](https://kailash.site) [![GitHub commit activity](https://img.shields.io/github/commit-activity/m/kailash-os/kailash-os)](https://github.com/kailash-os/kailash-os/graphs/commit-activity) [![Libraries.io dependency status for GitHub repo](https://img.shields.io/librariesio/github/kailash-os/kailash-os)](https://libraries.io/github/kailash-os/kailash-os) [![GitHub Release](https://img.shields.io/github/v/release/kailash-os/kailash-os?include_prereleases)](https://github.com/kailash-os/kailash-os/releases)

[![pre-commit.ci status](https://results.pre-commit.ci/badge/github/kailash-os/kailash-os/master.svg)](https://results.pre-commit.ci/latest/github/kailash-os/kailash-os/master)

[![OpenSSF Scorecard](https://img.shields.io/ossf-scorecard/github.com/kailash-os/kailash-os?label=OpenSSF%20Scorecard&style=flat)](https://scorecard.dev/viewer/?uri=github.com/kailash-os/kailash-os) [![OpenSSF Best Practices](https://img.shields.io/badge/cii%20best%20practices-in%20progress-orange)](https://www.bestpractices.dev/projects/15182) [![flake-check](https://github.com/kailash-os/kailash-os/actions/workflows/flake-check.yml/badge.svg)](https://github.com/kailash-os/kailash-os/actions/workflows/flake-check.yml) [![Dependency Review](https://github.com/kailash-os/kailash-os/actions/workflows/dependency-review.yml/badge.svg)](https://github.com/kailash-os/kailash-os/actions/workflows/dependency-review.yml)

Kailash OS is a NixOS-based Linux distribution for AI security. One declaratively
built environment carries four tool layers: ATTACK, DEFENCE, CLASSIC, and OPS.
Curated tooling, category navigation, and live images made Kali Linux the default
security environment. The AI systems stack is the surface Kali Linux never mapped.
Kailash OS applies the same contract to this stack.

The distribution targets four pillars. Each pillar pairs the offensive side with
the build-side or defensive side:

- **AppSec** — classic application security assessment (the CLASSIC layer).
- **APISec** — web, API, and AI-endpoint runtime assessment (the DEFENCE and OPS layers).
- **MLSec** — adversarial ML: evasion, poisoning, extraction; predictive AI (the ATTACK layer).
- **AISec** — LLM, agentic, and MCP security: prompt injection, tool-use attacks,
  supply chain (the ATTACK layer).

- **4 layers** over the CORE substrate — CLASSIC · ATTACK · DEFENCE · OPS
- **31 categories** — the generated table below
- **264 primary tool slots** across the four layers — data-packs excluded from counts

Every number in this README is generated from the taxonomy's single home. No
number is hand-maintained.

## Category table

<!-- BEGIN GENERATED CATEGORY TABLE (tools/generate-readme-table.py; KA-20.1) — do not edit -->

| # | Category | Layer | Primary tool slots |
| --- | --- | --- | --- |
| 1 | Information Gathering | CLASSIC | 38 |
| 2 | Vulnerability Analysis | CLASSIC | 7 |
| 3 | Web Application Assessment | CLASSIC | 10 |
| 4 | Database Assessment | CLASSIC | 7 |
| 5 | Password & Offline-Credential Attacks | CLASSIC | 16 |
| 6 | Reverse Engineering (software artefacts) | CLASSIC | 26 |
| 7 | Exploitation & Post-Exploitation (software) | CLASSIC | 8 |
| 8 | Forensics, IR & Reporting | CLASSIC | 21 |
| 9 | Runtime AppSec for AI Systems | CLASSIC | 1 |
| 10 | AI Reconnaissance & Target Discovery | ATTACK | 1 |
| 11 | LLM Prompt Injection & Jailbreaking | ATTACK | 6 |
| 12 | Agentic, MCP & Tool-Use Attacks | ATTACK | 5 |
| 13 | Model Supply Chain & Artefact Poisoning | ATTACK | 3 |
| 14 | Model Extraction, Inversion & MIA | ATTACK | 7 |
| 15 | Multi-modal & Physical-AI Attacks | ATTACK | 0 |
| 16 | AI System Exploitation | ATTACK | 0 |
| 17 | Data Poisoning & Dataset Attacks | ATTACK | 1 |
| 18 | MLOps & ML Engineering Suite | OPS | 18 |
| 19 | Compute & Serving Infrastructure | OPS | 11 |
| 20 | Vector Stores & Retrieval | OPS | 9 |
| 21 | Local LLM & Inference Labs | OPS | 4 |
| 22 | AI Engineering SDKs & Dev Environment | OPS | 26 |
| 23 | Documentation, Reporting & Authoring | OPS | 10 |
| 24 | Agent & MCP Operability | OPS | 4 |
| 25 | AI Runtime Defence & Guardrails | DEFENCE | 4 |
| 26 | AI Detection, Monitoring, Observability & IR | DEFENCE | 6 |
| 27 | AI Assurance, Evals & Benchmarks | DEFENCE | 6 |
| 28 | Model Provenance, Signing & Trust | DEFENCE | 8 |
| 29 | AI Threat Modelling | DEFENCE | 1 |
| 30 | AI Governance & Regulation Mapping | DEFENCE | 0 |
| 31 | Standards Verification Toolkit | DEFENCE | 0 |
| — | **Total** | 31 categories | **264** |

Per-layer primary tool slots: CLASSIC 134 · ATTACK 23 · DEFENCE 25 · OPS 82 — 31 categories, 264 tool slots across the four layers (data-packs excluded from counts, [spec §2.6](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md#26-the-full-category-table-post-purge-census)), generated from [`categories.yaml`](https://github.com/kailash-os/kailash-packages/blob/main/manifest/categories.yaml) — the taxonomy's single home — on the `kailash-packages` main HEAD.
<!-- END GENERATED CATEGORY TABLE -->



The table is **generated** from the Kailash packages manifest. Hand edits never
touch the table (the no-hand-sync rule). Regenerate or verify it with:

```console
$ python3 tools/generate-readme-table.py --check          # gate: nonzero on drift
$ python3 tools/generate-readme-table.py --emit           # print the table
$ python3 tools/generate-readme-table.py --pin --emit     # snapshot: the flake.lock pin
```

## Install (from the flake, x86_64-linux / aarch64-linux)

Try the manifest CLI without installing the OS. The packages overlay is a
standalone flake:

```console
$ nix run github:kailash-os/kailash-packages#kailash -- list
$ nix run github:kailash-os/kailash-packages#kailash -- manifest validate
```

Evaluate a host configuration from the OS flake. The minimal profile carries
the CORE substrate with zero categories enabled:

```console
$ nix flake show github:kailash-os/kailash-os          # surface: nixosConfigurations.kailash-minimal, nixosModules.kailash
$ nix build github:kailash-os/kailash-os#nixosConfigurations.kailash-minimal.config.system.build.toplevel
```

The manifest gate runs in CI before any package builds. The gate is
`tests/validate_manifest.py`, mirrored in the packages repo. The CLI carries
the same validator locally:

```console
$ nix run github:kailash-os/kailash-packages#kailash -- manifest validate
manifest-wellformed: OK (32 category entries, 270 tools; primary slots: ATTACK 23, CLASSIC 134, DEFENCE 25, OPS 82; data-packs excluded from counts)
```

### Images and ISOs (KA-28.0 shape decision)

Pre-built artefacts ship with the `2026.01` train. Until release assets exist,
the flake above is the install surface.
[`docs/guide/images.md`](docs/guide/images.md) documents the images matrix:
every target, budget, download surface, and the verify commands. The
deliverable shapes, in shipping priority
([kailash-os#132](https://github.com/kailash-os/kailash-os/issues/132)):

1. **QEMU/VM disk image — the primary shape.** One
   `nixos-generators` output per profile (`minimal` first). The verification
   gates exercise this artefact ([KA-32](https://github.com/kailash-os/kailash-os/issues/32)
   golden-image reproducibility, [KA-43](https://github.com/kailash-os/kailash-os/issues/43)
   headless-agent boot polish).
2. **Bootable ISO — the secondary shape.** It carries the installable targets
   and the bare-metal evaluation of the CLASSIC and ATTACK tooling. The size
   budgets hold per format.
3. **Container surfaces — the tertiary shape.** Per-category nixos-container /
   podman provisioning serves the OPS service stack
   ([KA-42](https://github.com/kailash-os/kailash-os/issues/42)).
4. **The flake — always.** `github:kailash-os/kailash-os` is the importable
   surface for composed profiles. It stays as image artefacts ship.

QEMU images and ISOs emit from the same profile eval. One source gives two
formats. The arch strategy is x86 hosted, arm local
([kailash-os#198](https://github.com/kailash-os/kailash-os/issues/198)):
the aarch64 `minimal` and `headless-agent` rows build via
[`tools/build-arm-images.sh`](tools/build-arm-images.sh); the aarch64
`redteam-ai` rows stay the [KA-36](https://github.com/kailash-os/kailash-os/issues/36)
residual. The initial trains exclude: cloud-image formats
(AMI/export), PXE/netboot, and live-patch surfaces.

## Project Status:

Send questions about this project to [shain.singh@owasp.org](mailto:shain.singh@owasp.org).

## Cadence and version scheme

Releases run every **6 weeks**. The lockfile is the version. A release carries
the `flake.lock` commit and a calendar tag. The first staged cut of the first
train is `2026.01-alpha.1`. The bare tag `2026.01` stays reserved for general
availability (**versionScheme: `2026.xx`**, the `YYYY.NN` release-index scheme).
A Kailash install never updates nix, nixpkgs, or tooling on its own. Source
pins and flake inputs move on explicit, documented schedules. `main` never
takes a direct commit. The full policy, including the
staged-cut → GA → re-cut ladder, sits in
[`docs/guide/releases.md`](docs/guide/releases.md). Every release — alpha, rc,
GA — fills in the standing checklist
([`docs/guide/release-checklist.md`](docs/guide/release-checklist.md),
tracked per cut from the `release-cut` issue template).

## FAQ

Q. Why the name 'Kailash'?<br>
A. The authors used WHAX/SLAX, BackTrack/Knoppix, and Kali Linux over many years. The name "Kailash" credits Kali Linux as the main source of inspiration.
Kailash is also the residence of Lord Shiva in the Hindu scriptures.

Q. Why is Kailash based on NixOS and not {Debian|Arch}? <br>
A. The authors started recently with Nix and NixOS. The project is the deep-dive surface.

## Acknowledgements

- [Kali Linux](https://kali.org)
- [NixOS](https://nixos.org)
- [Spectrum](https://spectrum-os.org)
- [KaliNix](https://github.com/balsoft/kalinix/)
- [Nix Security Box](https://github.com/fabaff/nix-security-box)
- [RedNix](https://github.com/redcode-labs/RedNix)
