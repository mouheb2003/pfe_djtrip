const express = require("express");
const router = express.Router();
const multer = require("multer");
const path = require("path");
const wrapRouter = require("../middleware/wrapRouter");
const { cacheGet, invalidateCache } = require("../middleware/cache");
const { verifyToken } = require("../middleware/auth");
const imageUpload = require("../middleware/upload");
const messageController = require("../controllers/message");

const audioUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_, file, cb) => {
    const mime = (file.mimetype || "").toLowerCase();
    const ext = path.extname(file.originalname || "").toLowerCase();
    const allowedAudioExt = [
      ".m4a",
      ".aac",
      ".mp3",
      ".wav",
      ".ogg",
      ".webm",
      ".amr",
    ];
    const isAudioMime = mime.startsWith("audio/");
    const isGenericMobileMime = mime === "application/octet-stream";
    const isAllowedByExt = allowedAudioExt.includes(ext);

    if (isAudioMime || isGenericMobileMime || isAllowedByExt) {
      return cb(null, true);
    }
    return cb(new Error("Only audio files are allowed"));
  },
});

const videoUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 30 * 1024 * 1024 },
  fileFilter: (_, file, cb) => {
    if (file.mimetype && file.mimetype.startsWith("video/")) {
      return cb(null, true);
    }
    return cb(new Error("Only video files are allowed"));
  },
});

// All message routes require a valid JWT
router.use(verifyToken);

router.get(
  "/conversations",
  cacheGet("messages:conversations", 30),
  messageController.getConversations,
);
router.post(
  "/conversations/:partnerId/archive",
  invalidateCache(["messages"]),
  messageController.archiveConversation,
);
router.delete(
  "/conversations/:partnerId/archive",
  invalidateCache(["messages"]),
  messageController.unarchiveConversation,
);
router.delete(
  "/conversations/:partnerId",
  invalidateCache(["messages"]),
  messageController.deleteConversation,
);
router.get(
  "/with/:partnerId",
  cacheGet("messages:thread", 30),
  messageController.getMessages,
);
router.post(
  "/with/:partnerId",
  invalidateCache(["messages"]),
  messageController.sendMessage,
);
router.post(
  "/with/:partnerId/image",
  imageUpload.single("image"),
  invalidateCache(["messages"]),
  messageController.sendImageMessage,
);
router.post(
  "/with/:partnerId/audio",
  audioUpload.single("audio"),
  invalidateCache(["messages"]),
  messageController.sendAudioMessage,
);
router.post(
  "/with/:partnerId/video",
  videoUpload.single("video"),
  invalidateCache(["messages"]),
  messageController.sendVideoMessage,
);
router.put(
  "/:messageId",
  invalidateCache(["messages"]),
  messageController.editMessage,
);
router.delete(
  "/:messageId",
  invalidateCache(["messages"]),
  messageController.deleteMessage,
);
router.get(
  "/unread-count",
  cacheGet("messages:unread-count", 15),
  messageController.getUnreadCount,
);

// Ensure upload/filter errors are returned as JSON for mobile clients.
router.use((err, _req, res, next) => {
  if (!err) return next();

  if (err instanceof multer.MulterError) {
    if (err.code === "LIMIT_FILE_SIZE") {
      return res
        .status(400)
        .json({ success: false, message: "File too large" });
    }
    return res.status(400).json({ success: false, message: err.message });
  }

  if (err.message) {
    return res.status(400).json({ success: false, message: err.message });
  }

  return res.status(500).json({ success: false, message: "Upload error" });
});

module.exports = wrapRouter(router);
