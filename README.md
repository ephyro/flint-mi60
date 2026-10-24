# Flint on AMD MI60 / gfx906

A standalone Docker build recipe and launcher for Recursive Flint with llama.cpp on AMD Instinct MI60 (gfx906). This is not a llama.cpp fork and does not modify upstream source code.

## Status

Tested on one 32 GB MI60 using the Unsloth `flint-UD-Q4_K_XL.gguf` quantization. Model weights are not included. MI50 and Radeon VII use gfx906 too, but have not been tested here; smaller VRAM cards may need different settings.

Pinned components:

- llama.cpp commit [`9ae73e68f5a78933c0d988bbd17bf4647ad6a0b2`](https://github.com/ggml-org/llama.cpp/commit/9ae73e68f5a78933c0d988bbd17bf4647ad6a0b2).
- [Mixa's gfx906 ROCm base](https://github.com/mixa3607/ML-gfx906), image digest `sha256:c01191620a86b5066af5f0a3719984d8c1c17697b91d46da9ebf1dd74968a3a1`.

Flint support requires a recent llama.cpp revision. The older base image's bundled server cannot load Flint; this recipe builds and uses a separate server under `/opt/flint/bin`.

## Requirements

Linux with working AMD GPU drivers, `/dev/kfd`, `/dev/dri`, Docker access, internet access for the build, and sufficient free disk/RAM. The model alone is about 25.1 GB on disk. Build and container storage need additional space.

## Build and launch

```bash
git clone https://github.com/ephyro/flint-mi60.git
cd flint-mi60
./build.sh
./start.sh /absolute/path/to/flint-UD-Q4_K_XL.gguf
```

The launcher does not stop existing GPU workloads. Free enough VRAM first, and ensure port 8010 is unused. It refuses to replace an existing container.

```bash
curl http://127.0.0.1:8010/health
curl http://127.0.0.1:8010/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"flint","messages":[{"role":"user","content":"Reply with exactly: Flint is online."}],"max_tokens":128,"temperature":0}'
```

Watch startup with `docker logs -f flint-mi60`. To stop or resume the same container, use `docker stop flint-mi60` or `docker start flint-mi60`. After a failed startup, inspect the logs before retrying; restarts are limited to three attempts.

## Settings

Defaults: 32768 context, one slot, GPU layers 99, Flash Attention enabled, Q4_0 K/V cache; temperature 1.0, top-p 0.95, top-k 20. The model's embedded chat template is used.

Environment overrides: `MODEL_PATH`, `IMAGE`, `CONTAINER_NAME`, `CTX_SIZE`, `GPU_LAYERS`, `HOST_BIND`, `HOST_PORT`, `VIDEO_GID`, `RENDER_GID`, `REASONING`; `BUILD_JOBS` for building. `DRY_RUN=1` prints the launch command without Docker calls.

```bash
CTX_SIZE=16384 HOST_PORT=8011 ./start.sh /path/to/flint.gguf
```

## Smoke-test results and limits

Tested 2026-10-24 UTC on a single MI60 32 GB with Xeon E5-1650 v3 host, 32 GB system RAM, and a Fish S2 TTS server resident on the same GPU:

| Task | Generated tokens | Generation rate |
| --- | ---: | ---: |
| Exact-response test | 36 | 61.26 tokens/s |
| Small Python deduplication function | 150 | 63.20 tokens/s |
| Strict JSON-schema response | 110 | 63.09 tokens/s |

These rates include internal reasoning, not just visible reply text. They exclude prompt processing and are not long-context benchmarks. All tests completed; there were no container restarts. 32K context was allocated, not filled or stress-tested.

The running prototype was built with a local source checkout copied into the same pinned base. This publication recipe fetches that exact revision instead. The portable clean-build variant has not yet been independently rebuilt or tested on a second machine.

Known issues:

- `cudaMemGetInfo ... invalid argument` warnings occurred, but loading and these generation tests succeeded. Automatic VRAM fitting is not validated.
- Flint emitted separate `reasoning_content` even with `--reasoning off`. Do not assume the switch suppresses reasoning or that short visible replies use few tokens.
- Build dependencies are installed from live package repositories; this is revision-pinned, not a byte-for-byte reproducible build.

## Security

The API binds to localhost by default and has no API key. Do not expose it to an untrusted network without authentication and firewall rules. A Docker-published port is separate from the server's internal `0.0.0.0` binding.

This recipe retains the working prototype's relaxed seccomp/AppArmor settings and `SYS_PTRACE` capability. These weaken container isolation; run trusted images and treat the container accordingly. No model files are mounted writable.

## Credits and licensing

Maintained by [Ephyro](https://github.com/ephyro). The build recipe and launcher are MIT licensed; see [LICENSE](LICENSE). AI assistance was used during development.

- [llama.cpp](https://github.com/ggml-org/llama.cpp), MIT: model runtime and Flint support.
- [Mixa's ML-gfx906](https://github.com/mixa3607/ML-gfx906): the ROCm/gfx906 base image.
- [Recursive Flint](https://huggingface.co/RecursiveSI/flint): model, separately licensed Apache-2.0.
- [Unsloth Flint GGUF](https://huggingface.co/unsloth/flint-GGUF): tested quantization.

This repository contains only build/launcher material, not upstream source or weights. Dependencies retain their respective licenses. Review upstream notices before redistributing built images. AI assistance was used to prepare the recipe, launcher and documentation.

## Launcher checks

Run `./test.sh` for syntax and dry-run checks. These do not load a model or replace a GPU smoke test.
