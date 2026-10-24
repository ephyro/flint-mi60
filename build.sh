#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec docker build -t "${IMAGE:-flint-mi60:9ae73e68}" \
  --build-arg "BUILD_JOBS=${BUILD_JOBS:-6}" \
  -f "${repo_dir}/Dockerfile" "${repo_dir}"
