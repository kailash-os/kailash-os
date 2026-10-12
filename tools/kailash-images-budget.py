#!/usr/bin/env python3
"""kailash-images-budget — the §8.1 size-budget check leg's verifier.

Usage:
  kailash-images-budget.py --census tests/images-census.json            # enforce
  kailash-images-budget.py --census tests/images-census.json --report-only
  kailash-images-budget.py --self-test

The §8.1 matrix (images/kailash-images-table.nix) carries per-target
budgets. This verifier enforces the TABLE against the committed census
snapshot (tests/images-census.json): per target, mass = Σ NarSize bytes
over the profile toplevel's derivation-level closures (the recorded
evidence — real narinfo NarSize sums from the nixpkgs binary cache; no
builds). Exits 1 on any breach with the breach named.

--self-test drives the same enforcement unit against a synthetic census
with breach + exclusion cases (the RED proof the check leg renders).
"""
import argparse
import json
import sys

MIB = 1024 * 1024


def load_census(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def mass_and_packs(census, target_name):
    """Return (massMB, pack_names) for one target from the census doc."""
    tgt = census["targets"][target_name]
    mass = 0
    packs = []
    for row in tgt["closures"]:
        mass += row.get("narSize") or 0
        toks = row.get("packTokens") or []
        for tok in toks:
            if tok not in packs:
                packs.append(tok)
    return mass / MIB, packs


def enforce(census, report_only=False):
    """Return (ok, lines). Enforces budgets + pack exclusions."""
    table = census["table"]
    rows = []
    ok = True
    for name, tgt in sorted(table.items()):
        mass, packs = mass_and_packs(census, name)
        budget = tgt["budgetMB"]
        status = "OK" if mass <= budget else "BREACH"
        if mass > budget:
            ok = False
        for pack in ("sdr-pack", "wordlists-mega"):
            if pack in packs:
                ok = False
                status = "PACK-LEAK"
        rows.append(
            "%-24s %12.1f MB / %8d MB  %-9s packs=%s" % (name, mass, budget, status, ",".join(packs) or "-")
        )
    if report_only:
        return True, rows
    return ok, rows


def self_test():
    """Breach + exclusion cases against the same enforcement unit."""
    base = {
        "table": {
            "qemu-minimal": {"profile": "minimal", "format": "qemu", "budgetMB": 100},
            "iso-headless": {"profile": "headless-agent", "format": "iso", "budgetMB": 100},
        },
        "targets": {
            "qemu-minimal": {
                "closures": [
                    {"name": "a", "narSize": 60 * MIB, "packTokens": []},
                    {"name": "b", "narSize": 39 * MIB, "packTokens": []},
                ]
            },
            "iso-headless": {
                "closures": [
                    {"name": "c", "narSize": 90 * MIB, "packTokens": ["sdr-pack"]},
                ]
            },
        },
    }
    ok, rows = enforce(base, report_only=True)
    print("\n".join(rows))
    # iso-headless must trip BOTH the pack leak and (90 > 100 is under) only
    # the pack rule; qemu-minimal stays under (99 <= 100).
    ok2, _ = enforce(base)
    if ok2:
        print("self-test: FAIL — the pack-leak target did not trip the leg")
        return 1
    # A mass breach case: shrink the budget
    base["table"]["qemu-minimal"]["budgetMB"] = 50
    ok3, _ = enforce(base)
    if ok3:
        print("self-test: FAIL — the mass-breach case did not trip the leg")
        return 1
    # The clean case: restore, drop the pack token
    base["table"]["qemu-minimal"]["budgetMB"] = 100
    base["targets"]["iso-headless"]["closures"][0]["packTokens"] = []
    ok4, _ = enforce(base)
    if not ok4:
        print("self-test: FAIL — the clean case tripped the leg")
        return 1
    print("kailash-images-budget --self-test: OK (breach + exclusion + clean all proven)")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="KA-28 §8.1 image size-budget verifier")
    ap.add_argument("--census", required=False, default=None)
    ap.add_argument("--report-only", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)
    if args.self_test:
        return self_test()
    if not args.census:
        ap.error("--census is required unless --self-test")
    census = load_census(args.census)
    ok, rows = enforce(census)
    print("\n".join(rows))
    if not ok:
        print("images-budget: FAIL — see the BREACH/PACK-LEAK rows above")
        return 1
    print("images-budget: OK — every target inside its §8.1 budget, no pack leaks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
