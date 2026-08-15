#!/usr/bin/env bash
# Hermes-friendly runner for LocalOCR. Usage:
#   run.sh <image> [--engine paddleocr|tesseract] [--save-dir <dir>]
set -euo pipefail
IMAGE="${1:?usage: run.sh <image> [--engine paddleocr|tesseract] [--save-dir <dir>]}"
shift || true
ENGINE="paddleocr"
SAVE_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --engine) ENGINE="$2"; shift 2 ;;
    --save-dir) SAVE_DIR="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

ARGS=(analyze "$IMAGE" "--engine" "$ENGINE" "--json")
if [[ -n "$SAVE_DIR" ]]; then ARGS+=(--save-dir "$SAVE_DIR"); fi
local-ocr "${ARGS[@]}"
