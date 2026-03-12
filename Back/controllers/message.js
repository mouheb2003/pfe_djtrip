const Message = require("../models/message");
const User = require("../models/user");

// Get all conversations for the current user (one entry per unique partner)
exports.getConversations = async (req, res) => {
  try {
    const userId = req.user.userId;

    // All messages involving this user, newest first
    const messages = await Message.find({
      $or: [{ sender_id: userId }, { receiver_id: userId }],
    }).sort({ createdAt: -1 });

    // Collect last message per unique partner
    const partnerMap = new Map(); // partnerId → lastMessage
    for (const msg of messages) {
      const partnerId =
        msg.sender_id.toString() === userId
          ? msg.receiver_id.toString()
          : msg.sender_id.toString();
      // Skip messages sent to yourself
      if (partnerId === userId) continue;
      if (!partnerMap.has(partnerId)) {
        partnerMap.set(partnerId, msg);
      }
    }

    const conversations = await Promise.all(
      Array.from(partnerMap.entries()).map(async ([partnerId, lastMsg]) => {
        const partner = await User.findById(partnerId).select(
          "fullname avatar userType isOnline",
        );
        const unreadCount = await Message.countDocuments({
          sender_id: partnerId,
          receiver_id: userId,
          is_read: false,
        });
        return { partner, lastMessage: lastMsg, unreadCount };
      }),
    );

    res.json(conversations);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Get message history between current user and a specific partner
exports.getMessages = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    const messages = await Message.find({
      $or: [
        { sender_id: userId, receiver_id: partnerId },
        { sender_id: partnerId, receiver_id: userId },
      ],
    }).sort({ createdAt: 1 });

    // Mark received messages as read
    await Message.updateMany(
      { sender_id: partnerId, receiver_id: userId, is_read: false },
      { is_read: true },
    );

    res.json(messages);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Get total unread message count for the current user
exports.getUnreadCount = async (req, res) => {
  try {
    const count = await Message.countDocuments({
      receiver_id: req.user.userId,
      is_read: false,
    });
    res.json({ count });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
