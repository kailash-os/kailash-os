#!/usr/bin/env bash
# KA-08.5 (kailash-os#109) — the platform-VM acceptance harness.
#
# Boots nothing and fabricates nothing. It is the CI-checkable probe
# pair that asserts the acceptance against REAL running endpoints:
#
#   1. ollama  — POST /api/generate completes a one-token-scale prompt
#                (the response text is non-empty)
#   2. MLflow  — GET /health answers HTTP 200 on the tracking server
#
# Run it where the endpoints are:
#
#   * INSIDE the booted platform VM (the canonical run — both services
#     bind the loopback per the §11.2 posture, so guest-side curl is the
#     real surface):
#         kailash-vm-acceptance
#   * FROM THE HOST at a qemu port-forward (hostfwd target = the guest
#     address, NOT the guest loopback — the acceptance-vm fixture host
#     nixosConfigurations.kailash-platform-acceptance carries the
#     documented lab posture: ollama binds 0.0.0.0 (the o-04 docs'
#     operator move; the qemu user-net VM is an isolated lab segment,
#     no default-route interface), MLflow's labReachable (the module's
#     documented 0.0.0.0 lab bind); only services bound off the guest
#     loopback are reachable through hostfwd):
#         kailash-vm-acceptance --ollama-url http://127.0.0.1:2222 \
#           --mlflow-url http://127.0.0.1:5001
#   * against any lab host exposing the services:
#         kailash-vm-acceptance --ollama-url http://lab:11434 ...
#
# THE VM BOOT ITSELF is the maintainer's interactive step on macOS
# (qemu-system-x86_64, TCG — this lane's host has no Linux builder):
#
#     nix build .#checks.x86_64-linux.kailash-platform-vm-acceptance \
#       --system x86_64-linux   # after a hosted-green run: substitutes
#     result-vm/bin/nixos-vm
#
# ...with the boot-wait below as the unattended tail (--wait-seconds).
#
# Verdict discipline: the probes print ATTEMPTED/REACHABLE/ok/FAIL —
# never "PASS" — and every probe's verbatim output is echoed so the
# record capture has the real text. With --record, the verbatim
# endpoint outputs are written to a `real` JSON record for
# tests/vm-acceptance-record.json + the record verifier.

set -euo pipefail

OLLAMA_URL="http://127.0.0.1:11434"
MLFLOW_URL="http://127.0.0.1:5000"
OLLAMA_MODEL="qwen2.5:0.5b"   # the O-4 module header's documented tiny model
WAIT_SECONDS="300"
RECORD=""

usage() {
  sed -n '2,45p' "$0" | sed 's/^# \{0,1\}//'
  echo "usage: kailash-vm-acceptance [--wait-seconds N] [--ollama-model NAME]"
  echo "           [--ollama-url URL] [--mlflow-url URL] [--record PATH]"
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --wait-seconds) WAIT_SECONDS="$2"; shift 2 ;;
    --ollama-model) OLLAMA_MODEL="$2"; shift 2 ;;
    --ollama-url)   OLLAMA_URL="$2"; shift 2 ;;
    --mlflow-url)   MLFLOW_URL="$2"; shift 2 ;;
    --record)       RECORD="$2"; shift 2 ;;
    -h|--help)      usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "kailash-vm-acceptance: FAIL: missing required tool: $1" >&2
    exit 1
  }
}
need curl
need jq

echo "== KA-08.5 platform-VM acceptance harness =="
echo "ollama: $OLLAMA_URL (model: $OLLAMA_MODEL)"
echo "mlflow: $MLFLOW_URL"
echo

# ---- stage 1: boot-wait ------------------------------------------------
# The services rise with the booted host; poll the ollama daemon (the
# slower of the pair) until it answers or the window closes. A closed
# window is an ATTEMPTED-not-REACHABLE verdict — exit 1, exit code that
# CI can hang a boot-wait retry on.
echo "--- boot-wait: polling $OLLAMA_URL/api/tags (window: ${WAIT_SECONDS}s)"
deadline=$(( $(date +%s) + WAIT_SECONDS ))
reachable=""
while [ "$(date +%s)" -lt "$deadline" ]; do
  if body="$(curl -fsS -m 5 "$OLLAMA_URL/api/tags" 2>/dev/null)"; then
    reachable=1
    echo "boot-wait: REACHABLE after $(( deadline - $(date +%s) + WAIT_SECONDS - WAIT_SECONDS ))s — /api/tags:"
    printf '%s\n' "$body" | jq -c '.' | head -c 2000
    echo
    break
  fi
  sleep 3
done
if [ -z "$reachable" ]; then
  echo "boot-wait: ATTEMPTED, not REACHABLE within ${WAIT_SECONDS}s — the VM is not up (boot hung? window too short?)"
  exit 1
fi

fail=0

# ---- stage 2: ollama prompt -------------------------------------------
echo "--- ollama: POST /api/generate (one completion, stream off)"
payload="$(jq -n --arg m "$OLLAMA_MODEL" \
  '{model: $m, prompt: "Reply with exactly: KA-08.5 ollama prompt complete", stream: false}')"
echo "command: curl -fsS -m 300 -H 'Content-Type: application/json' -d '$payload' $OLLAMA_URL/api/generate"
if out="$(curl -fsS -m 300 -H 'Content-Type: application/json' -d "$payload" "$OLLAMA_URL/api/generate" 2>&1)"; then
  response_text="$(printf '%s' "$out" | jq -r '.response // empty' 2>/dev/null || true)"
  echo "verbatim response (trimmed):"
  printf '%s\n' "$out" | head -c 3000
  echo
  if [ -n "$response_text" ]; then
    echo "ollama-11434-prompt: ok — non-empty model response:"
    printf '%s\n' "$response_text"
    verbatim_ollama="$(printf '%s\n' "$out" | head -c 8000)"
  else
    echo "ollama-11434-prompt: FAIL — 200 but .response empty (model not pulled? try: ollama pull $OLLAMA_MODEL in the VM)"
    fail=1
    verbatim_ollama="$(printf '%s\n' "$out" | head -c 8000)"
  fi
else
  echo "ollama-11434-prompt: FAIL — curl error:"
  printf '%s\n' "$out" | head -c 3000
  echo
  verbatim_ollama="FAIL: $out"
  fail=1
fi

echo

# ---- stage 3: MLflow health -------------------------------------------
echo "--- mlflow: GET /health"
echo "command: curl -fsS $MLFLOW_URL/health"
if out="$(curl -fsS -m 30 "$MLFLOW_URL/health" 2>&1)"; then
  echo "mlflow-5000-health: ok — verbatim response:"
  printf '%s\n' "$out" | head -c 2000
  verbatim_mlflow="$(printf '%s\n' "$out" | head -c 8000)"
else
  echo "mlflow-5000-health: FAIL — curl error:"
  printf '%s\n' "$out" | head -c 3000
  echo
  verbatim_mlflow="FAIL: $out"
  fail=1
fi

echo

# ---- record ------------------------------------------------------------
if [ -n "$RECORD" ] && [ "$fail" -eq 0 ]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)"
  jq -n \
    --arg ts "$ts" \
    --arg verbatim_ollama "$verbatim_ollama" \
    --arg verbatim_mlflow "$verbatim_mlflow" \
    --arg omodel "$OLLAMA_MODEL" \
    --arg ourl "$OLLAMA_URL" \
    --arg murl "$MLFLOW_URL" \
    '{status: "real", recorded_at: $ts,
      endpoint_checks: {
        "ollama-11434-prompt": {
          verdict: "ok", endpoint: $ourl, model: $omodel,
          command: ("POST /api/generate prompt completed against " + $ourl),
          verbatim: $verbatim_ollama},
        "mlflow-5000-health": {
          verdict: "ok", endpoint: $murl,
          command: ("GET /health against " + $murl),
          verbatim: $verbatim_mlflow}},
      verbatim_sections: ["ollama-11434-prompt", "mlflow-5000-health"],
      commands: ["POST /api/generate (ollama)", "GET /health (mlflow)"]}' \
    > "$RECORD"
  echo "record written: $RECORD"
fi

if [ "$fail" -ne 0 ]; then
  echo "kailash-vm-acceptance: FAIL (one or both endpoints did not clear)"
  exit 1
fi
echo "kailash-vm-acceptance: BOTH endpoint checks ok"
