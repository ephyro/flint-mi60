ARG BASE_IMAGE=mixa3607/llama.cpp-gfx906@sha256:c01191620a86b5066af5f0a3719984d8c1c17697b91d46da9ebf1dd74968a3a1
FROM ${BASE_IMAGE} AS builder
USER root
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential cmake ninja-build libcurl4-openssl-dev libssl-dev git
ARG LLAMA_COMMIT=9ae73e68f5a78933c0d988bbd17bf4647ad6a0b2
RUN git init /src && git -C /src remote add origin https://github.com/ggml-org/llama.cpp.git \
    && git -C /src fetch --depth 1 origin "${LLAMA_COMMIT}" \
    && git -C /src checkout --detach FETCH_HEAD \
    && test "$(git -C /src rev-parse HEAD)" = "${LLAMA_COMMIT}"
ARG BUILD_JOBS=6
RUN cmake -S /src -B /build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DGGML_HIP=ON -DGPU_TARGETS=gfx906 \
    -DGGML_NATIVE=OFF -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=ON \
    && cmake --build /build --target llama-server -j"${BUILD_JOBS}"

FROM ${BASE_IMAGE}
COPY --from=builder /build/bin/ /opt/flint/bin/
ENV LD_LIBRARY_PATH=/opt/flint/bin:/opt/rocm/lib:/opt/rocm/lib64
ENTRYPOINT ["/opt/flint/bin/llama-server"]
