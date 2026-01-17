#!/usr/bin/env python3
"""
PaddleOCR wrapper for BookToNote OCR Server.
Provides significantly better accuracy than Tesseract.

Usage: python ocr_engine.py <image_path> [output_file]

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

# Suppress PaddlePaddle logging
os.environ["GLOG_minloglevel"] = "2"
os.environ["GLOG_v"] = "0"
os.environ["DISABLE_MODEL_SOURCE_CHECK"] = "True"


def run_ocr(image_path: str) -> tuple[str, list[str]]:
    """
    Run PaddleOCR on an image and return extracted text.

    Returns:
        tuple of (full_text, list_of_paragraphs)
    """
    from paddleocr import PaddleOCR

    # Initialize PaddleOCR
    # use_textline_orientation=True enables text direction classification
    # lang='en' for English (can be changed or made configurable)
    ocr = PaddleOCR(
        use_textline_orientation=True,
        lang='en',
    )

    # Run OCR using the new predict API
    result = ocr.predict(image_path)

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
            # Threshold is relative to typical line height
            gap = y_pos - last_y
            if gap > 40:  # Adjust this threshold as needed
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


def main():
    if len(sys.argv) < 2:
        print("Usage: python ocr_engine.py <image_path> [output_file]", file=sys.stderr)
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
