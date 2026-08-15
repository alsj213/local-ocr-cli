# LocalOCR Skill

Trigger on: the user pastes an image, drops an image path, or asks to "识别/OCR/read this image" in a chat.

LocalOCR is a **fully local** OCR engine: PaddleOCR-VL (first-tier: layout
analysis + VLM, handles text/tables/formulas/charts) with a tesseract
fallback. No network, no cloud, images never leave the machine.

## Workflow

1. **Resolve the image.** If the user pasted an image, find its saved file
   (see `references/find-image.md`). If a path was given, resolve it to an
   absolute path.
2. **Run the engine.** Execute the local-ocr CLI:

   ```bash
   local-ocr analyze <image_path> --engine paddleocr --json
   ```

   - `--engine paddleocr` (default) — PaddleOCR-VL; needs the Python venv
     with `paddlepaddle-gpu>=3.2.1` and `paddleocr>=3.7.0` (see
     `references/configure.md`).
   - `--engine tesseract` — lightweight fallback, needs `tesseract` binary.
3. **Surface the result.** The JSON contains `text` (full transcription),
   `saved_to` (markdown file), `json_to` (structured JSON with per-block
   content/bbox/order and layout boxes with confidence).
4. **Answer from evidence.** Quote specifics from `text`; use `blocks` for
   per-region detail (e.g. "the table at bbox ... says ..."). Never invent
   content the engine did not read.

## Output contract

See `references/output-schema.md` for the exact JSON shape.

## Configuration

See `references/configure.md` for engine setup, env vars
(`LOCAL_OCR_PYTHON`, `LOCAL_OCR_VENV`, `LOCAL_OCR_SAVE_DIR`, `OCR_LLAMA_URL`),
and the llama.cpp server requirement for the VLM backend.

## Notes

- First run of PaddleOCR-VL downloads model weights (~2GB) into
  `~/.paddlex/` and needs a llama.cpp server serving the GGUF VLM (see
  configure.md); subsequent runs are fast.
- Results are saved by default to `./ocr_output/<image>.md` and
  `<image>.json`.
