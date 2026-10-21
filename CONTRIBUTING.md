# Contributing

Contributions are welcome. This document is the working agreement. It states
how changes move: proposal, review, merge. It also states what the
continuous-integration gates enforce.

## Ground rules

1. **Never commit to `master`.** All work happens on a branch. One branch
   carries one change. A pull request merges the branch. Branch names follow
   `<type>/<short-description>` with kebab-case — e.g. `feat/taxonomy-layer`,
   `fix/flake-eval`, `docs/module-page`.
2. **Conventional Commits.** Every commit subject follows
   the [specification](https://www.conventionalcommits.org/en/v1.0.0). The
   form: `type(scope): subject`.
   - Types: `feat`, `fix`, `docs`, `refactor`, `test`, `build`, `ci`, `chore`,
     `perf`, `revert`.
   - `scope` is a component. The components:
     - `nix` (flake/module), `taxonomy` (the four-layer category tree),
       `manifest` (tool entries, packaging), `cli` (kailash command surface).
     - `menu` (menu definitions), `safety` (lab-mode and gating), `docs`, `ci`.
   - Subject: imperative, lowercase, no trailing period. The body (optional)
     records the change and the reason. Wrap the body at 72 columns.
   - PR titles follow the same form. Roadmap-slice PRs carry the id in the
     subject — `type(scope): KA-XX — subject`. Squash merges use the PR title
     as the commit subject (`squash_merge_commit_title: COMMIT_OR_PR_TITLE`).
     The PR title is then the commit record. A CI gate checks the form on
     every PR. Bot and dependency PRs keep their canonical titles: renovate,
     pre-commit.ci autoupdate.
3. **Sign everything.** Commits must be GPG- or SSH-signed. The global
   setting: `git config --global commit.gpgsign true`. Releases carry signed
   tags. The project does not merge unsigned commits. It does not publish
   unsigned tags. Check signatures with `git log --show-signature` /
   `git tag -v`.
4. **One logical change per PR.** Small, reviewable diffs merge faster.
5. **Pre-commit runs locally.** Install the hooks once per clone:
   `pre-commit install && pre-commit install --hook-type pre-push`. Every
   `git commit` and `git push` then runs the hook set that CI runs. Bypass
   with `--no-verify` only for the rare legitimate exception.

## Security-sensitive changes

Changes that touch the tool manifest, the safety gating, or the packaging
harness need extra care. [SECURITY.md](SECURITY.md) holds the full posture:

- **Vulnerabilities are not issues.** Follow [SECURITY.md](SECURITY.md). Never
  open a public issue for an unreported vulnerability.
- **Offensive tooling entries** (`area:layer-attack`) must carry their safety
  level in the manifest entry. An active-exploit tool sits behind a double
  gate: explicit host opt-in + explicit shell opt-in (`KAILASH_LAB_MODE`
  defaults off). Review rejects a manifest change that adds an active-exploit
  entry without the declared gate.
- **Taxonomy integrity:** the categories and their ATLAS/OWASP mappings are
  part of the distribution's contract. A re-ordering or a removal states its
  impact in the PR body.
- **Nix-side entrypoints:** keep the module code reproducible under eval.
  Every runtime dependency belongs in the flake. The lockfile pins it.

## The acceptance suite

```
nix flake check --all-systems --no-build   # (KA-15) everything evaluates
nix develop -c pre-commit run --all-files  # the hook set CI runs
```

`nix flake check --all-systems --no-build` evaluates everything. The check
covers both declared systems. The `build` workflow runs the manifest→matrix build
legs. Since KA-15 the per-package matrix is live. The Cachix cache fronts the
builds. The hook set runs on every PR: trailing whitespace, YAML/JSON validity,
large-file guards, `detect-private-key`, shellcheck on shell scripts.

## CI on every pull request

| Check | What it does |
|---|---|
| `flake-check` | `nix flake check --all-systems` on hosted runners |
| `build` | the manifest→matrix build gate (KA-15) |
| Dependency Review | flags vulnerable or licence-incompatible dependency changes |
| OpenSSF Scorecard | publishes the security-posture score |
| `PR title — Conventional Commits + KA id` | PR title checked against the Conventional Commits form |

## Commits and pull requests

- Cut the branch from current `master`. Push it. Open a PR against `master`.
  The PR description states the change and the reason.
- Link the `KA-XX` issue that the change implements. The project board is
  [kailash Roadmap](https://github.com/orgs/kailash-os/projects/1).
- Releases carry signed tags (example: `git tag -s 2026.01-alpha.1`). The
  release-naming ladder lives on
  [`docs/guide/releases.md`](docs/guide/releases.md): the `YYYY.NN` release
  index, alpha/rc staging, and the bare `2026.01` tag reserved for GA. The
  project does not publish unsigned tags. The v-series (`v0.1.0`) is retired
  ([kailash-os#142](https://github.com/kailash-os/kailash-os/issues/142)).

## Reporting bugs

Open a [GitHub issue](https://github.com/kailash-os/kailash-os/issues/new).
The issue reports the flake revision (or the release tag, once releases
start). It also names the category/manifest surface, the host OS, and the
relevant error excerpt. Security issues never go here. Use
[SECURITY.md](SECURITY.md) instead.

## Licence

The project carries the **BSD-3-Clause** licence — see [LICENSE](LICENSE).
By opening a pull request, the contributor accepts the project's
**BSD-3-Clause** terms for the contributed work.

## Engineering standard: hypothesis-first TDD

Every feature, fix, and refactor follows **hypothesis → failing test →
minimal implementation → refactor**. The scope clauses:
[kailash-os#119](https://github.com/kailash-os/kailash-os/issues/119). The
standing spec:
[kailash-os#51](https://github.com/kailash-os/kailash-os/issues/51).

1. State the hypothesis in the issue: expected behaviour, assumed mechanism,
   falsifying observation.
2. **Commit the failing test first** on the feature branch. Run it. Paste the
   RED run's failure line into the PR.
3. Implement the minimum that passes the test. Then pass the full suite. Then
   refactor with the tests green.
4. The suite covers the edge and error paths before close: overflow, malformed
   input, failure modes.

Unit tests cannot reach some surfaces: kernel-attached code, live-cluster
behaviour. On those surfaces the issue's acceptance criterion **is** the test.
Record the EXPECTED-FAIL run before the build. Re-run it green after. The
discipline is the same. The harness differs.

**Harness before capability.** The check gates the behaviour and ships in the
same PR. Nothing merges ahead of the check that catches its regression. A new
gate surface proves the negative case in CI: the gate fails on defective
input. The proof never sits in prose alone. In roadmap terms: spec → test
(RED) → feature (GREEN) → build (CI proves it on the runner).

**GitHub Actions is the authoritative check and build surface.** The
acceptance suite runs on hosted ubuntu runners: `nix flake check
--all-systems`, derivation checks, VM tests. Contributor machines run the same
suite for development only. They never carry merge evidence. Self-hosted
runners enter only for the disk-bound image builds (the KA-15 arrangement).
A check that runs in both places defaults to Actions.

Exceptions need the user's explicit go-ahead in the issue. The work starts
only after the go-ahead.

## Packaging gates (stub — filled by KA-01.1 follow-ons)

Work that lands in `pkgs/` of the packages overlay must satisfy the gates
below. The same rule covers work that references bespoke derivations. The
manifest (`manifest/tools.yaml`, kailash-packages) is the only hand-maintained
registry. The manifest lists every packaged item.

- Packaging follows the three populations: nixpkgs-native pin, stale-override,
  bespoke derivation. The manifest entry records the population.
- Bespoke derivations build clean under `nix build`. The package carries the
  import and smoke checks that fit it. Test gates live beside the code.
- `nvfetcher/_sources/` stays committed. Pinned sources never move silently.

## Safety policy (stub — expanded by KA-18)

Offensive tooling exists for authorised security work only. The authorised
work: engagements with written authorisation, academic research, and defender
validation of one's own systems. The AU framing is law: Cyber Security Act
2024 (Cth); Criminal Code Act 1995 (Cth) Div 474. Tools tagged `exp` in the
manifest are lab-gated. They refuse to run without lab mode. Lab mode needs
explicit opt-in at both levels: the host (profile) and the shell
(environment). No D-layer service auto-starts. Enabling a lab-posture service
is a deliberate act.
