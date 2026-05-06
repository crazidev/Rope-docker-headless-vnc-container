# Rope-docker-headless-vnc-container 

This is a docker for running [**Rope**](https://github.com/Hillobar/Rope) using [**headless VNC environments**](https://github.com/ConSol/docker-headless-vnc-container). Useful for running Rope on cloud GPU services like [Runpod.io](https://www.runpod.io/) or [Vast.ai](https://vast.ai/).

The Docker image is installed with the following components:
* [**Rope**](https://github.com/Hillobar/Rope) Pearl-00
* JupyterLab (default http port `8080`)
* VNC-Server (default VNC port `5901`)
* [**noVNC**](https://github.com/novnc/noVNC) 1.5.0 - HTML5 VNC client (default http port `6901`)
* CUDA Toolkit 11.8
* Pytorch 2.0.1+cu118
* Desktop environment [**Xfce4**](http://www.xfce.org)
* [**fiebrowser**](https://github.com/filebrowser/filebrowser) (default http port `8585`)
*  Mozilla Firefox

![screenshot2](https://github.com/user-attachments/assets/2ecad65f-3795-4d95-8568-d8bf33ed1966)

## Usage
- Run command with mapping to local port `5901` (vnc protocol), `6901` (vnc web access), `8080` (JupyterLab), and `8585` (filebrowser):

      docker run -d --gpus all -p 5901:5901 -p 6901:6901 -p 8080:8080 -p 8585:8585 -e VNC_PASSWORDLESS=true -e VNC_RESOLUTION=1024x768 asyafiqe/rope_vnc:latest

    For more options, please check [ConSol's docker-headless-vnc-container github](https://github.com/ConSol/docker-headless-vnc-container).
- Build an image from scratch:

      docker build -t asyafiqe/rope_vnc .

- [Vast.ai](https://vast.ai/) template:
    Put `asyafiqe/rope_vnc:latest` in image path/tag.
    Docker options:
    ```
    -p 5901:5901 -p 6901:6901 -p 8080:8080 -p 8585:8585 -e VNC_PASSWORDLESS=true  -e VNC_RESOLUTION=1024x768
    ```
    In Launch Mode select 'Run interactive shell server, SSH'. Check 'Use direct SSH connection'.
    On-start Script:
    
    ```
    env | grep _ >> /etc/environment; echo 'starting up'
    /dockerstartup/vnc_startup.sh
    sleep infinity
    ```
    ![vast ai_template](https://github.com/user-attachments/assets/28079139-db32-4f5a-97a8-af99d8d6244a)

- [Runpod.io](https://www.runpod.io/) template:
    * Container image: `asyafiqe/rope_vnc:latest`.
    * Docker command: 
    ```
    -p 5901:5901 -p 6901:6901 -p 8080:8080 -p 8585:8585
    ```
    * Container disk: minimum 30GB
    * Volume disk: personal preference
    * Volume mount path: `/workspace`
    * Expose http ports: `6901,8080,8585`
    * Expose TCP ports: `5901`
    * Environment Variables: key: `VNC_PASSWORDLESS`, value `true`
    ![runpod io_template](https://github.com/user-attachments/assets/1e07306a-5958-4c2d-938d-8c80c68b221e)

## Rope-Live: Larix (iOS) ingest, virtual camera, Runpod

Use [`Dockerfile.rope-live`](Dockerfile.rope-live) for [**Rope-Live**](https://github.com/argenspin/Rope-Live) with the same headless VNC stack, plus **MediaMTX** so you can publish from [**Larix Broadcaster**](https://softvelum.com/larix/ios) over **RTMP** or **SRT**, decode with **FFmpeg**, and write frames to **v4l2loopback** (default `/dev/video10`) so Rope-Live / OBS can treat it like a webcam.

**Heavy pieces are not in the image:** the **conda env** (`CONDA_ENV_PREFIX`, default `/workspace/data/conda/envs/RopeLive`), **Rope-Live** clone (`ROPE_LIVE_HOME`, default `/workspace/data/Rope-Live`), **pip/PyTorch/TensorRT stack**, and **JupyterLab** are installed on **first start** by [`deferred-install.sh`](src/rope-live/deferred-install.sh). All output is appended to **`/workspace/data/install.log`** and mirrored to stdout/stderr (visible in **Runpod / docker logs**). **OBS** is installed separately via [`install-obs.sh`](src/rope-live/install-obs.sh). **Mount `/workspace` on a volume** so conda/pip caches and the env survive restarts. **VNC/noVNC come up first**; [`deferred-install.sh`](src/rope-live/deferred-install.sh) runs **in the background** while you use the desktop — progress still goes to **`/workspace/data/install.log`** and stderr/Runpod logs. Jupyter and Rope-Live start **after** that install finishes. Use **`SKIP_WORKSPACE_INSTALL=1`** to skip the conda/Rope/pip step, **`FORCE_REINSTALL=1`** to redo it, **`SKIP_OBS_INSTALL=1`** to skip OBS.

### Build

Use BuildKit for faster local rebuilds:

```bash
DOCKER_BUILDKIT=1 docker build -f Dockerfile.rope-live -t rope-live-vnc:latest .
# Optional: default INSTALL_TENSORRT=1 in image env for runtime pip (TensorRT line handling in requirements).
DOCKER_BUILDKIT=1 docker build -f Dockerfile.rope-live --build-arg INSTALL_TENSORRT=1 -t rope-live-vnc:trt .
```

### Python dependency caches (Runpod volume)

On each start, [`bootstrap-workspace.sh`](src/rope-live/bootstrap-workspace.sh) creates **`/workspace/data/cache/`** and writes **`/workspace/data/cache/exports.env`**. The startup script exports:

| Path / variable | Role |
|-----------------|------|
| `PIP_CACHE_DIR=/workspace/data/cache/pip` | `pip install` reuses wheels across pod restarts when `/workspace` is a network volume. |
| `CONDA_PKGS_DIRS=/workspace/data/cache/conda/pkgs` | `conda install` / `conda create` can reuse downloaded packages into this directory. |
| `UV_CACHE_DIR=/workspace/data/cache/uv` | For [uv](https://github.com/astral-sh/uv) if you install it later. |
| `XDG_CACHE_HOME=/workspace/data/cache/xdg` | Misc Python/tooling caches that honor XDG. |

Set **`WORKSPACE_PYTHON_CACHE=0`** to skip sourcing `exports.env` (defaults to enabled). **`deferred-install.sh`** still runs once (unless skipped); caches speed **repeated** installs after wiping the env only if dirs on the volume are preserved.

### Ports (map all you need)

| Port | Protocol | Purpose |
|------|-----------|---------|
| 5901 | TCP | TigerVNC |
| 6901 | TCP | noVNC |
| 8080 | TCP | JupyterLab |
| 8585 | TCP | filebrowser |
| 1935 | TCP | RTMP ingest (Larix → MediaMTX) |
| 8554 | TCP | RTSP (FFmpeg reads `rtsp://127.0.0.1:8554/<path>` inside the container) |
| 8890 | UDP | SRT (optional; set `INGEST_MODE=srt` or override `INGEST_SOURCE_URL`) |

### Runpod and `/workspace`

- Mount a **network volume** at **`/workspace`**. Models and caches live under **`/workspace/data/models`** (including **`inswapper_128.fp16.onnx`**, downloaded on first start from [argenspin/rope-assets 1.0.0](https://github.com/argenspin/rope-assets/releases/tag/1.0.0) if missing).
- Use a **privileged** pod (or sufficient capability to run `modprobe v4l2loopback`) so `/dev/video10` can be created. Without the module, ingest and `pyvirtualcam` may not work.
- **Docker / pod options** example:

```text
--privileged
-p 5901:5901 -p 6901:6901 -p 8080:8080 -p 8585:8585 -p 1935:1935 -p 8554:8554 -p 8890:8890/udp
-v <your-runpod-volume>:/workspace
-e VNC_PASSWORDLESS=true
-e INGEST_MODE=rtmp
-e RTMP_PATH=live/ingest
```

### Larix connection URL

With defaults, publish **RTMP** to:

```text
rtmp://<pod-public-host>:1935/live/ingest
```

Use the same path in **`RTMP_PATH`** (default `live/ingest`) if you change it. After Larix connects, FFmpeg inside the container pulls **`rtsp://127.0.0.1:8554/${RTMP_PATH}`** and writes **YUV420P** to **`V4L2_DEVICE`** (default `/dev/video10`).

### Runpod: which port for Larix?

- **Larix uses RTMP**, so expose **TCP container port `1935`** on Runpod and use the **mapped public port** in the URL (e.g. `rtmp://213.173.x.x:<external-1935>/live/ingest`).
- **`8554` is RTSP**, not RTMP. A mapping like `213.173.x.x:18653 -> :8554` is for viewers (VLC, ffplay) with **`rtsp://213.173.x.x:18653/live/ingest`**, **not** for Larix.
- **MediaMTX is in the image**; startup runs [`start-ingest.sh`](src/rope-live/start-ingest.sh) automatically unless `INGEST_MODE=off`. Ingest logs go to **`/dockerstartup/ingest.log`** and **`ingest-ffmpeg.log`**, and (after the latest startup script) are **teed to the container log** so Runpod’s log UI can show them.
- Without a working **`/dev/video10`**, the script logs **`Waiting for /dev/video10`** in a loop; **FFmpeg will not pull** until then, but **MediaMTX can still accept** an RTMP publisher on **1935** if that port is reachable.

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FACESWAP_BACKEND` | `rope-live` | Only `rope-live` is implemented; `deeplive` / `deepfacelive` exit with a clear error (future multi-backend phase). |
| `INGEST_MODE` | `rtmp` | `rtmp` (FFmpeg reads RTSP from local MediaMTX), `srt`, or `off` to skip ingest. |
| `RTMP_PATH` | `live/ingest` | Path name for RTMP publish and RTSP read. |
| `INGEST_SOURCE_URL` | (built from mode) | Override FFmpeg input (e.g. custom SRT URL). |
| `INGEST_SCALE` | `1280:720` | FFmpeg `scale=` before `v4l2`. |
| `INGEST_FPS` | `30` | FFmpeg `fps=` filter. |
| `V4L2_DEVICE` | `/dev/video10` | v4l2loopback device node. |
| `INSWAPPER_URL` | rope-assets GitHub URL | Override download URL for the swapper ONNX. |
| `WORKSPACE_PYTHON_CACHE` | `1` | Set to `0` to disable exporting volume-backed `PIP_CACHE_DIR` / `CONDA_PKGS_DIRS` / `UV_CACHE_DIR` / `XDG_CACHE_HOME`. |
| `SKIP_WORKSPACE_INSTALL` | `0` | Set to `1` to skip [`deferred-install.sh`](src/rope-live/deferred-install.sh) (no conda env / Rope / pip / Jupyter on volume). |
| `FORCE_REINSTALL` | `0` | Set to `1` to remove the runtime-ready stamp and re-run deferred install. |
| `SKIP_OBS_INSTALL` | `0` | Set to `1` to skip [`install-obs.sh`](src/rope-live/install-obs.sh). |
| `ROPE_LIVE_HOME` | `/workspace/data/Rope-Live` | Clone path for Rope-Live. |
| `CONDA_ENV_PREFIX` | `/workspace/data/conda/envs/RopeLive` | Conda env prefix on the volume. |

### WebRTC / WHIP

Larix can publish **WebRTC using WHIP** against a compatible HTTPS server ([Larix WebRTC](https://larix.info/)); this image **does not** include a WHIP endpoint yet. **RTMP or SRT** to MediaMTX is the supported path for v1.

### Security

The bundled **MediaMTX** config allows **anonymous RTMP publish** on the paths you expose. Treat **`1935` / `8890`** like open ingest: restrict with Runpod firewall, VPN, IP allowlisting, or replace **`/etc/mediamtx.yml`** (for example mount your own file or bake a custom `authInternalUsers` policy).

### Future backends (plan phase 3)

[**Deep-Live-Cam**](https://github.com/hacksider/Deep-Live-Cam) and archived [**DeepFaceLive** `build/linux`](https://github.com/iperov/DeepFaceLive/tree/master/build/linux) expect different Python/CUDA stacks than Rope-Live. A follow-up is separate conda envs or separate image tags; `FACESWAP_BACKEND` is reserved for that.
