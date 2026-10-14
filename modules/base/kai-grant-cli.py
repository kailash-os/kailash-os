#!/usr/bin/env python3
"""kai-grant — the capability-grant checker (KA-25 v1, os#25).

Usage: kai-grant check <holder> <action> [<tool-id>]
       action ∈ {read, exec, service-start}

Posture (spec §9.2 KA-25 v1):
  * read            — the unsupervised-agent floor; always allowed for
                      EXISTING holders (a grants file with no such
                      holder denies even reads — the holder IS the grant);
  * exec            — deny unless the grant's window is live, the tool
                      (by id or primary category via KAILASH_MANIFEST) is
                      in scope, the holder is not read-only-only, and for
                      safety.level == "exp" rows the grant carries
                      allow_exp;
  * service-start   — deny unless allow_service_start (the no-auto-start
                      audit still binds; this only scopes it).

Every decision — allow AND deny — appends one JSON line to
$KAILASH_GRANT_LOG (stdout when unset). Exit 0 allow, 1 deny. The checker
NEVER bypasses the lab-mode double-key gate: hosts invoke it as one more
condition for grant-scoped actions (the exp gate keys are checked
independently by the gate wrappers).
"""
import json
import os
import sys
from datetime import datetime, timezone

GRANTS = os.environ.get("KAILASH_GRANTS")
LOG = os.environ.get("KAILASH_GRANT_LOG")


def _emit(decision, holder, action, tool, reason):
    rec = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "holder": holder,
        "action": action,
        "tool": tool or "",
        "decision": decision,
        "reason": reason,
    }
    line = json.dumps(rec, sort_keys=True)
    print(line)
    if LOG:
        try:
            with open(LOG, "a") as f:
                f.write(line + "\n")
        except OSError:
            pass


def _ts(value):
    if not value:
        return None
    try:
        d = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        return d if d.tzinfo else d.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def _load():
    if not GRANTS:
        return {}
    try:
        with open(GRANTS) as f:
            doc = json.load(f)
        return doc if isinstance(doc, dict) else {}
    except (OSError, ValueError):
        return {}


def _tool_category(tool_id):
    # The §7.3 loader contract: resolve the tool's primary category
    # from the pinned manifest. Absent env/unreadable — None (tool-id
    # scope only).
    path = os.environ.get("KAILASH_MANIFEST")
    if not path:
        return None
    try:
        import yaml
        with open(path) as f:
            doc = yaml.safe_load(f)
        for row in doc.get("tools", []):
            if row.get("id") == tool_id:
                return row.get("category")
    except Exception:
        return None
    return None


def _tool_safety(tool_id):
    path = os.environ.get("KAILASH_MANIFEST")
    if not path or not tool_id:
        return None
    try:
        import yaml
        with open(path) as f:
            doc = yaml.safe_load(f)
        for row in doc.get("tools", []):
            if row.get("id") == tool_id:
                return (row.get("safety") or {}).get("level")
    except Exception:
        return None
    return None


def main(argv):
    if len(argv) < 3 or argv[0] != "check":
        sys.stderr.write(
            "kai-grant: usage: kai-grant check <holder> <action> [<tool-id>]\n")
        return 2
    holder, action = argv[1], argv[2]
    tool = argv[3] if len(argv) > 3 else ""

    doc = _load()
    grant = (doc.get("grants") or {}).get(holder) or {}
    if not grant:
        _emit("deny", holder, action, tool, "no such holder")
        return 1

    # read — the floor posture (list/search/read only)
    if action == "read":
        _emit("allow", holder, action, tool, "read-only floor")
        return 0

    now = datetime.now(timezone.utc)
    after = _ts(grant.get("not_after"))
    before = _ts(grant.get("not_before"))
    if after is None or after < now:
        _emit("deny", holder, action, tool, "no live window")
        return 1
    if before is not None and before > now:
        _emit("deny", holder, action, tool, "window not open yet")
        return 1

    if action == "service-start":
        if grant.get("allow_service_start") and not grant.get("read_only_only"):
            _emit("allow", holder, action, tool, "service-start granted")
            return 0
        _emit("deny", holder, action, tool, "service-start not granted")
        return 1

    if action == "exec":
        if grant.get("read_only_only") and not grant.get("allow_service_start"):
            _emit("deny", holder, action, tool, "read-only holder")
            return 1
        cats = grant.get("categories") or []
        tools = grant.get("tools") or []
        cat = _tool_category(tool) if tool else None
        if tool and tool not in tools and (cat is None or cat not in cats):
            _emit("deny", holder, action, tool, "out of scope")
            return 1
        safety = _tool_safety(tool) if tool else None
        if safety == "exp" and not grant.get("allow_exp"):
            _emit("deny", holder, action, tool, "exp row without allow_exp")
            return 1
        _emit("allow", holder, action, tool, "in scope")
        return 0

    _emit("deny", holder, action, tool, "unknown action")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
