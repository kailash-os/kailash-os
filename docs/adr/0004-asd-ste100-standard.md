# 0004 — ASD-STE100: the org writing standard

Status: accepted

## Context

Written prose fills many surfaces in this org: the README and the docs pages, the issue and PR bodies, the site pages, and the CLI strings. The register differs between the surfaces: sentence length, tense, and person drift. A reader cannot trust one word list across the docs estate.

## Decision

The operator's directive (2026-10-20) sets the standard. Every written text in the org follows ASD-STE100 Simplified Technical English. No substantive technical discussion recorded. The record cites the wave issues it drives.

The ADR topology follow-up (the operator, 2026-10-21) keeps one canonical record per org, in the tree where the decision's authority sits. This tree carries kailash's canonical record.

The rule set:

1. One thought per sentence. A sentence carries one fact or one instruction.
2. A sentence stays at or under 20 words.
3. The voice is active. The tense is present. Instructions sit in the imperative.
4. A non-approved verb takes one fixed approved substitution (the STE100 word list).
5. One word carries one meaning, on every surface.
6. Fixed technical names stay exact: tool ids, flag names, layer names, gate names.
7. Numbers use digits, with units adjacent.
8. Rendered text carries no idioms, no slang, and no first or second person.
9. No invented facts. A claim states its basis. A measured number cites the record that measured it.
10. Historical records keep their filed tense and wording.

The scope:

- The README and the docs markdown in every org repo.
- The rendered site pages: kailash.site, docs.kailash.tools, book.kailash.tools.
- Issue and PR bodies written after this record.
- The CLI help and output strings. Such a change rides its own code lane and re-pins every recorded output line.
- Chat replies to the operator follow the same structure rules.

Enforcement:

- This repo carries kailash's canonical record. The kailash-website, the kailash-book, and the kailash-packages carry no ADR scaffolding. Each carries a one-paragraph adoption note in its README that links this record.
- Each repo carries one conversion issue. The repo's surfaces convert lane by lane. A lane's acceptance: the text passes the rule set, and the repo's hosted gates stay green.
- The generated surfaces keep their generators. A table or a page whose words come from a manifest converts at the generator, not by hand.

## Consequences

- Text written after this record follows the rule set from the merge day on.
- The standing text converts through the per-repo conversion issues: [kailash-os#216](https://github.com/kailash-os/kailash-os/issues/216), [kailash-website#46](https://github.com/kailash-os/kailash-website/issues/46), [kailash-book#25](https://github.com/kailash-os/kailash-book/issues/25), [kailash-packages#68](https://github.com/kailash-os/kailash-packages/issues/68).
- The conversion never moves a §-anchor URL, a generated block, or a signed record.
- The spec prose (`docs/spec.md`) converts as its own lane, with the anchors held.
