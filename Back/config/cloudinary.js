const cloudinary = require("cloudinary").v2;

cloudinary.config({
  cloud_name: process.env.CLOUD_NAME,
  api_key: process.env.API_KEY,
  api_secret: process.env.API_SECRET,
});

if (
  !process.env.CLOUD_NAME ||
  !process.env.API_KEY ||
  !process.env.API_SECRET
) {
  console.warn(
    "⚠️  Cloudinary credentials are not fully configured. Image uploads will fail.",
  );
} else {
  console.log("✅ Cloudinary configured for cloud:", process.env.CLOUD_NAME);
}

module.exports = cloudinary;
