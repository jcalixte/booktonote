# How to Open This Collection in Bruno

## Method 1: Open Collection (Recommended)

1. **Open Bruno** application
2. Click **"Open Collection"** button (or File → Open Collection)
3. **Navigate to and SELECT the folder**: `booktonote/bruno/BookToNote-OCR`
   - Important: Select the entire `BookToNote-OCR` folder, NOT the bruno.json file
4. The collection will appear in Bruno's sidebar

## Method 2: Alternative

If Method 1 doesn't work, try:

1. In Bruno, go to **File → Open Collection**
2. Browse to: `/Users/julien/lab/booktonote/bruno/BookToNote-OCR`
3. Click **"Select Folder"** or **"Open"**

## After Opening

1. You should see all requests in the left sidebar:
   - Health Check
   - API Documentation
   - Upload Image for OCR
   - Upload Invalid Format
   - Missing File Field

2. Select the **"Local"** environment from the dropdown in the top-right corner

3. Make sure your server is running:
   ```bash
   cd /Users/julien/lab/booktonote
   gleam run
   ```

4. Click on "Upload Image for OCR" request and test it!

## Troubleshooting

### "Unsupported collection format" error
This usually means you're trying to import the bruno.json file directly. Instead:
- Use "Open Collection" and select the FOLDER (BookToNote-OCR)
- Do NOT try to import the bruno.json file

### Collection doesn't appear
- Make sure you selected the `BookToNote-OCR` folder, not the parent `bruno` folder
- Check that all .bru files are in the `BookToNote-OCR` directory

### Can't select image file
- Go to the "Body" tab
- Click on the file input field next to "image"
- A file picker should appear
- Select your image (JPG, PNG, TIFF, or PDF)
