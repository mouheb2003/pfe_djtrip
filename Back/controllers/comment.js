const Comment = require("../models/comment");
const Post = require("../models/post");
const { sendPushNotification } = require("../services/notificationService");
const { createActivityLog } = require("../services/activityLogService");

// Helper function to get user reaction type
const getUserReaction = (reactions, userId) => {
  if (!reactions || !Array.isArray(reactions)) return null;
  const reaction = reactions.find((r) => String(r.user_id) === String(userId));
  return reaction ? reaction.type : null;
};

// Helper function to get reaction counts
const getReactionCounts = (reactions) => {
  if (!reactions || !Array.isArray(reactions)) return {};
  const counts = {};
  reactions.forEach((r) => {
    counts[r.type] = (counts[r.type] || 0) + 1;
  });
  return counts;
};

// Helper function to map comment for response
const mapComment = (comment, currentUserId = null) => {
  const user = comment.user_id || {};
  const parent = comment.parent_comment_id || {};
  
  return {
    _id: comment._id,
    post_id: comment.post_id,
    user_id: {
      _id: user._id,
      fullname: user.fullname || "Anonymous",
      avatar: user.avatar,
      userType: user.userType,
    },
    content: comment.content,
    parent_comment_id: comment.parent_comment_id
      ? {
          _id: parent._id,
          user_id: parent.user_id,
          content: parent.content,
        }
      : null,
    reactions: comment.reactions || [],
    total_reactions: comment.total_reactions || 0,
    user_reaction: currentUserId ? getUserReaction(comment.reactions, currentUserId) : null,
    reaction_counts: getReactionCounts(comment.reactions),
    created_at: comment.created_at,
    updated_at: comment.updated_at,
  };
};

// Create a new comment (IMMEDIATE PUBLICATION - NO PENDING)
exports.createComment = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { postId } = req.params;
    const { content, parentCommentId = null } = req.body;

    const trimmedContent = String(content || "").trim();
    if (!trimmedContent) {
      return res.status(400).json({ message: "Comment content is required" });
    }

    // Verify post exists and is active
    const post = await Post.findOne({ _id: postId, is_active: true });
    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    // Verify parent comment exists if provided
    if (parentCommentId) {
      const parentComment = await Comment.findOne({
        _id: parentCommentId,
        post_id: postId,
        is_active: true,
      });
      if (!parentComment) {
        return res.status(404).json({ message: "Parent comment not found" });
      }
    }

    // Create comment - IMMEDIATE PUBLICATION
    const comment = await Comment.create({
      post_id: postId,
      user_id: userId,
      content: trimmedContent,
      parent_comment_id: parentCommentId,
    });

    // Update post comment count
    await Post.findByIdAndUpdate(postId, {
      $inc: { comments_count: 1 },
    });

    // Get populated comment
    const populatedComment = await Comment.findById(comment._id)
      .populate("user_id", "fullname avatar userType")
      .populate("parent_comment_id", "user_id content")
      .lean();

    // SEND PUSH NOTIFICATIONS
    try {
      const notificationPromises = [];

      // Notify post owner
      if (String(post.author_id) !== String(userId)) {
        notificationPromises.push(
          sendPushNotification({
            userId: post.author_id,
            title: "Nouveau commentaire",
            body: `${populatedComment.user_id.fullname} a commenté votre publication`,
            data: {
              type: "new_comment",
              postId: String(post._id),
              commentId: String(comment._id),
            },
          })
        );
      }

      // Notify parent comment author if it's a reply
      if (parentCommentId) {
        const parentComment = await Comment.findById(parentCommentId).lean();
        if (parentComment && String(parentComment.user_id) !== String(userId)) {
          notificationPromises.push(
            sendPushNotification({
              userId: parentComment.user_id,
              title: "Réponse à votre commentaire",
              body: `${populatedComment.user_id.fullname} a répondu à votre commentaire`,
              data: {
                type: "comment_reply",
                postId: String(post._id),
                commentId: String(comment._id),
                parentCommentId: String(parentCommentId),
              },
            })
          );
        }
      }

      await Promise.allSettled(notificationPromises);
    } catch (notifError) {
      console.warn("Push notification failed for comment:", notifError.message);
    }

    // Log activity
    try {
      await createActivityLog({
        actorId: userId,
        action: "create_comment",
        targetType: "comment",
        targetId: comment._id,
        templateKey: "create_comment",
        metadata: {
          postId: postId,
          content: trimmedContent.slice(0, 100),
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for createComment:", logError.message);
    }

    return res.status(201).json({
      message: "Comment created successfully",
      comment: mapComment(populatedComment, userId),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error creating comment",
      error: error.message,
    });
  }
};

// Get comments for a post with pagination
exports.getPostComments = async (req, res) => {
  try {
    const { postId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const currentUserId = req.user?.userId || null;

    const result = await Comment.getPostCommentsPaginated(postId, { page, limit });

    const comments = result.comments.map((c) => mapComment(c, currentUserId));

    return res.status(200).json({
      comments,
      pagination: result.pagination,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading comments",
      error: error.message,
    });
  }
};

// Get a single comment by ID
exports.getComment = async (req, res) => {
  try {
    const { commentId } = req.params;
    const currentUserId = req.user?.userId || null;

    const comment = await Comment.findById(commentId)
      .populate("user_id", "fullname avatar userType")
      .populate("parent_comment_id", "user_id content")
      .lean();

    if (!comment || !comment.is_active) {
      return res.status(404).json({ message: "Comment not found" });
    }

    return res.status(200).json({
      comment: mapComment(comment, currentUserId),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading comment",
      error: error.message,
    });
  }
};

// UPDATE COMMENT - Only owner can edit
exports.updateComment = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { commentId } = req.params;
    const { content } = req.body;

    const trimmedContent = String(content || "").trim();
    if (!trimmedContent) {
      return res.status(400).json({ message: "Comment content is required" });
    }

    const comment = await Comment.findById(commentId);
    if (!comment || !comment.is_active) {
      return res.status(404).json({ message: "Comment not found" });
    }

    // CHECK PERMISSIONS: Only owner can edit
    if (!comment.canEdit(userId)) {
      return res.status(403).json({
        message: "You can only edit your own comments",
      });
    }

    // Update comment
    comment.content = trimmedContent;
    comment.updated_at = new Date();
    await comment.save();

    const populatedComment = await Comment.findById(commentId)
      .populate("user_id", "fullname avatar userType")
      .populate("parent_comment_id", "user_id content")
      .lean();

    // Log activity
    try {
      await createActivityLog({
        actorId: userId,
        action: "update_comment",
        targetType: "comment",
        targetId: comment._id,
        templateKey: "update_comment",
        metadata: {
          postId: comment.post_id,
          oldContent: comment.content,
          newContent: trimmedContent.slice(0, 100),
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for updateComment:", logError.message);
    }

    return res.status(200).json({
      message: "Comment updated successfully",
      comment: mapComment(populatedComment, userId),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error updating comment",
      error: error.message,
    });
  }
};

// DELETE COMMENT - Owner, Post Owner, or Admin can delete
exports.deleteComment = async (req, res) => {
  try {
    const userId = req.user.userId;
    const userRole = req.user.userType; // 'admin' or other
    const { commentId } = req.params;

    const comment = await Comment.findById(commentId);
    if (!comment || !comment.is_active) {
      return res.status(404).json({ message: "Comment not found" });
    }

    // Get post to check if user is post owner
    const post = await Post.findById(comment.post_id);
    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    const isPostOwner = String(post.author_id) === String(userId);
    const isAdmin = userRole === "admin";

    // CHECK PERMISSIONS: Owner OR Post Owner OR Admin
    if (!comment.canDelete(userId, isPostOwner, isAdmin)) {
      return res.status(403).json({
        message: "You don't have permission to delete this comment",
      });
    }

    // Soft delete comment
    comment.is_active = false;
    await comment.save();

    // Update post comment count
    await Post.findByIdAndUpdate(post._id, {
      $inc: { comments_count: -1 },
    });

    // Log activity
    try {
      await createActivityLog({
        actorId: userId,
        action: "delete_comment",
        targetType: "comment",
        targetId: comment._id,
        templateKey: "delete_comment",
        metadata: {
          postId: post._id,
          content: comment.content.slice(0, 100),
          deletedBy: isPostOwner ? "post_owner" : isAdmin ? "admin" : "owner",
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for deleteComment:", logError.message);
    }

    return res.status(200).json({
      message: "Comment deleted successfully",
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error deleting comment",
      error: error.message,
    });
  }
};

// REACT TO COMMENT - Atomic operation
exports.reactToComment = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { commentId } = req.params;
    const { reactionType } = req.body;

    // Valid reaction types
    const validReactions = ["like", "love", "laugh", "wow", "sad", "angry"];
    if (!validReactions.includes(reactionType)) {
      return res.status(400).json({ message: "Invalid reaction type" });
    }

    const comment = await Comment.findById(commentId);
    if (!comment || !comment.is_active) {
      return res.status(404).json({ message: "Comment not found" });
    }

    // ATOMIC REACTION TOGGLE
    // Remove user's existing reaction if any
    await Comment.findByIdAndUpdate(
      commentId,
      {
        $pull: { reactions: { user_id: userId } },
      },
      { new: false }
    );

    // Check if user is removing their reaction (same type)
    const existingReaction = comment.reactions.find(
      (r) => String(r.user_id) === String(userId)
    );
    const isRemoving = existingReaction && existingReaction.type === reactionType;

    if (!isRemoving) {
      // Add new reaction
      await Comment.findByIdAndUpdate(
        commentId,
        {
          $push: {
            reactions: {
              user_id: userId,
              type: reactionType,
              created_at: new Date(),
            },
          },
          $inc: { total_reactions: 1 },
        },
        { new: true }
      );
    } else {
      // User removed their reaction, decrement count
      await Comment.findByIdAndUpdate(
        commentId,
        {
          $inc: { total_reactions: -1 },
        },
        { new: true }
      );
    }

    // Get updated comment
    const updatedComment = await Comment.findById(commentId)
      .populate("user_id", "fullname avatar userType")
      .lean();

    return res.status(200).json({
      message: "Reaction updated successfully",
      user_reaction: isRemoving ? null : reactionType,
      total_reactions: updatedComment.total_reactions,
      reaction_counts: getReactionCounts(updatedComment.reactions),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error updating reaction",
      error: error.message,
    });
  }
};

// Get comment reactions
exports.getCommentReactions = async (req, res) => {
  try {
    const { commentId } = req.params;

    const comment = await Comment.findById(commentId).lean();

    if (!comment || !comment.is_active) {
      return res.status(404).json({ message: "Comment not found" });
    }

    return res.status(200).json({
      total_reactions: comment.total_reactions || 0,
      reaction_counts: getReactionCounts(comment.reactions),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading reactions",
      error: error.message,
    });
  }
};

// ADMIN: Get all comments with filters
exports.getAdminComments = async (req, res) => {
  try {
    const { page = 1, limit = 50, postId, search } = req.query;
    const skip = (page - 1) * limit;

    const filter = { is_active: true };
    if (postId) filter.post_id = postId;
    if (search) {
      filter.content = { $regex: search, $options: "i" };
    }

    const comments = await Comment.find(filter)
      .populate("user_id", "fullname email userType")
      .populate("post_id", "content author_id")
      .sort({ created_at: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    const total = await Comment.countDocuments(filter);

    return res.status(200).json({
      comments,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading admin comments",
      error: error.message,
    });
  }
};

// ADMIN: Delete any comment
exports.adminDeleteComment = async (req, res) => {
  try {
    const adminId = req.user.userId;
    const { commentId } = req.params;

    const comment = await Comment.findById(commentId);
    if (!comment || !comment.is_active) {
      return res.status(404).json({ message: "Comment not found" });
    }

    // Soft delete
    comment.is_active = false;
    await comment.save();

    // Update post comment count
    await Post.findByIdAndUpdate(comment.post_id, {
      $inc: { comments_count: -1 },
    });

    // Log activity
    try {
      await createActivityLog({
        actorId: adminId,
        action: "admin_delete_comment",
        targetType: "comment",
        targetId: comment._id,
        templateKey: "admin_delete_comment",
        metadata: {
          postId: comment.post_id,
          content: comment.content.slice(0, 100),
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for adminDeleteComment:", logError.message);
    }

    return res.status(200).json({
      message: "Comment deleted by admin",
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error deleting comment",
      error: error.message,
    });
  }
};
