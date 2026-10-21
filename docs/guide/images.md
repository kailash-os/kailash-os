# Images: the build matrix, download surfaces and verification

This page states the shipping images of Kailash OS: the ratified matrix, the
per-target size budgets, the download surface of each artefact per release,
and the verify steps for each download. Policy companions: the release/versioning
record ([`releases.md`](releases.md)) and the shape decision
([kailash-os#132](https://github.com/kailash-os/kailash-os/issues/132)).

## The matrix

One source, two formats: each profile evaluates once and emits BOTH the
QEMU disk image (the PRIMARY deliverable shape) and the bootable ISO
(the SECONDARY shape) —
[`images/kailash-images-table.nix`](../../images/kailash-images-table.nix)
is the single declaration; every flake attr, budget, CI leg and release
asset name derives from it. The budgets are enforced by construction:
the rows with the largest closures (texlive, gnuradio, SDR/wordlist packs)
never enter a default image. They ship only through opt-in
`kailash-data.*` derivations, asserted per target by the census/budget
check legs.

| Ref (`nix build .#<ref>`) | Profile | Format | System | Budget | Built by |
| --- | --- | --- | --- | --- | --- |
| `kailash-images-qemu-minimal` | minimal | qcow2 | x86_64 | ≤4 GB | hosted |
| `kailash-images-iso-minimal` | minimal | ISO | x86_64 | ≤4 GB | hosted |
| `kailash-images-qemu-redteam-ai` | redteam-ai | qcow2 | x86_64 | ≤8 GB | hosted |
| `kailash-images-iso-redteam-ai` | redteam-ai | ISO | x86_64 | ≤8 GB | hosted |
| `kailash-images-qemu-full` | full | qcow2 | x86_64 | ≤10 GB | hosted |
| `kailash-images-iso-full` | full | ISO | x86_64 | ≤10 GB | hosted |
| `kailash-images-qemu-headless-agent` | headless-agent | qcow2 | x86_64 | ≤1.5 GB | hosted |
| `kailash-images-iso-headless-agent` | headless-agent | ISO | x86_64 | ≤1.5 GB | hosted |
| `kailash-images-qemu-aarch64-minimal` | minimal | qcow2 | aarch64 | ≤4 GB | arm-local |
| `kailash-images-iso-aarch64-minimal` | minimal | ISO | aarch64 | ≤4 GB | arm-local |
| `kailash-images-qemu-aarch64-headless-agent` | headless-agent | qcow2 | aarch64 | ≤1.5 GB | arm-local |
| `kailash-images-iso-aarch64-headless-agent` | headless-agent | ISO | aarch64 | ≤1.5 GB | arm-local |

Profiles: `minimal` (the CORE substrate, no categories enabled),
`redteam-ai` (the lab VM scope), `full` (the "kali-everything" live
scope), `headless-agent` (base + CLI, no desktop; the qcow2 grows at
first boot). Build surfaces: **hosted** = the
[release-images workflow](../../.github/workflows/release-images.yml)
(all eight x86_64 legs; a dispatch `targets:` input builds a stated
subset); **arm-local** = [`tools/build-arm-images.sh`](../../tools/build-arm-images.sh)
on Apple Silicon (the arch strategy: x86 hosted, arm local —
[kailash-os#198](https://github.com/kailash-os/kailash-os/issues/198)).
The aarch64 `redteam-ai` rows land with the KA-36 slice-2 sweep
([kailash-os#36](https://github.com/kailash-os/kailash-os/issues/36)).

The table carries a checker:
`images-release-completeness` (a check leg in the root flake). It fails CI
whenever a table row lacks a declared build surface in the workflow, or
the arm builder's default expansion drifts off-table. Run the same
checker locally:

```console
$ python3 tools/check-images-release-completeness.py \
    --table images/kailash-images-table.nix \
    --workflow .github/workflows/release-images.yml \
    --builder tools/build-arm-images.sh
```

## Where to download

Release artefacts attach to the tagged GitHub release
([2026.01-alpha.1](https://github.com/kailash-os/kailash-os/releases/tag/2026.01-alpha.1)
is the first). Three surfaces, per artefact:

- **Release asset** (`kailash-<tag>-<ref>.iso|.qcow2`) — artefacts under
  the legacy per-asset cap of 2 147 483 648 B.
- **Chunked release assets** — every artefact above the cap still uploads.
  The upload carries byte-exact split parts (`<…>.part-000`, each ≤1900 MiB)
  plus a per-part sheet (`SHA256SUMS-parts-<name>`), all attached to the same
  release. The split is lossless packaging: reassemble with `cat`, and the
  file is byte-identical to the attested subject.
- **Flake pull** — any artefact, any tag, from the Cachix-held closure:

  ```console
  $ nix build github:kailash-os/kailash-os/<tag>#<ref>
  ```

The release notes' artefact table states each artefact's surface for
that release. The checksum sheet `SHA256SUMS` on the release covers
every artefact (attached or chunked or flake-pulled) at WHOLE-file
digest level; the sheet is the artefact-identity authority. The per-part
sheets (`SHA256SUMS-parts-<name>`) authenticate each chunk in transit and
sit beside the whole-file sheet, never replace it. The arm builder writes
its own suffixed sheet `SHA256SUMS-aarch64-local` that concatenates into
the release sheet at attach time.

## Reassemble a chunked artefact

```console
$ sha256sum -c SHA256SUMS-parts-kailash-2026.01-alpha.1-kailash-qemu-full.qcow2
$ cat kailash-2026.01-alpha.1-kailash-qemu-full.qcow2.part-* > kailash-2026.01-alpha.1-kailash-qemu-full.qcow2
$ sha256sum -c SHA256SUMS                                   # the WHOLE-file line (the identity check)
$ gh attestation verify kailash-2026.01-alpha.1-kailash-qemu-full.qcow2 -R kailash-os/kailash-os
```

(`tools/split-release-artefact.sh verify <artefact> <dir>` drives the
whole chain; the attestation check passes against the ORIGINAL build's
records — the attested subject is the whole file, and `cat` reproduces
its exact bytes.)

## Verify the artefact

```console
$ sha256sum -c SHA256SUMS                      # digests
$ gh attestation verify kailash-<tag>-<ref>.iso -R kailash-os/kailash-os
$ git tag -v <tag>                             # the signed tag (GPG)
```

Every published artefact carries SLSA v1.0 build provenance plus an
SPDX SBOM, Sigstore-signed over the repo's OIDC identity
(the KA-48 attestation slice,
[kailash-os#171](https://github.com/kailash-os/kailash-os/issues/171)).

## Build the arm images yourself

```console
$ git checkout <tag>
$ tools/build-arm-images.sh <tag>              # all table-scoped profiles, both formats
$ tools/build-arm-images.sh <tag> minimal qemu # one target
$ tools/build-arm-images.sh <tag> all all upload   # + gh release upload (needs the uploader's PAT)
```

Output lands in `./release-arm/` with `SHA256SUMS-aarch64-local`.
The Nix distribution must run `aarch64-linux` derivations
(Apple Silicon runs them natively; see
[`TROUBLESHOOTING.md`](../../TROUBLESHOOTING.md) for environment notes).
