# 配置

LocalOCR 没有配置文件——通过环境变量和已安装组件配置。一切都在本地。

## 环境变量

| 变量 | 含义 | 默认值 |
| :-- | :-- | :-- |
| `LOCAL_OCR_PYTHON` | Python 解释器绝对路径（需装有 paddleocr） | 自动探测：包旁的 `ocr-venv/bin/python`，然后 `python3` |
| `LOCAL_OCR_VENV` | venv 目录，使用其 `bin/python` | — |
| `LOCAL_OCR_SAVE_DIR` | `.md`/`.json` 结果保存目录 | `ocr_output/` |
| `OCR_LLAMA_URL` | llama.cpp 服务地址（VLM 后端） | `http://127.0.0.1:8091/v1` |

## 引擎搭建

### PaddleOCR-VL（默认，推荐）

需要 Python 3.10 venv：

```bash
uv venv --python 3.10 .venv
uv pip install --python .venv/bin/python paddlepaddle-gpu==3.2.1 -i https://www.paddlepaddle.org.cn/packages/stable/cu126/
uv pip install --python .venv/bin/python "paddleocr[doc-parser]"
```

然后启动 llama.cpp 服务加载 VLM GGUF（量化模型，约 1.2GB）：

```bash
# 从 HuggingFace 下载 PaddleOCR-VL-1.6-Q4_K_M.gguf + mmproj
llama-server -m PaddleOCR-VL-1.6-Q4_K_M.gguf \
  --mmproj PaddleOCR-VL-1.6-mmproj.gguf \
  --port 8091 --host 127.0.0.1 -c 4096
```

将引擎指向 venv 和服务：

```bash
export LOCAL_OCR_VENV=/path/to/.venv
export OCR_LLAMA_URL=http://127.0.0.1:8091/v1
```

首次运行会下载约 2GB PaddleOCR 模型到 `~/.paddlex/`。

### tesseract（回退）

```bash
apt install tesseract-ocr tesseract-ocr-chi-sim
```

## 说明

- 引擎会始终绕过本地 llama.cpp 服务的代理（自动设置 NO_PROXY），因此系统 `http_proxy` 不会破坏本地 VLM 读取。
- 6GB 显存机器：完整 PaddleOCR-VL 流程无法直接在 6GB 上运行；请使用上面的 llama.cpp 混合模式（版面分析用飞桨 GPU，VLM 用量化 GGUF 走 llama.cpp），可舒适运行。
