#!/usr/bin/env python3
# tools/gen-exp-wrap.py — exp-wrap wrapper-input generator (KA-19.1, kailash-os#94).
#
# MIRROR PAIR: this generator is vendored byte-identically in BOTH repos —
# kailash-packages/tools/gen-exp-wrap.py and kailash-os/tools/gen-exp-wrap.py.
# Keep the two byte-identical (cmp in verify); a change lands against both
# in the same cycle. The packages repo owns the manifest + the emit
# contract; the OS repo consumes the emitted surface through its parity
# leg (the vendored copy runs there too, off the same file).
#
# Parses manifest/tools.yaml, selects the rows whose `safety.level` is
# `exp`, and emits the wrapper-generation inputs to stdout as one JSON
# blob:
#
#   {"exp_ids":   ["<tool-id>", ...],
#    "wrappers":  [{"id": ..., "program": ..., "derivation": <path|null>},
#                  ...]}
#
# Deterministic: rows sorted by id, sort_keys on. The packages repo owns
# the manifest + this emit surface; the WRAPPER GENERATION (the lab-mode
# gate) lives in the OS repo's modules/base/safety-defaults.nix — the
# gateFor hook point KA-19.1 wires (kailash.safety.extraTools).
#
# `program` resolution mirrors the OS gate's mainProgOf convention
# (nixos_menu.exec when the row carries one, else the row name, else the
# row id); `derivation` is the packaging.derivation path or null.
#
# RED STUB (KA-19.1): the RED commit carried a deliberately empty
# emit stub; the watched reds on the exp-wrap-manifest-emit /
# exp-wrap-generator-self-test checks are the test-first evidence.
# GREEN (this commit): the real rows.

from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MANIFEST = os.path.join(HERE, os.pardir, "manifest", "tools.yaml")


def _program_of(tool):
    """The OS gate's mainProgOf convention: nixos_menu.exec, else the
    row name, else the row id."""
    menu = tool.get("nixos_menu") or {}
    return menu.get("exec") or tool.get("name") or tool.get("id")


def _derivation_of(tool):
    """packaging.derivation path, or None (data rows carry none)."""
    packaging = tool.get("packaging") or {}
    drv = packaging.get("derivation")
    return drv if drv else None


def _normalize_rows(tools):
    """Both manifest row shapes the OS scanner accepts: `- id: <tool>`
    rows and keyed `- <tool>:` rows (the level row still closes each
    entry) — normalize to id-bearing dicts."""
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
    """Real core: safety.level == 'exp' rows -> the wrapper-generation
    inputs, sorted by id (deterministic across manifest edits)."""
    exp = sorted(
        (t for t in _normalize_rows(tools) if (t.get("safety") or {}).get("level") == "exp"),
        key=lambda t: t.get("id") or "",
    )
    return {
        "exp_ids": [t["id"] for t in exp],
        "wrappers": [
            {
                "id": t["id"],
                "program": _program_of(t),
                "derivation": _derivation_of(t),
            }
            for t in exp
        ],
    }


def load_tools(path):
    """Parse the manifest with PyYAML (guaranteed in both repos' check
    envs — the flake legs build python3.withPackages ps.pyyaml)."""
    import yaml  # type: ignore[import-not-found]

    with open(path, encoding="utf-8") as fh:
        doc = yaml.safe_load(fh.read())
    if doc is None:
        return []
    tools = doc.get("tools") or [] if isinstance(doc, dict) else doc
    return [t for t in tools if isinstance(t, dict)]


def generate(path):
    return emit_inputs(load_tools(path))


def self_test() -> int:
    """Assert-based core self-check (no nix, no network). RED: the stub
    core fails every exp-selection case."""
    cases = [
        (
            {"schema_version": 1, "tools": []},
            {"exp_ids": [], "wrappers": []},
        ),
        (
            {
                "tools": [
                    {"id": "garak", "safety": {"level": "exp"}},
                    {"id": "nmap", "safety": {"level": "safe"}},
                    {"id": "sqlmap", "safety": {"level": "requires-target"}},
                ]
            },
            {
                "exp_ids": ["garak"],
                "wrappers": [{"id": "garak", "program": "garak", "derivation": None}],
            },
        ),
        # module-shape cases: keyed-row documents (the OS scanner's other
        # accepted shape) and the empty manifest
    (
        {
            "tools": [
                {"garak": {"safety": {"level": "exp"}}},
                {"nmap": {"safety": {"level": "safe"}}},
            ]
        },
        {
            "exp_ids": ["garak"],
            "wrappers": [{"id": "garak", "program": "garak", "derivation": None}],
        },
    ),
    (
        {"schema_version": 1, "tools": []},
        {"exp_ids": [], "wrappers": []},
    ),
]
    for i, (doc, want) in enumerate(cases):
        got = emit_inputs(doc.get("tools") or [])
        assert got["exp_ids"] == want["exp_ids"], f"case {i}: exp_ids {got['exp_ids']!r} != {want['exp_ids']!r}"
        assert got["wrappers"] == want["wrappers"], f"case {i}: wrappers {got['wrappers']!r} != {want['wrappers']!r}"
    # non-exp rows are excluded (safe / requires-target / missing safety)
    mixed = [
        {"id": "a", "safety": {"level": "exp"}},
        {"id": "b", "safety": {"level": "safe"}},
        {"id": "c", "safety": {"level": "requires-target"}},
        {"id": "d"},
    ]
    got = emit_inputs(mixed)
    assert got["exp_ids"] == ["a"], f"non-exp rows leaked: {got['exp_ids']!r}"
    # id shapes: every exp id is a manifest slug; wrappers stay aligned
    for w in got["wrappers"]:
        tid = w["id"]
        assert tid and all(c.isalnum() or c in "._-" for c in tid), f"bad id shape: {tid!r}"
    # determinism: re-emitting the same rows in a different order emits
    # the identical blob
    shuffled = [mixed[1], mixed[3], mixed[0], mixed[2]]
    assert emit_inputs(shuffled) == got, "emit is not order-deterministic"
    # 3.9-era compat guard: no PEP 604 union syntax anywhere in this file
    # (needle is built split so this line cannot contain the pattern)
    union = "|" + " None"
    with open(os.path.abspath(__file__), encoding="utf-8") as fh:
        src = fh.read()
    for ln in src.splitlines():
        assert union not in ln, f"PEP 604 union found (host python is 3.9): {ln}"
    print("tools/gen-exp-wrap.py: self-test OK")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    path = None
    i = 0
    while i < len(argv):
        if argv[i] == "--manifest-file":
            i += 1
            path = argv[i]
        i += 1
    out = generate(path or DEFAULT_MANIFEST)
    sys.stdout.write(json.dumps(out, sort_keys=True, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
