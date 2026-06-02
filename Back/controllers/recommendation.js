const User = require("../models/user");
const Activite = require("../models/activite");
const Lieu = require("../models/lieu");

exports.getRecommendations = async (req, res) => {
  try {
    const userId = req.user?.userId || req.user?.id;
    if (!userId) {
      return res.status(401).json({ message: "Authentication required" });
    }

    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const interests = user.centres_interet || [];
    
    // Convert interests to lowercase for easier matching
    const normalizedInterests = interests.map(i => i.toLowerCase());

    // Fetch active activities and places
    const activities = await Activite.find({ statut: "active" }).populate("organisateur_id", "fullname avatar");
    let places = await Lieu.find({}); // Assuming Lieu doesn't have a specific statut field as seen in schema

    // Scoring function
    const calculateScore = (item, isActivity) => {
      let score = 0;
      const type = isActivity ? (item.type_activite || item.categorie || "") : (item.type || "");
      const title = isActivity ? (item.titre || "") : (item.name || "");
      const description = isActivity ? (item.description || "") : (item.short_description || item.long_description || "");

      normalizedInterests.forEach(interest => {
        if (type.toLowerCase().includes(interest)) score += 3;
        if (title.toLowerCase().includes(interest)) score += 2;
        if (description.toLowerCase().includes(interest)) score += 1;
      });

      return score;
    };

    const scoredActivities = activities.map(a => {
      const doc = a.toObject();
      doc.recommendationScore = calculateScore(a, true);
      doc.itemType = 'activity';
      return doc;
    });

    const scoredPlaces = places.map(p => {
      const doc = p.toObject();
      doc.recommendationScore = calculateScore(p, false);
      doc.itemType = 'place';
      return doc;
    });

    // Combine and sort by score descending
    let recommended = [...scoredActivities, ...scoredPlaces]
      .sort((a, b) => b.recommendationScore - a.recommendationScore);

    // Limit to top 20 recommendations
    recommended = recommended.slice(0, 20);

    return res.status(200).json({
      success: true,
      recommendations: recommended,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Error fetching recommendations",
      error: error.message,
    });
  }
};
