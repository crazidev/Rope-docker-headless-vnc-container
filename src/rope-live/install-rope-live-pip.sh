#!/usr/bin/env bash
set -euo pipefail
cd "${ROPE_LIVE_HOME:?ROPE_LIVE_HOME must be set}"

req="/tmp/rope-live-requirements-filtered.txt"
if [ "${INSTALL_TENSORRT:-0}" = "1" ]; then
  cp requirements.txt "$req"
else
  # Do not strip tensorrt-cu11: Rope-Live imports tensorrt at module load; a line like
  # "tensorrt-cu11" must stay. Only drop a bare "tensorrt" package line (word boundary).
  grep -vE '^[[:space:]]*tensorrt([[:space:]]|$)' requirements.txt >"$req" || cp requirements.txt "$req"
fi

pip install --no-cache-dir -r "$req"
