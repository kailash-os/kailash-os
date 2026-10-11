# 0003 — Release naming: calendar `YYYY.NN` release-index scheme with the staged → GA → re-cut ladder

Status: accepted

## Context

The distribution's release surfaces stated a semver-flavoured scheme,
`vMAJOR.YYYYMM.<patch>` (plan §8.6, then recorded in the cadence guide
and the README `versionScheme` line), while the project intends
calendar-flavoured releases — the scheme exists to answer "how fresh is
this system" and to make two machines with the same version agree on
the lock, not to number a stable API. The first release cut (#7, the
KA-46 gate) was planned as tag `v0.1.0`, which would have burned a
v-series name the scheme cannot mean.

The amendment is kailash-os#142 (KA-47 — release naming amendment:
calendar versioning replacing `vMAJOR.YYYYMM`). Decision recorded on
kailash-os#142 by the maintainer, 2026-10-11
([comment 6106595339](https://github.com/kailash-os/kailash-os/issues/142#issuecomment-6106595339)
— calendar-minor `2026.xx`;
[comment 6106617652](https://github.com/kailash-os/kailash-os/issues/142#issuecomment-6106617652)
— the three-stage ladder and the reserved bare tag;
[comment 6106634915](https://github.com/kailash-os/kailash-os/issues/142#issuecomment-6106634915)
— `NN` refined to the release index within the year, not the month,
and CHANGELOG grouping by train;
[comment 6106646381](https://github.com/kailash-os/kailash-os/issues/142#issuecomment-6106646381)
— the documentation shape). One documentation-record change rides the
same decision:
[kailash-packages#134](https://github.com/kailash-os/kailash-packages/issues/134)
(KA-16.2) is the existing record of the guide document's creation —
this ADR records its supersession (path changed, content extended,
scheme superseded). No invented quotes: read the comments for the
decision's own wording.

## Decision

Release names follow **`YYYY.NN`**, an annual release-index form:
**versionScheme: `2026.xx`** — the year of the release train plus the
train's index within the year (not the month). Tag names, CHANGELOG
headers (`## 2026.01 — <date>`), GitHub Release titles and the README
`versionScheme` line all derive from that one choice. A train's tags
climb a three-stage ladder in the same scheme family:

- staged development cut `2026.xx-<stage>.<n>` (e.g. `2026.01-alpha.1`);
  the v0.1-lane first cut (KA-46, #7) tags `2026.01-alpha.1` — no
  v-series tag ever lands;
- GA `2026.xx` — the bare calendar tag is reserved and lands only at
  general availability (full artefact matrix + review posture);
- material re-cut of a shipped GA `2026.xx.1` — only when a shipped
  artefact actually changes (changelog-notes-only re-cuts keep the
  tag).

`NN` is the release index within the year, so a calendar year holds
8–10 trains at the six-week cadence without collision; the year rolls
with the first cut of the new calendar year (`2027.01-alpha.1`) even if
the previous train gauged weeks earlier; `2026.02` may ship in January
2027 and still be `2026.02` (train identity, not date). CHANGELOG
groups by train. The user-facing policy document is
`docs/guide/releases.md` — the former `docs/guide/cadence.md`, renamed
(git mv, history preserved) and extended to cover update cadence,
version scheme and the naming ladder as one document, rendered on the
site's Build section and cited by the README `versionScheme` pointer.
The plan revision (§8.6 supersession) remains the canonical scheme
record; the guide document is its user-facing rendering.

## Consequences

- Every surface that states the scheme now states one scheme: no
  v-series or `vMAJOR.YYYYMM` name remains in README, docs, CHANGELOG
  or release titles; the first published tag is `2026.01-alpha.1`.
- The bare `2026.01` tag is burned only at GA — pre-GA releases are
  visibly staged in `git tag -v` output, and no staging name consumes a
  GA name.
- Re-cut pressure drops: notes-only re-cuts reuse the shipped tag;
  `2026.01.1` implies a material artefact change.
- The guide document has one canonical URL (`docs/guide/releases.md`);
  inbound links to the old path are replaced in-repo, and links on
  other repos' surfaces (kailash-packages, kailash-website) are swept
  there, not here.
- Deferred: the plan-master revision (§8.6 supersession) is a separate
  artefact on the parent lane, not this repository; until it renders,
  the issue comments cited above are the decision record.
