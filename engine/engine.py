#!/usr/bin/env python3
"""LocalOCR Python engine: PaddleOCR-VL (first-tier, local) with tesseract fallback.

Spawned as a subprocess by the local-ocr CLI (src/main.ts) or the dsh plugin
(dsh/index.js). Everything runs on this machine — no network, no cloud.

Usage:
    engine.py <image_path> [--engine paddleocr|tesseract] [--version v1|v1.5|v1.6]
              [--save-dir <dir>] [--json]

Output (--json): {"text", "engine", "version", "saved_to"?, "json_to"?, "blocks"?, "layout_boxes"?}
"""
import argparse
import json
import os
import sys
from pathlib import Path

# llama.cpp server is a local service — never route it through a proxy.
# Force (not setdefault): a parent env may carry http_proxy + a no_proxy that
# httpx does not apply to 127.0.0.1; overriding both guarantees the VLM call
# stays on localhost.
os.environ["NO_PROXY"] = "127.0.0.1,localhost"
os.environ["no_proxy"] = "127.0.0.1,localhost"

LLAMA_SERVER_URL = os.environ.get("OCR_LLAMA_URL", "http://127.0.0.1:8091/v1")
DEFAULT_SAVE_DIR = os.environ.get("LOCAL_OCR_SAVE_DIR", "ocr_output")


# ---------------------------------------------------------------------------
# Saving
# ---------------------------------------------------------------------------
def save_results(image: str, text: str, res: object, save_dir: str) -> dict:
    """Persist markdown + structured JSON next to the image, return paths."""
    d = Path(save_dir)
    d.mkdir(parents=True, exist_ok=True)
    stem = Path(image).stem
    md_path = d / f"{stem}.md"
    md_path.write_text(text, encoding="utf-8")
    paths = {"saved_to": str(md_path)}

    blocks: list[dict] = []
    boxes: list[dict] = []
    j = getattr(res, "json", None)
    inner = j.get("res") if isinstance(j, dict) else None
    if inner and isinstance(inner.get("parsing_res_list"), list):
        for blk in inner["parsing_res_list"]:
            blocks.append({
                "label": blk.get("block_label"),
                "content": blk.get("block_content"),
                "bbox": blk.get("block_bbox"),
                "order": blk.get("block_order"),
                "group_id": blk.get("group_id"),
                "polygon": blk.get("block_polygon_points"),
            })
    ldr = inner.get("layout_det_res") if inner else None
    if ldr and isinstance(ldr.get("boxes"), list):
        for b in ldr["boxes"]:
            boxes.append({
                "label": b.get("label"),
                "score": round(b.get("score", 0), 4),
                "coordinate": b.get("coordinate"),
            })
    json_path = d / f"{stem}.json"
    json_path.write_text(json.dumps({
        "image": str(image),
        "markdown": text,
        "blocks": blocks,
        "layout_boxes": boxes,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    paths["json_to"] = str(json_path)
    paths["blocks"] = blocks
    paths["layout_boxes"] = boxes
    return paths


# ---------------------------------------------------------------------------
# Engines
# ---------------------------------------------------------------------------
def run_paddleocr(image: str, version: str) -> dict:
    """PaddleOCR-VL pipeline: layout analysis (local Paddle) + VLM (llama.cpp)."""
    from paddleocr import PaddleOCRVL

    # Model name the llama-server knows it by. A server started with
    # --alias PaddleOCR-VL-1.6 answers that name; a server started with the
    # bare GGUF path answers the filename. Override via env when your server
    # uses a different alias.
    model_name = os.environ.get("OCR_LLAMA_MODEL", "PaddleOCR-VL-1.6")

    pipeline = PaddleOCRVL(
        pipeline_version=version,
        device="gpu",
        vl_rec_backend="llama-cpp-server",
        vl_rec_server_url=LLAMA_SERVER_URL,
        vl_rec_api_model_name=model_name,
    )
    results = pipeline.predict(image)
    for res in results:
        md = getattr(res, "markdown", None)
        if isinstance(md, dict):
            text = md.get("markdown_texts") or md.get("markdown") or ""
        else:
            text = str(md or "")
        return {"text": text, "engine": "paddleocr", "version": version, "res": res}
    return {"text": "", "engine": "paddleocr", "version": version}


def run_tesseract(image: str, language: str = "chi_sim+eng", psm: int = 3) -> dict:
    import subprocess

    proc = subprocess.run(
        ["tesseract", image, "stdout", "-l", language, "--psm", str(psm)],
        capture_output=True, text=True, timeout=120,
    )
    if proc.returncode != 0:
        err = proc.stderr
        if "GLIBC_" in err and "not found" in err:
            raise RuntimeError(
                "tesseract binary is broken (glibc mismatch). "
                "If it comes from homebrew/linuxbrew, install a system build instead: "
                "sudo apt install tesseract-ocr tesseract-ocr-chi-sim"
            )
        raise RuntimeError(f"tesseract failed: {err}")
    return {"text": proc.stdout, "engine": "tesseract", "version": "local"}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="LocalOCR engine (local only)")
    parser.add_argument("image")
    parser.add_argument("--engine", default="paddleocr", choices=["paddleocr", "tesseract"])
    parser.add_argument("--version", default="v1.6", choices=["v1", "v1.5", "v1.6"])
    parser.add_argument("--language", default="chi_sim+eng")
    parser.add_argument("--psm", type=int, default=3)
    parser.add_argument("--save-dir", default="")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if not Path(args.image).exists():
        print(json.dumps({"error": f"file not found: {args.image}"}, ensure_ascii=False))
        sys.exit(1)

    try:
        if args.engine == "tesseract":
            result = run_tesseract(args.image, args.language, args.psm)
        else:
            result = run_paddleocr(args.image, args.version)
        if args.save_dir and result.get("text"):
            res_obj = result.pop("res", None)
            extra = save_results(args.image, result["text"], res_obj, args.save_dir)
            result.update(extra)
        if args.json:
            print(json.dumps(result, ensure_ascii=False, default=str))
        else:
            print(result.get("text", ""))
    except Exception as e:  # noqa: BLE001 — CLI boundary: report and exit
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        sys.exit(2)


if __name__ == "__main__":
    main()
