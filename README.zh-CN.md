<h1 align="center">LocalOCR</h1>

<p align="center"><b>为纯文本 LLM 提供完全本地的 OCR 能力。PaddleOCR-VL 第一梯队引擎，tesseract 回退。图片永不出机器。</b></p>

<p align="center">
  <a href="./README.md">English</a> ·
  <a href="INSTALL.md">安装指南</a> ·
  <a href="docs/cli.md">CLI 手册</a> ·
  <a href="docs/troubleshooting.md">排障</a> ·
  <a href="skills/local-ocr/references/output-schema.md">输出契约</a> ·
  <a href="docs/security.md">安全</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License"></a>
</p>

LocalOCR 给**纯文本模型**（DeepSeek、GLM 等）装上真正的 OCR 视觉，**完全在你自己的机器上运行**。它用第一梯队模型 **PaddleOCR-VL-1.6**（版面分析 + VLM：文本、表格、公式、图表——OmniDocBench 评测 SOTA）读取本地图片，并可在需要轻量方案时回退到 tesseract。

- **本地优先设计。** 无需 API key、无云端、无网络。图片永不离开你的机器。
- **第一梯队引擎。** PaddleOCR-VL-1.6 量化后经 llama.cpp 运行——6GB 显存即可舒适运行。
- **证据而非猜测。** 完整转录 + 阅读顺序版面区域 + 逐块坐标 + 置信度，同时保存为 Markdown 和结构化 JSON。
- **dsh 即插即用。** 一行插件配置即可注册 `ocr` 工具，纯文本 DeepSeek Harness 模型可直接调用。

## 安装（DeepSeek Harness）

```bash
dsh plugin --profile web add local-ocr-cli
```

重启 dsh 后，`ocr` 工具出现在每次请求中。

## 安装（其他环境）

见 [INSTALL.md](INSTALL.md)——Node CLI 加 Python 引擎（PaddleOCR-VL venv + llama.cpp GGUF 服务，tesseract 可选）。

## 发布（维护者）

npm 发布通过 **Trusted Publishing（OIDC）** 完全自动化——无需令牌、无需 2FA 提示、自动生成 provenance。推送 `vX.Y.Z` tag 触发 [`.github/workflows/release.yml`](.github/workflows/release.yml)，执行 typecheck + test + build 后 `npm publish --provenance`。

```bash
npm version patch        # 升版本并打 vX.Y.Z tag
git push --tags          # GitHub Actions 自动发布到 npm
```

## 使用

```bash
local-ocr analyze shot.png --engine paddleocr --json
local-ocr analyze invoice.jpg --engine tesseract
local-ocr doctor
```

输出：JSON，含 `text`（Markdown 转录）、`saved_to`（md 文件）、`json_to`（结构化 JSON：带 bbox/order 的文本块、带置信度的版面框）。详见[输出契约](skills/local-ocr/references/output-schema.md)。

## 引擎

| 引擎 | 说明 | 依赖 |
| :-- | :-- | :-- |
| `paddleocr`（默认） | PaddleOCR-VL-1.6：版面 + VLM，SOTA | Python venv + llama.cpp GGUF 服务 |
| `tesseract` | 经典 OCR，轻量 | tesseract 二进制 |

两者均本地运行。`local-ocr doctor` 检查可用性。

## 示例

| demo | 展示内容 |
| :-- | :-- |
| [日本投降书](examples/japanese-instrument-of-surrender/) | 1945 年密集历史文档：印刷条款 + 手写签名 + 多国签署区；33 个结构化文本块、39 个版面框 |
| [金刚经书法](examples/diamond-sutra-calligraphy/) | 宋代竖排繁体书法，正确按列读序识别 |

## 文档

| 文档 | 何时阅读 |
| :-- | :-- |
| [CLI 手册](docs/cli.md) | 全部参数与子命令 |
| [配置](skills/local-ocr/references/configure.md) | 搭建引擎 |
| [排障](docs/troubleshooting.md) | 运行失败时 |
| [能力边界](docs/capability-boundaries.md) | 引擎能读什么、不能读什么 |
| [输出契约](skills/local-ocr/references/output-schema.md) | 消费 JSON |
| [安全](docs/security.md) | LocalOCR 永远不会做什么 |

## 许可证

MIT
