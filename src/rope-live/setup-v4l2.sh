#!/usr/bin/env bash
# Load v4l2loopback when available (typically requires privileged Runpod).
set -euo pipefail

V4L2_DEVICE="${V4L2_DEVICE:-/dev/video10}"

if ! modprobe v4l2loopback video_nr=10 card_label="LarixIn" exclusive_caps=1 devices=1 2>/dev/null; then
  if ! modprobe v4l2loopback devices=1 video_nr=10 2>/dev/null; then
    echo "[v4l2] WARN: modprobe v4l2loopback failed (need CAP_SYS_MODULE / privileged pod and host module support)"
  else
    echo "[v4l2] Loaded v4l2loopback (fallback params)"
  fi
else
  echo "[v4l2] Loaded v4l2loopback (video_nr=10 exclusive_caps=1)"
fi

if [ -c "$V4L2_DEVICE" ]; then
  echo "[v4l2] Device present: $V4L2_DEVICE"
else
  echo "[v4l2] WARN: $V4L2_DEVICE not a char device; Larix->FFmpeg->v4l2 and pyvirtualcam may fail until module loads"
fi
