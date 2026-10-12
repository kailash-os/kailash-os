#!/usr/bin/env python3
# tools/gen-category-packages.py — the §4.5 category package-list generator
# (KA-08.1/08.2, ko#105/#106).
#
# MIRROR PAIR: this generator lives in BOTH repos — kailash-packages
# tools/gen-category-packages.py (beside the manifest it reads) and
# kailash-os tools/gen-category-packages.py (beside the committed lists it
# feeds through modules/ops/generated/). Keep the two byte-identical (cmp
# in verify); a change lands against both in the same cycle — the same
# mirror-pair discipline as the sibling generator tools/gen-exp-wrap.py
# (KA-19.1, ko#94).
#
# CONTRACT (§4.5; the manifest is the only hand-maintained registry):
# parses manifest/tools.yaml, selects a category's rows, and emits the
# per-category package lists as Nix files to stdout:
#
#   packaging.status == "native"  → a resolved package entry (see
#                                   NATIVE_ATTRS for id→attr divergence;
#                                   the resolved attr is `?`-guarded at
#                                   the use site by the category module)
#   packaging.status == "module"  → EXCLUDED (the row's own service module
#                                   owns it — module rows NEVER reach a
#                                   package list)
#   packaging.status == "bespoke" → EXCLUDED here (they resolve through
#                                   the packages overlay at the use site,
#                                   guarded; the generated list stays
#                                   overlay-free so it evaluates on bare
#                                   nixpkgs)
#   packaging.status in {"data","stale"} → data packs excluded ("data");
#                                   "stale" handled by the per-tool
#                                   override policy, not the generator's
#                                   business (no o-0x rows at this pin)
#   safety.level == "exp"         → NEVER in a package list (§11.2: the
#                                   double-key gate owns exp routing) —
#                                   the generator REFUSES (exit 1) if a
#                                   category's exp rows would be needed
#                                   for membership: the manifest row IS
#                                   the routing record
#
# Deterministic: rows in manifest order per selection (stable by
# construction of the manifest), emit sorted with sort_keys; id → attr
# divergence lives in NATIVE_ATTRS (probed per pin, never assumed).
#
# RED STUB (KA-08.1 watched RED): the RED commit carries this file with
# generate_category() returning { } — the watched RED is the
# o-01-generator-emit check failing on the empty emit (plus the o-01
# options assertion on the empty list). GREEN (this commit, or the paired
# GREEN commit of the lane): the real rows.
#
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_MANIFEST = os.path.join(HERE, os.pardir, "manifest", "tools.yaml")

# id → pinned-nixpkgs attr path. Probed per pin with nix eval (never
# assumed id==attr); divergence rows are recorded HERE (the generated
# file headers carry the same record with versions). Attr paths are
# `?`-guarded at the use site (the category module resolves rows against
# the module's own pkgs), so a pin where an attr moves still evaluates —
# with the row missing from the installed set until the table catches up.
NATIVE_ATTRS = {
    # o-01 native rows (probed at pin 7374e7a: kailash-os flake.lock pin)
    "dvc": ["dvc"],
    "git-lfs": ["git-lfs"],
    "wandb-cli": ["python3Packages", "wandb"],
    "pandas": ["python3Packages", "pandas"],
    "polars": ["python3Packages", "polars"],
    "scikit-learn": ["python3Packages", "scikit-learn"],
    "numpy": ["python3Packages", "numpy"],
    "scipy": ["python3Packages", "scipy"],
    "xgboost": ["xgboost"],
    "lightgbm": ["lightgbm"],
    # o-02 native rows
    "k3s": ["k3s"],
    "minikube": ["minikube"],
    "kind": ["kind"],
    "podman": ["podman"],
    "nvidia-container-toolkit": ["nvidia-container-toolkit"],
}

# statuses whose rows never reach a generated package list, with the
# owner that DOES carry them (the refusal message names it)
STATUS_OWNER = {
    "module": "the row's own service module",
    "bespoke": "the packages overlay (resolved at the category-module use site)",
    "data": "the kailash-data packs",
}


def _normalize_rows(tools):
    """Both manifest row shapes the OS scanner accepts: `- id: <tool>`
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


def _nix_attr_path(path):
    """[\"python3Packages\", \"wandb\"] → pkgs.python3Packages.wandb (dotted
    for identifier-safe segments, quoted for the rest)."""
    parts = []
    for seg in path:
        ok = seg and (seg[0].isalpha() or seg[0] == "_") and all(
            c.isalnum() or c in "._" for c in seg
        )
        parts.append(seg if ok else '"%s"' % seg)
    return "pkgs." + ".".join(parts)


def _emit_list(category, rows):
    """One generated Nix file per category: header + the native rows as
    guarded attr expressions (the `?` guard keeps host evaluation green
    at revisions/pins where an attr moves or the overlay is absent)."""
    native = [t for t in rows if (t.get("packaging") or {}).get("status") == "native"]
    native.sort(key=lambda t: t.get("id") or "")
    excluded = {}
    for t in rows:
        st = (t.get("packaging") or {}).get("status")
        if st and st != "native":
            excluded.setdefault((st, STATUS_OWNER.get(st, "its own owner")), []).append(
                t.get("id")
            )
    exp_ids = sorted(t.get("id") for t in rows
                     if (t.get("safety") or {}).get("level") == "exp")
    if exp_ids:
        print(
            "gen-category-packages: %s carries safety:exp rows (%s) — exp rows "
            "NEVER enter package lists (plan §11.2); refusing to emit"
            % (category, ", ".join(exp_ids)),
            file=sys.stderr,
        )
        raise SystemExit(1)

    lines = []
    lines.append("# GENERATED FILE — KA-08.x. DO NOT EDIT: regen with")
    lines.append(
        "#   python3 tools/gen-category-packages.py --category %s" % category
    )
    lines.append("# from the pinned packages manifest; the committed lists are")
    lines.append("# drift-checked every PR by the OS flake's category checks.")
    lines.append("# Excluded at this pin (never package-list entries): %s"
                 % json.dumps(
                     {"%s (%s)" % (st, owner): ids for (st, owner), ids in sorted(excluded.items())},
                     sort_keys=True,
                 ))
    lines.append("{ lib, pkgs }:")
    lines.append("")
    lines.append("{")
    lines.append("  %s = [" % category)
    for t in native:
        attr = _nix_attr_path(NATIVE_ATTRS.get(t["id"], [t["id"]]))
        lines.append("    (pkgs ? %s : %s)" % (attr, attr))
    lines.append("  ];")
    lines.append("}")
    return "\n".join(lines) + "\n"


def generate_category(tools, category):
    return {}
    rows = [t for t in _normalize_rows(tools) if (t.get("category") or "") == category]
    return _emit_list(category, rows)


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


def self_test() -> int:
    """Assert-based core self-check (no nix, no network). RED stub: the
    empty-emit core fails the selection case; GREEN asserts the real
    selection + exclusion contracts."""
    cases = [
        (
            {
                "tools": [
                    {"id": "dvc", "category": "o-01-test",
                     "packaging": {"status": "native"},
                     "safety": {"level": "safe"}},
                    {"id": "mlflow", "category": "o-01-test",
                     "packaging": {"status": "module"},
                     "safety": {"level": "safe"}},
                    {"id": "bentoml", "category": "o-01-test",
                     "packaging": {"status": "bespoke"},
                     "safety": {"level": "safe"}},
                    {"id": "ollama", "category": "o-04-somewhere-else",
                     "packaging": {"status": "native"},
                     "safety": {"level": "safe"}},
                ]
            },
            {
                "o-01-test": [
                    "(pkgs ? pkgs.dvc : pkgs.dvc)",
                ]
            },
        ),
    ]
    for i, (doc, want) in enumerate(cases):
        got = generate_category(doc.get("tools") or [], list(want)[0])
        assert got == want, f"case {i}: {got!r} != {want!r}"
    # exp rows refuse selection in every shape
    for doc in (
        {"tools": [{"id": "x", "packaging": {"status": "native"},
                    "safety": {"level": "exp"}}]},
        {"tools": [{"x": {"packaging": {"status": "native"},
                          "safety": {"level": "exp"}}}]},
    ):
        try:
            generate_category(doc.get("tools") or [], "o-01-test")
        except SystemExit:
            pass
        else:
            raise AssertionError("exp rows did not refuse selection")
    # 3.9-era compat guard: no PEP 604 union syntax anywhere in this file
    union = "|" + " None"
    with open(os.path.abspath(__file__), encoding="utf-8") as fh:
        src = fh.read()
    for ln in src.splitlines():
        assert union not in ln, f"PEP 604 union found (host python is 3.9): {ln}"
    print("tools/gen-category-packages.py: self-test OK")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    path = None
    categories = []
    i = 0
    while i < len(argv):
        if argv[i] == "--manifest-file":
            i += 1
            path = argv[i]
        elif argv[i] == "--category":
            i += 1
            categories.append(argv[i])
        i += 1
    tools = load_tools(path or DEFAULT_MANIFEST)
    for category in categories:
        out = generate_category(tools, category)
        if not out:
            print(
                "gen-category-packages: no emit for %s (generator not wired?)"
                % category,
                file=sys.stderr,
            )
            return 1
        sys.stdout.write(out[category])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
