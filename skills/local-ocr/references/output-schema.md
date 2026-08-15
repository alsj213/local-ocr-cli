# Output contract

Every successful run emits JSON. The CLI (`local-ocr analyze <image> --json`)
and the dsh `ocr` tool both normalize to this shape.

## Top level

```json
{
  "text": "full transcription as markdown",
  "engine": "paddleocr | tesseract",
  "version": "v1 | v1.5 | v1.6",
  "saved_to": "/abs/path/to/ocr_output/<image>.md",
  "json_to": "/abs/path/to/ocr_output/<image>.json",
  "blocks": [ { "label": "text", "content": "...", "bbox": [x1,y1,x2,y2], "order": 1, "group_id": 0 } ],
  "layout_boxes": [ { "label": "text", "score": 0.9257, "coordinate": [x1,y1,x2,y2] } ],
  "durationSeconds": 4.2
}
```

| field | meaning |
| :-- | :-- |
| `text` | the full transcription, markdown-structured (tables as `<table>`, images as placeholders) |
| `engine` | which engine produced the result |
| `version` | PaddleOCR-VL pipeline version used |
| `saved_to` | markdown file persisted next to the image (when `--save-dir` given) |
| `json_to` | structured JSON file persisted |
| `blocks` | ordered text regions: content + bbox + reading order + group |
| `layout_boxes` | layout-detection boxes with confidence scores |
| `durationSeconds` | wall time of the engine call |

## Error shape

On failure the JSON has `{ "error": "<message>" }` and the CLI exits non-zero
(1 = input problem, 2 = engine failure).

## Consumption notes

- `text` is safe to show directly or to feed to a text-only model.
- `blocks` preserve reading order (`order`) and geometry (`bbox`); use them
  when the answer must reference a specific region of the image.
- `layout_boxes` give per-region confidence; a low score suggests the model
  itself was unsure — say so rather than guessing.
