#!/usr/bin/env bash
# Install OBS Studio on first run (keeps image smaller; logs to volume + stderr for Runpod).
set -euo pipefail

LOG="${RUNTIME_INSTALL_LOG:-/workspace/data/install.log}"
mkdir -p "$(dirname "$LOG")"
stamp="${OBS_INSTALL_STAMP:-/workspace/data/.obs-studio-installed}"

if [[ "${SKIP_OBS_INSTALL:-0}" == "1" ]]; then
  echo "[obs] SKIP_OBS_INSTALL=1, skipping."
  exit 0
fi

if command -v obs >/dev/null 2>&1; then
  echo "[obs] already on PATH ($(command -v obs))"
  exit 0
fi

if [[ -f "$stamp" ]]; then
  echo "[obs] stale stamp without binary, reinstalling"
  rm -f "$stamp"
fi

install_obs() {
  echo "[obs] apt install obs-studio starting $(date -Is)"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends obs-studio
  date -Is >"$stamp"
  echo "[obs] done $(date -Is)"
}

install_obs 2>&1 | tee -a "$LOG"
