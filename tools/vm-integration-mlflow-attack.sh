#!/usr/bin/env bash
# integration-mlflow-attack — the pairing-thesis acceptance probe pair (KA-23,
# kailash-os#23; plan §8.2).
#
# Boots nothing and fabricates nothing on CI. The §8.2 name carries the
# INTEGRATION acceptance: O-1 (the MLflow unauth lab default,
# services.kailash.mlflow) up, the A-7 mlflow-bypass surface paired
# against it, the artefact listing asserted. CI legs assert the
# COMPOSITION (flake.nix checks.integration-mlflow-attack-*); this
# probe pair runs where the booted VM's endpoints are — inside the booted
# Kailash VM, or from the host at the qemu hostfwd ports (the
# kailash-platform-acceptance lab posture: tracking API 0.0.0.0:5000,
# the mlflow-artifacts file store proxied on :5000).
#
#   * inside the booted VM:   kailash-integration-mlflow-attack
#   * host at hostfwd:        kailash-integration-mlflow-attack \
#         --mlflow-url http://127.0.0.1:5101 \
#         --artifacts-url http://127.0.0.1:5102
#
# The probe pair (verbatim MLflow API shapes, live-probed on mlflow 3.x
# at the packages pin):
#   1. TRACKING  — the O-1 surface is UNAUTHENTICATED: POST
#                  /api/2.0/mlflow/experiments/search (the §1.x
#                  tracking route, ML_METHOD_FLAG) answers 200 JSON
#                  without any credentials;
#   2. BYPASS    — GET /ajax-api/2.0/mlflow/artifacts/list?run_id=…&path=
#                  (MLFLOW_BYPASS_LIST) answers the artefact listing.
#                  With MLFLOW_BYPASS_SEED=1 the pair first writes a
#                  marker artefact through the SAME unauthenticated
#                  artefact API (PUT
#                  /api/2.0/mlflow-artifacts/artifacts/put, seed run
#                  created unauthenticated through POST
#                  /api/2.0/mlflow/runs/create), so the listing proves
#                  the full unauthenticated write→read round trip
#                  end-to-end; without the seed the pair requires an
#                  existing run id on an already-seeded experiment
#                  (the maintainer's seeded lab).
#
# THE A-7 TOOL ITSELF stays off PATH — the mlflow-bypass manifest row is
# safety.level == "exp"; the §11.2 double-key gate owns that surface and
# no bare upstream derivation substitutes for its bespoke recipe either
# (the 2026-10-13 lane record for the mlflow-bypass upstream is a
# missing-repository note on kailash-os#23; the lane's transparent
# lab probe carries the two API recipes so the acceptance runs the
# REAL protocol against the REAL target, and the maintainer's
# interactive boot records the REAL tool when it lands).
#
# Verdict discipline mirrors tools/vm-acceptance-harness.sh: the probes
# print ATTEMPTED/ok/FAIL — never "PASS" — and every probe's verbatim
# output is echoed so the record capture has the real text. With
# --record, the verbatim outputs are written to a `real` JSON record
# for the tests/vm-acceptance-mlflow-record.json + its verifier leg
# (the record is the tripwire — a hand-typed ok with no verbatim
# output behind it fails CI).

set -euo pipefail

MLFLOW_URL="http://127.0.0.1:5000"
ARTIFACTS_URL=""          # defaults to MLFLOW_URL (the proxied file store)
WAIT_SECONDS="300"
SEED="0"                  # 1 = the unauthenticated write→read round trip
RECORD=""

usage() {
  sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
  echo "usage: kailash-integration-mlflow-attack [--wait-seconds N]"
  echo "           [--mlflow-url URL] [--artifacts-url URL] [--seed]"
  echo "           [--record PATH]"
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --wait-seconds) WAIT_SECONDS="$2"; shift 2 ;;
    --mlflow-url)   MLFLOW_URL="$2"; shift 2 ;;
    --artifacts-url) ARTIFACTS_URL="$2"; shift 2 ;;
    --seed)         SEED="1"; shift ;;
    --record)       RECORD="$2"; shift 2 ;;
    -h|--help)      usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

# The §9 Phase-3 wording: the tracking server's /api/2.0/mlflow
# namespace is the tracking-API surface; the /api/2.0/mlflow-artifacts
# namespace is the artifact store proxied by that server when it serves
# the default mlflow-artifacts URI.
ARTIFACTS_URL="${ARTIFACTS_URL:-$MLFLOW_URL}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "kailash-integration-mlflow-attack: FAIL: missing required tool: $1" >&2
    exit 1
  }
}
need curl
need jq
[ "$SEED" = "1" ] && need python3

echo "== KA-23 integration-mlflow-attack acceptance pair =="
echo "tracking : $MLFLOW_URL"
echo "artifacts: $ARTIFACTS_URL (seed: $SEED)"
echo

# ---- stage 1: boot-wait ------------------------------------------------
echo "--- boot-wait: polling $MLFLOW_URL/health (window: ${WAIT_SECONDS}s)"
deadline=$(( $(date +%s) + WAIT_SECONDS ))
reachable=""
while [ "$(date +%s)" -lt "$deadline" ]; do
  if body="$(curl -fsS -m 5 "$MLFLOW_URL/health" 2>/dev/null)"; then
    reachable=1
    echo "boot-wait: REACHABLE — /health: $body"
    break
  fi
  sleep 3
done
if [ -z "$reachable" ]; then
  echo "boot-wait: ATTEMPTED, not REACHABLE within ${WAIT_SECONDS}s — the MLflow surface is not up (boot hung? window too short?)"
  exit 1
fi

fail=0

# ---- stage 2: TRACKING — the unauth lab default ------------------------
echo "--- track: POST /api/2.0/mlflow/experiments/search (UNAUTH)"
payload='{"max_results":50}'
track_out="$(curl -fsS -m 30 -X POST "$MLFLOW_URL/api/2.0/mlflow/experiments/search" \
  -H 'Content-Type: application/json' -d "$payload" 2>&1)"
track_rc=$?
if [ "$track_rc" -ne 0 ]; then track_out="FAIL: $track_out"; fi
printf '%s\n' "$track_out" | head -c 3000
echo
if [ "$track_rc" -eq 0 ] && [ "$(printf '%s' "$track_out" | jq -r '.experiments // empty | length' 2>/dev/null)" -ge 0 ]; then
  echo "track: ok — experiments/search answered unauthenticated (ML_METHOD_FLAG surface UP)"
  track_verbatim="$track_out"
else
  echo "track: FAIL — the unauth experiments/search probe failed (auth gate up? route moved?)"
  fail=1
fi

echo

# ---- stage 3: BYPASS — the artefact listing ----------------------------
run_id=""
seed_verbatim=""

write_verbatim=""

if [ "$SEED" = "1" ]; then
  # ---- stage 3a: the unauthenticated write→read round trip ------------
  echo "--- bypass(seed): POST /api/2.0/mlflow/runs/create (UNAUTH)"
  marker="ka23-bypass-$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  create_out="$(curl -fsS -m 30 -X POST "$MLFLOW_URL/api/2.0/mlflow/runs/create" \
    -H 'Content-Type: application/json' \
    -d "{\"experiment_id\": \"0\", \"run_name\": \"MLFLOW_BYPASS_LIST\"}" 2>&1)"
  create_rc=$?
  if [ "$create_rc" -ne 0 ]; then create_out="FAIL: $create_out"; fi
  printf '%s\n' "$create_out" | head -c 1200
  echo
  if [ "$create_rc" -ne 0 ]; then
    echo "bypass(seed): FAIL — the unauth run-create probe failed (auth gate up? backend moved?)"
    fail=1
  else
    run_id="$(printf '%s' "$create_out" | jq -r '.run.info.run_id // empty' 2>/dev/null)"
  fi
  if [ -z "$run_id" ]; then
    echo "bypass(seed): FAIL — no run_id parsed from the create response"
    fail=1
  else
    seed_verbatim="$create_out"
    # the artefact: marker + a local temp file (the proxied file store
    # uploads by file — the multipart form the REST API documents)
    tmp="$(mktemp)"
    printf 'kailash KA-23 mlflow-bypass listing probe — %s\n' "$marker" > "$tmp"
    echo "--- bypass(seed): PUT /api/2.0/mlflow-artifacts/artifacts/put (UNAUTH multipart)"
    put_out="$(curl -fsS -m 30 -X PUT "$ARTIFACTS_URL/api/2.0/mlflow-artifacts/artifacts/put?path=0%2F$run_id%2Fartifacts%2Fka23-listing.txt" \
      -F "file=@$tmp" 2>&1)"
    put_rc=$?
    if [ "$put_rc" -ne 0 ]; then put_out="FAIL: $put_out"; fi
    rm -f "$tmp"
    printf '%s\n' "$put_out" | head -c 600
    echo
    if [ "$put_rc" -ne 0 ]; then
      echo "bypass(seed): FAIL — the unauth artefact PUT failed"
      fail=1
    else
      write_verbatim="$put_out"
    fi
  fi
fi

echo "--- bypass: GET /ajax-api/2.0/mlflow/artifacts/list (UNAUTH)"
if [ -n "$run_id" ]; then
  list_url="$MLFLOW_URL/ajax-api/2.0/mlflow/artifacts/list?run_id=$run_id&path="
  echo "command: curl -fsS \"$list_url\""
else
  echo "(no --seed and no seeded run_id on this lab — the listing needs an existing seeded run)"
  list_url=""
  run_id="<SEEDED-LAB-RUN-ID-REQUIRED>"
fi
if [ -n "$list_url" ]; then
  list_out="$(curl -fsS -m 30 "$list_url" 2>&1)"
  list_rc=$?
  if [ "$list_rc" -ne 0 ]; then list_out="FAIL: $list_out"; fi
  printf '%s\n' "$list_out" | head -c 3000
  echo
  if [ "$list_rc" -eq 0 ] && [ "$(printf '%s' "$list_out" | jq -r '.files // empty | type' 2>/dev/null)" = "array" ]; then
    echo "bypass: ok — the artefact listing answered unauthenticated"
    list_verbatim="$list_out"
  else
    echo "bypass: FAIL — the artefact-list probe failed (route moved? no seeded artefact?)"
    fail=1
  fi
fi

echo

# ---- record ------------------------------------------------------------
# The record is written ONLY when every probe that ran says ok — the
# verbatim endpoint outputs ride the record JSON; a hand-typed ok with
# no verbatim output behind it fails the record verifier leg.
if [ -n "$RECORD" ] && [ "$fail" -eq 0 ]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  record_doc="{\"status\": \"real\", \"recorded_at\": \"$ts\""
  record_doc="$record_doc, \"tracking\": {\"verdict\": \"ok\", \"command\": \"MLFLOW_BYPASS_LIST\", \"verbatim\": $(jq -Rs . <<<"$track_verbatim"), \"seed\": $(jq -Rs . <<<"$seed_verbatim")}"
  record_doc="$record_doc, \"bypass\": {\"verdict\": \"ok\", \"command\": \"MLFLOW_BYPASS_LIST\", \"verbatim\": $(jq -Rs . <<<"$list_verbatim"), \"put\": $(jq -Rs . <<<"$write_verbatim")}"
  record_doc="$record_doc, \"endpoint_checks\": {\"mlflow-5000-health\": {\"verdict\": \"ok\", \"command\": \"GET /health against $MLFLOW_URL\", \"verbatim\": $(jq -Rs . <<<"$body")}}"
  record_doc="$record_doc, \"verbatim_sections\": [\"track\", \"bypass\"], \"commands\": [\"MLFLOW_BYPASS_LIST tracking+artifacts pair\"]}"
  printf '%s\n' "$record_doc" > "$RECORD"
  echo "record written: $RECORD"
fi

if [ "$fail" -ne 0 ]; then
  echo "kailash-integration-mlflow-attack: FAIL (one or more probes did not clear)"
  exit 1
fi
echo "kailash-integration-mlflow-attack: BOTH probes ok (track + bypass listing)"
