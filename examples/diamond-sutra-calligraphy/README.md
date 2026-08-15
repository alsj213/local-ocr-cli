# Example: Diamond Sutra Calligraphy (Song Dynasty, 1253)

Vertical traditional-Chinese calligraphy — a layout that classic OCR engines
handle poorly. PaddleOCR-VL reads it with correct reading order and accurate
traditional characters.

## Files

| file | what |
| :-- | :-- |
| `diamond-sutra.jpg` | source image (from Wikimedia Commons, public domain — Song dynasty manuscript) |
| `result.md` | recognition output (Markdown) |
| `result.json` | structured output (blocks with bbox/order) |

## Reproduce

```bash
local-ocr analyze examples/diamond-sutra-calligraphy/diamond-sutra.jpg \
  --engine paddleocr --json
```

## What the result shows

Vertical classical Chinese transcribed accurately and in reading order:

```
金剛般若波羅蜜經
是我聞一時佛在舍衛
國祇樹給孤獨園與大比
五千二百五十人俱爾
尊食時著衣持鉢入
...
```

- **Vertical text** — correctly ordered column-by-column (a classic
  tesseract failure mode).
- **Traditional characters** — 金剛般若波羅蜜經 etc., no simplified
  substitution.
- **Stable across runs** — two independent runs produced identical text.
