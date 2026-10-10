# Kailash OS: guide for contributors and coding agents

This file is the single source of truth for humans and coding agents
(GitHub Copilot, Claude, Cursor, Hermes, etc.) working on Kailash OS.
Tool-specific files (`CLAUDE.md`, `.github/copilot-instructions.md`) only
point here. When this file and a tool-specific file disagree, this file wins.

Read the [Testing](#testing), [Pull requests](#pull-requests) and
[Security](#security) sections before changing anything. The rest is a map of
the codebase.

The kailash specification (taxonomy, packaging shapes, phase gates and
verification gates) renders on [kailash.site](https://kailash.site) and ships
with this org's website repository. The roadmap board
([org project 1](https://github.com/orgs/kailash-os/projects/1)) carries issue
`KA-NN` items; [issue #61](https://github.com/kailash-os/kailash-os/issues/61)
is the canon map — the dependency graph plus the sprint decomposition register
every new roadmap item adds a row to.

## Project overview

Kailash OS is a NixOS-based Linux distribution for AI security: offensive
tooling (ATTACK), defensive tooling (DEFENCE), classic security tooling
(CLASSIC) and the AI-security platform stack (OPS) in one declaratively built
environment. The taxonomy — CORE plus four layers, 31 categories — is
**versioned data**, not prose: every later artifact (modules, profiles, menu,
CLI, docs, site) generates from the manifest in
[`kailash-packages`](https://github.com/kailash-os/kailash-packages).

The delivery unit is an **hour-scale slice** with a watchable RED→GREEN commit
pair ("leaf PR"): `KA-XXn` children map the specification's design sections to
runnable artefacts, per the sprint register on issue #61.

Other documents worth knowing:

- [`README.md`](README.md): status, badges, layout.
- [`CONTRIBUTING.md`](CONTRIBUTING.md): the working agreement.
- [`SECURITY.md`](SECURITY.md): vulnerability reporting policy. See [Security](#security).
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md): known environment issues and cures.
- The companion repo [`kailash-packages`](https://github.com/kailash-os/kailash-packages):
  the overlay flake — pinned sources, package derivations, and the manifest
  (`categories.yaml`, `tools.yaml`) that is the taxonomy's single home.

## Repository structure

| Directory | Purpose |
| --- | --- |
| `flake.nix` | Root flake: pinned inputs (including `kailash-packages`, whose `flake.lock` pin resolves against the real overlay), unfree posture explicit, no global CUDA |
| `profiles/` | Composable system profiles (`minimal.nix` = CORE substrate with zero categories enabled; further profiles layer categories on) |
| `modules/base/` | The CORE substrate every profile evaluates through |
| `modules/classic/` | Layer CLASSIC module surfaces (C-1…C-10) |
| `modules/attack/` | Layer ATTACK module surfaces (A-1…A-8) |
| `modules/defence/` | Layer DEFENCE module surfaces (D-1…D-7) |
| `modules/ops/` | Layer OPS module surfaces (O-1…O-7) |
| `cli/` | The `kailash` CLI (manifest-driven category surfaces) |
| `menu/` | Desktop menu generation |
| `images/` | NixOS image/ISO outputs |
| `packages/` | Per-category package groupings surfaced to profiles |
| `docs/` | Project documentation |

## The layer model and the manifest (single home rule)

The taxonomy lives in `kailash-packages/manifest/`: `categories.yaml` (the
31-category census) and `tools.yaml` (the tool inventory). The layer model is
the spec's §3.6 post-purge census — CLASSIC (~141 tool slots), ATTACK (~59),
DEFENCE (~46), OPS (~91) — with the C-7 SDR pack recorded as
`opt-in: data-pack`, never on default profiles or images.

**A fact has exactly one home.** Layer/category/tool facts are written in the
manifest, never duplicated into modules, READMEs or site copy; generated
artifacts regenerate from it. Deliberate exclusions (§3.7: no hardware/RF/wifi
tools, no paid-licence tools, no unmaintained or cloud-only tools) are the
"no-resurrection guard": do not reintroduce purged tooling, the manifest
validator refuses it.

ATLAS tactic mappings (ATTACK layer) and ASVS/AISVS/MLSVS/OWASP-LLM mappings
(DEFENCE layer) are manifest fields with real identifiers — verify mappings
against the public MITRE ATLAS dataset before writing one; never invent a
technique id.

## Testing

The repo follows the
[hypothesis-first TDD standard](https://github.com/kailash-os/kailash-os/issues/51):
**spec (from the issue's plan reference) → RED (watched, committed) → GREEN →
PR**. The watched-RED discipline is what makes every GREEN commit honest: a
failing test must exist, visibly, before the implementation lands. The
engineering standard pairs it with
[harness-before-capability ordering](https://github.com/kailash-os/kailash-os/issues/119):
the check that gates a behaviour ships in the same PR as the behaviour, and a
new gate's negative case is proven in CI, not asserted.

### Layer map

| What you are testing | Home | Do NOT put it in |
| --- | --- | --- |
| Manifest/taxonomy data invariants | the packages repo validator (`tests/validate_manifest.py`) + its checks | prose or per-module assertions |
| Nix module option behaviour | the checks/eval assertions in the same flake | shell scripts |
| Profile composition | `nix flake check` + the profile's eval assertion | manual rebuilds only |
| VM/image behaviour | a recorded run in the issue or PR | unit tests |

### Decision procedure

1. **Data invariant or category/tool fact?** Fix the manifest in the packages
   repo; extend the validator, never ad-hoc scripts.
2. **Option/behaviour assertion?** A row (or eval check) in the owning
   flake/module's existing checks.
3. **Neither?** Write a test function; one-line comment why it couldn't be a
   row; if no reason, it was a row.

### Instructions specific to coding agents

- **Watched RED is mandatory in the commit history**: a failing test's output
  appears in the RED commit's body; GREEN follows. Squash-without-RED is a
  review-blocking smell.
- **Run what CI runs** (`nix flake check` and the repo's workflows) before
  opening a PR.
- **No invented transcripts.** Any README/PR/issue claim about build or VM
  behaviour cites a real run: output verbatim, plus the issue/PR where it was
  recorded. A claim without a traceable run is marked PENDING with its owning
  issue — never approximated.

## Signing

**Everything is GPG-signed, always.** Commits AND tags
(`git config commit.gpgsign true`; signing key `AAF8226F3F4C1712` —
authored and committed as `Shain.Singh@owasp.org`). PR CI enforces
`required_signatures`; an unsigned or badly-attributed commit blocks the PR.
Never use the f5-attributed key for kailash work — the signing key and the
commit email must agree with the GitHub-verified identity or verification
fails with `bad_email` and the PR cannot merge.

Note: this repository's default branch is **`master`** (the packages and
website repos use `main`).

## Architecture Decision Records

Structural changes carry an ADR in the same PR, following the
[Coraza ADR standard](https://github.com/corazawaf/coraza/blob/main/docs/adr/README.md)
format. The bar here is small: most slices are leaf-sized, so the issue's plan
reference IS the design record — write an ADR only when **the change introduces
a new persistent artifact** (a manifest schema field whose semantics lock,
a profile contract, a wire format, a gate script) **or removes/changes one**.

Agent rules (borrowed from Coraza, same teeth):

- **Never invent discussion, deciders or quotes.** Cite commit/issue permalinks
  or write "No substantive technical discussion recorded".
- **Never rewrite an accepted ADR** to match a new change — supersede it.
- Dependency bumps, docs and CI tweaks don't need ADRs.

## Pull requests

Follow [`CONTRIBUTING.md`](CONTRIBUTING.md) and treat the PR checklist as a
contract, not decoration.

### Before opening

- Work happens on a leaf branch cut from **current `origin/master`** — never a
  stacked branch (the base must be the integration branch or the squash
  misses its target: verify content landed on the branch the squash merges to).
- **One logical change per PR.** No drive-by refactors, formatting or dependency bumps.
- TDD: watched RED committed before GREEN (see [Testing](#testing)).
- All commits GPG-signed by `Shain.Singh@owasp.org` (see [Signing](#signing)).

### Title and description

- Title carries the task id: `KA-XXn — summary [child of KA-XX]`; the PR body
  links the child issue (`Closes #NN`) and notes the parent gate stays open.
- Description: **what** changed, **why** (issue), **how verified** (watched RED
  output + GREEN output + any run evidence). Reviewers should not have to read
  the diff to know something changed.

### Commits

- Small, self-contained, same title style; no stray scratch files; probe files
  and temp scripts are deleted before commit, not gitignored.

## Labels

| Label | Meaning |
| --- | --- |
| `KA-XXn — <summary>` (in the TITLE, not a label) | issue/PR identity |
| `area:ci|cli|docs|github|images|layer-attack|layer-classic|layer-defence|layer-ops|manifest|menu|nix|packaging|repo|safety|taxonomy|testing|website` | component (the current catalog) |
| `type:task` | a leaf-sized roadmap slice (RED→GREEN→merge) — the only `type:*` label in the catalog today |
| `target:v0.1|v0.2|backlog` | milestone |
| `s:xs|s:s|s:m|s:l` | sprint effort (about one hour = `s:xs`/`s:s`) |
| `bug`, `documentation`, `ci` | maintenance |

Board status (`Todo` / `In Progress` / `Done`) is an org-project **field**, not a label: labels never encode progress. Agents applying labels mirror the area
from the directory the change lands in, and never invent new `area:*`/`type:*`
names — the label catalog is the vocabulary. Growing the catalog (a new
`area:*` or shape label) is a deliberate catalog change, not agent improvisation.

## Security

### Vulnerabilities

**Never open a public issue or PR describing an exploitable bug.** Report
through the GitHub security advisory link
([new advisory](https://github.com/kailash-os/kailash-os/security/advisories/new));
see [`SECURITY.md`](SECURITY.md).

### Secure defaults

- The distribution packages **offensive tooling**: the safety posture is
  deliberate and testable. Dangerous capability (`safety:exp` tooling) sits
  behind the lab-mode gate (`kailash.labMode` double-key gate, the
  safety-defaults module) — a PR that adds exp-class capability without the
  gating wiring is wrong by construction, not by review preference.
- No auto-start: services the operator did not explicitly enable must not
  listen on any interface; the no-auto-start audit is a standing check.
- Supply chain: inputs are pinned (`flake.lock` committed; nvfetcher pins +
  committed `_sources` in the packages repo); floating refs and unhashed
  fetches are review-blocking.
- Unfree licensing stays explicit at the flake level; never widen the posture
  for convenience — record the licence in the manifest instead.
- Secrets never enter the tree; secret hygiene is declarative (age/sops), not
  ad-hoc files.
- Treat manifest content as a supply-chain artifact: a tool's source URL and
  pin are attacker-relevant data — validate changes to them.

### Code style and conventions

- Nix: flake-parts module layout; typed options; one concern per module file;
  no `with lib;` in shared modules; `nix fmt` clean.
- Python tooling (the validator): stdlib-first, no new deps without
  justification in the PR body.
- Generated artifacts (`flake.lock`, nvfetcher `_sources/`) are committed;
  regeneration commands are documented next to the artifact.
- Package comments carry the package design claim: what it is, which manifest
  categories it serves, and the slice boundary.
