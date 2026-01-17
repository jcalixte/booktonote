# BookToNote OCR API - Bruno Collection

This is a Bruno API collection for testing the BookToNote OCR server.

## Setup

1. **Install Bruno**: Download from [usebruno.com](https://www.usebruno.com/)
2. **Open Collection**: In Bruno, click "Open Collection" and select the `bruno/BookToNote-OCR` folder
3. **Select Environment**: Choose "Local" environment from the dropdown (top right)
4. **Start Server**: Make sure your OCR server is running (`gleam run` or via Docker)

## Available Requests

### 1. Health Check
- **Method**: GET
- **Endpoint**: `/health`
- **Description**: Check if the OCR service is healthy

### 2. API Documentation
- **Method**: GET
- **Endpoint**: `/`
- **Description**: Get API information and available endpoints

### 3. Upload Image for OCR
- **Method**: POST
- **Endpoint**: `/ocr`
- **Description**: Upload an image to extract text
- **How to use**:
  1. Open the request
  2. Go to the "Body" tab
  3. Click on the "image" field
  4. Click "Choose File" button
  5. Select an image from your computer (JPG, PNG, TIFF, or PDF)
  6. Click "Send"

### 4. Upload Invalid Format (Test)
- Tests error handling for unsupported file formats
- Upload a .txt file to see the error response

### 5. Missing File Field (Test)
- Tests error handling when no file is uploaded
- Shows the error response for missing required field

## Environments

### Local
- **baseUrl**: `http://localhost:8080`
- Use this when running the server locally with `gleam run`

### Docker
- **baseUrl**: `http://localhost:8080`
- Use this when running the server in Docker

### Production
- **baseUrl**: `https://your-server.com`
- Update this with your production server URL

## Tips

- Switch between environments using the dropdown in the top right
- Use the "Tests" tab to add automated assertions
- Check the "Docs" tab in each request for detailed information
- All requests use `{{baseUrl}}` variable which comes from the selected environment

## Testing Workflow

1. Start with "Health Check" to verify the server is running
2. Check "API Documentation" to see available endpoints
3. Use "Upload Image for OCR" to test actual OCR functionality
4. Try error scenarios with "Upload Invalid Format" and "Missing File Field"

## Example cURL Commands

If you prefer command line:

```bash
# Health check
curl http://localhost:8080/health

# Upload image
curl -X POST http://localhost:8080/ocr -F "image=@/path/to/image.jpg"
```
