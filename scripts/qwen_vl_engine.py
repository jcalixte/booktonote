#!/usr/bin/env python3
"""
Qwen2-VL OCR wrapper for BookToNote OCR Server.
Uses Qwen2-VL-2B-Instruct for high-quality text extraction from book pages.

Usage: python qwen_vl_engine.py <image_path> [output_file]

If output_file is provided, writes text there. Otherwise prints to stdout.
Exit codes:
  0 - Success
  1 - No text detected
  2 - File not found
  3 - Processing error
"""

import sys
import os
from pathlib import Path

# Suppress warnings
os.environ["TOKENIZERS_PARALLELISM"] = "false"

# Maximum image dimension (resize guard)
MAX_IMAGE_SIZE = 1024


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

    Returns:
        tuple of (full_text, list_of_paragraphs)
    """
    import torch
    from PIL import Image
    from transformers import Qwen2VLForConditionalGeneration, AutoProcessor
    from qwen_vl_utils import process_vision_info

    # Select device
    if torch.cuda.is_available():
        device = "cuda"
        torch_dtype = torch.float16
    elif torch.backends.mps.is_available():
        device = "mps"
        torch_dtype = torch.float32  # MPS needs float32
    else:
        device = "cpu"
        torch_dtype = torch.float32

    # Load model and processor
    model_id = "Qwen/Qwen2-VL-2B-Instruct"

    model = Qwen2VLForConditionalGeneration.from_pretrained(
        model_id,
        dtype=torch_dtype,
        device_map=device
    )

    processor = AutoProcessor.from_pretrained(model_id)

    # Load and resize image
    image = Image.open(image_path).convert("RGB")
    original_size = image.size
    image = resize_image_if_needed(image)

    if image.size != original_size:
        # Save resized image to temp file for processing
        temp_path = "/tmp/qwen_vl_resized.jpg"
        image.save(temp_path, quality=95)
        image_file = temp_path
    else:
        image_file = image_path

    # Prepare messages for OCR
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "image", "image": f"file://{image_file}"},
                {"type": "text", "text": "Extract all the text from this book page. Output only the text, preserving paragraphs."},
            ],
        }
    ]

    # Process inputs
    text = processor.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    image_inputs, video_inputs = process_vision_info(messages)
    inputs = processor(
        text=[text],
        images=image_inputs,
        videos=video_inputs,
        padding=True,
        return_tensors="pt",
    ).to(device)

    # Generate
    generated_ids = model.generate(**inputs, max_new_tokens=2048)
    generated_ids_trimmed = [
        out_ids[len(in_ids):] for in_ids, out_ids in zip(inputs.input_ids, generated_ids)
    ]

    full_text = processor.batch_decode(
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


def main():
    if len(sys.argv) < 2:
        print("Usage: python qwen_vl_engine.py <image_path> [output_file]", file=sys.stderr)
        sys.exit(3)

    image_path = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    # Check if file exists
    if not Path(image_path).is_file():
        print(f"Error: File not found: {image_path}", file=sys.stderr)
        sys.exit(2)

    try:
        full_text, paragraphs = run_ocr(image_path)

        if not full_text.strip():
            print("No text detected", file=sys.stderr)
            sys.exit(1)

        if output_file:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(full_text)
        else:
            print(full_text)

        sys.exit(0)

    except Exception as e:
        print(f"Error processing image: {e}", file=sys.stderr)
        sys.exit(3)


if __name__ == "__main__":
    main()
