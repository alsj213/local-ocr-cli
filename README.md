<h1 align="center">LocalOCR</h1>

<p align="center"><b>Fully-local OCR for text-only LLMs. PaddleOCR-VL first-tier engine, tesseract fallback. Images never leave your machine.</b></p>

<p align="center">
  <a href="./README.zh-CN.md">简体中文</a> ·
  <a href="INSTALL.md">Install guide</a> ·
  <a href="docs/cli.md">CLI manual</a> ·
  <a href="docs/troubleshooting.md">Troubleshooting</a> ·
  <a href="skills/local-ocr/references/output-schema.md">Output contract</a> ·
  <a href="docs/security.md">Security</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square" alt="License"></a>
</p>

LocalOCR gives a **text-only model** (DeepSeek, GLM, any of them) real OCR
sight, **entirely on your machine**. It reads local images with the
first-tier **PaddleOCR-VL-1.6** pipeline (layout analysis + VLM: text,
tables, formulas, charts — SOTA on OmniDocBench) and falls back to
tesseract when you want something lighter.

- **Local by design.** No API keys, no cloud, no network. Images never leave
  the machine.
- **First-tier engine.** PaddleOCR-VL-1.6, quantized and run through
  llama.cpp — fits comfortably on a 6GB GPU.
- **Evidence, not guesses.** Full transcription + reading-order layout
  regions + per-block coordinates + confidence scores, saved as both
  Markdown and structured JSON.
- **Drop-in for dsh.** One plugin row registers an `ocr` tool a text-only
  DeepSeek Harness model can call directly.

## Install (DeepSeek Harness)

```bash
dsh plugin --profile web add local-ocr-cli
```

Then restart dsh. The `ocr` tool appears on every request.

## Install (anywhere)

See [INSTALL.md](INSTALL.md) — the Node CLI plus the Python engine (PaddleOCR-VL
venv + llama.cpp GGUF server, tesseract optional).

## Releases (maintainers)

Publishing to npm is fully automated via **Trusted Publishing (OIDC)** — no
tokens, no 2FA prompts, automatic provenance. Pushing a `vX.Y.Z` tag triggers
[`.github/workflows/release.yml`](.github/workflows/release.yml), which runs
typecheck + test + build and then `npm publish --provenance`.

```bash
npm version patch        # bumps version and tags vX.Y.Z
git push --tags          # GitHub Actions publishes to npm
```

## Usage

```bash
local-ocr analyze shot.png --engine paddleocr --json
local-ocr analyze invoice.jpg --engine tesseract
local-ocr doctor
```

Output: JSON with `text` (markdown transcription), `saved_to` (md file),
`json_to` (structured JSON: blocks with bbox/order, layout boxes with
confidence). See the [output contract](skills/local-ocr/references/output-schema.md).

## Engines

| engine | what | needs |
| :-- | :-- | :-- |
| `paddleocr` (default) | PaddleOCR-VL-1.6: layout + VLM, SOTA | Python venv + llama.cpp GGUF server |
| `tesseract` | classic OCR, light | tesseract binary |

Both run locally. `local-ocr doctor` checks what is available.

## Docs

| doc | read when |
| :-- | :-- |
| [CLI manual](docs/cli.md) | every flag, subcommand |
| [Configuration](skills/local-ocr/references/configure.md) | setting up engines |
| [Troubleshooting](docs/troubleshooting.md) | a run failed |
| [Output contract](skills/local-ocr/references/output-schema.md) | consuming the JSON |
| [Security](docs/security.md) | what LocalOCR never does |

## License

MIT
