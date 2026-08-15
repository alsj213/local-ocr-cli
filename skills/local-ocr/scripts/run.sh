#!/usr/bin/env bash
# LocalOCR skill runner: recognize one image, print text.
set -euo pipefail
IMAGE="${1:?usage: run.sh <image> [--engine paddleocr|tesseract]}"
ENGINE="${2:---engine paddleocr}"
local-ocr analyze "$IMAGE" "$ENGINE" --json
