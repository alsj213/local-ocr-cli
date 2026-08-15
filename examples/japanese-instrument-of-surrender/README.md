# Example: Japanese Instrument of Surrender (1945)

A historically significant, layout-heavy document — ideal for showing what
LocalOCR's PaddleOCR-VL engine can do. It contains dense printed clauses,
**handwritten signatures**, and a multi-nation signature block.

## Files

| file | what |
| :-- | :-- |
| `surrender-doc.jpg` | source image (1378x1102, from Wikimedia Commons; public domain — 1945 US government document) |
| `result.md` | full recognition output as Markdown (auto-generated) |
| `result.json` | structured output: 33 text blocks with bbox/order + 39 layout boxes with confidence |

## Reproduce

```bash
local-ocr analyze examples/japanese-instrument-of-surrender/surrender-doc.jpg \
  --engine paddleocr --json
```

Output is written to `ocr_output/` (Markdown + JSON) and printed to stdout.

## What the result shows

- **Printed text:** all eight clauses transcribed (Potsdam Declaration,
  unconditional surrender, cease-hostilities order, POW release, etc.) —
  printed text is near-perfect.
- **Layout structure:** regions classified (`paragraph_title`, `text`,
  `image`, `table`) with reading order and coordinates.
- **Handwritten signatures:** the hard part — e.g. MacArthur's signature read
  as `GongLuo Wue Arthur`, and 徐永昌 (Republic of China representative)
  correctly captured. Handwriting is imperfect by nature; low-confidence
  regions are flagged in `layout_boxes`.

## Side-by-side: first-tier vs classic OCR

The same image through tesseract misread the year `2026` as `2028` in a
simple test image; PaddleOCR-VL reads dense historical documents with far
better layout awareness. For handwriting, neither engine is perfect — that is
why LocalOCR returns confidence scores rather than pretending certainty.
