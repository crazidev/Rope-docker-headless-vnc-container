#!/usr/bin/env bash
# Idempotent layout and model bootstrap under /workspace (Runpod volume).
set -euo pipefail

export MODELS_DIR="${WORKSPACE_MODELS:-/workspace/data/models}"
mkdir -p "$MODELS_DIR" /workspace/data/config \
  /workspace/data/cache/pip \
  /workspace/data/cache/conda/pkgs \
  /workspace/data/cache/uv \
  /workspace/data/cache/xdg

# Persist pip / conda download caches on the Runpod volume (speeds repeated pip/conda installs).
# Sourced by vnc_startup_rope_live.sh unless WORKSPACE_PYTHON_CACHE=0.
cat > /workspace/data/cache/exports.env <<'ENVEOF'
PIP_CACHE_DIR=/workspace/data/cache/pip
CONDA_PKGS_DIRS=/workspace/data/cache/conda/pkgs
UV_CACHE_DIR=/workspace/data/cache/uv
XDG_CACHE_HOME=/workspace/data/cache/xdg
ENVEOF
chmod 0644 /workspace/data/cache/exports.env
echo "[bootstrap] Python-related caches -> /workspace/data/cache (see exports.env)"

INSWAPPER_URL="${INSWAPPER_URL:-https://github.com/argenspin/rope-assets/releases/download/1.0.0/inswapper_128.fp16.onnx}"
TARGET="$MODELS_DIR/inswapper_128.fp16.onnx"

if [ ! -f "$TARGET" ]; then
  echo "[bootstrap] Downloading inswapper_128.fp16.onnx ..."
  rm -f "$TARGET.partial"
  if ! wget --no-hsts -nv -O "$TARGET.partial" "$INSWAPPER_URL"; then
    rm -f "$TARGET.partial"
    exit 1
  fi
  mv "$TARGET.partial" "$TARGET"
  echo "[bootstrap] Model ready at $TARGET"
else
  echo "[bootstrap] inswapper_128.fp16.onnx already present"
fi

ROPE_LIVE_HOME="${ROPE_LIVE_HOME:-/opt/Rope-Live}"
if [ -d "$ROPE_LIVE_HOME" ]; then
  if [ -e "$ROPE_LIVE_HOME/models" ] && [ ! -L "$ROPE_LIVE_HOME/models" ]; then
    rm -rf "$ROPE_LIVE_HOME/models"
  fi
  ln -sfn "$MODELS_DIR" "$ROPE_LIVE_HOME/models"
  echo "[bootstrap] $ROPE_LIVE_HOME/models -> $MODELS_DIR"
fi
