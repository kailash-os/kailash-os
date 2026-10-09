# Contributing

Contributions are welcome. This document defines the working agreement: how
changes are proposed, reviewed, and merged, and what the continuous-integration
gates enforce.

## Ground rules

1. **Never commit to `master`.** All work happens on a branch, one change per
   branch, merged via pull request. Branch names follow
   `<type>/<short-description>` with kebab-case — e.g. `feat/taxonomy-layer`,
   `fix/flake-eval`, `docs/module-page`.
2. **Conventional Commits.** Every commit message follows
   the [specification](https://www.conventionalcommits.org/en/v1.0.0):
   `type(scope): subject`.
   - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, `chore`.
   - `scope` is a component: `nix` (flake/module), `taxonomy` (the four-layer
     category tree), `manifest` (tool entries, packaging), `cli` (kailash
     command surface), `menu` (menu definitions), `safety` (lab-mode and
     gating), `docs`, `ci`.
   - Subject: imperative, lowercase, no trailing period. Body (optional):
     what changed and why; wrap at 72 columns.
3. **Sign everything.** Commits must be GPG- or SSH-signed
   (`git config --global commit.gpgsign true`); releases are
   signed tags — unsigned commits and unsigned tags are
   not merged/published. Verify with `git log --show-signature` / `git tag -v`.
4. **One logical change per PR.** Small, reviewable diffs merge faster.
5. **Pre-commit runs locally.** Install the hooks once per clone —
   `pre-commit install && pre-commit install --hook-type pre-push` —
   then every `git commit` and `git push` runs the same hook set CI runs
   (bypass with `--no-verify` for the rare legitimate exception).

## Security-sensitive changes

Anything touching the tool manifest, the safety gating, or the packaging
harness warrants extra care (see [SECURITY.md](SECURITY.md) for the full
posture):

- **Vulnerabilities are not issues.** Follow [SECURITY.md](SECURITY.md) — never
  open a public issue for an unreported vulnerability.
- **Offensive tooling entries** (`area:layer-attack`) must carry their safety
  level in the manifest entry: tools whose safety level is active-exploit are
  double-gated behind explicit host and shell opt-in (`KAILASH_LAB_MODE`
  defaults off). A manifest change that new-tools an active-exploit entry
  without the gate declared is rejected in review.
- **Taxonomy integrity:** categories and their ATLAS/OWASP mappings are part
  of the distribution's contract — re-orderings or removals state their
  impact in the PR body.
- **Nix-side entrypoints:** keep module code evalu-reproducible — every
  runtime dependency belongs in the flake, pinned by the lockfile.

## The acceptance suite

```
nix flake check --all-systems --no-build   # (KA-15) everything evaluates
nix develop -c pre-commit run --all-files  # the hook set CI runs
```

`nix flake check` becomes the full gate when the root flake lands (KA-01) and
replaces the scaffold gate in KA-15; until then CI verifies the repository
carries its planned layout. The hook set (trailing whitespace, YAML/JSON
validity, large-file guards, `detect-private-key`, shellcheck on shell
scripts) runs on every PR.

## CI on every pull request

| Check | What it does |
|---|---|
| `flake-check` | layout-scaffold gate now; `nix flake check` from KA-15 |
| Dependency Review | flags vulnerable or licence-incompatible dependency changes |
| OpenSSF Scorecard | publishes the security-posture score |

## Commits and pull requests

- Push your branch and open a PR against `master`; describe the what and the why.
- Link the `KA-XX` issue the change implements; the project board
  is [kailash Roadmap](https://github.com/orgs/kailash-os/projects/1).
- Releases are signed tags (`git tag -s vX.Y.Z`); unsigned tags are not published.

## Reporting bugs

Open a [GitHub issue](https://github.com/kailash-os/kailash-os/issues/new) with
the flake revision (or the release tag once releases start), the category/manifest
surface you hit, host OS, and the relevant error excerpt. Security issues never
go here — [SECURITY.md](SECURITY.md) instead.

## Licence

The project is licensed under **BSD-3-Clause** — see [LICENSE](LICENSE).
Contributions are made under **BSD-3-Clause**: by submitting a pull request you
agree your work is licensed under the project's BSD-3-Clause terms.

## Engineering standard: hypothesis-first TDD

Every feature, fix and refactor follows **hypothesis → failing test → minimal implementation → refactor** (see #51 / #51 for the standing spec):

1. State the hypothesis in the issue: expected behaviour, assumed mechanism, falsifying observation.
2. **Commit the failing test first** on the feature branch; run it and paste the RED run's failure line into the PR.
3. Implement the minimum that passes; then the suite; then refactor with tests green.
4. Edge/error paths (overflow, malformed input, failure modes) are covered before close.

Where unit tests cannot reach — kernel-attached code, live-cluster behaviour — the issue's acceptance criterion **is** the test: record the EXPECTED-FAIL run before building, re-run green after. Same discipline, different harness.

Exceptions require the user's explicit go-ahead in the issue before work starts.

## Packaging gates (stub — filled by KA-01.1 follow-ons)

Work that lands in `pkgs/` of the packages overlay or references bespoke
derivations is expected to satisfy the gates below; the manifest
(`manifest/tools.yaml`, kailash-packages) is the only hand-maintained
registry, and anything packaged must be manifest-listed.

- Packaging follows the three populations (nixpkgs-native pin /
  stale-override / bespoke derivation) with the population recorded in the
  manifest entry.
- Bespoke derivations build clean under `nix build`, with import/smoke
  checks appropriate to the package; test gates live beside the code.
- `nvfetcher/_sources/` is committed; pinned sources never silently move.

## Safety policy (stub — expanded by KA-18)

Offensive tooling exists for authorised security work only: engagements
with written authorisation, academic research, and defender validation of
one's own systems (AU framing: Cyber Security Act 2024 (Cth); Criminal
Code Act 1995 (Cth) Div 474). Tools tagged `exp` in the manifest are
lab-gated — they refuse to run unless lab mode is explicitly enabled at
both the host (profile) and shell (environment) level. No D-layer service
auto-starts; enabling a lab-posture service is a deliberate act.
