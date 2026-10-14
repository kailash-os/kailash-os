#!/usr/bin/env python3
"""check-images-release-completeness — the release image-matrix gap gate.

Usage:
  check-images-release-completeness.py \
      --table images/kailash-images-table.nix \
      --workflow .github/workflows/release-images.yml \
      --builder tools/build-arm-images.sh
  check-images-release-completeness.py --self-test

The ratified matrix (images/kailash-images-table.nix, KA-28 + kailash-os#132)
is 12 targets: 8 x86_64 (hosted builds, release-images.yml) + 4 aarch64
(local builds, tools/build-arm-images.sh — the kailash-os#198 arch strategy).
KA-33 slice 1 shipped a 4-leg workflow subset: the never-built trio
(qemu-minimal, qemu-headless-agent, iso-headless-agent) had NO build record
anywhere — found only by diffing the table against the release page
(kailash-os#200). This gate turns that drift into eval/CI RED:

  * every table row with no aarch64 system field must be a DECLARED
    release-images.yml matrix leg (declared = in the matrix; a dispatch
    `targets:` subset filters which legs RUN, visibly, never silently);
  * every table row WITH aarch64 must be producible by the local
    builder's default (`all`) profile x format expansion — and the
    expansion must NOT name refs outside the table (an unscoped row
    sneaking into release artefacts).

Exits 1 with the missing set named. --self-test drives the same
enforcement unit over synthetic breach + clean cases (the watched-RED
shape, mirroring tools/kailash-images-budget.py's self-test).
"""
import argparse
import json
import re
import sys

HOSTED = "hosted"
LOCAL = "local"


def parse_table(path):
    """Return {ref: system} for every target row (None system = hosted)."""
    text = open(path, encoding="utf-8").read()
    refs = {}
    # target entries: 4-space indent "name = {", contents until the
    # matching 4-space "};"; each carries ref, optional system, budgetMB.
    for m in re.finditer(r"^    ([a-z0-9-]+) = \{\n(.*?)^    \};", text, re.M | re.S):
        body = m.group(2)
        rm = re.search(r'ref = "(kailash-images-[a-z0-9-]+)"', body)
        if not rm:
            continue  # the formats block's entries carry no ref
        sysm = re.search(r'system = "([a-z0-9_-]+)"', body)
        refs[rm.group(1)] = sysm.group(1) if sysm else None
    if not refs:
        raise SystemExit(f"{path}: no target refs parsed — parser drift")
    return refs


def parse_workflow(path):
    """Return the set of target refs the workflow DECLARES.

    The declaration lives in TWO places that must agree, both parsed here:
    the resolve job's heredoc JSON block (the runtime matrix source —
    {"name": ..., "attr": "packages.x86_64-linux.<ref>"} rows) and, for
    belt-and-braces, any static YAML `- attr:` rows if they ever return.
    """
    text = open(path, encoding="utf-8").read()
    refs = set()
    # The resolve job's heredoc: <<'JSON' ... JSON
    for block in re.findall(r"<<'JSON'\n(.*?)\n\s*JSON\n", text, re.S):
        doc = json.loads(block)
        for leg in doc.get("include", []):
            m = re.match(r"packages\.[a-z0-9_-]+\.(kailash-images-[a-z0-9-]+)", leg.get("attr", ""))
            if not m:
                raise SystemExit(f"{path}: heredoc leg without a kailash-images attr: {leg}")
            refs.add(m.group(1))
    # A static YAML matrix (if the file ever carries one again)
    for m in re.finditer(r"attr: packages\.[a-z0-9_-]+\.(kailash-images-[a-z0-9-]+)", text):
        refs.add(m.group(1))
    if not refs:
        raise SystemExit(f"{path}: no declared kailash-images legs — parser drift")
    return refs


def parse_builder(path, fmts=("iso", "qemu")):
    """Return (default_profiles, ref_template) from the arm builder."""
    text = open(path, encoding="utf-8").read()
    # PROFILES=() is the empty declaration; the `all` branch carries the
    # real default — pick the first NON-EMPTY assignment.
    assigns = re.findall(r"PROFILES=\(([^)]*)\)", text)
    profiles = next((a.split() for a in assigns if a.strip()), [])
    rm = re.search(r'ref="([^"$]+)\$\{fmt\}-aarch64-\$\{prof\}"', text)
    if not rm:
        raise SystemExit(f"{path}: aarch64 ref template not found — parser drift")
    prefix = rm.group(1)  # e.g. "kailash-images-"
    return profiles, {f"{prefix}{fmt}-aarch64-{prof}" for prof in profiles for fmt in fmts}


def enforce(table, workflow, builder_profiles, builder_refs):
    """Return (ok, lines). table={ref: system|None}."""
    lines = []
    ok = True
    hosted_missing, local_missing, extra = [], [], []

    hosted = sorted(r for r, s in table.items() if s is None)
    local = sorted(r for r, s in table.items() if s is not None)
    lines.append(f"table: {len(hosted)} hosted (x86_64) + {len(local)} local (aarch64) targets")
    lines.append(f"workflow declares {len(workflow)} legs; builder default expands {len(builder_refs)} refs")

    for ref in hosted:
        if ref not in workflow:
            hosted_missing.append(ref)
    for ref in local:
        if ref not in builder_refs:
            local_missing.append(ref)
    for ref in sorted(builder_refs):
        if ref not in table:
            extra.append(ref)

    if hosted_missing:
        ok = False
        lines.append(f"MISSING (never built — no declared hosted matrix leg): {', '.join(hosted_missing)}")
    if local_missing:
        ok = False
        lines.append(f"MISSING (no local-builder expansion): {', '.join(local_missing)}")
    if extra:
        ok = False
        lines.append(f"EXTRA (builder default expands refs OUTSIDE the matrix table): {', '.join(extra)}")

    if ok:
        lines.append(
            f"OK — gap-free: all {len(hosted)} hosted targets declared in the release workflow, "
            f"all {len(local)} local targets producible by build-arm-images.sh, no out-of-table rows")
    return ok, lines


def self_test():
    """Breach + clean cases through the same enforcement unit."""
    tbl_ok = {f"kailash-images-{f}-{p}": None for f in ("iso", "qemu") for p in ("minimal", "full")}
    tbl_ok["kailash-images-iso-aarch64-minimal"] = "aarch64-linux"
    wf_full = {"kailash-images-iso-minimal", "kailash-images-qemu-minimal",
               "kailash-images-iso-full", "kailash-images-qemu-full"}
    cases = []

    def case(name, tbl, wf, bp, br, want_ok):
        got_ok, lines = enforce(tbl, wf, bp, br)
        cases.append((name, want_ok, got_ok, lines))

    case("clean", dict(tbl_ok), set(wf_full) | {"kailash-images-iso-aarch64-minimal"},
         ["minimal"], {"kailash-images-iso-aarch64-minimal"}, True)
    # breached workflow: a hosted leg undeclared (the ko#200 shape)
    case("hosted-missing", dict(tbl_ok), wf_full - {"kailash-images-qemu-minimal"},
         ["minimal"], {"kailash-images-iso-aarch64-minimal"}, False)
    # breached builder: a local target not producible
    case("local-missing", dict(tbl_ok), set(wf_full),
         ["nothing"], set(), False)
    # breached builder: an out-of-table ref in the default expansion
    case("builder-extra", dict(tbl_ok), set(wf_full),
         ["minimal", "full"],
         {"kailash-images-iso-aarch64-minimal", "kailash-images-iso-aarch64-full"}, False)

    ok = True
    for name, want, got, lines in cases:
        status = "OK" if want == got else "MISMATCH"
        if want != got:
            ok = False
        print(f"self-test {name}: {status} (want {'ok' if want else 'fail'}, got {'ok' if got else 'fail'})")
        if want != got:
            for l in lines:
                print(f"  {l}")
    if not ok:
        print("self-test FAILED")
        return 1
    print("self-test: OK (gap-free + builder-proven)")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--table")
    ap.add_argument("--workflow")
    ap.add_argument("--builder")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        sys.exit(self_test())
    for req in ("--table", "--workflow", "--builder"):
        if getattr(a, req.strip("-").replace("-", "_")) is None:
            ap.error(f"{req} required (or --self-test)")
    table = parse_table(a.table)
    workflow = parse_workflow(a.workflow)
    profiles, builder_refs = parse_builder(a.builder)
    ok, lines = enforce(table, workflow, profiles, builder_refs)
    for l in lines:
        print(l)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
