#!/usr/bin/env bash
set -euo pipefail

WHISPER_VERSION="v1.8.6"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/VoiceFlow/Libs"
WORK_DIR="${VOICEFLOW_WHISPER_WORK_DIR:-${TMPDIR:-/tmp}/voiceflow-whisper-${WHISPER_VERSION}}"
SOURCE_DIR="${WORK_DIR}/source"
BUILD_DIR="${WORK_DIR}/build"

required_libraries=(
  libwhisper.a
  libggml.a
  libggml-base.a
  libggml-cpu.a
  libggml-metal.a
  libggml-blas.a
)

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  rm -rf "${SOURCE_DIR}"
  mkdir -p "${WORK_DIR}"
  git clone --depth 1 --branch "${WHISPER_VERSION}" \
    https://github.com/ggml-org/whisper.cpp.git "${SOURCE_DIR}"
fi

cmake -S "${SOURCE_DIR}" -B "${BUILD_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DWHISPER_BUILD_EXAMPLES=OFF \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_SERVER=OFF \
  -DGGML_METAL=ON \
  -DGGML_ACCELERATE=ON

cmake --build "${BUILD_DIR}" --config Release --parallel "${VOICEFLOW_BUILD_JOBS:-6}"

mkdir -p "${OUTPUT_DIR}"

for library in "${required_libraries[@]}"; do
  source_path="$(find "${BUILD_DIR}" -name "${library}" -type f -print -quit)"
  if [[ -z "${source_path}" ]]; then
    echo "error: whisper.cpp did not produce ${library}" >&2
    echo "Available static libraries:" >&2
    find "${BUILD_DIR}" -name '*.a' -type f -print >&2
    exit 1
  fi
  cp "${source_path}" "${OUTPUT_DIR}/${library}"
done

echo "VoiceFlow whisper.cpp libraries are ready:"
ls -lh "${OUTPUT_DIR}"
