# BookToNote OCR Server

A high-performance image-to-text OCR server built with Gleam, powered by Tesseract OCR.

## Features

- **Fast OCR Processing**: Extract text from images using Tesseract OCR
- **Multiple Format Support**: JPG, JPEG, PNG, TIFF, and PDF files
- **Paragraph Array**: Returns both full text and split paragraphs array
- **Character Normalization**: Automatically converts smart quotes, fancy dashes, and special characters to ASCII equivalents
- **UTF-8 Compatible**: Clean, UTF-8 compatible output
- **Type-Safe**: Built with Gleam for robust, type-safe code
- **Production Ready**: Dockerized with GitLab CI/CD integration
- **REST API**: Simple JSON API for easy integration

## API Endpoints

### POST /ocr

Upload an image for text extraction.

**Request:**

```bash
curl -X POST http://localhost:8080/ocr \
  -F "image=@your-image.jpg"
```

**Response:**

```json
{
  "success": true,
  "data": {
    "text": "Extracted text from image...",
    "paragraphs": [
      "First paragraph",
      "Second paragraph",
      "Third paragraph"
    ]
  }
}
```

**Response Fields:**

- `text`: Full extracted text with paragraphs separated by `\n\n` (double newlines). Each paragraph can contain single `\n` for line breaks within the paragraph.
- `paragraphs`: Array of individual paragraphs (split by `\n\n`). Each element is one paragraph with its internal line breaks preserved.

**Note:** The output is clean text, not markdown-formatted. You can format the paragraphs as markdown on the frontend as needed.

### GET /health

Check service health and Tesseract availability.

**Response:**

```json
{
  "status": "healthy",
  "services": {
    "tesseract": "available"
  }
}
```

### GET /

API documentation and service information.

## Development

### Prerequisites

- [Gleam](https://gleam.run/) >= 1.14.0
- [Erlang/OTP](https://www.erlang.org/) >= 28.0
- [Tesseract OCR](https://github.com/tesseract-ocr/tesseract)

### Install Tesseract

**macOS:**

```sh
brew install tesseract
```

**Ubuntu/Debian:**

```sh
apt-get install tesseract-ocr tesseract-ocr-eng
```

### Run Locally

```sh
# Install dependencies
gleam deps download

# Run the server
gleam run

# Run tests
gleam test
```

The server will start on `http://localhost:8080`

### API Testing with Bruno

A complete Bruno API collection is included for easy testing:

```sh
# Open Bruno and load the collection
bruno/BookToNote-OCR/
```

The collection includes:

- Health check endpoint
- API documentation endpoint
- Image upload for OCR (with file picker)
- Error handling test cases
- Multiple environments (Local, Docker, Production)

See [bruno/BookToNote-OCR/README.md](bruno/BookToNote-OCR/README.md) for detailed instructions.

## Docker Deployment

### Build and Run with Docker

```sh
# Build the image
docker build -t booktonote-ocr .

# Run the container
docker run -d -p 8080:8080 --name booktonote booktonote-ocr
```

### Using Docker Compose

```sh
# Start the service
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the service
docker-compose down
```

## GitLab CI/CD

This project includes a `.gitlab-ci.yml` configuration that automatically:

1. **Builds** the Docker image on every push
2. **Tests** the built image (health checks, API endpoints)
3. **Deploys** to staging automatically on main branch
4. **Deploys** to production manually (requires approval)

### Setup on GitLab

1. Push your code to GitLab
2. The CI/CD pipeline will automatically build and test your image
3. Images are pushed to GitLab Container Registry
4. For production deployment, manually trigger the deploy job

### Pull from GitLab Registry

```sh
# Login to GitLab registry
docker login registry.gitlab.com

# Pull the image
docker pull registry.gitlab.com/your-username/booktonote:latest

# Run it
docker run -d -p 8080:8080 registry.gitlab.com/your-username/booktonote:latest
```

## Configuration

### Environment Variables

- `PORT`: Server port (default: 8080)

### File Limits

- Maximum file size: 10MB
- Supported formats: .jpg, .jpeg, .png, .tiff, .tif, .pdf

### Character Normalization

The OCR output is automatically normalized to ensure clean, UTF-8 compatible text:

**Smart Quotes → Straight Quotes:**

- `"` `"` `„` → `"`
- `'` `'` `‚` → `'`

**Fancy Dashes → Regular Hyphens:**

- `—` (em-dash) → `-`
- `–` (en-dash) → `-`

**Other Normalizations:**

- `…` (ellipsis) → `...`
- `•` `◦` (bullets) → `-`
- Various Unicode spaces → regular space
- Zero-width characters removed

**Output Format:**

- Clean plain text (not markdown-formatted)
- Paragraphs separated by double newlines (`\n\n`)
- Single newlines (`\n`) preserved within paragraphs for line breaks
- Empty paragraphs removed
- Trailing/leading whitespace trimmed per paragraph

## Architecture

```
src/
├── booktonote.gleam              # Server entry point
└── booktonote/
    ├── types.gleam               # Type definitions
    ├── router.gleam              # HTTP routing
    ├── handlers/
    │   ├── ocr.gleam            # OCR upload handler
    │   └── health.gleam         # Health check handler
    └── services/
        └── tesseract.gleam      # Tesseract integration
```

## Error Handling

The API returns structured error responses:

```json
{
  "success": false,
  "error": {
    "type": "invalid_image_format",
    "message": "Supported formats: jpg, jpeg, png, tiff, pdf"
  }
}
```

**Error Types:**

- `tesseract_not_found` (503): Tesseract is not installed
- `invalid_image_format` (400): Unsupported file format
- `file_too_large` (413): File exceeds 10MB limit
- `processing_failed` (500): OCR processing error
- `no_text_detected` (200): No text found in image

## License

Apache-2.0

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
