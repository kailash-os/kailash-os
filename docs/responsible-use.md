# Responsible use (Kailash OS)

Kailash OS ships offensive AI-security tooling alongside defensive and
platform tooling. The distribution is built for **authorised security work
only**: red-team engagements with written authorisation, academic research,
and defender-validation exercises against systems the operator is authorised
to test.

## The operator's responsibility

Possession of a tool is not authorisation to use it. The operator is
responsible for knowing the law in their jurisdiction and for holding
authorisation before testing any system they do not own. Unauthorised access
to, or impairment of, computer systems is a criminal offence in most
jurisdictions; the provisions most relevant to a Kailash operator are named
below.

## Australia

- **Cyber Security Act 2024 (Cth)** — the current security-legislation
  environment in Australia, including the incident-reporting framework for
  critical infrastructure entities.
- **Criminal Code Act 1995 (Cth), Division 474** — the
  telecommunications-offence provisions covering unauthorised access to,
  modification of, and impairment of, restricted data and computer systems
  (sections 474.17, 474.18 and 474.19 among them).
- IRAP / Information Security Manual controls, including the AI-relevant
  guidance — the governance mapping used by Layer DEFENCE's governance pack
  (D-6).

Other jurisdictions carry their own equivalents (the US Computer Fraud and
Abuse Act, the UK Computer Misuse Act, and others). This statement names the
Australian provisions because the project's authorship is Australian; it is
not exhaustive and is not legal advice.

## How the distribution enforces it

The responsible-use statement is paired with technical gates, not prose
alone:

- **Double-key lab gate** — every tool the packages manifest tags
  `safety: exp` installs only through a gate wrapper that refuses to run
  unless BOTH the host option `kailash.labMode` is enabled AND the
  individual invocation sets `KAILASH_LAB_MODE=1`
  (plan §11.2; `modules/base/safety-defaults.nix`; the refusal text cites
  this file).
- **No auto-start** — no service in the flake auto-starts an exp-class
  tool, and no service module self-enables; every service is
  `mkEnableOption`-off by default (plan §11.2).
- **Secrets hygiene** — keys (including model API keys) live outside the
  Nix store, whose paths are world-readable; sops-nix is the declarative
  mechanism, and model API keys are read at runtime from
  `~/.config/kailash/keys/` (plan §11.2).

## Scope of the statement

This file is the data source the desktop MOTD, the `kailash doctor` output
and the site's Layer-ATTACK pages render from — the statement ships with the
distribution so the reminder travels wherever the tooling does. The
authoritative safety doctrine is the spec's §11; the tool manifest's
`safety` field is the enforcement data.
