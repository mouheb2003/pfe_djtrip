const Post = require("../models/post");
const cloudinary = require("../config/cloudinary");

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

  return {
    _id: c._id,
    content: c.content,
    parent_comment_id: c.parent_comment_id,
    createdAt: c.createdAt,
    updatedAt: c.updatedAt,
    author_id: authorObj,
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

exports.getFeedPosts = async (_req, res) => {
  try {
    const posts = await Post.find({ is_active: true })
      .sort({ createdAt: -1 })
      .limit(100)
      .populate(basePopulate)
      .lean();

    return res.status(200).json({ posts });
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

    return res.status(200).json({ posts });
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

exports.togglePostLike = async (req, res) => {
  try {
    const userId = String(req.user.userId || "");
    const { postId } = req.params;

    if (!userId) {
      return res.status(401).json({ message: "Authentication required" });
    }

    const post = await Post.findOne({ _id: postId, is_active: true });
    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    const likedBy = Array.isArray(post.liked_by)
      ? post.liked_by.map((id) => String(id))
      : [];
    const alreadyLiked = likedBy.includes(userId);

    if (alreadyLiked) {
      post.liked_by = (post.liked_by || []).filter(
        (id) => String(id) !== userId,
      );
    } else {
      post.liked_by = [...(post.liked_by || []), userId];
    }

    post.likes_count = (post.liked_by || []).length;
    await post.save();

    return res.status(200).json({
      message: alreadyLiked ? "Like removed" : "Post liked",
      liked: !alreadyLiked,
      likesCount: post.likes_count,
      postId: String(post._id),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error updating like",
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
    const { postId } = req.params;
    const post = await Post.findById(postId);

    if (!post) {
      return res.status(404).json({ message: "Post not found" });
    }

    post.is_active = false;
    await post.save();

    return res.status(200).json({ message: "Post deleted" });
  } catch (error) {
    return res.status(500).json({
      message: "Error deleting post as admin",
      error: error.message,
    });
  }
};
