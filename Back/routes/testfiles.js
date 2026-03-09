const express = require('express');
const router = express.Router();
const testFilesController = require('../controllers/testfiles');
const upload = require('../middleware/upload');

// POST /test-upload - Test single file upload to Cloudinary
// In Postman: use field name "image" (type: File)
router.post('/test-upload', upload.single('image'), testFilesController.testUpload);

// POST /test-multiple-upload - Test multiple files upload to Cloudinary
// In Postman: use field name "images" (type: File) and select multiple files
router.post('/test-multiple-upload', upload.array('images', 5), testFilesController.testMultipleUpload);

// DELETE /delete-test-file - Delete a test file from Cloudinary
router.delete('/delete-test-file', testFilesController.deleteTestFile);

module.exports = router;
