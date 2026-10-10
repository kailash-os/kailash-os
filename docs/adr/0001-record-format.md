# 0001 — ADR record format

Status: accepted

## Context

ADRs need a stable shape so readers can compare decisions and tools can
index them. The format below is the repo's standard record layout.

## Decision

Each ADR is `docs/adr/NNNN-short-slug.md`, numbered sequentially (the
next unused number; numbers are never recycled). File layout:

```markdown
# NNNN — Title (imperative phrase: the thing decided)

Status: accepted | superseded by NNNN | amended by NNNN

## Context

The forces at play: the problem, constraints, and the options
considered. Facts only, cite issue/commit permalinks.

## Decision

The chosen option, stated as a decision. One paragraph.

## Consequences

What becomes easier, what becomes harder, what is now
irreversible. Explicitly note anything deferred.
```

- Markdown, one decision per file, English, no `TODO` placeholders —
  an ADR is written only when it is ready to be accepted.
- The index (`0000`) gains one row per ADR at merge time.

## Consequences

Anyone reconstructing the architecture's history reads decisions in
number order; superseded ADRs stay in place, and every contradiction
between two accepted records resolves by reading the newer one.
