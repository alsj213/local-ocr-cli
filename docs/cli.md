# local-ocr CLI manual

```
local-ocr <command> [options]
```

## Commands

### `analyze <input>` (default)

Recognize text in a local image.

| flag | default | meaning |
| :-- | :-- | :-- |
| `-e, --engine <name>` | `paddleocr` | `paddleocr` (PaddleOCR-VL) or `tesseract` |
| `-v, --version <ver>` | `v1.6` | PaddleOCR-VL pipeline: `v1` \| `v1.5` \| `v1.6` |
| `-l, --language <lang>` | `chi_sim+eng` | tesseract language (tesseract only) |
| `--psm <n>` | `3` | tesseract page segmentation mode (tesseract only) |
| `-s, --save-dir <dir>` | env `LOCAL_OCR_SAVE_DIR` or `ocr_output/` | where `.md`/`.json` results are written |
| `-j, --json` | on | emit structured JSON |

Exit codes: `0` success, `1` input problem, `2` engine failure.

### `doctor`

Offline diagnostics: Python resolution, engine file presence, save dir. No
network, no engine calls.

### `engine-path`

Print the resolved path of the bundled Python engine script.

## Environment

| var | meaning |
| :-- | :-- |
| `LOCAL_OCR_PYTHON` | absolute Python interpreter path (must have paddleocr) |
| `LOCAL_OCR_VENV` | venv dir whose `bin/python` to use |
| `LOCAL_OCR_SAVE_DIR` | default save directory |
| `OCR_LLAMA_URL` | llama.cpp server URL for the VLM (`http://127.0.0.1:8091/v1`) |
