# Kailash OS: guide for contributors and coding agents

This file is the single source of truth for humans and coding agents on
Kailash OS. The coding agents include GitHub Copilot, Claude, Cursor and
Hermes.

Tool-specific files (`CLAUDE.md`, `.github/copilot-instructions.md`) only
point here. When this file and a tool-specific file disagree, this file wins.

Read the [Testing](#testing), [Pull requests](#pull-requests) and
[Security](#security) sections before any change. The rest is a map of the
codebase.

The kailash specification is the normative prose in
[`docs/spec.md`](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md)
in this repository. It records the taxonomy, the packaging shapes, the phase
gates and the verification gates. The tool and category data lives in the
[`kailash-packages` manifest](https://github.com/kailash-os/kailash-packages/tree/main/manifest).
Its rendered site surfaces live on [kailash.site](https://kailash.site).

The roadmap board
([org project 1](https://github.com/orgs/kailash-os/projects/1)) carries issue
`KA-NN` items. [Issue #61](https://github.com/kailash-os/kailash-os/issues/61)
is the canon map. Every new roadmap item adds a row to its dependency graph
and sprint decomposition register.

## Project overview

Kailash OS is a NixOS-based Linux distribution for AI security. It carries
offensive tooling (ATTACK), defensive tooling (DEFENCE), classic security
tooling (CLASSIC) and the AI-security platform stack (OPS). All layers live
in one declaratively built environment.

The taxonomy is CORE plus four layers and 31 categories. The taxonomy is
**versioned data**, not prose: every later artifact (modules, profiles, menu,
CLI, docs, site) generates from the manifest in
[`kailash-packages`](https://github.com/kailash-os/kailash-packages).

The delivery unit is the ("leaf PR"): an **hour-scale slice** with a
watchable RED→GREEN commit pair. The `KA-XXn` children map the
specification's design sections to runnable artefacts. Add each new roadmap
item as a row in the sprint register on issue #61.

Other documents:

- [`README.md`](README.md): status, badges, layout.
- [`CONTRIBUTING.md`](CONTRIBUTING.md): the working agreement.
- [`SECURITY.md`](SECURITY.md): vulnerability reporting policy. See [Security](#security).
- [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md): known environment issues and cures.
- The companion repo [`kailash-packages`](https://github.com/kailash-os/kailash-packages):
  the overlay flake with pinned sources and package derivations. It carries
  the manifest (`categories.yaml`, `tools.yaml`). The manifest is the
  taxonomy's single home.

## Repository structure

| Directory | Purpose |
| --- | --- |
| `flake.nix` | Root flake. Pins all inputs, including `kailash-packages` (its `flake.lock` pin resolves against the real overlay). Sets the unfree posture explicitly. Carries no global CUDA |
| `profiles/` | Composable system profiles. `minimal.nix` is the CORE substrate with zero categories enabled. Further profiles layer categories on |
| `modules/base/` | The CORE substrate every profile evaluates through |
| `modules/classic/` | Layer CLASSIC module surfaces (C-1…C-10) |
| `modules/attack/` | Layer ATTACK module surfaces (A-1…A-8) |
| `modules/defence/` | Layer DEFENCE module surfaces (D-1…D-7) |
| `modules/ops/` | Layer OPS module surfaces (O-1…O-7) |
| `cli/` | The `kailash` CLI. Category surfaces are manifest-driven |
| `menu/` | Desktop menu generation |
| `images/` | NixOS image/ISO outputs |
| `packages/` | Per-category package groupings surfaced to profiles |
| `docs/` | Project documentation |

## The layer model and the manifest (single home rule)

The taxonomy lives in `kailash-packages/manifest/`. `categories.yaml` carries
the census categories: 31 shippable + 1 data-pack. `tools.yaml` carries the
tool inventory. The layer model is [the spec's §2.6 post-purge
census](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md#26-the-full-category-table-post-purge-census).
The census figures live in that spec table. Read the figures there; never
restate them. The purge basis:
[kailash-os#210](https://github.com/kailash-os/kailash-os/issues/210), 2026-10-14. The purged rows
claimed upstreams that did not exist. The C-7 SDR pack is the data-pack census
category. Default profiles and images exclude it.

**A fact has exactly one home.** Layer, category and tool facts live in the
manifest. Never duplicate them into modules, READMEs or site copy. Generated
artifacts regenerate from the manifest.

The [spec
§2.7](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md#27-deliberate-exclusions)
records the deliberate exclusions. The excluded classes: no hardware/RF/wifi
tools, no paid-licence tools, no unmaintained or cloud-only tools. These
exclusions are the ("no-resurrection guard"). Do not reintroduce purged
tooling. The manifest validator refuses it.

ATLAS tactic mappings (ATTACK layer) are manifest fields with real
identifiers. ASVS, AISVS, MLSVS and OWASP-LLM mappings (DEFENCE layer) are
manifest fields with real identifiers. Verify each mapping against the public
MITRE ATLAS dataset first. Never invent a technique id.

## Testing

The repo follows the
[hypothesis-first TDD standard](https://github.com/kailash-os/kailash-os/issues/51):
**spec (from the issue's plan reference) → RED (watched, committed) → GREEN →
PR**. The spec is
[`docs/spec.md`](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md).
A failing test must exist, visibly, before the implementation lands. The
watched-RED discipline keeps every GREEN commit honest.

The engineering standard also orders
[harness-before-capability](https://github.com/kailash-os/kailash-os/issues/119).
The check that gates a behaviour ships in the same PR as the behaviour. CI
proves every new gate's negative case.

### Layer map

| Test target | Home | Do NOT put it in |
| --- | --- | --- |
| Manifest/taxonomy data invariants | the packages repo validator (`tests/validate_manifest.py`) + its checks | prose or per-module assertions |
| Nix module option behaviour | the checks/eval assertions in the same flake | shell scripts |
| Profile composition | `nix flake check` + the profile's eval assertion | manual rebuilds only |
| VM/image behaviour | a recorded run in the issue or PR | unit tests |

### Decision procedure

1. **Data invariant or category/tool fact?** Fix the manifest in the packages
   repo. Extend the validator, never ad-hoc scripts.
2. **Option/behaviour assertion?** Add a row (or eval check) to the owning
   flake or module checks.
3. **Neither?** Write a test function. Add a one-line comment that records why
   it is not a row. No reason means it is a row.

### Instructions specific to coding agents

- **Watched RED is mandatory in the commit history.** The RED commit body
  carries the failing test's output. GREEN follows. A squash without watched
  RED blocks review.
- **Run what CI runs** before opening a PR: `nix flake check` and the repo's
  workflows.
- **No invented transcripts.** A README, PR or issue claim about build or VM
  behaviour cites a real run. The citation carries the output verbatim, plus
  the issue or PR where the run lives. A claim without a traceable run gets a
  PENDING marker and its owning issue. Never approximate the evidence.

## Signing

**Everything is GPG-signed, always.** Commits and tags stay GPG-signed
(`git config commit.gpgsign true`). PR CI enforces `required_signatures`.
An unsigned or badly-attributed commit blocks the PR. The signing key and the
commit email must match a GitHub-verified identity. A mismatch fails
verification with `bad_email`, and the PR cannot merge.

The default branch here is **`master`**. The packages and website repos use
`main`.

## Architecture Decision Records

Structural changes carry an ADR in the same PR. Most slices are leaf-sized:
the issue's plan reference IS the design record, so no ADR is needed. Write
an ADR in these cases only. The change introduces a new persistent artifact:
a manifest schema field whose semantics lock, a profile contract, a wire
format, a gate script. Or the change removes or alters one.

The record lives in [`docs/adr/`](docs/adr/).
[`0000-architecture-decision-records.md`](docs/adr/0000-architecture-decision-records.md)
explains the process.
[`0001-record-format.md`](docs/adr/0001-record-format.md) fixes the format.
The format is NNNN-short-slug.md, numbered sequentially, one decision per
file. The hard rules:

- **Accepted ADRs are immutable.** A change that contradicts an accepted ADR
  supersedes it with a new one. Never rewrite the accepted record.
- **Never invent discussion, deciders or quotes.** Cite commit/issue
  permalinks, or write "No substantive technical discussion recorded".
- Dependency bumps, docs and CI tweaks don't need ADRs.

## Pull requests

Follow [`CONTRIBUTING.md`](CONTRIBUTING.md). Treat the PR checklist as a
contract.

### Before opening

- Work happens on a leaf branch cut from **current `origin/master`**. Never
  stack on another branch. The base must be the integration branch, or the
  squash misses its target: verify the content lands on the branch the squash
  merges to.
- **One logical change per PR.** No drive-by refactors, formatting or
  dependency bumps.
- TDD: watched RED lands before GREEN in the history (see [Testing](#testing)).
- All commits stay GPG-signed with a GitHub-verified identity (see
  [Signing](#signing)).

### Title and description

- Titles follow Conventional Commits. Roadmap slices carry the task id in the
  subject: `type(scope): KA-XXn — summary`. Example:
  `feat(safety): KA-18.1 — safety-defaults.nix + lab-mode gate`. The PR body
  links the child issue (`Closes #NN`) and notes the parent gate stays open.
  A CI title gate checks the form. Issue titles are a separate surface:
  `KA-XXn — summary` sits in the TITLE, not in a label (issue identity — see
  [Labels](#labels)).
- The description states **what** changed, **why** (issue), and **how
  verified**. The verification carries watched RED output, GREEN output and
  any run evidence. Reviewers must not need the diff to know what changed.

### Commits

- Keep commits small and self-contained. Subjects follow the
  `type(scope): subject` form. No stray scratch files. Delete probe files and
  temp scripts before commit, never gitignore them.

## Labels

| Label | Meaning |
| --- | --- |
| `KA-XXn — <summary>` (issue titles carry it in the title, not a label; PR titles carry it in the conventional subject) | issue/PR identity |
| `area:ci\|cli\|docs\|github\|images\|layer-attack\|layer-classic\|layer-defence\|layer-ops\|manifest\|menu\|nix\|packaging\|repo\|safety\|taxonomy\|testing\|website` | component (the current catalog) |
| `type:task` | a leaf-sized roadmap slice (RED→GREEN→merge) — the only `type:*` label in the catalog today |
| `target:v0.1\|v0.2\|backlog` | milestone |
| `s:xs\|s:s\|s:m\|s:l` | sprint effort (about one hour = `s:xs`/`s:s`) |
| `bug`, `documentation`, `ci` | maintenance |

Board status (`Todo` / `In Progress` / `Done`) is an org-project **field**,
not a label. Labels never encode progress. Agents applying labels mirror the
area from the directory that receives the change. Agents never invent new
`area:*` or `type:*` names: the label catalog is the vocabulary. A catalog
growth (a new `area:*` or shape label) is a deliberate catalog change, not
agent improvisation.

## Security

### Vulnerabilities

**Never open a public issue or PR describing an exploitable bug.** Report
through the GitHub security advisory link
([new advisory](https://github.com/kailash-os/kailash-os/security/advisories/new));
see [`SECURITY.md`](SECURITY.md).

### Secure defaults

- The distribution packages **offensive tooling**. The safety posture is
  deliberate and testable. Dangerous capability (`safety:exp` tooling) sits
  behind the lab-mode gate. The gate is the `kailash.labMode` double-key gate
  in the safety-defaults module. A PR that adds exp-class capability without
  the gating wiring is wrong by construction, not a review preference.
- Services the operator did not explicitly enable must not listen on any
  interface. The no-auto-start audit is a standing check.
- Supply chain: inputs stay pinned. The committed `flake.lock`, the nvfetcher
  pins and the committed `_sources` in the packages repo carry the pins.
  Floating refs and unhashed fetches block review.
- Unfree licensing stays explicit at the flake level. Never widen the posture
  for convenience. Record the licence in the manifest instead.
- Secrets never enter the tree. Secret hygiene is declarative (age/sops),
  never ad-hoc files.
- Treat manifest content as a supply-chain artifact. A tool's source URL and
  pin are attacker-relevant data. Validate every change to them.

### Code style and conventions

- Nix uses the flake-parts module layout with typed options. Each module file
  carries one concern. No `with lib;` in shared modules. `nix fmt` output
  stays clean.
- Python tooling (the validator) stays stdlib-first. A new dependency needs a
  justification in the PR body.
- Generated artifacts (`flake.lock`, nvfetcher `_sources/`) stay committed.
  Document the regeneration commands next to the artifact.
- Package comments carry the package design claim. The claim names what the
  package is, which manifest categories it serves, and the slice boundary.
