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

## `tesseract` fails with `GLIBC_2.38 not found`

The `tesseract` on PATH comes from homebrew/linuxbrew, built against a newer
glibc than your Ubuntu. `local-ocr doctor` reports this as `[BROKEN: glibc
mismatch]`. Fix: install a system tesseract (`sudo apt install
tesseract-ocr`) or use the no-sudo deb-unpack recipe in
[configure.md](../skills/local-ocr/references/configure.md). Or just use
`--engine paddleocr`.

## llama-server "couldn't bind port 8091"

Another llama-server is already running (possibly from a different agent
profile) — probably serving the very same PaddleOCR-VL models. Reuse it
instead of starting a second:

- If it is healthy, just run OCR — the engine talks to `127.0.0.1:8091`.
- If its model alias is not `PaddleOCR-VL-1.6`, set `OCR_LLAMA_MODEL` to the
  name it answers, or restart it with `--alias PaddleOCR-VL-1.6`.

Check first: `ss -tlnp | grep 8091`.

## `curl` to 127.0.0.1:8091 returns 502

A system `http_proxy` (e.g. `http://127.0.0.1:7892`) hijacks localhost
requests. The engine sets `NO_PROXY` itself so OCR still works, but manual
probes need: `curl --noproxy '*' http://127.0.0.1:8091/health`.

## `uv venv` fails "virtual environment already exists"

A previous interrupted install left the venv. The installer now rebuilds it
automatically; manually: `rm -rf <venv>` (or `uv venv --clear`) and re-run.

## PaddleOCR-VL first run is slow

First run downloads ~2GB of models into `~/.paddlex/`. Subsequent runs are
fast. In sandboxed agent profiles `~` may be redirected (e.g. to
`~/.hermes/profiles/<name>/home/`) — use absolute paths in scripts.

## `model not found` from llama-server

The server was started with a bare GGUF path, so its default model name is
the filename, but the engine requests `PaddleOCR-VL-1.6`. Fix: start the
server with `--alias PaddleOCR-VL-1.6`, or set `OCR_LLAMA_MODEL` to the
server's actual model name.

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
