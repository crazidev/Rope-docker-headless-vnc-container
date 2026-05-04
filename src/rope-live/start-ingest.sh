#!/bin/bash
# Larix (or any RTMP publisher) -> MediaMTX -> FFmpeg -> v4l2loopback.
# SRT: set INGEST_MODE=srt and use INGEST_SOURCE_URL override if needed.
set -euo pipefail

INGEST_MODE="${INGEST_MODE:-rtmp}"
V4L2_DEVICE="${V4L2_DEVICE:-/dev/video10}"
RTMP_PATH="${RTMP_PATH:-live/ingest}"
INGEST_SCALE="${INGEST_SCALE:-1280:720}"
INGEST_FPS="${INGEST_FPS:-30}"
# Set INGEST_LOW_LATENCY=1 for smaller FFmpeg demux/decode delay (tradeoff: less tolerant of jitter).
INGEST_LOW_LATENCY="${INGEST_LOW_LATENCY:-0}"

if [ "$INGEST_MODE" = "off" ]; then
  echo "[ingest] INGEST_MODE=off, exiting ingest helper"
  exit 0
fi

if [ -n "${INGEST_SOURCE_URL:-}" ]; then
  SOURCE_URL="$INGEST_SOURCE_URL"
elif [ "${INGEST_MODE}" = "srt" ]; then
  SOURCE_URL="srt://127.0.0.1:8890?streamid=read:live/ingest&latency=200"
else
  SOURCE_URL="rtsp://127.0.0.1:8554/${RTMP_PATH}"
fi

echo "[ingest] INGEST_MODE=$INGEST_MODE SOURCE_URL=$SOURCE_URL -> $V4L2_DEVICE"

/usr/local/bin/mediamtx /etc/mediamtx.yml &
MTX_PID=$!
sleep 1
kill -0 "$MTX_PID" || { echo "[ingest] ERROR: mediamtx failed to start"; exit 1; }

cleanup() {
  kill "$MTX_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "[ingest] MediaMTX PID=$MTX_PID (RTMP :1935 RTSP :8554 SRT :8890 — see /etc/mediamtx.yml)"
echo "[ingest] Publish from Larix: rtmp://<pod-ip>:1935/${RTMP_PATH}"

while true; do
  if [ ! -c "$V4L2_DEVICE" ]; then
    echo "[ingest] Waiting for $V4L2_DEVICE ..."
    sleep 2
    continue
  fi
  # Reconnect loop until Larix publishes; scale for Rope-Live / virtual cam stability
  if [[ "$SOURCE_URL" == srt://* ]]; then
    FFIN=( -hide_banner -loglevel warning -y )
  else
    FFIN=( -hide_banner -loglevel warning -y -rtsp_transport tcp -stimeout 5000000 )
  fi
  if [[ "${INGEST_LOW_LATENCY}" == "1" ]]; then
    FFIN+=( -fflags nobuffer+flush_packets -flags low_delay -probesize 500000 -analyzeduration 500000 )
  fi
  FFIN+=( -i "$SOURCE_URL" )
  ffmpeg "${FFIN[@]}" \
    -vf "scale=${INGEST_SCALE}:flags=bilinear,fps=${INGEST_FPS}" \
    -pix_fmt yuv420p \
    -f v4l2 "$V4L2_DEVICE" 2>>"${STARTUPDIR:-/dockerstartup}/ingest-ffmpeg.log" || true
  sleep 1
done
