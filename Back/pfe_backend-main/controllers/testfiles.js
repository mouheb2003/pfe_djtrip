const cloudinary = require('../config/cloudinary');

// Test upload to Cloudinary
exports.testUpload = async (req, res) => {
  try {
    console.log('Received file:', req.file);
    console.log('Received body:', req.body);

    if (!req.file) {
      return res.status(400).json({ 
        message: 'No file uploaded',
        help: 'Make sure to use "image" as the field name in Postman form-data'
      });
    }

    // File information from Cloudinary (via multer-storage-cloudinary)
    const fileInfo = {
      message: 'File uploaded successfully to Cloudinary',
      file: {
        filename: req.file.filename,
        path: req.file.path,
        size: req.file.size,
        format: req.file.format,
        url: req.file.path,
        publicId: req.file.filename
      }
    };

    res.status(200).json(fileInfo);
  } catch (err) {
    console.error('Upload error:', err);
    res.status(500).json({ 
      message: 'Error uploading file to Cloudinary', 
      error: err.message 
    });
  }
};

// Test multiple files upload
exports.testMultipleUpload = async (req, res) => {
  try {
    console.log('Received files:', req.files);
    console.log('Received body:', req.body);

    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ 
        message: 'No files uploaded',
        help: 'Make sure to use "images" as the field name in Postman form-data and select multiple files'
      });
    }

    const filesInfo = req.files.map(file => ({
      filename: file.filename,
      path: file.path,
      size: file.size,
      format: file.format,
      url: file.path,
      publicId: file.filename
    }));

    res.status(200).json({
      message: `${req.files.length} files uploaded successfully to Cloudinary`,
      files: filesInfo
    });
  } catch (err) {
    console.error('Multiple upload error:', err);
    res.status(500).json({ 
      message: 'Error uploading files to Cloudinary', 
      error: err.message 
    });
  }
};

// Delete test file from Cloudinary
exports.deleteTestFile = async (req, res) => {
  try {
    const { publicId } = req.body;

    if (!publicId) {
      return res.status(400).json({ message: 'Public ID is required' });
    }

    const result = await cloudinary.uploader.destroy(publicId);

    if (result.result === 'ok') {
      res.status(200).json({
        message: 'File deleted successfully from Cloudinary',
        result
      });
    } else {
      res.status(404).json({
        message: 'File not found or already deleted',
        result
      });
    }
  } catch (err) {
    res.status(500).json({ 
      message: 'Error deleting file from Cloudinary', 
      error: err.message 
    });
  }
};
