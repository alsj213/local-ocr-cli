#!/usr/bin/env bash
# install.sh — one-command setup for LocalOCR's PaddleOCR-VL engine.
#
# Creates the Python venv, installs paddlepaddle-gpu + paddleocr, downloads
# the quantized VLM (GGUF) + mmproj from HuggingFace, starts the llama.cpp
# server, and verifies with doctor.
#
# Requirements: Linux x64, NVIDIA GPU with >=6GB VRAM, curl, uv (or pip).
#
# Usage:
#   ./scripts/install.sh                 # full setup
#   ./scripts/install.sh --skip-models   # env only (models already present)
#   ./scripts/install.sh --skip-server   # env + models, no llama-server
#
# Config via env:
#   LOCAL_OCR_VENV      venv dir (default: .venv next to the script)
#   LOCAL_OCR_MODELS    GGUF dir (default: gguf-models/)
#   OCR_LLAMA_URL       llama.cpp server URL (default: http://127.0.0.1:8091/v1)
#   LLAMA_PORT          server port (default: 8091)
set -euo pipefail

# --- paths -------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VENV_DIR="${LOCAL_OCR_VENV:-$ROOT_DIR/.venv}"
MODELS_DIR="${LOCAL_OCR_MODELS:-$ROOT_DIR/gguf-models}"
LLAMA_PORT="${LLAMA_PORT:-8091}"
LLAMA_URL="${OCR_LLAMA_URL:-http://127.0.0.1:${LLAMA_PORT}/v1}"

# GGUF artifacts (quantized VLM). Version-locked to what the engine expects.
GGUF_BASE="https://huggingface.co/SanjeevSOLANKI/PaddleOCR-VL-1.6-GGUF/resolve/main"
GGUF_Q4="PaddleOCR-VL-1.6-Q4_K_M.gguf"      # 287 MB
GGUF_MMPROJ="PaddleOCR-VL-1.6-mmproj.gguf"  # 841 MB

# llama.cpp binaries — pinned release, CPU build (the VLM fits on CPU; Paddle
# uses the GPU for layout). Override with LLAMA_BIN_DIR to reuse an install.
LLAMA_VER="b10430"
LLAMA_TGZ="llama-${LLAMA_VER}-bin-ubuntu-x64.tar.gz"
LLAMA_URL_BASE="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_VER}"
LLAMA_DIR="$ROOT_DIR/llama-cpp"
LLAMA_SERVER="$LLAMA_DIR/llama-server"

SKIP_MODELS=0
SKIP_SERVER=0

# --- helpers -----------------------------------------------------------------
info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m  !! %s\033[0m\n' "$*"; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }

# --- args ---------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-models) SKIP_MODELS=1; shift ;;
    --skip-server) SKIP_SERVER=1; shift ;;
    -h|--help)
      echo "usage: $0 [--skip-models] [--skip-server]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

# --- 0. preflight --------------------------------------------------------------
info "preflight"
need curl
need git
if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  # uv is the recommended venv creator; fall back to python3 -m venv.
  if command -v uv >/dev/null 2>&1; then
    PYTHON_BIN="$VENV_DIR/bin/python"
  else
    need python3
    PYTHON_BIN="$VENV_DIR/bin/python"
  fi
else
  # already inside an active venv — use it directly
  VENV_DIR="$(dirname "$(dirname "$VIRTUAL_ENV")")"
  PYTHON_BIN="$(command -v python)"
fi

nvidia_gpu() {
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    return 0
  fi
  return 1
}
if nvidia_gpu; then
  ok "NVIDIA GPU detected"
else
  warn "no NVIDIA GPU detected — PaddleOCR-VL will be slow (CPU mode) or fail"
fi

# --- 1. Python venv + deps -----------------------------------------------------
if [[ -x "$PYTHON_BIN" ]] && "$PYTHON_BIN" -c "import paddleocr" >/dev/null 2>&1; then
  info "venv already has paddleocr, reusing $VENV_DIR"
else
  info "creating venv at $VENV_DIR"
  if command -v uv >/dev/null 2>&1; then
    uv venv --python 3.10 "$VENV_DIR" >/dev/null
    ok "venv created (uv)"
  else
    python3 -m venv "$VENV_DIR"
    ok "venv created (python3 -m venv)"
  fi

  info "installing paddlepaddle-gpu 3.2.1 + paddleocr[doc-parser] (this downloads ~1.5GB)"
  if command -v uv >/dev/null 2>&1; then
    uv pip install --python "$PYTHON_BIN" \
      paddlepaddle-gpu==3.2.1 -i https://www.paddlepaddle.org.cn/packages/stable/cu126/ >/dev/null
    uv pip install --python "$PYTHON_BIN" "paddleocr[doc-parser]" >/dev/null
  else
    "$PYTHON_BIN" -m pip install --upgrade pip >/dev/null
    "$PYTHON_BIN" -m pip install \
      paddlepaddle-gpu==3.2.1 -i https://www.paddlepaddle.org.cn/packages/stable/cu126/ >/dev/null
    "$PYTHON_BIN" -m pip install "paddleocr[doc-parser]" >/dev/null
  fi
  ok "paddleocr installed"
fi

# --- 2. GGUF models -------------------------------------------------------------
if [[ "$SKIP_MODELS" -eq 1 ]]; then
  info "skipping model download (--skip-models)"
elif [[ -f "$MODELS_DIR/$GGUF_Q4" && -f "$MODELS_DIR/$GGUF_MMPROJ" ]]; then
  info "models already present in $MODELS_DIR"
else
  info "downloading VLM models (~1.1GB) to $MODELS_DIR"
  mkdir -p "$MODELS_DIR"
  curl -L --retry 3 -o "$MODELS_DIR/$GGUF_Q4" "$GGUF_BASE/$GGUF_Q4"
  curl -L --retry 3 -o "$MODELS_DIR/$GGUF_MMPROJ" "$GGUF_BASE/$GGUF_MMPROJ"
  ok "models downloaded"
fi

# --- 3. llama.cpp server ---------------------------------------------------------
if [[ "$SKIP_SERVER" -eq 1 ]]; then
  info "skipping llama-server start (--skip-server) — start it later with:"
  echo "    $0                       # rerun; venv/models are reused, server starts"
elif curl -s --noproxy '*' --max-time 2 "$LLAMA_URL/models" >/dev/null 2>&1; then
  info "llama-server already running at $LLAMA_URL"
else
  if [[ ! -x "$LLAMA_SERVER" ]]; then
    info "downloading llama.cpp ${LLAMA_VER} (CPU build)"
    mkdir -p "$LLAMA_DIR"
    curl -L --retry 3 -o "/tmp/$LLAMA_TGZ" "$LLAMA_URL_BASE/$LLAMA_TGZ"
    tar xzf "/tmp/$LLAMA_TGZ" -C "$LLAMA_DIR" --strip-components=1
    ok "llama.cpp binaries installed"
  fi

  info "starting llama-server on 127.0.0.1:$LLAMA_PORT"
  nohup "$LLAMA_SERVER" \
    -m "$MODELS_DIR/$GGUF_Q4" \
    --mmproj "$MODELS_DIR/$GGUF_MMPROJ" \
    --port "$LLAMA_PORT" --host 127.0.0.1 -c 4096 \
    >"$ROOT_DIR/llama-server.log" 2>&1 &
  # wait for readiness
  for _ in $(seq 1 30); do
    if curl -s --noproxy '*' --max-time 2 "$LLAMA_URL/models" >/dev/null 2>&1; then
      ok "llama-server ready"
      break
    fi
    sleep 1
  done
  if ! curl -s --noproxy '*' --max-time 2 "$LLAMA_URL/models" >/dev/null 2>&1; then
    warn "llama-server did not become ready — check $ROOT_DIR/llama-server.log"
  fi
fi

# --- 4. verify ---------------------------------------------------------------------
info "verifying"
if command -v local-ocr >/dev/null 2>&1; then
  if ! local-ocr doctor >/dev/null 2>&1; then
    warn "global local-ocr is broken (stale install?) — try: npm install -g local-ocr-cli@latest"
  else
    local-ocr doctor || true
  fi
elif [[ -f "$ROOT_DIR/dist/main.js" ]]; then
  node "$ROOT_DIR/dist/main.js" doctor || true
else
  warn "local-ocr CLI not found — install with: npm install -g local-ocr-cli"
fi

info "done."
echo ""
echo "  engine:  $PYTHON_BIN"
echo "  models:  $MODELS_DIR"
echo "  server:  $LLAMA_URL"
echo ""
echo "  try: local-ocr analyze <image.png> --engine paddleocr --json"
