#!/bin/bash
### every exit != 0 fails the script
set -e

## print out help
help (){
echo "
USAGE:
docker run -it -p 6901:6901 -p 5901:5901 -p 1935:1935 -p 8554:8554 -p 8890:8890/udp <image> <option>

OPTIONS:
-w, --wait      (default) keeps the UI and the vncserver up until SIGINT or SIGTERM
-s, --skip      skip the VNC startup and just execute the assigned command
-d, --debug     enables more detailed startup output
-h, --help      print out this help

Rope-Live + Larix ingest (RTMP/SRT via MediaMTX) + v4l2loopback. See README for Runpod.

Fore more information see: https://github.com/ConSol/docker-headless-vnc-container
"
}
if [[ $1 =~ -h|--help ]]; then
    help
    exit 0
fi

case "${FACESWAP_BACKEND:-rope-live}" in
  rope-live) ;;
  deeplive|deepfacelive)
    echo "FACESWAP_BACKEND=${FACESWAP_BACKEND} is not implemented yet. Only rope-live is supported."
    exit 2
    ;;
  *)
    echo "Unknown FACESWAP_BACKEND=${FACESWAP_BACKEND}"
    exit 2
    ;;
esac

# should also source $STARTUPDIR/generate_container_user
source $HOME/.bashrc

# add `--skip` to startup args, to skip the VNC startup procedure
if [[ $1 =~ -s|--skip ]]; then
    echo -e "\n\n------------------ SKIP VNC STARTUP -----------------"
    echo -e "\n\n------------------ EXECUTE COMMAND ------------------"
    echo "Executing command: '${@:2}'"
    exec "${@:2}"
fi
if [[ $1 =~ -d|--debug ]]; then
    echo -e "\n\n------------------ DEBUG VNC STARTUP -----------------"
    export DEBUG=true
fi

## correct forwarding of shutdown signal
cleanup () {
    kill -s SIGTERM $! 2>/dev/null || true
    exit 0
}
trap cleanup SIGINT SIGTERM

## resolve_vnc_connection
VNC_IP=$(hostname -i)

echo -e "\n------------------ Rope-Live workspace bootstrap ------------------"
bash "$STARTUPDIR/bootstrap-workspace.sh"

if [[ "${WORKSPACE_PYTHON_CACHE:-1}" != "0" ]] && [[ -f /workspace/data/cache/exports.env ]]; then
  # shellcheck source=/dev/null
  set -a && source /workspace/data/cache/exports.env && set +a
  echo "[cache] Using volume-backed PIP_CACHE_DIR and CONDA_PKGS_DIRS (disable with WORKSPACE_PYTHON_CACHE=0)"
fi

CONDA_ENV_PREFIX="${CONDA_ENV_PREFIX:-/workspace/data/conda/envs/RopeLive}"
ROPE_LIVE_HOME="${ROPE_LIVE_HOME:-/workspace/data/Rope-Live}"
ROPE_PY="${CONDA_ENV_PREFIX}/bin/python"
JUPYTER_BIN="${CONDA_ENV_PREFIX}/bin/jupyter"
INSTALL_LOG="${RUNTIME_INSTALL_LOG:-/workspace/data/install.log}"
mkdir -p "$(dirname "$INSTALL_LOG")"

## change vnc password
echo -e "\n------------------ change VNC password  ------------------"
mkdir -p "$HOME/.vnc"
PASSWD_PATH="$HOME/.vnc/passwd"

if [[ -f $PASSWD_PATH ]]; then
    echo -e "\n---------  purging existing VNC password settings  ---------"
    rm -f $PASSWD_PATH
fi

if [[ $VNC_VIEW_ONLY == "true" ]]; then
    echo "start VNC server in VIEW ONLY mode!"
    echo $(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20) | vncpasswd -f > $PASSWD_PATH
fi
echo "$VNC_PW" | vncpasswd -f >> $PASSWD_PATH
chmod 600 $PASSWD_PATH


## start vncserver and noVNC webclient
echo -e "\n------------------ start noVNC  ----------------------------"
if [[ $DEBUG == true ]]; then echo "$NO_VNC_HOME/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT"; fi
$NO_VNC_HOME/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT > $STARTUPDIR/no_vnc_startup.log 2>&1 &
PID_SUB=$!

vncserver -kill $DISPLAY &> $STARTUPDIR/vnc_startup.log \
    || rm -rfv /tmp/.X*-lock /tmp/.X11-unix &> $STARTUPDIR/vnc_startup.log \
    || echo "no locks present"

echo -e "start vncserver with param: VNC_COL_DEPTH=$VNC_COL_DEPTH, VNC_RESOLUTION=$VNC_RESOLUTION\n..."

vnc_cmd="vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION PasswordFile=$HOME/.vnc/passwd --I-KNOW-THIS-IS-INSECURE"
if [[ ${VNC_PASSWORDLESS:-} == "true" ]]; then
  vnc_cmd="${vnc_cmd} -SecurityTypes None"
fi

if [[ $DEBUG == true ]]; then echo "$vnc_cmd"; fi
$vnc_cmd > $STARTUPDIR/no_vnc_startup.log 2>&1

echo -e "start window manager\n..."
$HOME/wm_startup.sh &> $STARTUPDIR/wm_startup.log

## log connect options
echo -e "\n\n------------------ VNC environment started ------------------"
echo -e "\nVNCSERVER started on DISPLAY= $DISPLAY \n\t=> connect via VNC viewer with $VNC_IP:$VNC_PORT"
echo -e "\nnoVNC HTML client started:\n\t=> connect via http://$VNC_IP:$NO_VNC_PORT/?password=...\n"
echo -e "Desktop is up. Conda/pip install runs next in the background — tail $INSTALL_LOG or watch Runpod logs.\n"

echo -e "Starting filebrowser at port 8585..."
nohup filebrowser -r /workspace -p 8585 -a 0.0.0.0 --noauth &

echo -e "\n------------------ OBS Studio (runtime install) ------------------"
bash "$STARTUPDIR/install-obs.sh"

echo -e "\n------------------ Rope-Live runtime install (conda, clone, pip, Jupyter) in background ------------------"
(
  bash "$STARTUPDIR/deferred-install.sh" 2>&1 | tee -a "$INSTALL_LOG" | tee /dev/stderr
) &
DEFERRED_PID=$!

echo -e "\n------------------ v4l2loopback ------------------"
bash "$STARTUPDIR/setup-v4l2.sh"

if [[ "${INGEST_MODE:-rtmp}" != "off" ]]; then
  echo -e "\n------------------ Larix ingest (MediaMTX + FFmpeg) ------------------"
  bash "$STARTUPDIR/start-ingest.sh" >>"$STARTUPDIR/ingest.log" 2>&1 &
fi

echo -e "\n------------------ Jupyter + Rope-Live (after runtime install finishes) ------------------"
(
  wait "$DEFERRED_PID" || true
  CONDA_ENV_PREFIX="${CONDA_ENV_PREFIX:-/workspace/data/conda/envs/RopeLive}"
  ROPE_LIVE_HOME="${ROPE_LIVE_HOME:-/workspace/data/Rope-Live}"
  ROPE_PY="${CONDA_ENV_PREFIX}/bin/python"
  JUPYTER_BIN="${CONDA_ENV_PREFIX}/bin/jupyter"
  if [[ -x "$JUPYTER_BIN" ]]; then
    echo -e "Starting jupyterlab at port 8080..."
    nohup "$JUPYTER_BIN" lab --port 8080 --notebook-dir=/workspace --allow-root --no-browser --ip=0.0.0.0 --NotebookApp.token='' --NotebookApp.password='' &
  else
    echo "[jupyter] skipped (install incomplete or env missing; see $INSTALL_LOG)"
  fi
  if [[ -x "$ROPE_PY" ]] && [[ -f "${ROPE_LIVE_HOME}/Rope.py" ]]; then
    echo -e "Starting Rope-Live..."
    cd "$ROPE_LIVE_HOME"
    nohup "$ROPE_PY" Rope.py >>"$STARTUPDIR/rope-live.log" 2>&1 &
    echo "Rope-Live started in background (log: $STARTUPDIR/rope-live.log, PID $!)"
  else
    echo "[rope-live] skipped: missing $ROPE_PY or ${ROPE_LIVE_HOME}/Rope.py — see $INSTALL_LOG"
  fi
) &

if [[ $DEBUG == true ]] || [[ $1 =~ -t|--tail-log ]]; then
    echo -e "\n------------------ $HOME/.vnc/*$DISPLAY.log ------------------"
    tail -f $STARTUPDIR/*.log $HOME/.vnc/*$DISPLAY.log
fi

if [ -z "$1" ] || [[ $1 =~ -w|--wait ]]; then
    wait $PID_SUB
else
    echo -e "\n\n------------------ EXECUTE COMMAND ------------------"
    echo "Executing command: '$@'"
    exec "$@"
fi
