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

## Tables & HTML in `text`

For table-heavy images (receipts, trade records), PaddleOCR-VL emits the
table as **inline HTML** inside the markdown:

```
<table border=1 ...><tr><td>...</td></tr></table>
```

That is expected, not a bug. When consuming programmatically, either keep
the HTML (it preserves structure) or strip tags to plain rows:

```
<tr> → newline, <td> → space
```

This yields one line per table row — exactly the shape a CSV/row parser
wants. Do not attempt to JSON-parse `text`; use the `blocks` array or the
`--json` wrapper for structured access.

## Batch usage

- Warm up first: run one image before a large batch so model downloads
  (`~/.paddlex/`, HF cache) complete and the llama-server is warm.
- Reuse the same llama-server for the whole batch (one instance per port).
- Strip proxy env vars before long runs (`env -u http_proxy ...`); the
  engine does this itself now, but a wrapper script benefits too.
- Write batch logs to a file (`> /tmp/batch.log 2>&1`) so an agent restart
  does not lose progress; make the batch idempotent (skip already-done
  outputs) so a re-run resumes instead of redoing everything.
