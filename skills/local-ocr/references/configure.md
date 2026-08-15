# Configuration

LocalOCR has no config file — it is configured by environment and by what is
installed. Everything is local.

## Environment variables

| var | meaning | default |
| :-- | :-- | :-- |
| `LOCAL_OCR_PYTHON` | absolute path to the Python interpreter (with paddleocr installed) | auto-detect: `ocr-venv/bin/python` next to the package, then `python3` |
| `LOCAL_OCR_VENV` | venv directory whose `bin/python` to use | — |
| `LOCAL_OCR_SAVE_DIR` | where `.md`/`.json` results land | `ocr_output/` |
| `OCR_LLAMA_URL` | llama.cpp server base URL for the VLM backend | `http://127.0.0.1:8091/v1` |

## Engine setup

### PaddleOCR-VL (default, recommended)

Needs a Python 3.10 venv with:

```bash
uv venv --python 3.10 .venv
uv pip install --python .venv/bin/python paddlepaddle-gpu==3.2.1 -i https://www.paddlepaddle.org.cn/packages/stable/cu126/
uv pip install --python .venv/bin/python "paddleocr[doc-parser]"
```

Then a llama.cpp server serving the VLM GGUF (quantized model, ~1.2GB):

```bash
# download PaddleOCR-VL-1.6-Q4_K_M.gguf + mmproj from HuggingFace
llama-server -m PaddleOCR-VL-1.6-Q4_K_M.gguf \
  --mmproj PaddleOCR-VL-1.6-mmproj.gguf \
  --port 8091 --host 127.0.0.1 -c 4096
```

Point the engine at the venv and server:

```bash
export LOCAL_OCR_VENV=/path/to/.venv
export OCR_LLAMA_URL=http://127.0.0.1:8091/v1
```

First run downloads ~2GB of PaddleOCR models into `~/.paddlex/`.

### tesseract (fallback)

```bash
apt install tesseract-ocr tesseract-ocr-chi-sim
```

## Notes

- The proxy is always bypassed for the local llama.cpp server (NO_PROXY is
  set by the engine), so a system `http_proxy` does not break local VLM reads.
- 6GB-GPU machines: the full PaddleOCR-VL pipeline does not fit on 6GB
  directly; use the llama.cpp hybrid mode above (layout on GPU via Paddle,
  VLM quantized via llama.cpp), which fits comfortably.
