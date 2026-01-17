#!/usr/bin/env python3
"""
Surya OCR wrapper for BookToNote OCR Server.
Uses Surya for high-quality text extraction.

Usage: python surya_engine.py <image_path> [output_file]

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


def run_ocr(image_path: str) -> tuple[str, list[str]]:
    """
    Run Surya OCR on an image and return extracted text.

    Returns:
        tuple of (full_text, list_of_paragraphs)
    """
    from PIL import Image
    from surya.detection import DetectionPredictor
    from surya.recognition import RecognitionPredictor, FoundationPredictor

    # Load models - v0.17.0 requires FoundationPredictor for recognition
    det_predictor = DetectionPredictor()
    foundation_predictor = FoundationPredictor()
    rec_predictor = RecognitionPredictor(foundation_predictor)

    # Load image
    image = Image.open(image_path)
    images = [image]

    # Run OCR - recognition predictor handles detection internally
    results = rec_predictor(images, det_predictor=det_predictor)

    if not results or not results[0].text_lines:
        return "", []

    # Extract text lines with their positions
    lines = []
    for text_line in results[0].text_lines:
        text = text_line.text.strip()
        if text and text_line.confidence > 0.5:
            # Get vertical position from bounding box
            bbox = text_line.bbox
            y_pos = (bbox[1] + bbox[3]) / 2  # Average of top and bottom y
            lines.append((y_pos, text))

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
        print("Usage: python surya_engine.py <image_path> [output_file]", file=sys.stderr)
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
