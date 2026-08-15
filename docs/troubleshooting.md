# Troubleshooting

## `input not found: <path>`

The path does not exist or is relative to a different directory. Use an
absolute path, or a path relative to where the CLI runs.

## `engine exited 1` / engine prints `{"error": "..."}`

Read the `error` field. Common causes:

| error | fix |
| :-- | :-- |
| `file not found` | input path wrong |
| `No module named 'paddleocr'` | the Python interpreter has no paddleocr; set `LOCAL_OCR_PYTHON`/`LOCAL_OCR_VENV` to the venv that has it |
| `tesseract failed: ...` | tesseract binary missing/broken; install it or use `--engine paddleocr` |
| `CUDA error ... out of memory` | full pipeline does not fit on your GPU; use the llama.cpp hybrid setup (see configure.md) |
| `Error code: 502` | the llama.cpp server call went through a proxy — LocalOCR sets NO_PROXY itself, but verify `OCR_LLAMA_URL` points at the running server |
| `Connection refused` | llama.cpp server not running; start it and set `OCR_LLAMA_URL` |

## `local-ocr: command not found`

The CLI is not installed. `npm install -g local-ocr-cli`, or run the built
`node dist/main.js` directly.

## PaddleOCR-VL first run is slow

First run downloads ~2GB of models into `~/.paddlex/`. Subsequent runs are
fast.

## Text quality

PaddleOCR-VL is a first-tier document parser; handwritten signatures and
heavily-styled text can still be misread. `layout_boxes` confidence scores
flag uncertain regions — do not silently "fix" text the model flagged as
low-confidence.

## Empty output (`text: ""`)

The engine classified the whole image as a chart/image region rather than
text (charts, dense UI screenshots). This is an engine boundary, not a bug —
see [capability boundaries](capability-boundaries.md) for what LocalOCR can
and cannot read.
