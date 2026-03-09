const multer = require("multer");
const path = require("path");

// Use memory storage to upload directly to Cloudinary (no local files)
const storage = multer.memoryStorage();

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB max
  },
  fileFilter: function (req, file, cb) {
    console.log("📄 File filter check:");
    console.log("  - Original name:", file.originalname);
    console.log("  - Mimetype:", file.mimetype);
    console.log("  - Fieldname:", file.fieldname);

    // Accept common image formats including WebP (used by Android)
    const allowedTypes = /jpeg|jpg|png|webp/;
    const allowedMimeTypes = /image\/(jpeg|jpg|png|webp|octet-stream)/;

    const extname = allowedTypes.test(
      path.extname(file.originalname).toLowerCase(),
    );
    const mimetype = allowedMimeTypes.test(file.mimetype);

    console.log("  - Extension valid:", extname);
    console.log("  - Mimetype valid:", mimetype);

    if (mimetype || extname) {
      console.log("✅ File accepted");
      return cb(null, true);
    } else {
      console.log("❌ File rejected - invalid type");
      return cb(null, false);
    }
  },
});

module.exports = upload;
