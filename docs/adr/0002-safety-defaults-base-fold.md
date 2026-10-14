# 0002 — Safety defaults as base-fold data gates (lab mode, no-auto-start audit, secrets hygiene)

Status: accepted

## Context

KA-18.1/KA-18.2 (os#92, os#93; [spec §9.2](https://github.com/kailash-os/kailash-os/blob/master/docs/spec.md#92-safety-defaults-module-basesafety-defaultsnix)) make the safety doctrine
executable: the double-key lab gate for `safety:exp` tooling, a standing
no-auto-start audit, and sops-nix secrets hygiene. These are distribution
posture, not per-package behaviour, and they must hold on every profile the
distribution ships — including the category-less minimal host.

## Decision

Safety posture lands as `modules/base/` modules folded into the CORE
substrate every profile imports:
`modules/base/safety-defaults.nix` (the `kailash.labMode` double-key gate
and the exp wrap surface), `modules/base/auto-start-audit.nix` (the
`kailash.audit.autoStart` finding list and its flake checks), and
`modules/base/secrets-hygiene.nix` (the sops-nix skeleton plus the
runtime-key-dir convention). The responsible-use statement is a data file
(`docs/responsible-use.md`) that profiles and gates reference — never a
service or a message that fires on boot.

## Consequences

- Every profile (minimal included) carries the gate surface, so category
  wiring (Wave-5/6) cannot ship an exp tool un-gated.
- The no-auto-start audit is enforced by hosted CI on every PR (the check
  rides `nix flake check`), with the negative case proven by a hostile
  fixture rather than asserted.
- Secrets hygiene has a concrete wiring point before the first service
  module lands; a service module that wants secrets extends
  `kailash.secrets`, never ad-hoc store paths.
- The posture file (`docs/responsible-use.md`) is the single text the MOTD,
  doctor output and site pages render from — wording changes are one-file
  changes.
