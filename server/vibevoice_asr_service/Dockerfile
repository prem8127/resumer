FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake git ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --recurse-submodules \
    https://github.com/microsoft/VibeASR.cpp.git /opt/vibeasr && \
    cmake -S /opt/vibeasr -B /opt/vibeasr/build -DCMAKE_BUILD_TYPE=Release && \
    cmake --build /opt/vibeasr/build --target asr_infer -j2

FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 libstdc++6 ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    useradd --create-home --uid 10001 app && \
    mkdir -p /models/vibeasr && chown -R app:app /models

WORKDIR /app
COPY --from=build /opt/vibeasr/build/bin/asr_infer /opt/vibeasr/build/bin/asr_infer
COPY app.py start.sh ./
RUN pip install --no-cache-dir "fastapi>=0.115,<1" "uvicorn[standard]>=0.34,<1" \
    "python-multipart>=0.0.20,<1" "huggingface_hub>=0.27,<2" && \
    chmod +x /app/start.sh && chown -R app:app /app

ENV VIBEVOICE_ASR_BINARY=/opt/vibeasr/build/bin/asr_infer \
    VIBEVOICE_MODEL_DIR=/models/vibeasr \
    VIBEVOICE_ASR_THREADS=4
USER app
EXPOSE 7860
CMD ["/app/start.sh"]
