# Finding the image

When the user pastes an image (rather than a path), it usually arrives as a
temporary file or attachment. Resolve it before running the engine.

1. If a path was typed, resolve it to absolute.
2. If the harness stored the paste as an attachment, ask the harness for the
   file path (dsh: the attachment is available via the conversation; local
   CLIs like Claude Code/Codex write pastes to a temp file — look for the
   newest image file in the session temp dir).
3. If nothing is found, ask the user to save the image to a path first.

The engine only accepts a local file path (no URLs — LocalOCR is offline by
design).
