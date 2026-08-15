# Capability boundaries

What LocalOCR's default engine (PaddleOCR-VL-1.6) handles well — and where
it stops. Measured on real samples, 2026-08, local llama.cpp hybrid mode on
an RTX 3060 6GB.

> These are **engine characteristics**, not bugs. PaddleOCR-VL is a document
> parser; chart understanding and UI extraction are different problems.

## Sample matrix

| sample | type | result |
| :-- | :-- | :-- |
| Japanese Instrument of Surrender | historical document: printed clauses + handwritten signatures | ✅ excellent (see `examples/`) |
| Diamond Sutra calligraphy | vertical traditional-Chinese manuscript | ✅ excellent (see `examples/`) |
| ROC-era handwritten speech | handwritten Chinese | ⚠️ mostly readable, some misreads |
| Chinese e-receipt (phone screenshot) | dense small-text form | ⚠️ partial (fields, not the table body) |
| Excel chart | data chart / bar chart | ❌ no text (classified as `chart_box`) |
| Blender UI screenshot | dense graphical interface | ❌ no text (classified as image regions) |

## What it handles well

- **Documents, manuscripts, print** — including **vertical text** and
  **traditional characters**. The Diamond Sutra demo transcribes vertical
  Song-dynasty calligraphy in correct column order, stably across runs.
- **Complex layouts** — regions classified (`paragraph_title`, `text`,
  `image`, `table`), reading order preserved, per-block coordinates and
  confidence emitted.
- **Handwriting** — readable but not perfect. Main nouns come through
  (民生主義, 民族主義), connected-stroke misreads happen (三民主義 → 三民主党).

## Where it stops

- **Pure charts** (bar/line/scatter): the whole figure is classified as a
  chart region and no text is transcribed. Extracting *chart content* needs
  chart understanding, not OCR.
- **Dense UI screenshots**: text mixed with graphics is treated as image
  regions. For UI text extraction, use a vision model that is tuned for
  interfaces, not a document parser.
- **Small-text forms after downscaling**: dense tables and tiny digits lose
  detail when an image is resized — keep original resolution for such
  documents.

## Practical guidance

| need | tool |
| :-- | :-- |
| document / manuscript / form OCR | ✅ LocalOCR (PaddleOCR-VL) |
| handwritten notes | ✅ usable, verify important fields |
| chart content ("what does this plot say") | chart-understanding model, not OCR |
| UI/interface text extraction | UI-tuned vision model |

## Sample sources

All sample images from Wikimedia Commons (public domain / open license).
Representative successes are kept in `examples/`.
