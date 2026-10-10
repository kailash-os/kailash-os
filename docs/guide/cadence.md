# Update cadence & release versioning

Policy record for how Kailash updates — sources, locks, releases — and
how a release gets its version number. Companion record: the Renovate
configuration in this repo and in
[`kailash-packages`](https://github.com/kailash-os/kailash-packages/blob/main/renovate.json)
(cadence roadmap child KA-16.1; this document is KA-16.2).

## Never on its own: a Kailash install does not update nix

The OS does not update nix, nixpkgs, or any tool in the background —
nothing re-links, re-installs, or re-downloads unprompted. The nixpkgs
lock in `flake.lock` stays put between scheduled refreshes; tools pinned
inside the lock do not move; the distro is versioned by the lock. A
user's system moves forward in exactly two ways:

- `nixos-rebuild switch` against a newer lock, at the user's own
  cadence, or
- upgrading to a newer release of Kailash.

This is the anti-churn posture: **the lockfile is the version.** Rolling
changes merge to `main` between releases when required, but a user who
pinned last month's lock keeps rebuilding it reproducibly until they
deliberately pull a newer one.

## Source pins update by class, on explicit cadences

Every bespoke tool's upstream source is pinned in the packages repo
(`nvfetcher/config.toml` + committed `_sources/`); pins are contract —
they change only with the manifest entry they belong to, never by hand
in `_sources`. Each pin carries an update class; the class drives the
machine-driven check cadence:

| Class | Upstream behaviour | Check cadence | Ship rule |
| --- | --- | --- | --- |
| fast-moving | churns weekly (LLM red-team scanners, discovery tooling) | weekly, Monday scheduled dry-run | PR only when the new rev passes its smoke check |
| steady | churns fortnightly (scanner/packaging utilities) | fortnightly, same dry-run shape | PR only when the new rev passes its smoke check |
| slow / locked | nixpkgs-native or pinned big frameworks | ride the nixpkgs refresh only | no dedicated cadence |

The class is recorded with the pin (`nvfetcher/config.toml`) and shown
per tool in the manifest. No pin floats: research-grade tools pin to
commit revs, and every `_sources` entry is committed with its SRI hash.

## Flake inputs: monthly, scheduled, PR-gated

| Input | Cadence | Gate |
| --- | --- | --- |
| nixpkgs (`nixos-unstable` lock) | monthly, scheduled the first Monday of the month | PR, green checks + one approval |
| other flake inputs (flake-parts, disko, nixos-generators, sops-nix, home-manager, …) | monthly, batched into the same PR as nixpkgs where practical | same |
| `kailash-packages` pinned in this repo | on the packages repo's tagged releases, not continuously | lock-bump PR |

Automerge is deliberately off everywhere: Renovate opens PRs, CI gates
them, and a human approves. Lockfile maintenance runs on a scheduled
window and lands as its own PR so the monthly refresh review stays
readable. Configuration lives in each repo's `renovate.json`.

## Release cadence: every 6 weeks

Tagged releases run on a six-week cycle (Kali-like, deliberately not
bleeding-edge). The release PR **is** the release review: one lock-bump
PR carrying the evaluated image sizes and the golden-image diff against
the previous release inline. Out of a release come the artefact matrix
and a signed changelog generated from the lock delta. Between releases
`main` moves freely; the six-week cycle is the only thing that moves a
user's lock.

## Version scheme: `vMAJOR.YYYYMM.<patch>`

The version number is derived from the lock, not hand-edited:

- **MAJOR** — bumps on taxonomy or content-shape changes (categories,
  safety model); it is not a marketing number.
- **YYYYMM** — the release month; it encodes which lock reality a
  release is.
- **patch** — within-month lock corrections only.

Worked example:

| Event | Version |
| --- | --- |
| November 2026 release train ships | `v1.202611.0` |
| a wrong pin is corrected before the next train | `v1.202611.1` |
| a category is added to the taxonomy (content shape changed) | `v2.202612.0` |

There are no fictional stable APIs to number: the scheme exists to
answer "how fresh is this system" at a glance and to make two machines
with the same version agree on the lock.

## Branch policy

Never commit `main` or `master` directly — on either repo, rulesets
enforce it. All work lands as a leaf branch cut from the current
integration branch, conventional signed commits, then PR with green
checks and one approval. Renovate PRs follow the same gate: checks pass
plus one approval, no exceptions for bot-authored changes.
