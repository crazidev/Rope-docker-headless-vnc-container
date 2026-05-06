#!/usr/bin/env bash
# First boot: conda env on /workspace, Rope-Live clone, pip + Jupyter — streams to install.log and stdout (Runpod).
set -euo pipefail

STARTUPDIR="${STARTUPDIR:-/dockerstartup}"
STAMP="${ROPE_RUNTIME_STAMP:-/workspace/data/.rope-live-runtime-ready}"
LOG="${RUNTIME_INSTALL_LOG:-/workspace/data/install.log}"
CONDA_ENV_PREFIX="${CONDA_ENV_PREFIX:-/workspace/data/conda/envs/RopeLive}"
ROPE_LIVE_HOME="${ROPE_LIVE_HOME:-/workspace/data/Rope-Live}"
ROPE_LIVE_GIT="${ROPE_LIVE_GIT:-https://github.com/argenspin/Rope-Live.git}"
MODELS_DIR="${WORKSPACE_MODELS:-/workspace/data/models}"
INSTALL_TENSORRT="${INSTALL_TENSORRT:-0}"

mkdir -p "$(dirname "$LOG")" "$CONDA_ENV_PREFIX" "$(dirname "$ROPE_LIVE_HOME")"

if [[ "${SKIP_WORKSPACE_INSTALL:-0}" == "1" ]]; then
  echo "[runtime-install] SKIP_WORKSPACE_INSTALL=1"
  exit 0
fi

if [[ "${FORCE_REINSTALL:-0}" == "1" ]]; then
  rm -f "$STAMP"
fi

if [[ -f "$STAMP" ]] && [[ -x "${CONDA_ENV_PREFIX}/bin/python" ]] && [[ -f "${ROPE_LIVE_HOME}/Rope.py" ]]; then
  echo "[runtime-install] Already complete ($STAMP)"
  exit 0
fi

exec > >(tee -a "$LOG") 2>&1

echo "========== Rope-Live runtime install started $(date -Is) =========="

source /opt/conda/etc/profile.d/conda.sh

export DEBIAN_FRONTEND=noninteractive
echo "[runtime-install] apt: build-essential, git"
apt-get update -qq
apt-get install -y --no-install-recommends build-essential git

echo "[runtime-install] conda ToS + env at $CONDA_ENV_PREFIX"
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

if [[ ! -x "${CONDA_ENV_PREFIX}/bin/python" ]]; then
  conda create -y -p "$CONDA_ENV_PREFIX" python=3.10.13
fi
conda clean -afy 2>/dev/null || true

export PATH="${CONDA_ENV_PREFIX}/bin:/opt/conda/bin:$PATH"

echo "[runtime-install] git clone Rope-Live -> $ROPE_LIVE_HOME"
if [[ ! -f "${ROPE_LIVE_HOME}/Rope.py" ]]; then
  rm -rf "$ROPE_LIVE_HOME"
  git clone --depth 1 "$ROPE_LIVE_GIT" "$ROPE_LIVE_HOME"
fi

echo "[runtime-install] pip install Rope-Live requirements (long)"
bash "$STARTUPDIR/install-rope-live-pip.sh"

echo "[runtime-install] JupyterLab"
pip install jupyterlab

echo "[runtime-install] models symlink -> $MODELS_DIR"
mkdir -p "$MODELS_DIR"
if [[ -e "${ROPE_LIVE_HOME}/models" ]] && [[ ! -L "${ROPE_LIVE_HOME}/models" ]]; then
  rm -rf "${ROPE_LIVE_HOME}/models"
fi
ln -sfn "$MODELS_DIR" "${ROPE_LIVE_HOME}/models"

if ! grep -qF "conda activate $CONDA_ENV_PREFIX" /root/.bashrc 2>/dev/null; then
  {
    echo ""
    echo "# Rope-Live workspace conda (runtime install)"
    echo "source /opt/conda/etc/profile.d/conda.sh"
    echo "conda activate $CONDA_ENV_PREFIX"
  } >>/root/.bashrc
fi

date -Is >"$STAMP"
echo "========== Rope-Live runtime install finished $(date -Is) =========="
