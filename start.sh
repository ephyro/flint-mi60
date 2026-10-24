#!/usr/bin/env bash
set -euo pipefail

model_path="${MODEL_PATH:-${1:-}}"
[[ -n "$model_path" && -f "$model_path" ]] || {
  echo 'Usage: ./start.sh /absolute/path/to/flint.gguf (or set MODEL_PATH)' >&2
  exit 1
}
model_path="$(realpath -- "$model_path")"
[[ "$model_path" != *,* ]] || { echo 'Model paths containing commas are not supported.' >&2; exit 1; }
container_name="${CONTAINER_NAME:-flint-mi60}"
video_gid="${VIDEO_GID:-$(getent group video | cut -d: -f3)}"
render_gid="${RENDER_GID:-$(getent group render | cut -d: -f3)}"
[[ -n "$video_gid" && -n "$render_gid" ]] || { echo 'Set VIDEO_GID and RENDER_GID for your GPU device groups.' >&2; exit 1; }

# Never stop another model or silently replace an existing container.
if [[ "${DRY_RUN:-0}" != 1 ]]; then
  docker info >/dev/null
  if docker container inspect "$container_name" >/dev/null 2>&1; then
    echo "Container $container_name already exists. Use docker start, or choose another CONTAINER_NAME." >&2
    exit 1
  fi
fi
args=(run --detach --name "$container_name" --restart on-failure:3
  --device=/dev/kfd --device=/dev/dri
  --group-add "$video_gid" --group-add "$render_gid"
  --security-opt seccomp=unconfined --security-opt apparmor=unconfined --cap-add=SYS_PTRACE
  -p "${HOST_BIND:-127.0.0.1}:${HOST_PORT:-8010}:8080"
  -e HSA_OVERRIDE_GFX_VERSION=9.0.6 -e ROC_ENABLE_PRE_VEGA=1 -e HSA_ENABLE_SDMA=0
  -e HIP_VISIBLE_DEVICES=0 -e ROCR_VISIBLE_DEVICES=0
  --mount "type=bind,source=${model_path},target=/models/model.gguf,readonly"
  "${IMAGE:-flint-mi60:9ae73e68}"
  -m /models/model.gguf -c "${CTX_SIZE:-32768}" -np 1 -ngl "${GPU_LAYERS:-99}"
  -fa on -ctk q4_0 -ctv q4_0 --jinja --reasoning "${REASONING:-off}"
  --alias flint --temp 1.0 --top-p 0.95 --top-k 20 --host 0.0.0.0 --port 8080)
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  printf '%q ' docker "${args[@]}"
  printf '\n'
else
  exec docker "${args[@]}"
fi
