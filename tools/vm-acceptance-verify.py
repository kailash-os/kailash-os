#!/usr/bin/env python3
"""KA-08.5 (kailash-os#109) — VM-acceptance record verifier.

Validates the committed tests/vm-acceptance-record.json against the
record kinds the lane contract allows:

  kind == "real"       — a REAL boot was exercised: BOTH endpoint checks
                         (ollama :11434 prompt completion, MLflow :5000
                         /health) must be recorded "ok" AND the record
                         must carry verbatim output sections plus the
                         probe command lines (never a claim without the
                         output it stands on).
  kind == "pending-vm" — the boot was ATTEMPTED and blocked by host
                         constraints: the record must carry every
                         attempted command verbatim, its verbatim output
                         excerpt, the host-constraint statement, and the
                         ONE interactive step the maintainer must run
                         locally (qemu boot on his Mac) — the residual.

Anything else (missing fields, empty proofs, an "ok" verdict without
verbatim output) is a hard error: the verifier is the tripwire that
keeps the acceptance honest — a hand-typed "ok" with no output behind
it fails CI.
"""

import argparse
import json
import sys
from typing import NoReturn, Union

REQUIRED_REAL_STR = [
    "status",
    "recorded_at",
]
REQUIRED_REAL = REQUIRED_REAL_STR + [
    "endpoint_checks",
    "verbatim_sections",
    "commands",
]
REQUIRED_PENDING = REQUIRED_REAL + [
    "host_constraint",
    "interactive_step",
]
# pending-vm fields checked as plain non-empty values without a type:
# host_constraint/interactive_step are strings, commands a list.
REQUIRED_PENDING_STR = ["status", "recorded_at", "host_constraint", "interactive_step"]


def _fail(msg: str) -> NoReturn:
    print(f"vm-acceptance-verify: FAIL: {msg}")
    sys.exit(1)


def _require_nonempty_str(rec: Union[dict, object], key: str) -> str:
    val = rec.get(key) if isinstance(rec, dict) else None
    if not isinstance(val, str) or not val.strip():
        _fail(f"record field {key!r} must be a non-empty string")
    assert val is not None  # narrow for the type checker; _fail exits otherwise
    return val


def _require_nonempty_list(rec: Union[dict, object], key: str) -> list:
    val = rec.get(key) if isinstance(rec, dict) else None
    if not isinstance(val, list) or len(val) == 0:
        _fail(f"record field {key!r} must be a non-empty list")
    return val


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--record", required=True)
    args = ap.parse_args()

    rec_obj = None
    try:
        rec_obj = json.load(open(args.record, encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - verbatim failure text below
        _fail(f"record does not parse as JSON: {exc}")

    rec: dict = rec_obj  # narrow after the guarded load; _fail never returns

    status = rec.get("status")
    if status == "real":
        for key in REQUIRED_REAL_STR:
            _require_nonempty_str(rec, key)
        endpoints = rec.get("endpoint_checks")
        if not isinstance(endpoints, dict) or len(endpoints) < 2:
            _fail("endpoint_checks must carry BOTH endpoint checks")
        for name in ("ollama-11434-prompt", "mlflow-5000-health"):
            check = endpoints.get(name)
            if check is None or not isinstance(check, dict):
                _fail(f"endpoint_checks missing {name!r} (both endpoints are the acceptance)")
            if check.get("verdict") != "ok":
                _fail(f"endpoint {name!r} verdict {check.get('verdict')!r} != 'ok'")
            _require_nonempty_str(check, "verbatim")
            _require_nonempty_str(check, "command")
            text = check["verbatim"]
            if "FAIL" in text:
                # An embedded FAIL marker inside a section the record
                # still calls "ok" is inconsistent by construction.
                _fail(f"endpoint {name!r} marked ok but its verbatim section carries FAIL")
        sections = _require_nonempty_list(rec, "verbatim_sections")
        cmds = _require_nonempty_list(rec, "commands")
        for c in cmds:
            if not isinstance(c, str) or not c.strip():
                _fail("commands entries must be non-empty command strings")
        print(
            "vm-acceptance-verify: OK (kind=real: "
            f"{len(endpoints)} endpoint checks ok, "
            f"{len(sections)} verbatim sections, "
            f"{len(cmds)} recorded commands)"
        )
    elif status == "pending-vm":
        for key in REQUIRED_PENDING_STR:
            _require_nonempty_str(rec, key)
        for key in REQUIRED_PENDING:
            val = rec.get(key)
            if not isinstance(val, (str, list)) or (
                isinstance(val, list) and len(val) == 0
            ):
                _fail(f"pending record field {key!r} must be non-empty")
        _require_nonempty_str(rec, "host_constraint")
        _require_nonempty_str(rec, "interactive_step")
        _require_nonempty_list(rec, "commands")
        # Every attempted command must carry a verbatim output excerpt.
        attempts = rec.get("attempts")
        if not isinstance(attempts, list) or not attempts:
            _fail(
                "pending record field 'attempts' must be a non-empty list "
                "of {command, output} entries"
            )
        for att in attempts:
            if (
                not isinstance(att, dict)
                or not att.get("command", "").strip()
                or not att.get("output", "").strip()
            ):
                _fail("each attempts[] entry needs non-empty command AND verbatim output")
        print(
            "vm-acceptance-verify: OK (kind=pending-vm: "
            f"{len(attempts)} attempted commands recorded with verbatim output; "
            "the interactive step is documented)"
        )
    else:
        _fail(
            "record status must be 'real' or 'pending-vm' — got "
            f"{status!r}; no fabricated acceptance state is loadable"
        )


if __name__ == "__main__":
    main()
