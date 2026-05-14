const Lieu = require("../models/lieu");
const LieuService = require("../services/lieu");
const User = require("../models/user");

async function enrichLieuReviewsWithUsers(lieuObj) {
  if (!lieuObj || !Array.isArray(lieuObj.reviews) || lieuObj.reviews.length === 0) {
    return lieuObj;
  }

  const userIds = Array.from(
    new Set(
      lieuObj.reviews
        .map((review) => {
          const plainReview = review.toObject ? review.toObject() : review;
          return (plainReview?.user ?? "").toString().trim();
        })
        .filter((id) => id.length > 0),
    ),
  );

  if (userIds.length === 0) {
    return lieuObj;
  }

  try {
    const users = await User.find({ _id: { $in: userIds } })
      .select("_id fullname username avatar")
      .lean();

    const usersById = new Map(
      users.map((user) => [String(user._id), user]),
    );

    lieuObj.reviews = lieuObj.reviews.map((review) => {
      const plainReview = review.toObject ? review.toObject() : review;
      const reviewUserId = (plainReview?.user ?? "").toString().trim();
      const user = usersById.get(reviewUserId);
      
      const enriched = { ...plainReview };
      
      if (user) {
        const fullname = (user.fullname ?? "").toString().trim();
        const username = (user.username ?? "").toString().trim();
        const authorName = fullname || username || "User";
        
        enriched.authorName = authorName;
        enriched.userName = username;
        enriched.touriste_id = {
          _id: String(user._id),
          fullname,
          username,
          avatar: user.avatar ?? "",
        };
      } else {
        enriched.authorName = "User";
      }
      
      return enriched;
    });
  } catch (error) {
    console.error('[ENRICH REVIEWS] Error:', error);
  }

  return lieuObj;
}

// Create a new place
exports.createLieu = async (req, res) => {
  try {
    // Generate slug from name if not provided
    if (!req.body.slug && req.body.name) {
      req.body.slug = req.body.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '') + '-' + Date.now();
    }

    const lieu = new Lieu(req.body);
    await lieu.save();
    res.status(201).json({
      success: true,
      message: "Place created successfully",
      lieu,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error creating place",
      error: error.message,
    });
  }
};

// Get all places
exports.getAllLieux = async (req, res) => {
  try {
    const { type, search, is_featured, city, country } = req.query;
    const filter = {};

    if (type) filter.type = type;
    if (is_featured === "true") filter.is_featured = true;
    if (city) filter.city = { $regex: city, $options: "i" };
    if (country) filter.country = { $regex: country, $options: "i" };
    if (search) {
      filter.$or = [
        { name: { $regex: search, $options: "i" } },
        { short_description: { $regex: search, $options: "i" } },
        { long_description: { $regex: search, $options: "i" } },
        { tags: { $in: [new RegExp(search, "i")] } },
      ];
    }

    const lieux = await Lieu.find(filter).sort({ popularity_score: -1 });
    res.status(200).json({
      success: true,
      count: lieux.length,
      lieux,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving places",
      error: error.message,
    });
  }
};

// Get a place by ID
exports.getLieuById = async (req, res) => {
  try {
    const userId = req.user ? req.user.userId : null;
    const lieu = await Lieu.findById(req.params.id);
    if (!lieu) {
      return res
        .status(404)
        .json({ success: false, message: "Place not found" });
    }

    // Convert to plain object to add dynamic properties
    const lieuObj = lieu.toObject();

    // Check if bookmarked by current user
    if (userId && Array.isArray(lieu.bookmarked_by)) {
      lieuObj.isBookmarked = lieu.bookmarked_by.some(
        (id) => String(id) === String(userId)
      );
    } else {
      lieuObj.isBookmarked = false;
    }

    // Enrich reviews with user data
    await enrichLieuReviewsWithUsers(lieuObj);

    res.status(200).json({ success: true, lieu: lieuObj });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving place",
      error: error.message,
    });
  }
};

// Update a place
exports.updateLieu = async (req, res) => {
  try {
    const lieu = await Lieu.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    });
    if (!lieu) {
      return res
        .status(404)
        .json({ success: false, message: "Place not found" });
    }
    res.status(200).json({
      success: true,
      message: "Place updated successfully",
      lieu,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error updating place",
      error: error.message,
    });
  }
};

// Delete a place
exports.deleteLieu = async (req, res) => {
  try {
    const lieu = await Lieu.findByIdAndDelete(req.params.id);
    if (!lieu) {
      return res
        .status(404)
        .json({ success: false, message: "Place not found" });
    }
    res.status(200).json({
      success: true,
      message: "Place deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error deleting place",
      error: error.message,
    });
  }
};

// Add a review to a place
exports.addReview = async (req, res) => {
  try {
    const { rating, comment } = req.body;
    const currentUserId = (req.user?.userId ?? req.user?.id ?? "").toString();

    if (!currentUserId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const lieu = await Lieu.findById(req.params.id);
    
    if (!lieu) {
      return res
        .status(404)
        .json({ success: false, message: "Place not found" });
    }

    // Check if user already reviewed
    const existingReview = lieu.reviews.find(
      (review) => String(review.user) === currentUserId,
    );
    if (existingReview) {
      return res
        .status(400)
        .json({ success: false, message: "You have already reviewed this place" });
    }

    // Add new review
    lieu.reviews.push({
      user: currentUserId,
      comment,
      rating,
      date: new Date(),
    });

    // Update rating and review count
    lieu.review_count = lieu.reviews.length;
    lieu.rating = lieu.reviews.reduce((acc, review) => acc + review.rating, 0) / lieu.reviews.length;

    await lieu.save();

    const lieuObj = lieu.toObject();
    await enrichLieuReviewsWithUsers(lieuObj);
    
    res.status(201).json({
      success: true,
      message: "Review added successfully",
      lieu: lieuObj,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error adding review",
      error: error.message,
    });
  }
};

// Get featured places
exports.getFeaturedLieux = async (req, res) => {
  try {
    const lieux = await Lieu.find({ is_featured: true }).sort({ popularity_score: -1 });
    res.status(200).json({
      success: true,
      count: lieux.length,
      lieux,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving featured places",
      error: error.message,
    });
  }
};

// Get places by type
exports.getLieuxByType = async (req, res) => {
  try {
    const { type } = req.params;
    const lieux = await Lieu.find({ type }).sort({ popularity_score: -1 });
    res.status(200).json({
      success: true,
      count: lieux.length,
      lieux,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error retrieving places by type",
      error: error.message,
    });
  }
};

// Upload images for a place
exports.uploadImages = async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No files uploaded",
      });
    }

    // Convert files to buffers
    const fileBuffers = req.files.map((file) => file.buffer);

    // Upload to Cloudinary
    const imageUrls = await LieuService.uploadMultipleImages(fileBuffers);

    res.status(200).json({
      success: true,
      message: "Images uploaded successfully",
      images: imageUrls.map((url) => ({ url })),
    });
  } catch (error) {
    console.error("Error uploading images:", error);
    res.status(500).json({
      success: false,
      message: "Error uploading images",
      error: error.message,
    });
  }
};

// Toggle bookmark on a place
exports.toggleLieuBookmark = async (req, res) => {
  try {
    const userId = String(req.user.userId || "");
    const { lieuId } = req.params;

    if (!userId) {
      return res.status(401).json({ message: "Authentication required" });
    }

    const lieu = await Lieu.findById(lieuId);
    if (!lieu) {
      return res.status(404).json({ message: "Place not found" });
    }

    const bookmarkedBy = Array.isArray(lieu.bookmarked_by)
      ? lieu.bookmarked_by.map((id) => String(id))
      : [];
    const alreadyBookmarked = bookmarkedBy.includes(userId);

    if (alreadyBookmarked) {
      // Remove bookmark
      lieu.bookmarked_by = lieu.bookmarked_by.filter(
        (id) => String(id) !== userId
      );
      lieu.bookmarks_count = Math.max(0, lieu.bookmarks_count - 1);
    } else {
      // Add bookmark
      lieu.bookmarked_by = [...(lieu.bookmarked_by || []), userId];
      lieu.bookmarks_count = lieu.bookmarked_by.length;
    }

    await lieu.save();

    return res.status(200).json({
      message: alreadyBookmarked ? "Bookmark removed" : "Bookmark added",
      bookmarked: !alreadyBookmarked,
      bookmarksCount: lieu.bookmarks_count,
      lieuId: String(lieu._id),
    });
  } catch (error) {
    return res.status(500).json({
      message: "Error updating bookmark",
      error: error.message,
    });
  }
};

// Get bookmarked places for current user
exports.getBookmarkedLieux = async (req, res) => {
  try {
    const userId = req.user.userId;

    const lieux = await Lieu.find({
      bookmarked_by: userId,
    })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    // Add isBookmarked field (always true for bookmarked places)
    const lieuxWithBookmarkStatus = lieux.map(lieu => ({
      ...lieu,
      isBookmarked: true,
    }));

    return res.status(200).json({ lieux: lieuxWithBookmarkStatus });
  } catch (error) {
    return res.status(500).json({
      message: "Error loading bookmarked places",
      error: error.message,
    });
  }
};

// Update a review
exports.updateReview = async (req, res) => {
  try {
    const { rating, comment } = req.body;
    const currentUserId = (req.user?.userId ?? req.user?.id ?? "").toString();
    const { id: lieuId, reviewId } = req.params;

    if (!currentUserId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const lieu = await Lieu.findById(lieuId);
    
    if (!lieu) {
      return res.status(404).json({
        success: false,
        message: "Place not found",
      });
    }

    // Find and update the review
    const reviewIndex = lieu.reviews.findIndex(
      (review) => String(review._id) === reviewId && String(review.user) === currentUserId,
    );

    if (reviewIndex === -1) {
      return res.status(404).json({
        success: false,
        message: "Review not found or you don't have permission to update it",
      });
    }

    lieu.reviews[reviewIndex].comment = comment;
    lieu.reviews[reviewIndex].rating = rating;
    lieu.reviews[reviewIndex].date = new Date();

    // Recalculate rating
    lieu.review_count = lieu.reviews.length;
    lieu.rating = lieu.reviews.reduce((acc, review) => acc + review.rating, 0) / lieu.reviews.length;

    await lieu.save();

    const lieuObj = lieu.toObject();
    await enrichLieuReviewsWithUsers(lieuObj);

    res.status(200).json({
      success: true,
      message: "Review updated successfully",
      lieu: lieuObj,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error updating review",
      error: error.message,
    });
  }
};

// Delete a review
exports.deleteReview = async (req, res) => {
  try {
    const currentUserId = (req.user?.userId ?? req.user?.id ?? "").toString();
    const { id: lieuId, reviewId } = req.params;

    if (!currentUserId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized",
      });
    }

    const lieu = await Lieu.findById(lieuId);
    
    if (!lieu) {
      return res.status(404).json({
        success: false,
        message: "Place not found",
      });
    }

    // Find and remove the review
    const reviewIndex = lieu.reviews.findIndex(
      (review) => String(review._id) === reviewId && String(review.user) === currentUserId,
    );

    if (reviewIndex === -1) {
      return res.status(404).json({
        success: false,
        message: "Review not found or you don't have permission to delete it",
      });
    }

    lieu.reviews.splice(reviewIndex, 1);

    // Recalculate rating
    lieu.review_count = lieu.reviews.length;
    if (lieu.reviews.length > 0) {
      lieu.rating = lieu.reviews.reduce((acc, review) => acc + review.rating, 0) / lieu.reviews.length;
    } else {
      lieu.rating = 0;
    }

    await lieu.save();

    const lieuObj = lieu.toObject();
    await enrichLieuReviewsWithUsers(lieuObj);

    res.status(200).json({
      success: true,
      message: "Review deleted successfully",
      lieu: lieuObj,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error deleting review",
      error: error.message,
    });
  }
};
