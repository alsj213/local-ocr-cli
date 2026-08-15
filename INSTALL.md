# Install guide

LocalOCR needs two pieces: the **Node CLI** and the **Python engine**.
Everything is local — no accounts, no API keys.

## 1. CLI

### From npm

```bash
npm install -g local-ocr-cli
local-ocr doctor        # verify
```

### From source

```bash
git clone https://github.com/alsj213/local-ocr-cli.git
cd local-ocr-cli
pnpm install
pnpm build              # produces dist/main.js
node dist/main.js doctor
```

## 2. Python engine

The engine (`engine/engine.py`) is bundled with the package, but it needs a
Python environment with the OCR libraries.

### PaddleOCR-VL (default, recommended)

Python 3.10 venv with PaddlePaddle GPU + PaddleOCR:

```bash
uv venv --python 3.10 .venv
uv pip install --python .venv/bin/python paddlepaddle-gpu==3.2.1 -i https://www.paddlepaddle.org.cn/packages/stable/cu126/
uv pip install --python .venv/bin/python "paddleocr[doc-parser]"
```

Then serve the quantized VLM with llama.cpp:

```bash
# download from HuggingFace:
#   SanjeevSOLANKI/PaddleOCR-VL-1.6-GGUF
#     - PaddleOCR-VL-1.6-Q4_K_M.gguf  (287 MB)
#     - PaddleOCR-VL-1.6-mmproj.gguf  (841 MB)
llama-server -m PaddleOCR-VL-1.6-Q4_K_M.gguf \
  --mmproj PaddleOCR-VL-1.6-mmproj.gguf \
  --port 8091 --host 127.0.0.1 -c 4096
```

Point the CLI at both:

```bash
export LOCAL_OCR_VENV=/path/to/.venv
export OCR_LLAMA_URL=http://127.0.0.1:8091/v1
```

First run downloads ~2 GB of PaddleOCR models into `~/.paddlex/`.

### tesseract (optional fallback)

```bash
apt install tesseract-ocr tesseract-ocr-chi-sim
```

## 3. DeepSeek Harness plugin

Add the plugin to a dsh profile:

```bash
dsh plugin --profile web add local-ocr-cli
```

Restart dsh — the `ocr` tool then appears on every request, backed by the
local engine.

## 4. Health check

```bash
local-ocr doctor
```

It reports the Python resolution, the engine file, and the save directory.
Then try a real image:

```bash
local-ocr analyze shot.png --engine paddleocr --json
```
