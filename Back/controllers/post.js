const Post = require("../models/post");
const cloudinary = require("../config/cloudinary");
const { createActivityLog } = require("../services/activityLogService");
const { triggerPublicationNotification } = require("../controllers/notification");
const notificationEventBus = require("../services/notificationEventBus");
const User = require("../models/user");

const basePopulate = {
  path: "author_id",
  select: "fullname avatar userType",
};

const uploadImageBuffer = (buffer, folder) =>
  new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      {
        folder,
        resource_type: "image",
      },
      (error, result) => {
        if (error) return reject(error);
        return resolve(result);
      },
    );
    stream.end(buffer);
  });

const mapComment = (c) => {
  const author = c.author_id || {};
  const authorObj =
    author && typeof author === "object"
      ? {
          _id: author._id,
          fullname: author.fullname,
          avatar: author.avatar,
          userType: author.userType,
        }
      : { _id: author };

  // Get reaction counts
  const reactionCounts = {};
  let totalReactions = 0;
  
  if (c.reactions && typeof c.reactions.entries === 'function') {
    for (const [type, data] of c.reactions.entries()) {
      reactionCounts[type] = data.count || 0;
      totalReactions += data.count || 0;
    }
  }

  return {
    _id: c._id,
    content: c.content,
    parent_comment_id: c.parent_comment_id,
    createdAt: c.createdAt,
    updatedAt: c.updatedAt,
    author_id: authorObj,
    total_reactions: totalReactions,
    reaction_counts: reactionCounts,
  };
};

exports.uploadPostImage = async (req, res) => {
  try {
    if (!req.file || !req.file.buffer) {
      return res.status(400).json({ message: "No image file provided" });
    }

    if (
      !process.env.CLOUD_NAME ||
      !process.env.API_KEY ||
      !process.env.API_SECRET
    ) {
      return res.status(500).json({ message: "Cloudinary is not configured" });
    }

    const uploaded = await uploadImageBuffer(req.file.buffer, "djtrip/posts");
    return res.status(200).json({
      message: "Image uploaded successfully",
      imageUrl: uploaded.secure_url,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error uploading post image",
      error: error.message,
    });
  }
};

// Get posts by user ID (Admin only)
exports.getUserPosts = async (req, res) => {
  try {
    const { userId } = req.params;

    const posts = await Post.find({ author_id: userId })
      .populate(basePopulate)
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      count: posts.length,
      posts: posts.map((post) => ({
        _id: post._id,
        content: post.content,
        imageUrl: post.image_url,
        imageUrls: post.image_urls,
        createdAt: post.createdAt,
        author_id: post.author_id,
        likes_count: post.likes_count || 0,
        comments_count: post.comments_count || 0,
        total_reactions: post.total_reactions || 0,
        reactions: post.reactions || [],
      })),
    });
  } catch (error) {
    console.error("Error fetching user posts:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching user posts",
    });
  }
};

exports.createPost = async (req, res) => {
  try {
    const authorId = req.user.userId;
    const {
      content = "",
      imageUrl = "",
      imageUrls = [],
      postType = "post",
      audience = "public",
      locationLabel = "",
      tripLink = "",
      hashtags = [],
    } = req.body || {};

    const trimmedContent = String(content || "").trim();
    const trimmedImageUrl = String(imageUrl || "").trim();
    const normalizedImageUrls = Array.isArray(imageUrls)
      ? imageUrls.map((u) => String(u || "").trim()).filter((u) => u.length > 0)
      : [];

    const effectiveImageUrls = [
      ...normalizedImageUrls,
      ...(trimmedImageUrl ? [trimmedImageUrl] : []),
    ];

    if (!trimmedContent && effectiveImageUrls.length === 0) {
      return res.status(400).json({
        message: "Content or image is required",
      });
    }

    const safeType = postType === "activity" ? "activity" : "post";
    const safeAudience = audience === "followers" ? "followers" : "public";
    const safeHashtags = Array.isArray(hashtags)
      ? hashtags
          .map((h) => String(h || "").trim())
          .filter((h) => h.length > 0)
          .slice(0, 10)
      : [];

    const post = await Post.create({
      author_id: authorId,
      content: trimmedContent,
      image_url: effectiveImageUrls[0] || "",
      image_urls: effectiveImageUrls,
      post_type: safeType,
      audience: safeAudience,
      location_label: String(locationLabel || "").trim(),
      trip_link: String(tripLink || "").trim(),
      hashtags: safeHashtags,
    });

    const populated = await Post.findById(post._id)
      .populate(basePopulate)
      .lean();

    try {
      await createActivityLog({
        actorId: authorId,
        action: "create_post",
        targetType: "post",
        targetId: post._id,
        templateKey: "create_post",
        metadata: {
          title:
            trimmedContent.length > 80
              ? `${trimmedContent.slice(0, 77)}...`
              : trimmedContent || "Publication sans titre",
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for createPost:", logError.message);
    }

    // Notify followers about new publication
    try {
      const User = require("../models/user");
      const author = await User.findById(authorId).select("fullname blockedUsers");
      
      if (author) {
        // Get users who follow this author (this would need to be implemented based on your follow system)
        // For now, this is a placeholder - you'll need to implement the actual follower logic
        // based on your database structure for followers/following
        
        // Example: Get followers and notify them
        // const followers = await User.find({ following: authorId }).select("_id");
        // for (const follower of followers) {
        //   await triggerPublicationNotification(
        //     follower._id,
        //     author.fullname,
        //     post._id,
        //     trimmedContent
        //   );
        // }
      }
    } catch (notifError) {
      console.warn("Notification failed for createPost:", notifError.message);
    }

    return res.status(201).json({
      message: "Post created successfully",
      post: populated,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error creating post",
      error: error.message,
    });
  }
};

exports.getFeedPosts = async (req, res) => {
  try {
    const currentUserId = req.user?.userId || null;
    const posts = await Post.find({ is_active: true })
      .sort({ createdAt: -1 })
      .limit(100)
      .populate(basePopulate)
      .lean();

    // Add isLiked field for current user
    const postsWithLikeStatus = posts.map(post => ({
      ...post,
      isLiked: currentUserId && post.liked_by ? post.liked_by.some(id => id.toString() === currentUserId.toString()) : false,
    }));

    return res.status(200).json({ posts: postsWithLikeStatus });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading posts feed",
      error: error.message,
    });
  }
};

exports.getMyPosts = async (req, res) => {
  try {
    const userId = req.user.userId;
    const posts = await Post.find({ author_id: userId, is_active: true })
      .sort({ createdAt: -1 })
      .limit(100)
      .populate(basePopulate)
      .lean();

    // Add isLiked field for current user
    const postsWithLikeStatus = posts.map(post => ({
      ...post,
      isLiked: post.liked_by ? post.liked_by.some(id => id.toString() === userId.toString()) : false,
    }));

    return res.status(200).json({ posts: postsWithLikeStatus });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading my posts",
      error: error.message,
    });
  }
};

exports.updateMyPost = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { postId } = req.params;
    const post = await Post.findOne({
      _id: postId,
      author_id: userId,
      is_active: true,
    });

    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    const body = req.body || {};

    if (Object.prototype.hasOwnProperty.call(body, "content")) {
      post.content = String(body.content || "").trim();
    }

    if (Object.prototype.hasOwnProperty.call(body, "locationLabel")) {
      post.location_label = String(body.locationLabel || "").trim();
    }

    if (Object.prototype.hasOwnProperty.call(body, "hashtags")) {
      post.hashtags = Array.isArray(body.hashtags)
        ? body.hashtags
            .map((h) => String(h || "").trim())
            .filter((h) => h.length > 0)
            .slice(0, 10)
        : [];
    }

    if (Object.prototype.hasOwnProperty.call(body, "imageUrls")) {
      const normalizedImageUrls = Array.isArray(body.imageUrls)
        ? body.imageUrls
            .map((u) => String(u || "").trim())
            .filter((u) => u.length > 0)
        : [];
      post.image_urls = normalizedImageUrls;
      post.image_url = normalizedImageUrls[0] || "";
    }

    post.updatedAt = new Date();
    await post.save();

    const populated = await Post.findById(post._id)
      .populate(basePopulate)
      .lean();

    return res.status(200).json({
      message: "Post updated successfully",
      post: populated,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error updating post",
      error: error.message,
    });
  }
};

exports.getPostComments = async (req, res) => {
  try {
    const { postId } = req.params;
    const post = await Post.findOne({ _id: postId, is_active: true })
      .populate("comments.author_id", "fullname avatar userType")
      .lean();

    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    const comments = (post.comments || [])
      .filter((c) => c.is_active !== false)
      .map(mapComment)
      .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));

    return res.status(200).json({ comments });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading post comments",
      error: error.message,
    });
  }
};

exports.addPostComment = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { postId } = req.params;
    const { content = "", parentCommentId = null } = req.body || {};

    const trimmedContent = String(content || "").trim();
    if (!trimmedContent) {
      return res.status(400).json({ message: "Comment content is required" });
    }

    const post = await Post.findOne({ _id: postId, is_active: true });
    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    let validParentId = null;
    if (parentCommentId) {
      const parent = (post.comments || []).find(
        (c) =>
          String(c._id) === String(parentCommentId) && c.is_active !== false,
      );
      if (!parent) {
        return res.status(404).json({ message: "Parent comment not found" });
      }
      validParentId = parent._id;
    }

    post.comments.push({
      author_id: userId,
      content: trimmedContent,
      parent_comment_id: validParentId,
    });

    post.comments_count = (post.comments || []).filter(
      (c) => c.is_active !== false,
    ).length;

    await post.save();

    const populated = await Post.findById(post._id)
      .populate("comments.author_id", "fullname avatar userType")
      .lean();
    const comments = (populated?.comments || [])
      .filter((c) => c.is_active !== false)
      .map(mapComment)
      .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));

    return res.status(201).json({
      message: "Comment added",
      comments,
      commentsCount: comments.length,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error adding comment",
      error: error.message,
    });
  }
};

// React to a comment
exports.reactToComment = async (req, res) => {
  try {
    const userId = String(req.user.userId || "");
    const { postId, commentId } = req.params;
    const { reactionType } = req.body;

    if (!userId) {
      return res.status(401).json({ message: "Authentication required" });
    }

    // Valid reaction types
    const validReactions = ["like", "love", "laugh", "wow", "sad", "angry"];
    if (!validReactions.includes(reactionType)) {
      return res.status(400).json({ message: "Invalid reaction type" });
    }

    const post = await Post.findOne({ _id: postId, is_active: true });
    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    // Find the comment
    const comment = (post.comments || []).find(
      (c) => String(c._id) === String(commentId) && c.is_active !== false
    );

    if (!comment) {
      return res.status(404).json({ message: "Comment not found" });
    }

    // Initialize reactions if not exists
    if (!comment.reactions) {
      comment.reactions = new Map();
    }

    // Remove user from all reactions first (toggle behavior)
    let userReaction = null;
    for (const [type, reactionData] of comment.reactions.entries()) {
      const userIndex = reactionData.users.findIndex(
        (u) => String(u) === userId
      );
      if (userIndex !== -1) {
        reactionData.users.splice(userIndex, 1);
        reactionData.count = Math.max(0, reactionData.count - 1);
        if (type === reactionType) {
          // User is removing their reaction
          userReaction = null;
        }
      }
    }

    // Add new reaction if not removing
    if (userReaction !== null) {
      if (!comment.reactions.has(reactionType)) {
        comment.reactions.set(reactionType, { users: [], count: 0 });
      }
      const reaction = comment.reactions.get(reactionType);
      reaction.users.push(userId);
      reaction.count += 1;
      userReaction = reactionType;
    }

    // Recalculate total reactions
    comment.total_reactions = Array.from(comment.reactions.values())
      .reduce((sum, r) => sum + r.count, 0);

    await post.save();

    // Get reaction counts for response
    const reactionCounts = {};
    for (const [type, data] of comment.reactions.entries()) {
      reactionCounts[type] = data.count;
    }

    return res.status(200).json({
      message: "Reaction updated successfully",
      userReaction,
      totalReactions: comment.total_reactions,
      reactionCounts,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error reacting to comment",
      error: error.message,
    });
  }
};

// Get comment reactions
exports.getCommentReactions = async (req, res) => {
  try {
    const { postId, commentId } = req.params;

    const post = await Post.findOne({ _id: postId, is_active: true });
    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    const comment = (post.comments || []).find(
      (c) => String(c._id) === String(commentId) && c.is_active !== false
    );

    if (!comment) {
      return res.status(404).json({ message: "Comment not found" });
    }

    // Get reaction counts
    const reactionCounts = {};
    for (const [type, data] of comment.reactions?.entries() || []) {
      reactionCounts[type] = data.count;
    }

    return res.status(200).json({
      totalReactions: comment.total_reactions || 0,
      reactionCounts,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error getting comment reactions",
      error: error.message,
    });
  }
};

exports.togglePostLike = async (req, res) => {
  try {
    const userId = String(req.user.userId || "");
    const { postId } = req.params;
    const { reactionType = 'like' } = req.body;

    if (!userId) {
      return res.status(401).json({ message: "Authentication required" });
    }

    const post = await Post.findOne({ _id: postId, is_active: true });
    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    // Valid reaction types
    const validReactions = ["like", "love", "laugh", "wow", "sad", "angry"];
    if (!validReactions.includes(reactionType)) {
      return res.status(400).json({ message: "Invalid reaction type" });
    }

    const likedBy = Array.isArray(post.liked_by)
      ? post.liked_by.map((id) => String(id))
      : [];
    const alreadyLiked = likedBy.includes(userId);

    // ATOMIC REACTION TOGGLE
    // Remove user's existing reaction if any
    await Post.findByIdAndUpdate(
      postId,
      {
        $pull: { reactions: { user_id: userId } },
      },
      { new: false }
    );

    // Check if user is removing their reaction (same type)
    const existingReaction = post.reactions?.find(
      (r) => String(r.user_id) === String(userId)
    );
    const isRemoving = existingReaction && existingReaction.type === reactionType;

    if (!isRemoving) {
      // Add new reaction
      await Post.findByIdAndUpdate(
        postId,
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

      // Update liked_by array for backward compatibility
      if (!alreadyLiked) {
        post.liked_by = [...(post.liked_by || []), userId];
        post.likes_count = post.liked_by.length;
        await post.save();
      }

      // Notify post author about new reaction (if not self-reaction)
      if (String(post.author_id) !== String(userId)) {
        try {
          const reactor = await User.findById(userId).select('fullname');
          notificationEventBus.emitPostReaction({
            postOwnerId: post.author_id,
            reactorName: reactor?.fullname || 'Someone',
            postId: String(post._id),
            reactionType: reactionType,
          });
        } catch (notifError) {
          console.error('Error emitting post reaction notification:', notifError);
        }
      }
    } else {
      // User removed their reaction, decrement count
      await Post.findByIdAndUpdate(
        postId,
        {
          $inc: { total_reactions: -1 },
        },
        { new: true }
      );

      // Update liked_by array for backward compatibility
      post.liked_by = (post.liked_by || []).filter(
        (id) => String(id) !== userId,
      );
      post.likes_count = post.liked_by.length;
      await post.save();
    }

    // Get reaction counts
    const reactionCounts = {};
    if (post.reactions && Array.isArray(post.reactions)) {
      post.reactions.forEach((r) => {
        reactionCounts[r.type] = (reactionCounts[r.type] || 0) + 1;
      });
    }

    return res.status(200).json({
      message: isRemoving ? "Reaction removed" : "Reaction added",
      liked: !isRemoving,
      likesCount: post.likes_count,
      totalReactions: post.total_reactions,
      reactionCounts,
      userReaction: isRemoving ? null : reactionType,
      postId: String(post._id),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error updating reaction",
      error: error.message,
    });
  }
};

exports.deleteMyPost = async (req, res) => {
  try {
    const userId = req.user.userId;
    const { postId } = req.params;

    const post = await Post.findOne({ _id: postId, author_id: userId });
    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    post.is_active = false;
    await post.save();

    return res.status(200).json({ message: "Post deleted" });
  } catch (error) {
    return res.status(500).json({
      message: "Error deleting post",
      error: error.message,
    });
  }
};

exports.getAdminPosts = async (_req, res) => {
  try {
    const posts = await Post.find({ is_active: true })
      .sort({ createdAt: -1 })
      .limit(200)
      .populate(basePopulate)
      .populate({
<<<<<<< HEAD
        path: "liked_by",
        select: "fullname avatar userType",
=======
        path: 'liked_by',
        select: 'fullname avatar userType',
>>>>>>> backend/djtripx2
      })
      .lean();

    return res.status(200).json({ posts });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading admin posts",
      error: error.message,
    });
  }
};

exports.createAdminPost = async (req, res) => {
  try {
    const adminId = req.user.userId;
    const {
      content = "",
      imageUrls = [],
      postType = "post",
      audience = "public",
      locationLabel = "",
      tripLink = "",
      hashtags = [],
    } = req.body || {};

    const trimmedContent = String(content || "").trim();
    const normalizedImageUrls = Array.isArray(imageUrls)
      ? imageUrls.map((u) => String(u || "").trim()).filter((u) => u.length > 0)
      : [];

    if (!trimmedContent && normalizedImageUrls.length === 0) {
      return res.status(400).json({
        message: "Content or image is required",
      });
    }

    const safeType = postType === "activity" ? "activity" : "post";
    const safeAudience = audience === "followers" ? "followers" : "public";
    const safeHashtags = Array.isArray(hashtags)
      ? hashtags
          .map((h) => String(h || "").trim())
          .filter((h) => h.length > 0)
          .slice(0, 10)
      : [];

    const post = await Post.create({
      author_id: adminId,
      content: trimmedContent,
      image_url: normalizedImageUrls[0] || "",
      image_urls: normalizedImageUrls,
      post_type: safeType,
      audience: safeAudience,
      location_label: String(locationLabel || "").trim(),
      trip_link: String(tripLink || "").trim(),
      hashtags: safeHashtags,
    });

    const populated = await Post.findById(post._id)
      .populate(basePopulate)
      .lean();

    try {
      await createActivityLog({
        actorId: adminId,
        action: "create_post",
        targetType: "post",
        targetId: post._id,
        templateKey: "create_post",
        metadata: {
          title:
            trimmedContent.length > 80
              ? `${trimmedContent.slice(0, 77)}...`
              : trimmedContent || "Publication admin",
        },
      });
    } catch (logError) {
      console.warn(
        "Activity log failed for createAdminPost:",
        logError.message,
      );
    }

    return res.status(201).json({
      message: "Post created successfully",
      post: populated,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error creating admin post",
      error: error.message,
    });
  }
};

exports.updatePostByAdmin = async (req, res) => {
  try {
    const adminId = req.user.userId;
    const { postId } = req.params;
    const post = await Post.findOne({ _id: postId, is_active: true });

    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    const body = req.body || {};

    if (Object.prototype.hasOwnProperty.call(body, "content")) {
      post.content = String(body.content || "").trim();
    }

    if (Object.prototype.hasOwnProperty.call(body, "locationLabel")) {
      post.location_label = String(body.locationLabel || "").trim();
    }

    if (Object.prototype.hasOwnProperty.call(body, "postType")) {
      post.post_type = body.postType === "activity" ? "activity" : "post";
    }

    if (Object.prototype.hasOwnProperty.call(body, "audience")) {
      post.audience = body.audience === "followers" ? "followers" : "public";
    }

    if (Object.prototype.hasOwnProperty.call(body, "hashtags")) {
      post.hashtags = Array.isArray(body.hashtags)
        ? body.hashtags
            .map((h) => String(h || "").trim())
            .filter((h) => h.length > 0)
            .slice(0, 10)
        : [];
    }

    if (Object.prototype.hasOwnProperty.call(body, "imageUrls")) {
      const normalizedImageUrls = Array.isArray(body.imageUrls)
        ? body.imageUrls
            .map((u) => String(u || "").trim())
            .filter((u) => u.length > 0)
        : [];

      post.image_urls = normalizedImageUrls;
      post.image_url = normalizedImageUrls[0] || "";
    }

    post.updatedAt = new Date();
    await post.save();

    const populated = await Post.findById(post._id)
      .populate(basePopulate)
      .lean();

    try {
      await createActivityLog({
        actorId: adminId,
        action: "update_post_admin",
        targetType: "post",
        targetId: post._id,
        templateKey: "update_post_admin",
        metadata: {
          title: post.content?.slice(0, 80) || "Publication",
        },
      });
    } catch (logError) {
      console.warn(
        "Activity log failed for updatePostByAdmin:",
        logError.message,
      );
    }

    return res.status(200).json({
      message: "Post updated successfully",
      post: populated,
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error updating post as admin",
      error: error.message,
    });
  }
};

exports.deletePostByAdmin = async (req, res) => {
  try {
    const adminId = req.user.userId;
    const { postId } = req.params;
    const post = await Post.findById(postId);

    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    post.is_active = false;
    await post.save();

    try {
      await createActivityLog({
        actorId: adminId,
        action: "delete_post_admin",
        targetType: "post",
        targetId: post._id,
        templateKey: "delete_post_admin",
        metadata: {
          title: post.content?.slice(0, 80) || "Publication",
        },
      });
    } catch (logError) {
      console.warn(
        "Activity log failed for deletePostByAdmin:",
        logError.message,
      );
    }

    return res.status(200).json({ message: "Post deleted" });
  } catch (error) {
    return res.status(500).json({
      message: "Error deleting post as admin",
      error: error.message,
    });
  }
};
