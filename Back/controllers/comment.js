console.log('[COMMENT CONTROLLER] Loading comment controller...');

const Comment = require("../models/comment");
const Post = require("../models/post");
const notificationEventBus = require("../services/notificationEventBus");
const { createActivityLog } = require("../services/activityLogService");
const User = require("../models/user");
const { extractAndValidateMentions, calculateDepth } = require("../utils/mentionParser");

// Socket.io will be set via app.locals from server.js
let io = null;

// Initialize io instance
exports.initSocketIO = (socketIO) => {
  io = socketIO;
  console.log('[COMMENT CONTROLLER] Socket.io initialized');
};

console.log('[COMMENT CONTROLLER] All imports loaded successfully');

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

  console.log('[mapComment] Debug:', {
    commentId: comment._id,
    userId: comment.user_id,
    userType: typeof comment.user_id,
    populatedUser: user,
    userFullname: user.fullname,
    userTypeField: user.userType,
  });

  return {
    _id: comment._id,
    post_id: comment.post_id,
    user_id: {
      _id: user._id,
      fullname: user.fullname || "Anonymous",
      avatar: user.avatar,
      userType: user.userType,
      username: user.username,
    },
    content: comment.content,
    parent_comment_id: comment.parent_comment_id
      ? {
          _id: parent._id,
          user_id: parent.user_id,
          content: parent.content,
        }
      : null,
    depth: comment.depth || 0,
    replies_count: comment.replies_count || 0,
    mentions: comment.mentions || [],
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
  console.log('[createComment] FUNCTION CALLED - Starting execution');
  try {
    const userId = req.user.userId;
    const { postId } = req.params;
    const { content, parentCommentId = null } = req.body;
    console.log('[createComment] Extracted params - userId:', userId, 'postId:', postId);

    const trimmedContent = String(content || "").trim();
    if (!trimmedContent) {
      return res.status(400).json({ message: "Comment content is required" });
    }

    console.log('[createComment] Creating comment for post:', postId, 'by user:', userId);

    // Check if user is Google-authenticated and has required fields
    try {
      console.log('[createComment] Step 0: Checking user data...');
      const userCheck = await User.findById(userId).select("fullname googleId facebookId userType email");
      console.log('[createComment] Step 0 user data:', {
        _id: userCheck?._id,
        fullname: userCheck?.fullname,
        googleId: userCheck?.googleId ? 'YES' : 'NO',
        facebookId: userCheck?.facebookId ? 'YES' : 'NO',
        userType: userCheck?.userType,
        email: userCheck?.email,
      });
      if (!userCheck) {
        console.error('[createComment] Step 0 ERROR: User not found');
        return res.status(404).json({ message: "User not found" });
      }
      if (!userCheck.fullname) {
        console.error('[createComment] Step 0 ERROR: User missing fullname');
        return res.status(400).json({ message: "User profile incomplete: missing fullname" });
      }
      if (!userCheck.userType) {
        console.error('[createComment] Step 0 ERROR: User missing userType');
        return res.status(400).json({ message: "User profile incomplete: missing userType" });
      }
      console.log('[createComment] Step 0 complete: User data valid');
    } catch (error) {
      console.error('[createComment] Step 0 ERROR checking user:', error.message);
      return res.status(500).json({ message: "Error checking user data", error: error.message });
    }

    // Verify post exists and is active
    let post;
    try {
      console.log('[createComment] Step 1: Finding post...');
      post = await Post.findOne({ _id: postId, is_active: true });
      console.log('[createComment] Step 1 complete: Post found =', !!post);
    } catch (error) {
      console.error('[createComment] Step 1 ERROR finding post:', error.message);
      return res.status(500).json({ message: "Error finding post", error: error.message });
    }

    if (!post) {
      console.log('[createComment] Post not found:', postId);
      return res.status(404).json({ message: "Post not found" });
    }

    console.log('[createComment] Post found, author:', post.author_id);

    // Verify parent comment exists if provided and calculate depth
    let commentDepth = 0;
    if (parentCommentId) {
      try {
        console.log('[createComment] Step 2: Finding parent comment and calculating depth...');
        commentDepth = await calculateDepth(parentCommentId, 3);
        console.log('[createComment] Step 2 complete: Depth calculated =', commentDepth);
      } catch (error) {
        console.error('[createComment] Step 2 ERROR calculating depth:', error.message);
        return res.status(400).json({ message: error.message });
      }
    }

    // Extract and validate mentions from content
    let mentionedUserIds = [];
    try {
      console.log('[createComment] Step 2.5: Extracting mentions...');
      const { validUserIds } = await extractAndValidateMentions(trimmedContent);
      mentionedUserIds = validUserIds;
      console.log('[createComment] Step 2.5 complete: Mentions found =', mentionedUserIds.length);
    } catch (error) {
      console.error('[createComment] Step 2.5 ERROR extracting mentions:', error.message);
      // Don't block comment creation if mention extraction fails
    }

    // Create comment - IMMEDIATE PUBLICATION
    let comment;
    try {
      console.log('[createComment] Step 3: Creating comment...');
      comment = await Comment.create({
        post_id: postId,
        user_id: userId,
        content: trimmedContent,
        parent_comment_id: parentCommentId,
        depth: commentDepth,
        mentions: mentionedUserIds,
      });
      console.log('[createComment] Step 3 complete: Comment created:', comment._id);
    } catch (error) {
      console.error('[createComment] Step 3 ERROR creating comment:', error.message);
      return res.status(500).json({ message: "Error creating comment", error: error.message });
    }

    // Update post comment count
    try {
      console.log('[createComment] Step 4: Updating post comment count...');
      await Post.findByIdAndUpdate(postId, {
        $inc: { comments_count: 1 },
      });
      console.log('[createComment] Step 4 complete: Post comment count updated');
    } catch (error) {
      console.error('[createComment] Step 4 ERROR updating post comment count:', error.message);
      return res.status(500).json({ message: "Error updating post comment count", error: error.message });
    }

    // Increment parent comment's replies_count if this is a reply
    if (parentCommentId) {
      try {
        console.log('[createComment] Step 4.5: Incrementing parent comment replies_count...');
        await Comment.findByIdAndUpdate(parentCommentId, {
          $inc: { replies_count: 1 },
        });
        console.log('[createComment] Step 4.5 complete: Parent comment replies_count updated');
      } catch (error) {
        console.error('[createComment] Step 4.5 ERROR updating parent comment replies_count:', error.message);
        // Don't block comment creation if this fails
      }
    }

    // Get populated comment
    let populatedComment;
    try {
      console.log('[createComment] Step 5: Populating comment...');
      populatedComment = await Comment.findById(comment._id)
        .populate("user_id", "fullname avatar userType")
        .populate("parent_comment_id", "user_id content")
        .lean();
      console.log('[createComment] Step 5 complete: Comment populated');
    } catch (error) {
      console.error('[createComment] Step 5 ERROR populating comment:', error.message);
      return res.status(500).json({ message: "Error populating comment", error: error.message });
    }

    console.log('[createComment] Comment populated:', populatedComment);

    // EMIT NOTIFICATION EVENTS
    try {
      console.log('[createComment] Step 6: Getting commenter info...');
      const commenter = await User.findById(userId).select("fullname");
      const commenterName = commenter?.fullname || 'Someone';
      console.log('[createComment] Step 6 complete: Commenter name =', commenterName);

      // Notify post owner about new comment
      if (String(post.author_id) !== String(userId)) {
        console.log('[createComment] Step 7: Triggering comment notification...');
        notificationEventBus.emitCommentCreated({
          postOwnerId: post.author_id,
          commenterName: commenterName,
          postId: String(post._id),
          commentId: String(comment._id),
          postMentions: post.mentions || [], // pass the people mentioned in the post
        });
        console.log('[createComment] Step 7 complete: Comment notification sent');
      } else if (post.mentions && post.mentions.length > 0) {
        // If author comments on their own post, still notify mentioned users
        notificationEventBus.emitCommentCreated({
          postOwnerId: post.author_id,
          commenterName: commenterName,
          postId: String(post._id),
          commentId: String(comment._id),
          postMentions: post.mentions || [],
          isSelfComment: true,
        });
      }

      // Notify parent comment author if it's a reply
      if (parentCommentId) {
        console.log('[createComment] Step 8: Triggering reply notification...');
        const parentComment = await Comment.findById(parentCommentId).lean();
        if (parentComment && String(parentComment.user_id) !== String(userId)) {
          notificationEventBus.emitCommentReply({
            parentCommentAuthorId: parentComment.user_id,
            replierName: commenterName,
            postId: String(post._id),
            commentId: String(comment._id),
            parentCommentId: String(parentCommentId),
          });
          console.log('[createComment] Step 8 complete: Reply notification sent');
        }
      }

      // Notify mentioned users
      if (mentionedUserIds.length > 0) {
        console.log('[createComment] Step 9: Triggering mention notifications...');
        for (const mentionedUserId of mentionedUserIds) {
          // Don't notify if the mentioned user is the commenter themselves
          if (String(mentionedUserId) !== String(userId)) {
            notificationEventBus.emitUserMentioned({
              mentionedUserId: mentionedUserId,
              commenterName: commenterName,
              postId: String(post._id),
              commentId: String(comment._id),
            });
          }
        }
        console.log('[createComment] Step 9 complete: Mention notifications sent');
      }
    } catch (notifError) {
      console.error('[createComment] Notification ERROR:', notifError.message);
      console.error('[createComment] Notification ERROR STACK:', notifError.stack);
    }

    // Log activity
    try {
      console.log('[createComment] Step 10: Creating activity log...');
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
      console.log('[createComment] Step 10 complete: Activity log created');
    } catch (logError) {
      console.error('[createComment] Activity log ERROR:', logError.message);
      console.error('[createComment] Activity log ERROR STACK:', logError.stack);
    }

    console.log('[createComment] Step 11: Sending response...');
    
    // Emit Socket.io event for real-time update
    if (io) {
      io.to(`post:${postId}`).emit('comment:created', mapComment(populatedComment, userId));
    }
    
    return res.status(201).json({
      message: "Comment created successfully",
      comment: mapComment(populatedComment, userId),
    });
  } catch (error) {
    console.error('[createComment] ERROR:', error.message);
    console.error('[createComment] ERROR STACK:', error.stack);
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
    const limit = parseInt(req.query.limit) || 10; // Default to 10 comments per page (Facebook/Instagram style)
    const currentUserId = req.user?.userId || null;

    // Check post exists and verify audience permissions
    const post = await Post.findOne({ _id: postId, is_active: true });
    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    // If post is followers-only, verify user is a follower or the author
    if (post.audience === "followers") {
      const isAuthor = String(post.author_id) === String(currentUserId);
      if (!isAuthor) {
        // Check if user follows the post author (assuming follow system exists)
        // For now, allow all authenticated users to see followers-only posts
        // TODO: Implement proper follow checking when follow system is ready
      }
    }

    const result = await Comment.getPostCommentsPaginated(postId, { page, limit });

    console.log('[getPostComments] Fetched comments count:', result.comments.length);
    console.log('[getPostComments] First comment sample:', result.comments[0]);

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

    if (!comment) {
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

// Get replies for a specific comment with pagination (Facebook/Instagram style)
exports.getCommentReplies = async (req, res) => {
  try {
    const { commentId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 5; // Default to 5 replies per page
    const currentUserId = req.user?.userId || null;

    // Check if parent comment exists
    const parentComment = await Comment.findById(commentId);
    if (!parentComment) {
      return res.status(404).json({ message: "Comment not found" });
    }

    const result = await Comment.getCommentRepliesPaginated(commentId, { page, limit });

    const replies = result.replies.map((r) => mapComment(r, currentUserId));

    return res.status(200).json({
      replies,
      pagination: result.pagination,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading replies",
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

    // Extract and validate mentions from content
    let mentionedUserIds = [];
    try {
      const { validUserIds } = await extractAndValidateMentions(trimmedContent);
      mentionedUserIds = validUserIds;
    } catch (error) {
      console.error('[updateComment] ERROR extracting mentions:', error.message);
      // Don't block comment update if mention extraction fails
    }

    // Update comment
    comment.content = trimmedContent;
    comment.mentions = mentionedUserIds;
    comment.updated_at = new Date();
    await comment.save();

    const populatedComment = await Comment.findById(commentId)
      .populate("user_id", "fullname avatar userType")
      .populate("parent_comment_id", "user_id content")
      .lean();

    // Emit Socket.io event for real-time update
    if (io) {
      io.to(`post:${comment.post_id.toString()}`).emit('comment:updated', mapComment(populatedComment, userId));
    }

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

    // Decrement parent comment's replies_count if this is a reply
    if (comment.parent_comment_id) {
      try {
        await Comment.findByIdAndUpdate(comment.parent_comment_id, {
          $inc: { replies_count: -1 },
        });
      } catch (error) {
        console.error('[deleteComment] ERROR updating parent comment replies_count:', error.message);
        // Don't block comment deletion if this fails
      }
    }

    // Emit Socket.io event for real-time update
    if (io) {
      io.to(`post:${post._id.toString()}`).emit('comment:deleted', { commentId });
    }

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

      // Notify comment author about new reaction (if not reacting to own comment)
      if (String(comment.user_id) !== String(userId)) {
        try {
          const reactor = await User.findById(userId).select("fullname");
          const reactorName = reactor?.fullname || 'Someone';
          const post = await Post.findById(comment.post_id).select("_id");

          notificationEventBus.emitReactionCreated({
            targetOwnerId: comment.user_id,
            reactorName: reactorName,
            postId: String(post?._id),
            targetId: String(commentId),
            reactionType: reactionType,
            targetType: 'comment'
          });
        } catch (notifError) {
          console.warn("Notification failed for comment reaction:", notifError.message);
        }
      }
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

// ADMIN: Get all comments with filters (including replies)
exports.getAdminComments = async (req, res) => {
  try {
    const { page = 1, limit = 50, postId, search } = req.query;
    const skip = (page - 1) * limit;

    console.log('[getAdminComments] Query params:', { page, limit, postId, search });

    const filter = { is_active: true };
    if (postId) filter.post_id = postId;
    if (search) {
      filter.content = { $regex: search, $options: "i" };
    }

    console.log('[getAdminComments] Filter:', filter);

    // Fetch ALL comments (both root and replies) for this post
    const comments = await Comment.find(filter)
      .sort({ created_at: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    console.log('[getAdminComments] Fetched comments count:', comments.length);

    // Manually populate user_id to avoid potential issues
    const userIds = comments.map(c => c.user_id).filter(Boolean);
    const users = await User.find({ _id: { $in: userIds } }).select("fullname email userType avatar").lean();
    const userMap = {};
    users.forEach(u => { userMap[u._id.toString()] = u; });

    const commentsWithUsers = comments.map(c => ({
      ...c,
      user_id: userMap[c.user_id?.toString()] || c.user_id,
    }));

    const total = await Comment.countDocuments(filter);
    console.log('[getAdminComments] Total comments:', total);

    return res.status(200).json({
      comments: commentsWithUsers,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error('[getAdminComments] ERROR:', error.message);
    console.error('[getAdminComments] ERROR STACK:', error.stack);
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

    // Find all replies to this comment
    const replies = await Comment.find({ parent_comment_id: commentId, is_active: true });
    const replyCount = replies.length;

    // Soft delete the comment
    comment.is_active = false;
    await comment.save();

    // Soft delete all replies
    if (replyCount > 0) {
      await Comment.updateMany(
        { parent_comment_id: commentId, is_active: true },
        { is_active: false }
      );
    }

    // Update post comment count (comment + all replies)
    await Post.findByIdAndUpdate(comment.post_id, {
      $inc: { comments_count: -(1 + replyCount) },
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
          repliesDeleted: replyCount,
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for adminDeleteComment:", logError.message);
    }

    return res.status(200).json({
      message: `Comment deleted by admin${replyCount > 0 ? ` along with ${replyCount} reply/replies` : ''}`,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error deleting comment",
      error: error.message,
    });
  }
};

// Search users for mention autocomplete
exports.searchUsersForMention = async (req, res) => {
  try {
    const { query } = req.query;
    const currentUserId = req.user?.userId || null;
    const limit = Math.min(parseInt(req.query.limit) || 10, 20);

    if (!query || query.length < 2) {
      return res.status(400).json({ message: "Query must be at least 2 characters" });
    }

    // Search users by username or fullname (case-insensitive)
    const users = await User.find({
      is_active: true,
      $or: [
        { username: { $regex: query, $options: "i" } },
        { fullname: { $regex: query, $options: "i" } },
      ],
      _id: { $ne: currentUserId }, // Exclude current user
    })
      .select("_id username fullname avatar userType")
      .limit(limit)
      .lean();

    return res.status(200).json({
      users: users.map(user => ({
        _id: user._id,
        username: user.username,
        fullname: user.fullname,
        avatar: user.avatar,
        userType: user.userType,
      })),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error searching users",
      error: error.message,
    });
  }
};
