const cloudinary = require("cloudinary").v2;

cloudinary.config({
  cloud_name: process.env.CLOUD_NAME,
  api_key: process.env.API_KEY,
  api_secret: process.env.API_SECRET,
});

// Log configuration status with values for debugging
console.log("🔧 Cloudinary Configuration:");
console.log("  - cloud_name:", process.env.CLOUD_NAME);
console.log("  - api_key:", process.env.API_KEY);
console.log(
  "  - api_secret:",
  process.env.API_SECRET
    ? `${process.env.API_SECRET.substring(0, 5)}...${process.env.API_SECRET.substring(process.env.API_SECRET.length - 3)} (length: ${process.env.API_SECRET.length})`
    : "MISSING",
);

module.exports = cloudinary;
