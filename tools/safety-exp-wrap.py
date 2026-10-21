#!/usr/bin/env python3
# tools/safety-exp-wrap.py — the exp-wrap parity validator (KA-18.1, os#92).
#
# The safety-defaults module contract (modules/base/safety-defaults.nix):
# every safety:exp tool the manifests list is wrapped into the
# kailash.labMode double-key gate; each host commits a per-id wrap report
# into its closure (/etc/kailash/safety/wrapped-exp-tools.json) and the
# root flake's safety-exp-wrap-parity check feeds that report to this tool.
#
# Check mode (the flake check; no nix subprocess, sandbox-pure):
#   safety-exp-wrap.py --manifest-file <tools.yaml> --wrapped-file <report.json>
#     * the manifest's safety:exp ids must ALL be covered by the report;
#     * every entry the report claims is verified BEHAVIORALLY: the store
#       path exists, bin/<program> exists, and the gate script carries both
#       key names (KAILASH_LAB_MODE + labMode) — a claimed-but-unwrapped
#       gate fails the parity leg, not just an id-count mismatch.
#
# Dev mode (host name given with no --wrapped-file): nix eval's the host's
# wrappedIds through the root flake — development evidence only, per the
# engineering standard; hosted CI exercises the check mode.
#
# --self-test: assert-based core self-check (no nix, no network).
#
# Python stdlib-first (repo rule): PyYAML is used when importable (the OS
# check env guarantees it); the stdlib fallback parses the manifest's
# `safety:\n  level: exp` row shapes and fails loudly on anything richer.

from __future__ import annotations

import json
import os
import subprocess
import sys

GATE_STRINGS = ("KAILASH_LAB_MODE", "labMode")


def exp_ids_from_yaml(tools_yaml: bytes) -> list[str]:
    """safety.level == 'exp' tool ids, in manifest order."""
    try:
        import yaml  # type: ignore[import-not-found]
    except ImportError:
        return exp_ids_fallback(tools_yaml)
    doc = yaml.safe_load(tools_yaml)
    tools = doc["tools"] if isinstance(doc, dict) else doc
    return [t["id"] for t in tools if (t.get("safety") or {}).get("level") == "exp"]


def exp_ids_fallback(text: bytes) -> list[str]:
    if b"\t" in text:
        raise ValueError("tab indentation in tools.yaml is not supported")
    import re

    ids: list[str] = []
    pending: str | None = None
    row = re.compile(r"^\s*-\s+(?:id:\s*(\S+)|([A-Za-z0-9][\w.-]*)):?\s*$")
    level = re.compile(r"^\s*level:\s*(\S+)\s*$")
    for raw in text.decode().splitlines():
        if raw.lstrip().startswith("#"):
            continue
        m = row.match(raw)
        if m:
            pending = m.group(1) or m.group(2)
            continue
        m = level.match(raw)
        if m and pending is not None:
            if m.group(1) == "exp":
                ids.append(pending)
            pending = None
    return ids


def coverage(manifest_exp: list[str], wrapped_ids: list[str]) -> list[str]:
    """Manifest exp ids the wrap report does not cover."""
    have = set(wrapped_ids)
    return [tid for tid in manifest_exp if tid not in have]


def verify_wrapped_entries(report: dict) -> list[str]:
    """Behavioral probes over the claimed wraps; returns failure lines.

    The report is the module's committed wrap state:
    {"wrapped": [{"id", "program", "package"} ...]} — one entry per gated
    tool. Every claim must point at a real bin/<program> gate script that
    carries both double-key names.
    """
    failures: list[str] = []
    for entry in report.get("wrapped", []):
        wid = entry.get("id", "?")
        program = entry.get("program")
        package = entry.get("package")
        if not program or not package:
            failures.append(f"entry {wid}: the program and package fields are missing")
            continue
        gate = os.path.join(package, "bin", program)
        if not os.path.exists(gate):
            failures.append(f"entry {wid}: the gate script is missing: {gate}")
            continue
        with open(gate, "rb") as fh:
            body = fh.read()
        for needle in GATE_STRINGS:
            if needle.encode() not in body:
                failures.append(f"entry {wid}: the gate script does not carry {needle}: {gate}")
    return failures


def load_wrapped_report(path: str) -> dict:
    with open(path) as fh:
        return json.load(fh)


def check(manifest_file: str, wrapped_file: str) -> int:
    with open(manifest_file, "rb") as fh:
        need = exp_ids_from_yaml(fh.read())
    if not os.path.exists(wrapped_file):
        print(f"safety-exp-wrap: FAIL: the wrap report is missing: {wrapped_file}")
        print("safety-exp-wrap: the report covers 0 of", len(need), "manifest exp ids")
        return 1
    report = load_wrapped_report(wrapped_file)
    wrapped = [e.get("id") for e in report.get("wrapped", [])]
    missing = coverage(need, wrapped)
    for tid in missing:
        print(f"safety-exp-wrap: FAIL: the manifest exp id is not wrapped: {tid}")
    failures = verify_wrapped_entries(report)
    for line in failures:
        print(f"safety-exp-wrap: FAIL: {line}")
    if missing or failures:
        return 1
    print(
        f"safety-exp-wrap: OK — {len(wrapped)} verified gate wrappers carry "
        f"{len(need)} manifest exp ids"
    )
    return 0


def dev_eval(host: str) -> int:
    """nix eval the host's wrap surface through the root flake (dev only)."""
    spec = f".#nixosConfigurations.{host}.config.kailash.safety.wrappedIds"
    try:
        out = subprocess.run(
            ["nix", "eval", "--json", spec],
            check=True, capture_output=True, text=True,
        ).stdout
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"nix eval failed for {spec}:\n{exc.stderr}") from exc
    ids = json.loads(out)
    print(f"safety-exp-wrap: dev-mode {host} wrappedIds = {ids}")
    return 0


def self_test() -> int:
    cases = [
        (b"schema_version: 1\ntools:\n  - id: garak\n    safety:\n      level: exp\n", ["garak"]),
        (b"schema_version: 1\ntools:\n  - garak:\n      safety:\n        level: exp\n", ["garak"]),
        (b"schema_version: 1\ntools:\n  - id: garak\n    safety:\n      level: safe\n", []),
        (b"schema_version: 1\ntools: []\n", []),
        (b"# comment\ntools:\n  - id: a\n    safety:\n      level: exp\n  - id: b\n    safety:\n      level: exp\n", ["a", "b"]),
    ]
    for i, (snippet, want) in enumerate(cases):
        got = exp_ids_from_yaml(snippet) if snippet.startswith(b"schema_version: 1\ntools:\n  - id:") else exp_ids_fallback(snippet)
        assert got == want, f"case {i}: {got!r} != {want!r}"
    assert coverage(["a", "b"], ["a", "b", "c"]) == []
    assert coverage(["a", "b"], ["a"]) == ["b"]
    ok_report = {"wrapped": [
        {"id": "t1", "program": "t1-gate", "package": os.getcwd()},
    ]}
    assert verify_wrapped_entries(ok_report) != []  # no real gate script here
    print("tools/safety-exp-wrap.py: self-test OK")
    return 0


def main(argv: list[str]) -> int:
    if argv and argv[0] == "--self-test":
        return self_test()
    manifest_file = None
    wrapped_file = None
    hosts: list[str] = []
    i = 0
    while i < len(argv):
        if argv[i] == "--manifest-file":
            i += 1
            manifest_file = argv[i]
        elif argv[i] == "--wrapped-file":
            i += 1
            wrapped_file = argv[i]
        else:
            hosts.append(argv[i])
        i += 1
    if manifest_file and wrapped_file:
        return check(manifest_file, wrapped_file)
    if manifest_file or wrapped_file:
        print("safety-exp-wrap: --manifest-file and --wrapped-file are a pair", file=sys.stderr)
        return 2
    if hosts:
        for host in hosts:
            dev_eval(host)
        return 0
    print(
        "safety-exp-wrap: usage: [--self-test] | "
        "[--manifest-file M --wrapped-file W] | [host ...]",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
