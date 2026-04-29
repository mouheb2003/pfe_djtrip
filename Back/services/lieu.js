const cloudinary = require("../config/cloudinary");

/**
 * Service for managing place (lieu) operations
 */
class LieuService {
  /**
   * Uploads an image to Cloudinary
   * @param {Buffer} fileBuffer - Image file buffer
   * @param {Object} options - Upload options
   * @returns {Promise<Object>} Upload result with secure_url
   */
  static async uploadImageToCloudinary(fileBuffer, options = {}) {
    const defaultOptions = {
      folder: "DJTrip/lieux",
      transformation: {
        width: 1200,
        height: 800,
        crop: "limit",
        quality: "auto",
      },
    };

    const uploadOptions = { ...defaultOptions, ...options };

    return new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        uploadOptions,
        (error, result) => {
          if (error) {
            console.error("❌ Cloudinary upload error:", error);
            reject(error);
          } else {
            console.log("✅ Cloudinary upload successful:", result.secure_url);
            resolve(result);
          }
        },
      );

      uploadStream.end(fileBuffer);
    });
  }

  /**
   * Uploads multiple images to Cloudinary
   * @param {Array<Buffer>} fileBuffers - Array of image file buffers
   * @returns {Promise<Array<String>>} Array of uploaded image URLs
   */
  static async uploadMultipleImages(fileBuffers) {
    try {
      const uploadPromises = fileBuffers.map((buffer) =>
        this.uploadImageToCloudinary(buffer),
      );

      const results = await Promise.all(uploadPromises);
      return results.map((result) => result.secure_url);
    } catch (error) {
      console.error("❌ Error uploading multiple images:", error);
      throw error;
    }
  }

  /**
   * Deletes an image from Cloudinary
   * @param {String} imageUrl - URL of the image to delete
   * @returns {Promise<Object>} Deletion result
   */
  static async deleteImageFromCloudinary(imageUrl) {
    try {
      // Extract the public_id from the Cloudinary URL
      const urlParts = imageUrl.split("/");
      const filename = urlParts[urlParts.length - 1];
      const publicId = `DJTrip/lieux/${filename.split(".")[0]}`;

      const result = await cloudinary.uploader.destroy(publicId);
      console.log("🗑️ Image deleted from Cloudinary:", publicId);
      return result;
    } catch (error) {
      console.error("❌ Error deleting image from Cloudinary:", error);
      throw error;
    }
  }
}

module.exports = LieuService;
