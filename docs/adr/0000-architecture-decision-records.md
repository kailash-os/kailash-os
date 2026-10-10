# Kailash OS — Architecture Decision Records

This directory holds the distribution's Architecture Decision Records
(ADRs): short, numbered documents recording a *structural* decision —
what was decided, why, and what it supersedes.

## Index

| Number | Title | Status |
| --- | --- | --- |
| [0000](0000-architecture-decision-records.md) | Architecture decision records (this process) | accepted |
| [0001](0001-record-format.md) | ADR record format | accepted |

## When an ADR is required

Most changes are leaf-sized slices whose design record is the roadmap
issue's plan reference (`KA-XXn`); they do **not** need an ADR. Write one
only when the change **introduces a new persistent artifact** or **removes
or changes one** — a manifest schema field whose semantics lock, a profile
contract, a wire format, a gate script, or the removal/change of any of
these. Dependency bumps, documentation and CI tweaks never need an ADR.

Rules (full text in
[`0000`](0000-architecture-decision-records.md)): accepted ADRs are
immutable and get superseded, never rewritten; never invent discussion,
deciders or quotes — cite permalinks or say "No substantive technical
discussion recorded"; every ADR lands in the same PR as the change it
records.
