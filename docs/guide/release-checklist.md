# The release-cut checklist

The standing checklist every Kailash release fills in — alpha, rc and GA
alike. Each cut opens its tracking issue from
[`.github/ISSUE_TEMPLATE/release-cut.yaml`](../../.github/ISSUE_TEMPLATE/release-cut.yaml)
(the same checklist as fill-in checkboxes); this page is the canonical
text. The ladder this operates on:
[`releases.md`](releases.md) — staged cut (`-alpha.N`, `-rc.N`) → GA
(bare `YYYY.NN`) → material re-cut (`YYYY.NN.M`).

Fill every box in the tracking issue. A box that does not apply gets a
one-line reason, never silence. A gate box that fails stops the cut
until it passes or the maintainer explicitly re-scopes it on the issue.

## Phase 1 — Gate (before tagging)

- [ ] **Residue sweep.** Every issue carrying the train's `target:` label
      is closed or explicitly re-scoped (label moved to `2026.02`/`backlog`
      with a one-line comment naming the deferral). This is the rc gate in
      particular: leftover backlog either rides with evidence or is moved —
      it may not linger silently past an rc.
- [ ] **Both repos eval-clean.** `nix flake check --all-systems` green on
      kailash-os and kailash-packages at the proposed release candidates
      (hosted CI counts; local leg per the lane-verification rules).
- [ ] **Truthfulness.** Manifest validator output recorded
      (`nix run github:kailash-os/kailash-packages#kailash -- manifest
      validate`), census snapshot in sync (regenerate via
      `scripts/gen-image-census.sh` in the same cycle if a pin bump moved
      the closures — the images-census leg fails red otherwise), and the
      README's generated table regenerated
      (`tools/generate-readme-table.py`).
- [ ] **VM/acceptance evidence.** Profiles boot + `kailash list`
      truthfulness recorded on the cut issue; any category smoke that
      changed this train re-recorded.
- [ ] **Lock-bump release PR** (kailash-packages): the PR body IS the
      release review — evaluated sizes, the lock delta vs the previous
      release, no silent removals. Green checks + user approval per the
      standing merge policy; merged BEFORE tagging. The OS repo's lock
      bump referencing the tagged packages rev merges first.
- [ ] **Reference hygiene.** `scripts/sweep_refs.py` dry-run green (no
      bare `ko#N`-form shorthands, no wrong-kind links, no `.pdf`
      citations) over everything about to go public.
- [ ] **Signed staged tag.** `-rc.1` increments on material changes only;
      changelog-only republishes keep the tag. `git tag -v` verifies.
      Bare `YYYY.NN` stays reserved for GA.

## Phase 2 — Publish

- [ ] **Release draft.** Notes = the CHANGELOG verbatim + the recorded
      evidence (CI runs, VM smokes, validator output at the tag). The USER
      publishes — the bot never does.
- [ ] **The image matrix, at the tag.** The release-publish trigger builds
      all eight hosted legs; stragglers/over-cap surfaces built via
      `workflow_dispatch` (`targets:` input) or the arm builder. Every
      target in `images/kailash-images-table.nix` has a build record at
      the tag — the `images-release-completeness` gate proves the
      declaration; the SHA256SUMS sheet proves the artefacts.
- [ ] **SHA256SUMS covering every artefact.** The sheet's
      whole-file lines are THE artefact-identity authority. ≤2 GiB
      artefacts attach as release assets directly; over-cap artefacts go
      up CHUNKED (split parts + per-part sheets via
      `tools/split-release-artefact.sh` — lossless packaging; the
      reassembled file re-verifies against the original attestation
      records). Every artefact of the matrix lives on the release in one
      of the two forms; the 2 GiB cap is a per-FILE endpoint limit, not
      a completeness excuse.
- [ ] **Attestations recorded + verified.** Every published artefact
      carries SLSA v1.0 provenance + SPDX SBOM from the pipeline;
      `gh attestation verify <file> -R kailash-os/kailash-os` PASS
      recorded on the cut issue for the shipped set.
- [ ] **Notes' asset table states every artefact's surface** (attached /
      over-cap + flake pull), with build-run links.

## Phase 3 — Post-release

- [ ] **Verify-after-tag.** `nix flake check` green at the tag; from the
      tag, `nix build .#kailash` pulls from Cachix; the validator at the
      tag matches the notes.
- [ ] **Completion receipt** on the cut issue: what shipped, with run ids
      and verification outputs (the ko#141 / ko#200 shape).
- [ ] **Board sweep.** Closed items Status=Done, Target mirrors the
      train; new items carry the right fields.
- [ ] **CHANGELOG.md committed** with the train section
      (`## 2026.NN — <date>`); the release notes match it verbatim.
- [ ] **sweep_refs re-run** over the new public surface (notes, PRs,
      comments) and every NEW link GET-verified for kind.
- [ ] **Residue ledger.** Every deferred item from Phase 1 carries a
      labelled open issue (owner + train named) — nothing defers into a
      comment only.

## Site / docs updates that ride a train

Fill when the site work in the cycle requires it; empty is allowed with
a reason, checked is recorded:

- [ ] **Site pin-rev bump** (the `kailash-website` generated sections
      follow the README/manifest at a pinned rev — KA-33's remaining
      slice).
- [ ] **`docs/guide/images.md`** updated if the matrix, budgets or asset
      surfaces changed this cycle (the canonical images page — release
      notes link to it, never duplicate it).
- [ ] **`docs/guide/releases.md`** touched only through the ladder rules
      themselves (a naming/policy change is its own issue + PR).
- [ ] **SECURITY.md** section resyncs (the site's include-copy), when the
      attestation/policy text changed (KA-48's slice owns the first
      version).
- [ ] **The site Build page** ("what ships when") matches the shipped
      artefact set after a matrix change.

## The rc stage — what makes it different from alpha

`-alpha.N` cuts iterate freely (build records optional per leg, the
reduced [§7.9 artefact set](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md#79-what-a-full-release-looks-like-the-artefact-manifest) may ship with explicit gaps, attestations
punctual). `-rc.N` commits to GA readiness:

- The FULL checklist above is filled — no box left unticked, no box
  skipped without a recorded re-scope.
- The artefact matrix is complete at the tag (every ratified target has
  a build record; SHA256SUMS covers the whole set; surfaces stated).
- GA follows an rc with no material change except the bare tag itself —
  if a material change lands, it's `-rc.2`, not a rushed GA.
- GA itself (`2026.01` bare) keeps the full artefact matrix + review
  posture per the ladder; the checklist is filled against the GA tag
  the same way.
