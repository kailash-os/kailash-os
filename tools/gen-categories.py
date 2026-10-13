#!/usr/bin/env python3
# tools/gen-categories.py — the §4.5 category-package-list generator
# (KA-06.1, ko#96; plan §4.5).
#
# The manifest (kailash-packages manifest/tools.yaml) is the ONLY
# hand-maintained tool registry; this generator derives the per-category
# id sets the §4.5 module contract composes
# (`kailash.layers.<layer>.categories.<id>.packages`), never hand-edited:
#
#   * `installable` — ids a category module installs as packages
#     (packaging.status native | stale | bespoke at the manifest's own
#     word — the id↔attr RESOLUTION lives in the category modules'
#     reviewed binding tables, not here);
#   * `excluded` — ids deliberately NOT in any package list:
#     status `module` → the tool ships as a systemd service module, not
#     a package-list surface; status `data` → opt-in data-pack row
#     (never on default profiles/ISOs — D7);
#   * `exp` — (KA-22, ko#22) ids whose `safety.level == "exp"` rides an
#     installable packaging.status: they LEAVE `installable` never to
#     enter a package list from this artifact (§11.2: the double-key
#     gate owns exp routing; the manifest row IS the routing record).
#     The ledger exists so a category module / check leg can verify the
#     routing both directions — an exp row present in `installable` is
#     the watched defect. Categories with no installable-status exp row
#     keep the old shape (no empty key). A data-status exp row stays
#     ONLY in `excluded` (its opt-in data-pack routing is the stricter
#     of the two owners).
#
# Consumers:
#   * generated/manifest-ids.json — the committed artifact (`make
#     gen-categories` regenerates it; the OS repo's flake parity leg runs
#     THIS file against the PINNED packages manifest and fails the build
#     with drift lines when a packages-side merge moves the surface —
#     the exp-parity drift-alarm shape, lifted to the §4.5 tree);
#   * the category modules read the committed artifact via
#     builtins.fromJSON and check their binding tables against it.
#
# Source resolution: --manifest-file <path> — the flake parity leg passes
# the PINNED packages manifest (kailash-packages.outPath +
# "/manifest/tools.yaml", through the flake input — never a hand-copy);
# the Makefile target defaults to the sibling-checkout convention
# (../kailash-packages). A live-web default is deliberately absent (the
# parity gate keeps the pin honest instead).
#
# Deterministic: manifest row order preserved (the census order), JSON
# with sort_keys. Python stdlib-first: PyYAML when importable; a stdlib
# fallback parser covers the manifest's own row shape otherwise (the
# --self-test asserts the fallback and PyYAML agree on the fixture).

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MANIFEST = os.path.join(HERE, os.pardir, "manifest", "tools.yaml")

INSTALLABLE = ("native", "stale", "bespoke")
EXCLUDED_NOTE = {
    "module": "service-module row — the tool ships as a systemd service, not a package-list surface",
    "data": "data-pack row (opt-in; D7) — category modules never install data rows",
}

OUTPUT_SCHEMA = "manifest-ids-v1"


def _normalize_rows(tools):
    """Both manifest row shapes the module scanners accept: `- id: <tool>`
    rows and keyed `- <tool>:` rows — normalize to id-bearing dicts."""
    for t in tools:
        if not isinstance(t, dict):
            continue
        if "id" in t:
            yield t
        elif len(t) == 1:
            (key, val), = t.items()
            if isinstance(val, dict):
                row = dict(val)
                row["id"] = key
                yield row


def emit_inputs(tools):
    """Pure core: manifest row list -> the manifest-ids document.

    Rows are BOTH shapes (`- id: x` and keyed `- x:` — normalized here,
    exactly gen-exp-wrap's contract). Per category (keyed by the
    manifest's own category id): row count, installable ids (manifest
    order), excluded rows (with the standing reason note)."""
    rows = list(_normalize_rows(tools))
    categories = {}
    for t in rows:
        cat = t.get("category")
        if not cat:
            continue
        categories.setdefault(cat, {"count": 0, "installable": [], "excluded": []})
    for t in rows:
        cat = t.get("category")
        st = (t.get("packaging") or {}).get("status")
        tid = t.get("id") or ""
        entry = categories.get(cat)
        if entry is None or not tid:
            continue
        entry["count"] += 1
        if (t.get("safety") or {}).get("level") == "exp" and st in INSTALLABLE:
            # §11.2 (KA-22): an installable-status exp row NEVER rides
            # `installable` — it lands in the category's own `exp` ledger
            # (the double-key gate owns the routing; the manifest row is
            # the routing record)
            entry.setdefault("exp", []).append(tid)
            continue
        if st in INSTALLABLE:
            entry["installable"].append(tid)
        elif st in EXCLUDED_NOTE:
            entry["excluded"].append({"id": tid, "status": st, "note": EXCLUDED_NOTE[st]})
    return {
        "schema": OUTPUT_SCHEMA,
        "tools_total": len(rows),
        "categories": categories,
    }


def _fallback_parse(text):
    """Narrow stdlib parser for the manifest's own row shape (used when
    PyYAML is absent): `- id: X` / keyed `- X:` entries at two-space
    indent; scalar fields `layer/category` at four; `status:` nested
    under packaging at six. Enough for this emit; the full invariants
    live in the packages repo's validator."""
    fields = ("layer", "category")
    doc = {"schema_version": 1, "tools": []}
    current = None
    for line in text.splitlines():
        row = line.rstrip()
        idRow = None
        keyedRow = None
        for probe in ("  - id: ", "\t- id: "):
            s = row.strip()
            if line.startswith(probe):
                idRow = line[len(probe):].strip()
        st = row.strip()
        if st.startswith("- "):
            body = st[2:]
            if body.startswith("id:"):
                idRow = body[3:].strip()
            elif body.endswith(":") and " " not in body:
                keyedRow = body[:-1]
        if idRow is not None:
            if current is not None:
                doc["tools"].append(current)
            current = {"id": idRow}
            continue
        if keyedRow is not None:
            if current is not None:
                doc["tools"].append(current)
            current = {"id": keyedRow}
            continue
        if current is None:
            continue
        indent = len(row) - len(row.lstrip(" "))
        stripped = row.strip()
        if stripped.startswith("#") or stripped == "":
            continue
        for f in fields:
            if stripped.startswith(f + ":") and indent:
                current[f] = stripped[len(f) + 1:].strip().strip('"')
        for f in ("status",):
            if stripped.startswith(f + ":") and indent:
                current.setdefault("packaging", {})
                if isinstance(current["packaging"], dict):
                    current["packaging"][f] = stripped[len(f) + 1:].strip().strip('"')
    if current is not None:
        doc["tools"].append(current)
    return doc


def load_tools(path):
    """Parse the manifest with PyYAML (guaranteed in the flake check
    envs — the parity legs build python3.withPackages ps.pyyaml), else
    the stdlib fallback."""
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    try:
        import yaml  # type: ignore[import-not-found]
    except ImportError:
        return _normalize_rows(_fallback_parse(text)["tools"])
    doc = yaml.safe_load(text)
    if doc is None:
        return []
    tools = doc.get("tools") or [] if isinstance(doc, dict) else doc
    return [t for t in tools if isinstance(t, dict)]


def generate(path):
    return emit_inputs(load_tools(path))


def self_test() -> int:
    """Assert-based core self-check (no nix, no network)."""
    cases = [
        # empty manifest -> empty categories, zero total
        (
            {"schema_version": 1, "tools": []},
            {"schema": OUTPUT_SCHEMA, "tools_total": 0, "categories": {}},
        ),
        # statuses route: native installs, module/data excluded with notes
        (
            {
                "tools": [
                    {"id": "nmap", "category": "c-01-information-gathering",
                     "packaging": {"status": "native"}},
                    {"id": "gvm", "category": "c-02-vulnerability-analysis",
                     "packaging": {"status": "module"}},
                    {"id": "sdr-x", "category": "c-07-signal-sdr",
                     "packaging": {"status": "data"}},
                    {"id": "unipacker", "category": "c-06-reverse-engineering",
                     "packaging": {"status": "bespoke"}},
                    {"id": "stale-tool", "category": "c-01-information-gathering",
                     "packaging": {"status": "stale"}},
                ]
            },
            {
                "schema": OUTPUT_SCHEMA,
                "tools_total": 5,
                "categories": {
                    "c-01-information-gathering": {
                        "count": 2,
                        "installable": ["nmap", "stale-tool"],
                        "excluded": [],
                    },
                    "c-02-vulnerability-analysis": {
                        "count": 1,
                        "installable": [],
                        "excluded": [{
                            "id": "gvm", "status": "module",
                            "note": EXCLUDED_NOTE["module"],
                        }],
                    },
                    "c-06-reverse-engineering": {
                        "count": 1,
                        "installable": ["unipacker"],
                        "excluded": [],
                    },
                    "c-07-signal-sdr": {
                        "count": 1,
                        "installable": [],
                        "excluded": [{
                            "id": "sdr-x", "status": "data",
                            "note": EXCLUDED_NOTE["data"],
                        }],
                    },
                },
            },
        ),
    ]
    for i, (tools, expected) in enumerate(cases):
        doc = tools["tools"] if isinstance(tools, dict) else tools
        got = emit_inputs(doc)
        assert got == expected, f"case {i}: {got} != {expected}"

    # keyed-row documents (the OS scanner's other accepted shape): the
    # KEY is the id (the `- <tool>:` row shape; gen-exp-wrap + the OS
    # module scanner agree on this convention)
    keyed = emit_inputs(list(_normalize_rows([
        {"c-09-something": {
            "category": "c-01-information-gathering",
            "packaging": {"status": "native"},
        }},
    ])))
    assert keyed["categories"]["c-01-information-gathering"]["installable"] == ["c-09-something"], keyed

    # the stdlib fallback agrees with the fixture's own shape (the
    # `- id:` row shape; keyed rows are covered by the emit-level case
    # above — the real manifest carries only `- id:` rows)
    fixture = """\
schema_version: 1
tools:
  - id: nmap
    layer: CLASSIC
    category: c-01-information-gathering
    packaging:
      status: native
  - id: gvm
    layer: CLASSIC
    category: c-02-vulnerability-analysis
    packaging:
      status: module
  - id: subfinder
    layer: CLASSIC
    category: c-01-information-gathering
    packaging:
      status: bespoke
"""
    parsed = _fallback_parse(fixture)
    got = emit_inputs(parsed["tools"])
    assert got["tools_total"] == 3, got
    assert got["categories"]["c-01-information-gathering"]["installable"] == ["nmap", "subfinder"], got
    assert got["categories"]["c-02-vulnerability-analysis"]["excluded"][0]["id"] == "gvm", got
    # PyYAML (when importable) reads the SAME fixture to the same emit
    try:
        import yaml  # noqa: F401  # type: ignore[import-not-found]
    except ImportError:
        pass
    else:
        doc = yaml.safe_load(fixture)
        got2 = emit_inputs([t for t in doc["tools"] if isinstance(t, dict)])
        assert got == got2, (got, got2)
    # §11.2 exp routing (KA-22): an installable-status exp row leaves
    # `installable` into the category's own `exp` ledger, manifest order
    # kept; a data-status exp row stays ONLY in `excluded` (the two
    # ledger owners never double-record); a safe row is untouched.
    expCase = emit_inputs([
        {"id": "safe-tool", "category": "a-99-test",
         "packaging": {"status": "bespoke"}, "safety": {"level": "safe"}},
        {"id": "exp-bespoke", "category": "a-99-test",
         "packaging": {"status": "bespoke"}, "safety": {"level": "exp"}},
        {"id": "exp-data", "category": "a-99-test",
         "packaging": {"status": "data"}, "safety": {"level": "exp"}},
    ])
    gotCat = expCase["categories"]["a-99-test"]
    assert gotCat["installable"] == ["safe-tool"], gotCat
    assert gotCat["exp"] == ["exp-bespoke"], gotCat
    assert [e["id"] for e in gotCat["excluded"]] == ["exp-data"], gotCat
    # a category with no installable-status exp row keeps the OLD shape
    # (no empty `exp` key) — every pre-KA-22 consumer keeps working
    noExp = emit_inputs([
        {"id": "nmap", "category": "c-01-information-gathering",
         "packaging": {"status": "native"}, "safety": {"level": "safe"}},
    ])
    assert "exp" not in noExp["categories"]["c-01-information-gathering"], noExp
    # 3.9-era compat guard: no PEP 604 union syntax anywhere in this file
    union = "|" + " None"
    with open(os.path.abspath(__file__), encoding="utf-8") as fh:
        src = fh.read()
    for ln in src.splitlines():
        assert union not in ln, f"PEP 604 union found (host python is 3.9): {ln}"
    return 0


def main() -> int:
    import argparse

    ap = argparse.ArgumentParser(
        prog="gen-categories",
        description="Emit the §4.5 per-category id sets from manifest/tools.yaml (KA-06.1).",
    )
    ap.add_argument("--manifest-file", default=DEFAULT_MANIFEST,
                    help="tools.yaml path (flake legs pass the pinned packages manifest)")
    ap.add_argument("--out", default=None,
                    help="write the emit here (default stdout); a committed path is regenerated via `make gen-categories`")
    ap.add_argument("--self-test", action="store_true",
                    help="assert-based core self-check; no nix, no network")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    doc = generate(args.manifest_file)
    payload = json.dumps(doc, sort_keys=True, indent=2) + "\n"
    if args.out:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(payload)
        print(f"manifest-ids generated -> {args.out}", file=sys.stderr)
        return 0
    sys.stdout.write(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
