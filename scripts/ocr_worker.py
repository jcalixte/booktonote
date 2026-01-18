#!/usr/bin/env python3
"""
Persistent Qwen2-VL OCR worker for BookToNote OCR Server.
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

# Suppress warnings
os.environ["TOKENIZERS_PARALLELISM"] = "false"

# Global model instances - loaded once at startup
_model = None
_processor = None
_device = None
_torch_dtype = None

# Maximum image dimension (resize guard for memory)
MAX_IMAGE_SIZE = 1024


def init_ocr():
    """Initialize Qwen2-VL model once at startup."""
    global _model, _processor, _device, _torch_dtype

    import torch
    from transformers import Qwen2VLForConditionalGeneration, AutoProcessor

    # Select device
    if torch.cuda.is_available():
        _device = "cuda"
        _torch_dtype = torch.float16
    elif torch.backends.mps.is_available():
        _device = "mps"
        _torch_dtype = torch.float32  # MPS needs float32
    else:
        _device = "cpu"
        _torch_dtype = torch.float32

    model_id = "Qwen/Qwen2-VL-2B-Instruct"

    _model = Qwen2VLForConditionalGeneration.from_pretrained(
        model_id,
        dtype=_torch_dtype,
        device_map=_device
    )

    _processor = AutoProcessor.from_pretrained(model_id)

    return _model, _processor


def resize_image_if_needed(image):
    """
    Resize image if it exceeds MAX_IMAGE_SIZE on any dimension.
    Returns the (possibly resized) image.
    """
    from PIL import Image

    width, height = image.size

    if width <= MAX_IMAGE_SIZE and height <= MAX_IMAGE_SIZE:
        return image

    # Calculate resize ratio
    ratio = min(MAX_IMAGE_SIZE / width, MAX_IMAGE_SIZE / height)
    new_size = (int(width * ratio), int(height * ratio))

    return image.resize(new_size, Image.Resampling.LANCZOS)


def run_ocr(image_path: str) -> tuple[str, list[str]]:
    """
    Run Qwen2-VL OCR on an image and return extracted text.
    Uses the global pre-loaded model instance.

    Returns:
        tuple of (full_text, list_of_paragraphs)
    """
    global _model, _processor, _device

    from PIL import Image
    from qwen_vl_utils import process_vision_info

    # Load and resize image
    image = Image.open(image_path).convert("RGB")
    image = resize_image_if_needed(image)

    # Save resized image to temp file for processing
    temp_path = "/tmp/qwen_vl_resized.jpg"
    image.save(temp_path, quality=95)

    # Prepare messages for OCR
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "image", "image": f"file://{temp_path}"},
                {"type": "text", "text": "Extract all the text from this book page. Output only the text, preserving paragraphs."},
            ],
        }
    ]

    # Process inputs
    text = _processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    image_inputs, video_inputs = process_vision_info(messages)
    inputs = _processor(
        text=[text],
        images=image_inputs,
        videos=video_inputs,
        padding=True,
        return_tensors="pt",
    ).to(_device)

    # Generate
    generated_ids = _model.generate(**inputs, max_new_tokens=2048)
    generated_ids_trimmed = [
        out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
    ]

    full_text = _processor.batch_decode(
        generated_ids_trimmed, skip_special_tokens=True, clean_up_tokenization_spaces=False
    )[0].strip()

    if not full_text:
        return "", []

    # Split into paragraphs
    raw_paragraphs = full_text.split("\n\n")

    # If no double newlines, try single newlines
    if len(raw_paragraphs) == 1:
        raw_paragraphs = full_text.split("\n")

    # Clean up paragraphs
    paragraphs = []
    for p in raw_paragraphs:
        cleaned = " ".join(p.split())  # Normalize whitespace
        if cleaned:
            paragraphs.append(cleaned)

    # Reconstruct full text
    full_text = "\n\n".join(paragraphs)

    return full_text, paragraphs


def process_request(request: dict) -> dict:
    """Process a single OCR request."""
    image_path = request.get("image_path")

    if not image_path:
        return {"success": False, "error": "Missing image_path"}

    if not Path(image_path).is_file():
        return {"success": False, "error": f"File not found: {image_path}"}

    try:
        full_text, paragraphs = run_ocr(image_path)

        if not full_text.strip():
            return {"success": False, "error": "No text detected"}

        return {
            "success": True,
            "text": full_text,
            "paragraphs": paragraphs
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def main():
    """Main loop - read requests from stdin, write responses to stdout."""
    # Initialize model once at startup
    sys.stderr.write("Loading Qwen2-VL model...\n")
    sys.stderr.flush()

    try:
        init_ocr()
        sys.stderr.write("Qwen2-VL model loaded successfully\n")
        sys.stderr.flush()
    except Exception as e:
        sys.stderr.write(f"Failed to load Qwen2-VL: {e}\n")
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
