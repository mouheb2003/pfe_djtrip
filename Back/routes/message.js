const express = require("express");
const router = express.Router();
const { verifyToken } = require("../middleware/auth");
const messageController = require("../controllers/message");

// All message routes require a valid JWT
router.use(verifyToken);

router.get("/conversations", messageController.getConversations);
router.get("/with/:partnerId", messageController.getMessages);
router.get("/unread-count", messageController.getUnreadCount);

module.exports = router;
