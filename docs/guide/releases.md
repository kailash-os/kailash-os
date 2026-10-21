# Update cadence & release versioning

This record states how Kailash updates sources, locks, and releases. It
states how a release gets its version number. Companion record: the Renovate
configuration in this repo and in
[`kailash-packages`](https://github.com/kailash-os/kailash-packages/blob/main/renovate.json)
(cadence roadmap child KA-16.1; this document is KA-16.2, recorded as
[kailash-packages#134](https://github.com/kailash-os/kailash-packages/issues/134)).
The release-naming amendment
[kailash-os#142](https://github.com/kailash-os/kailash-os/issues/142)
renamed this document and extended it.

## Never on its own: a Kailash install does not update nix

The OS never updates nix, nixpkgs, or any tool in the background. Nothing
re-links, re-installs, or re-downloads unprompted. The nixpkgs lock in
`flake.lock` stays put between scheduled refreshes. Tools pinned inside the
lock do not move. The distro is versioned by the lock. A user's system moves
forward in exactly two ways:

- `nixos-rebuild switch` against a newer lock, at the user's own
  cadence, or
- an upgrade to a newer release of Kailash.

This is the anti-churn posture: **the lockfile is the version.** Rolling
changes merge to `main` between releases when required. A user who pinned
last month's lock rebuilds it reproducibly; the user pulls a newer lock
deliberately.

## Source pins update by class, on explicit cadences

Every bespoke tool's upstream source is pinned in the packages repo
(`nvfetcher/config.toml` + committed `_sources/`). Pins are contract: they
change only with the manifest entry they belong to. A pin never changes by
hand in `_sources`. Each pin carries an update class. The class drives the
machine-driven check cadence:

| Class | Upstream behaviour | Check cadence | Ship rule |
| --- | --- | --- | --- |
| fast-moving | moves weekly (LLM red-team scanners, discovery tooling) | weekly, Monday scheduled dry-run | PR only when the new rev passes its smoke check |
| steady | moves fortnightly (scanner/packaging utilities) | fortnightly, same dry-run shape | PR only when the new rev passes its smoke check |
| slow / locked | nixpkgs-native or pinned big frameworks | ride the nixpkgs refresh only | no dedicated cadence |

The class is recorded with the pin (`nvfetcher/config.toml`) and shown
per tool in the manifest. No pin floats: research-grade tools pin to commit
revs. Every `_sources` entry is committed with its SRI hash.

## Flake inputs: monthly, scheduled, PR-gated

| Input | Cadence | Gate |
| --- | --- | --- |
| nixpkgs (`nixos-unstable` lock) | monthly, scheduled the first Monday of the month | PR, green checks + one approval |
| other flake inputs (flake-parts, disko, nixos-generators, sops-nix, home-manager, …) | monthly, batched into the same PR as nixpkgs where practical | same |
| `kailash-packages` pinned in this repo | on the packages repo's tagged releases, not continuously | lock-bump PR |

Automerge is deliberately off everywhere. Renovate opens PRs. CI gates them.
A human approves. Lockfile maintenance runs on a scheduled window and lands
as its own PR. The monthly refresh review stays readable. Configuration
lives in each repo's `renovate.json`.

## Release cadence: every 6 weeks

Tagged releases run on a six-week cycle (the Kali cadence, deliberately
behind upstream head). The release PR **is** the release review. One
lock-bump PR carries the evaluated image sizes and the golden-image diff
against the previous release. A release gives the artefact matrix and a
signed changelog generated from the lock delta. Between releases, `main`
moves freely. The six-week cycle alone moves a user's lock.

## Version scheme: `YYYY.NN` (release index within the year)

**versionScheme: `2026.xx`.** The version number is a calendar year plus a
release **index** within that year. The index names the year's release
train, not the month of the year. The first train of 2026 is `2026.01`. The
second is `2026.02`, and so on. A year holds from 8 to 10 releases at the
six-week cadence. Month-numbering would break (`2026.13`). Release-index
numbering never collides and sorts forever. The year prefix answers "how
old is this install?" directly.

- **YYYY** — the year the train belongs to. It encodes which lock state
  the release is.
- **NN** — the release index within the year, not the month of the
  year.
- The tag names the train; the release date names the calendar day.
  `2026.02` may ship in January 2027 and still read `2026.02` — train
  identity, not date.

Worked example:

| Event | Version |
| --- | --- |
| the year's first release train stages its first cut | `2026.01-alpha.1` |
| the same train ships general availability | `2026.01` |
| a shipped GA artefact changes before the next train | `2026.01.1` |
| the next train stages, in the same year | `2026.02-alpha.1` → `2026.02` |
| the year rolls: the first cut of the new calendar year | `2027.01-alpha.1` |

No stable API exists to number. The scheme answers "how fresh is this
system" directly. Two machines with the same version agree on the lock.

## The release ladder: staged cut → GA → material re-cut

Within one scheme family, a release's tags move through three stages. The
ladder is per-year: `2027.01-alpha.1` is 2027's first staging; the year's
GA is `2027.01`.

| Stage | Tag form | Meaning | Example |
| --- | --- | --- | --- |
| Staged development cut | `2026.xx-<stage>.<n>` | pre-GA milestones off the main track; the tag carries stage + increment so the staged-ness is visible in `git tag -v` output | `2026.01-alpha.1`, `2026.01-rc.1` |
| GA | `2026.01` | the general-availability release for the train, full artefact matrix + review posture | `2026.01` — kept as the reserved name, **not used until GA** |
| Material re-cut of a shipped GA | `2026.01.1` | only if a shipped GA artefact actually changes | `2026.01.1` |

**The two pre-GA stages differ by commitment, not by form.**
An `alpha.N` cut iterates freely. The reduced
[§7.9 artefact set](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md#79-what-a-full-release-looks-like-the-artefact-manifest)
may ship with documented gaps. Attestation and build coverage stay punctual.
An `rc.1` cut is the **GA-readiness gate**. The standing release checklist
([`release-checklist.md`](release-checklist.md), tracked per cut from
the `release-cut` issue template) is filled in FULL. Every gate box is
ticked. The train's backlog disposition is recorded: ride with evidence,
or re-scope explicitly to `2026.02`/backlog. The artefact matrix is
complete at the tag, and SHA256SUMS covers every artefact. An rc increments
only on material changes. GA follows an rc, except the bare tag itself. A
material change in between makes `rc.2` first.

Rules:

- **Reserved bare tag.** A bare `2026.xx` reads as general availability, so
  the bare form is reserved. No `2026.01` tag lands until GA carries its
  full artefact matrix + review posture. Staging names never consume a GA
  name.
- **Re-cut rule.** A material re-cut of a shipped GA posts `2026.xx.1`
  only if a shipped artefact changed. Changelog-notes-only re-cuts keep the
  tag.
- **No gaps, no renames.** An RC that slips renumbers nothing. The index is
  the train's identity, not the ship date.
- **CHANGELOG groups by train** (`## 2026.01 — <date>`), per the six-week
  release cadence above.

## Branch policy

Never commit `main` or `master` directly. Rulesets enforce this on both
repos. All work lands as a leaf branch cut from the current integration
branch. Commits stay conventional and signed, then the PR runs with green
checks and one approval. Renovate PRs follow the same gate: green checks
plus one approval. Bot-authored changes get no exception.
