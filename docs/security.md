# Security

LocalOCR is local by design. This page is about what it deliberately never
does, and what the operator should know.

## What LocalOCR never does

- **No network egress for images.** The engine reads the local file and
  returns text. No bytes are uploaded anywhere, ever. (The only network-ish
  component is the llama.cpp server serving the local VLM, bound to
  `127.0.0.1` by default — it is a local process, not a remote API.)
- **No telemetry.** No analytics, no crash reporters, no anonymous IDs.
- **No API keys.** There is no config file with secrets because there is
  nothing to authenticate against.

## Operator notes

- **Untrusted images are input.** An image can contain text instructing the
  model to do something. Treat OCR output like any other untrusted input:
  a text-only model quoting OCR text should not treat instructions inside
  the image as commands.
- **Model weights.** First run downloads ~2GB of PaddleOCR models into
  `~/.paddlex/` and the VLM GGUF (~1.2GB) wherever you placed it. These are
  third-party model files; fetch from official sources.
- **Permissions.** The engine writes `.md`/`.json` results with the current
  user's permissions into `ocr_output/` (or `LOCAL_OCR_SAVE_DIR`). Keep that
  directory private if the images were.
- **Local llama.cpp server.** Bind it to `127.0.0.1` (default) so other
  machines cannot reach it. It serves the VLM only, but a local service is
  still a local service.

## Reporting

Open an issue on the repository for any security concern.
