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
| `OCR_LLAMA_MODEL` | model name to request from the llama-server | `PaddleOCR-VL-1.6` |
| `LOCAL_OCR_TESSERACT` | tesseract binary path (for the fallback probe) | `tesseract` |

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
sudo apt install tesseract-ocr tesseract-ocr-chi-sim
```

**No-sudo install** (when you cannot `apt install`): download the deb files
and unpack to a user directory. Package names differ per Ubuntu release —
on jammy (22.04) they are `liblept5` and `libtesseract4`, not the newer
names. `apt-cache search tesseract` / `apt-cache search liblept` to find the
real names, then add missing libs (`libgif7`, ...) as runtime errors report
them:

```bash
mkdir -p /tmp/ocr_tess && cd /tmp/ocr_tess
apt-get download tesseract-ocr tesseract-ocr-chi-sim liblept5 libtesseract4 libgif7
mkdir root && for d in *.deb; do dpkg -x "$d" root; done
export PATH=/tmp/ocr_tess/root/usr/bin:$PATH
export LD_LIBRARY_PATH=/tmp/ocr_tess/root/usr/lib/x86_64-linux-gnu
export TESSDATA_PREFIX=/tmp/ocr_tess/root/usr/share/tesseract-ocr/4.00/tessdata
```

> Why: a tesseract from homebrew/linuxbrew is built against a newer glibc
> than Ubuntu 22.04's 2.35 and fails with `GLIBC_2.38 not found`. `local-ocr
> doctor` detects this and says so.

## Notes

- The proxy is always bypassed for the local llama.cpp server (NO_PROXY is
  set by the engine), so a system `http_proxy` does not break local VLM
  reads. When probing the server yourself with curl, use
  `curl --noproxy '*' http://127.0.0.1:8091/health`.
- Only one llama-server should run on port 8091 — if one is already up
  (maybe from another profile), reuse it instead of starting a second. If
  its model alias is not `PaddleOCR-VL-1.6`, set `OCR_LLAMA_MODEL` to the
  name it answers, or restart it with `--alias PaddleOCR-VL-1.6`.
- 6GB-GPU machines: the full PaddleOCR-VL pipeline does not fit on 6GB
  directly; use the llama.cpp hybrid mode above (layout on GPU via Paddle,
  VLM quantized via llama.cpp), which fits comfortably.
- First run downloads ~2GB of PaddleOCR models (PP-DocLayoutV3 etc.) into
  `~/.paddlex/` — subsequent runs are fast. Note `~` may be redirected in
  sandboxed agent profiles; use absolute paths in scripts.
