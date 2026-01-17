#!/usr/bin/env python3
"""
Persistent PaddleOCR worker for BookToNote OCR Server.
Keeps the OCR model loaded in memory for fast subsequent requests.

Protocol (line-based JSON over stdin/stdout):
  Input:  {"image_path": "/path/to/image.png"}
  Output: {"success": true, "text": "...", "paragraphs": ["..."]}
      or: {"success": false, "error": "..."}

The worker stays running and processes requests until stdin closes.
"""

import sys
import os
import json
from pathlib import Path

# Suppress PaddlePaddle logging and model source checking before importing
os.environ["GLOG_minloglevel"] = "2"
os.environ["GLOG_v"] = "0"
os.environ["FLAGS_use_mkldnn"] = "0"

# Disable model source/connectivity check at the source
os.environ["DISABLE_MODEL_SOURCE_CHECK"] = "True"
os.environ["HUB_HOME"] = "/tmp/paddlehub"

# Patch the connectivity check before importing paddleocr
try:
    from paddlehub.utils import utils as hub_utils
    hub_utils.check_url = lambda *a, **kw: True
except (ImportError, AttributeError, ModuleNotFoundError):
    pass

try:
    from paddlehub.server import server_source
    server_source.check_connectivity = lambda *a, **kw: None
    server_source.ServerSource.check_connectivity = lambda *a, **kw: None
except (ImportError, AttributeError, ModuleNotFoundError):
    pass

# Global OCR instance - loaded once at startup
_ocr = None


def init_ocr():
    """Initialize PaddleOCR once at startup."""
    global _ocr
    from paddleocr import PaddleOCR
    _ocr = PaddleOCR(
        use_textline_orientation=True,
        lang='en',
    )
    return _ocr


def run_ocr(image_path: str) -> tuple[str, list[str]]:
    """
    Run PaddleOCR on an image and return extracted text.
    Uses the global pre-loaded OCR instance.

    Returns:
        tuple of (full_text, list_of_paragraphs)
    """
    global _ocr

    # Run OCR using the predict API
    result = _ocr.predict(image_path)

    if not result or not result[0] or not result[0].get('rec_texts'):
        return "", []

    # Extract text lines with their positions
    lines = []
    rec_texts = result[0].get('rec_texts', [])
    rec_scores = result[0].get('rec_scores', [])
    rec_boxes = result[0].get('rec_boxes', [])

    for i, text in enumerate(rec_texts):
        confidence = rec_scores[i] if i < len(rec_scores) else 0
        if text and confidence > 0.5:
            # Get vertical position from bounding box
            if i < len(rec_boxes):
                bbox = rec_boxes[i]
                y_pos = (bbox[1] + bbox[3]) / 2  # Average of top and bottom y
            else:
                y_pos = i * 10  # Fallback ordering
            lines.append((y_pos, text.strip()))

    if not lines:
        return "", []

    # Sort by vertical position (top to bottom)
    lines.sort(key=lambda x: x[0])

    # Group lines into paragraphs based on vertical gaps
    paragraphs = []
    current_paragraph = []
    last_y = None

    for y_pos, text in lines:
        if last_y is not None:
            # If there's a significant vertical gap, start a new paragraph
            gap = y_pos - last_y
            if gap > 40:
                if current_paragraph:
                    paragraphs.append(" ".join(current_paragraph))
                    current_paragraph = []

        current_paragraph.append(text)
        last_y = y_pos

    # Don't forget the last paragraph
    if current_paragraph:
        paragraphs.append(" ".join(current_paragraph))

    # Join paragraphs with double newlines
    full_text = "\n\n".join(paragraphs)

    return full_text, paragraphs


def detect_image_type(file_path: str) -> str:
    """Detect image type from file magic bytes."""
    with open(file_path, 'rb') as f:
        header = f.read(12)

    # Check magic bytes
    if header[:3] == b'\xff\xd8\xff':
        return 'jpg'
    elif header[:8] == b'\x89PNG\r\n\x1a\n':
        return 'png'
    elif header[:4] == b'%PDF':
        return 'pdf'
    elif header[:2] == b'BM':
        return 'bmp'
    elif header[:4] in (b'II\x2a\x00', b'MM\x00\x2a'):
        return 'tiff'
    else:
        # Default to png
        return 'png'


# Maximum dimension for OCR processing (longer side)
MAX_OCR_DIMENSION = 2200


def resize_image_if_needed(image_path: str, output_path: str) -> bool:
    """
    Resize image if it exceeds MAX_OCR_DIMENSION.
    Uses lossless PNG output to preserve quality.
    Returns True if image was resized, False if copied as-is.
    """
    from PIL import Image

    with Image.open(image_path) as img:
        width, height = img.size
        max_dim = max(width, height)

        if max_dim <= MAX_OCR_DIMENSION:
            # Image is small enough, just copy it
            img.save(output_path, 'PNG')
            return False

        # Calculate new dimensions maintaining aspect ratio
        scale = MAX_OCR_DIMENSION / max_dim
        new_width = int(width * scale)
        new_height = int(height * scale)

        # Resize using high-quality Lanczos resampling
        resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        resized.save(output_path, 'PNG')
        return True


def process_request(request: dict) -> dict:
    """Process a single OCR request."""
    import time

    image_path = request.get("image_path")

    if not image_path:
        return {"success": False, "error": "Missing image_path"}

    if not Path(image_path).is_file():
        return {"success": False, "error": f"File not found: {image_path}"}

    # Preprocess: resize large images and save as PNG (PaddleOCR needs proper extension)
    temp_path = None
    try:
        temp_path = f"/tmp/ocr_input_{int(time.time() * 1000000)}.png"
        was_resized = resize_image_if_needed(image_path, temp_path)

        full_text, paragraphs = run_ocr(temp_path)

        if not full_text.strip():
            return {"success": False, "error": "No text detected"}

        return {
            "success": True,
            "text": full_text,
            "paragraphs": paragraphs
        }
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        # Clean up temp file
        if temp_path and Path(temp_path).exists():
            try:
                Path(temp_path).unlink()
            except:
                pass


def main():
    """Main loop - read requests from stdin, write responses to stdout."""
    # Initialize OCR model once at startup
    sys.stderr.write("Loading PaddleOCR model...\n")
    sys.stderr.flush()

    try:
        init_ocr()
        sys.stderr.write("PaddleOCR model loaded successfully\n")
        sys.stderr.flush()
    except Exception as e:
        sys.stderr.write(f"Failed to load PaddleOCR: {e}\n")
        sys.stderr.flush()
        sys.exit(1)

    # Signal ready
    print(json.dumps({"ready": True}), flush=True)

    # Process requests from stdin
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            request = json.loads(line)
            response = process_request(request)
        except json.JSONDecodeError as e:
            response = {"success": False, "error": f"Invalid JSON: {e}"}
        except Exception as e:
            response = {"success": False, "error": f"Unexpected error: {e}"}

        # Send response
        print(json.dumps(response), flush=True)


if __name__ == "__main__":
    main()
