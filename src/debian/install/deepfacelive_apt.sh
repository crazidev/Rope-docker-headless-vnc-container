#!/usr/bin/env bash
# Runtime libraries for PyQt6 / OpenCV (DeepFaceLive) on headless X/VNC.
set -euo pipefail
apt-get update
apt-get install -y --no-install-recommends \
    libgl1 libegl1 libxrandr2 libxss1 libxcursor1 libxcomposite1 \
    libasound2 libxi6 libxtst6 curl nano gnupg2 libsm6 \
    libxcb-icccm4 libxkbcommon-x11-0 libxcb-keysyms1 libxcb-render0 \
    libxcb-render-util0 libxcb-image0 libxcb-cursor0 \
    libxcb-xinerama0 libxcb-xinput0 libxcb-xfixes0 libxcb-shape0 \
    libxcb-shm0 libxcb-sync1 libxcb-xkb1 libxcb-util1 \
    libfontconfig1 libfreetype6 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*
