---
name: local-ocr
description: "Fully-local OCR: recognize text in images with PaddleOCR-VL (first-tier: layout analysis + VLM for text/tables/formulas) or tesseract fallback. Images never leave the machine."
version: 1.0.0
author: LocalOCR
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [OCR, Vision, Document, Image-Text, Chinese, Table, Local, Offline, Privacy]
    related_skills: [ocr-and-documents, read_file, vision_analyze]
---

# LocalOCR — fully local image OCR

LocalOCR reads text out of **image files** (PNG/JPG/WebP) on this machine.
No network, no cloud — images never leave your machine. It is a companion to
Hermes's own `ocr-and-documents` skill (which targets PDFs/scans): use
LocalOCR when the input is already an image and you want the first-tier
PaddleOCR-VL engine.

## When to use this skill

- User pastes or points at an **image file** and wants its text.
- Input is a **scanned photo / screenshot / document image** (not a PDF).
- You need **structured output**: reading-order blocks with coordinates,
  layout regions, confidence scores.
- Chinese / traditional-Chinese / vertical text, tables, formulas.

When the input is a **PDF**, prefer Hermes's `ocr-and-documents` skill
(pymupdf / marker-pdf). When you only need a quick read of a small image and
no structure, `vision_analyze` may be enough.

## Prerequisites

LocalOCR is a CLI (`local-ocr`) with a Python engine. If `local-ocr` is not
installed, run:

```bash
npm install -g local-ocr-cli
local-ocr doctor          # shows what's missing
```

Then set up the engine (Python venv + models + llama-server). The bundled
one-command installer does everything:

```bash
# inside the package, or via the installed CLI's scripts dir
local-ocr --version && scripts/install.sh
```

See the project's INSTALL.md / configure.md for manual setup. Without the
engine, `--engine tesseract` still works if the tesseract binary exists.

## How to use

### 1. Basic recognition

```bash
local-ocr analyze /path/to/image.png --engine paddleocr --json
```

Prints a JSON object:

```json
{
  "text": "full transcription as markdown",
  "engine": "paddleocr",
  "version": "v1.6",
  "durationSeconds": 18.4
}
```

`text` is safe to quote directly to the user.

### 2. Structured output (blocks + layout)

Pass `--save-dir <dir>` to also persist `.md` and `.json` files with
per-block content, bounding boxes, reading order, and layout confidence:

```bash
local-ocr analyze /path/to/image.png --engine paddleocr --json --save-dir ./ocr_output
```

The `.json` file has `blocks[]` (content + bbox + order) and
`layout_boxes[]` (label + confidence). Use them when the answer must cite a
specific region of the image.

### 3. Fallback engine

```bash
local-ocr analyze /path/to/image.png --engine tesseract --json
```

Lighter, no GPU needed, but lower quality on complex layouts and Chinese.

## Notes & boundaries

- **First run** downloads ~2GB of PaddleOCR models into `~/.paddlex/` and
  needs a llama.cpp server (started by the installer).
- **Handwriting** is readable but not perfect; connected-stroke misreads
  happen. Don't silently "fix" text the model flagged low-confidence.
- **Charts / dense UI screenshots** may return empty `text` — the engine
  classifies them as image regions, which is an engine boundary, not a bug.
- The CLI is a plain executable: any shell-capable agent can call it, and it
  works identically inside Hermes.

## Verification

```bash
local-ocr doctor
```
