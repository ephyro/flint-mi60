#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash -n "$repo_dir/build.sh" "$repo_dir/start.sh" "$repo_dir/test.sh"
if MODEL_PATH='' "$repo_dir/start.sh" >/dev/null 2>&1; then
  echo 'FAIL: missing model path was accepted' >&2
  exit 1
fi
# A fixture path is sufficient: dry-run validates command construction only.
command_line="$(DRY_RUN=1 MODEL_PATH='' VIDEO_GID=44 RENDER_GID=109 HOST_BIND=127.0.0.1 HOST_PORT=8010 CONTAINER_NAME=flint-mi60 "$repo_dir/start.sh" "$repo_dir/README.md")"
for required in '127.0.0.1:8010:8080' 'readonly' 'flint-mi60' '32768' 'on-failure:3'; do
  [[ "$command_line" == *"$required"* ]] || { echo "FAIL: missing $required" >&2; exit 1; }
done
[[ "$command_line" != *'docker stop'* && "$command_line" != *'docker rm'* ]]
echo 'PASS: syntax, missing-path rejection, dry-run command, loopback binding and read-only model mount.'
