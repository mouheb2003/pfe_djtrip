const Message = require("../models/message");
const User = require("../models/user");
const notificationEventBus = require("../services/notificationEventBus");
const cloudinary = require("../config/cloudinary");

// Socket.io will be set via app.locals from server.js
let io = null;

// Initialize io instance
exports.initSocketIO = (socketIO) => {
  io = socketIO;
  console.log('[MESSAGE CONTROLLER] Socket.io initialized');
};

const uploadMediaBuffer = (buffer, folder, resourceType = "video") =>
  new Promise((resolve, reject) => {
    const uploadStream = cloudinary.uploader.upload_stream(
      {
        folder,
        resource_type: resourceType,
      },
      (error, result) => {
        if (error) return reject(error);
        return resolve(result);
      },
    );
    uploadStream.end(buffer);
  });

// Get all conversations for the current user (one entry per unique partner)
exports.getConversations = async (req, res) => {
  try {
    const userId = req.user.userId;
    const currentUser = await User.findById(userId).select(
      "archivedConversationPartners deletedConversationPartners",
    );
    const archivedPartners = new Set(
      (currentUser?.archivedConversationPartners || []).map(String),
    );
    const deletedPartners = new Set(
      (currentUser?.deletedConversationPartners || []).map(String),
    );

    // All messages involving this user, newest first.
    // Warning messages are visible only to the warned receiver.
    const messages = await Message.find({
      $or: [
        {
          sender_id: userId,
          message_type: { $ne: "warning" },
        },
        {
          receiver_id: userId,
        },
      ],
    }).sort({ createdAt: -1 });

    // Check for new messages from deleted partners and restore conversations
    const partnersToRestore = [];
    const userIdString = String(userId).trim();
    for (const msg of messages) {
      const partnerId =
        msg.sender_id.toString().trim() === userIdString
          ? msg.receiver_id.toString().trim()
          : msg.sender_id.toString().trim();
      if (partnerId === userIdString) continue;
      if (deletedPartners.has(partnerId)) {
        partnersToRestore.push(partnerId);
      }
    }

    // Remove restored partners from deletedConversationPartners
    if (partnersToRestore.length > 0) {
      await User.findByIdAndUpdate(userId, {
        $pull: {
          deletedConversationPartners: { $in: partnersToRestore },
        },
      });
      // Update deletedPartners set for the rest of the function
      for (const partnerId of partnersToRestore) {
        deletedPartners.delete(partnerId);
      }
    }

    // Collect last message per unique partner
    const partnerMap = new Map(); // partnerId → lastMessage
    for (const msg of messages) {
      const partnerId =
        msg.sender_id.toString().trim() === userIdString
          ? msg.receiver_id.toString().trim()
          : msg.sender_id.toString().trim();
      // Skip messages sent to yourself
      if (partnerId === userIdString) continue;
      if (deletedPartners.has(partnerId)) continue;
      if (!partnerMap.has(partnerId)) {
        partnerMap.set(partnerId, msg);
      }
    }

    const conversations = await Promise.all(
      Array.from(partnerMap.entries()).map(async ([partnerId, lastMsg]) => {
        const partner = await User.findById(partnerId).select(
          "_id fullname avatar userType isOnline",
        );
        const unreadCount = await Message.countDocuments({
          sender_id: partnerId,
          receiver_id: userId,
          is_read: false,
        });
        const payload = lastMsg.toObject();
        if (payload.message_type === "audio" && !payload.content) {
          payload.content = "🎤 Voice message";
        }
        if (payload.message_type === "video" && !payload.content) {
          payload.content = "🎬 Video message";
        }
        return {
          partner: partner?.toObject() || {},
          lastMessage: payload,
          unreadCount,
          archived: archivedPartners.has(partnerId),
        };
      }),
    );

    res.json(conversations);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

exports.archiveConversation = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    await User.findByIdAndUpdate(userId, {
      $addToSet: { archivedConversationPartners: partnerId },
    });

    res.status(200).json({ success: true, archived: true, partnerId });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

exports.unarchiveConversation = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    await User.findByIdAndUpdate(userId, {
      $pull: { archivedConversationPartners: partnerId },
    });

    res.status(200).json({ success: true, archived: false, partnerId });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

exports.deleteConversation = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    await User.findByIdAndUpdate(userId, {
      $addToSet: { deletedConversationPartners: partnerId },
    });

    res.status(200).json({ success: true, partnerId });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Get message history between current user and a specific partner
exports.getMessages = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    // Check if partner is in deletedConversationPartners
    const currentUser = await User.findById(userId).select(
      "deletedConversationPartners",
    );
    const deletedPartners = new Set(
      (currentUser?.deletedConversationPartners || []).map(String),
    );

    console.log('🔍 [getMessages] userId:', userId);
    console.log('🔍 [getMessages] partnerId:', partnerId, 'type:', typeof partnerId);
    console.log('🔍 [getMessages] deletedPartners:', Array.from(deletedPartners));
    console.log('🔍 [getMessages] isDeleted:', deletedPartners.has(String(partnerId)));

    // If partner is in deleted list, return empty array (respect user's choice to clear)
    if (deletedPartners.has(String(partnerId))) {
      console.log('✅ [getMessages] Returning empty array - chat is cleared');
      return res.json([]);
    }

    const now = new Date();
    // Mark received messages as read with timestamp
    await Message.updateMany(
      { sender_id: partnerId, receiver_id: userId, is_read: false },
      { $set: { is_read: true, read_at: now } },
    );

    const messages = await Message.find({
      $or: [
        {
          sender_id: userId,
          receiver_id: partnerId,
          message_type: { $ne: "warning" },
        },
        { sender_id: partnerId, receiver_id: userId },
      ],
    })
      .sort({ createdAt: 1 })
      .lean();

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

// Send a message to a specific partner
exports.sendMessage = async (req, res) => {
  try {
    const senderId = req.user.userId;
    const { partnerId } = req.params;

    // Check if sender is blocked by receiver
    const receiver = await User.findById(partnerId).select('blockedUsers');
    const receiverBlockedUsers = new Set(
      (receiver?.blockedUsers || []).map(String),
    );

    if (receiverBlockedUsers.has(String(senderId))) {
      console.log('🚫 [sendMessage] Sender is blocked by receiver:', senderId, '->', partnerId);
      return res.status(403).json({ message: "You are blocked by this user" });
    }

    // Restore conversation if it was cleared (user is sending a message)
    await User.findByIdAndUpdate(senderId, {
      $pull: { deletedConversationPartners: partnerId },
    });

    console.log('🔍 [sendMessage] Restored conversation for userId:', senderId, 'partnerId:', partnerId);

    const { content, message_type } = req.body;

    if (!content || !content.trim()) {
      return res.status(400).json({ message: "Message content is required" });
    }

    const normalizedType = message_type === "warning" ? "warning" : "text";

    const senderRole = String(req.user.userType || "").toLowerCase();
    if (normalizedType === "warning" && senderRole !== "admin") {
      return res.status(403).json({ message: "Only admins can send warnings" });
    }

    const msg = new Message({
      sender_id: senderId,
      receiver_id: partnerId,
      content: content.trim(),
      message_type: normalizedType,
    });

    await msg.save();

    // Emit event for message notification
    try {
      const sender = await User.findById(senderId).select('fullname');
      await notificationEventBus.emitMessageReceived({
        recipientId: partnerId,
        senderId: senderId,
        senderName: sender?.fullname || 'Someone',
        conversationId: null,
        messageId: msg._id.toString(),
        content: content.trim(),
      });
    } catch (notifError) {
      console.warn('Failed to emit message received event:', notifError.message);
      // Don't fail the message send if notification fails
    }

    // Emit real-time via Socket.io
    try {
      if (io) {
        // Send to recipient's room (room name format: user_${userId})
        io.to(`user_${partnerId}`).emit('new_message', {
          _id: msg._id.toString(),
          sender_id: senderId,
          receiver_id: partnerId,
          content: content.trim(),
          message_type: normalizedType,
          createdAt: msg.createdAt,
        });
        console.log('✅ Socket.io message emitted to user_${partnerId}');
      }
    } catch (socketError) {
      console.warn('Failed to emit socket message:', socketError.message);
    }

    res.status(201).json({ message: msg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Send an image message to a specific partner
exports.sendImageMessage = async (req, res) => {
  try {
    const senderId = req.user.userId;
    const { partnerId } = req.params;

    if (!req.file || !req.file.buffer) {
      return res.status(400).json({ message: "Image file is required" });
    }

    const uploaded = await uploadMediaBuffer(
      req.file.buffer,
      "djtrip/messages/image",
      "image",
    );

    const msg = new Message({
      sender_id: senderId,
      receiver_id: partnerId,
      content: "🖼️ Image message",
      message_type: "image",
      media_url: uploaded.secure_url,
      media_duration: 0,
    });

    await msg.save();

    // Emit event for message notification
    try {
      const sender = await User.findById(senderId).select('fullname');
      await notificationEventBus.emitMessageReceived({
        recipientId: partnerId,
        senderId: senderId,
        senderName: sender?.fullname || 'Someone',
        conversationId: null,
        messageId: msg._id.toString(),
        content: "🖼️ Image message",
      });
    } catch (notifError) {
      console.warn('Failed to emit message received event:', notifError.message);
      // Don't fail the message send if notification fails
    }

    // Emit real-time via Socket.io
    try {
      if (io) {
        // Send to recipient's room (room name format: user_${userId})
        io.to(`user_${partnerId}`).emit('new_message', {
          _id: msg._id.toString(),
          sender_id: senderId,
          receiver_id: partnerId,
          content: "🖼️ Image message",
          message_type: "image",
          media_url: uploaded.secure_url,
          createdAt: msg.createdAt,
        });
        console.log('✅ Socket.io image message emitted to user_${partnerId}');
      }
    } catch (socketError) {
      console.warn('Failed to emit socket image message:', socketError.message);
    }

    res.status(201).json({ message: msg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Send an audio message to a specific partner
exports.sendAudioMessage = async (req, res) => {
  try {
    const senderId = req.user.userId;
    const { partnerId } = req.params;
    const durationSec = Number(req.body?.duration_sec || 0);

    if (!req.file || !req.file.buffer) {
      return res.status(400).json({ message: "Audio file is required" });
    }

    const uploaded = await uploadMediaBuffer(
      req.file.buffer,
      "djtrip/messages/audio",
    );

    const msg = new Message({
      sender_id: senderId,
      receiver_id: partnerId,
      content: "🎤 Voice message",
      message_type: "audio",
      media_url: uploaded.secure_url,
      media_duration: Number.isFinite(durationSec) ? durationSec : 0,
    });

    await msg.save();

    // Emit event for message notification
    try {
      const sender = await User.findById(senderId).select('fullname');
      await notificationEventBus.emitMessageReceived({
        recipientId: partnerId,
        senderId: senderId,
        senderName: sender?.fullname || 'Someone',
        conversationId: null,
        messageId: msg._id.toString(),
        content: "🎤 Voice message",
      });
    } catch (notifError) {
      console.warn('Failed to emit message received event:', notifError.message);
      // Don't fail the message send if notification fails
    }

    // Emit real-time via Socket.io
    try {
      if (io) {
        // Send to recipient's room (room name format: user_${userId})
        io.to(`user_${partnerId}`).emit('new_message', {
          _id: msg._id.toString(),
          sender_id: senderId,
          receiver_id: partnerId,
          content: "🎤 Voice message",
          message_type: "audio",
          media_url: uploaded.secure_url,
          media_duration: Number.isFinite(durationSec) ? durationSec : 0,
          createdAt: msg.createdAt,
        });
        console.log('✅ Socket.io audio message emitted to user_${partnerId}');
      }
    } catch (socketError) {
      console.warn('Failed to emit socket audio message:', socketError.message);
    }

    res.status(201).json({ message: msg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Send a video message to a specific partner
exports.sendVideoMessage = async (req, res) => {
  try {
    const senderId = req.user.userId;
    const { partnerId } = req.params;

    if (!req.file || !req.file.buffer) {
      return res.status(400).json({ message: "Video file is required" });
    }

    const uploaded = await uploadMediaBuffer(
      req.file.buffer,
      "djtrip/messages/video",
    );

    const msg = new Message({
      sender_id: senderId,
      receiver_id: partnerId,
      content: "🎬 Video message",
      message_type: "video",
      media_url: uploaded.secure_url,
      media_duration: 0,
    });

    await msg.save();

    // Emit event for message notification
    try {
      const sender = await User.findById(senderId).select('fullname');
      await notificationEventBus.emitMessageReceived({
        recipientId: partnerId,
        senderId: senderId,
        senderName: sender?.fullname || 'Someone',
        conversationId: null,
        messageId: msg._id.toString(),
        content: "🎬 Video message",
      });
    } catch (notifError) {
      console.warn('Failed to emit message received event:', notifError.message);
      // Don't fail the message send if notification fails
    }

    res.status(201).json({ message: msg });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Edit current user's message
exports.editMessage = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { messageId } = req.params;
    const { content } = req.body;

    if (!content || !content.trim()) {
      return res.status(400).json({ message: "Message content is required" });
    }

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ message: "Message not found" });
    }

    if (message.sender_id.toString() !== userId) {
      return res
        .status(403)
        .json({ message: "Not allowed to edit this message" });
    }

    message.content = content.trim();
    message.is_edited = true;
    message.edited_at = new Date();
    await message.save();

    res.status(200).json({ message });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Delete current user's message
exports.deleteMessage = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { messageId } = req.params;

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({ message: "Message not found" });
    }

    if (message.sender_id.toString() !== userId) {
      return res
        .status(403)
        .json({ message: "Not allowed to delete this message" });
    }

    await Message.findByIdAndDelete(messageId);
    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// Clear chat for current user (one-sided deletion)
exports.clearChat = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    console.log('🔍 [clearChat] userId:', userId);
    console.log('🔍 [clearChat] partnerId:', partnerId, 'type:', typeof partnerId);

    // Add partner to deletedConversationPartners
    const result = await User.findByIdAndUpdate(userId, {
      $addToSet: { deletedConversationPartners: partnerId },
    }, { new: true });

    console.log('🔍 [clearChat] Updated deletedConversationPartners:', result?.deletedConversationPartners);

    res.status(200).json({
      success: true,
      message: "Chat cleared successfully"
    });
  } catch (err) {
    console.error('❌ [clearChat] Error:', err);
    res.status(500).json({ message: err.message });
  }
};

// Block a user
exports.blockUser = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    console.log('🔍 [blockUser] userId:', userId, 'partnerId:', partnerId);

    // Add partner to blockedUsers
    await User.findByIdAndUpdate(userId, {
      $addToSet: { blockedUsers: partnerId },
    });

    res.status(200).json({
      success: true,
      message: "User blocked successfully"
    });
  } catch (err) {
    console.error('❌ [blockUser] Error:', err);
    res.status(500).json({ message: err.message });
  }
};

// Unblock a user
exports.unblockUser = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    console.log('🔍 [unblockUser] userId:', userId, 'partnerId:', partnerId);

    // Remove partner from blockedUsers
    await User.findByIdAndUpdate(userId, {
      $pull: { blockedUsers: partnerId },
    });

    res.status(200).json({
      success: true,
      message: "User unblocked successfully"
    });
  } catch (err) {
    console.error('❌ [unblockUser] Error:', err);
    res.status(500).json({ message: err.message });
  }
};

// Mute conversation
exports.muteConversation = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    console.log('🔍 [muteConversation] userId:', userId, 'partnerId:', partnerId);

    // Add partner to mutedConversationPartners
    await User.findByIdAndUpdate(userId, {
      $addToSet: { mutedConversationPartners: partnerId },
    });

    res.status(200).json({
      success: true,
      message: "Conversation muted successfully"
    });
  } catch (err) {
    console.error('❌ [muteConversation] Error:', err);
    res.status(500).json({ message: err.message });
  }
};

// Unmute conversation
exports.unmuteConversation = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { partnerId } = req.params;

    console.log('🔍 [unmuteConversation] userId:', userId, 'partnerId:', partnerId);

    // Remove partner from mutedConversationPartners
    await User.findByIdAndUpdate(userId, {
      $pull: { mutedConversationPartners: partnerId },
    });

    res.status(200).json({
      success: true,
      message: "Conversation unmuted successfully"
    });
  } catch (err) {
    console.error('❌ [unmuteConversation] Error:', err);
    res.status(500).json({ message: err.message });
  }
};

// Get blocked users for current user
exports.getBlockedUsers = async (req, res) => {
  try {
    const userId = req.user.userId;

    const user = await User.findById(userId).select('blockedUsers mutedConversationPartners');
    
    // Also find users who have blocked the current user
    const blockedByUsers = await User.find({ blockedUsers: userId }).select('_id');
    const blockedByUserIds = blockedByUsers.map(u => u._id.toString());
    
    res.status(200).json({
      success: true,
      blockedUsers: user?.blockedUsers || [],
      mutedConversationPartners: user?.mutedConversationPartners || [],
      blockedByUsers: blockedByUserIds,
    });
  } catch (err) {
    console.error('❌ [getBlockedUsers] Error:', err);
    res.status(500).json({ message: err.message });
  }
};
