const mongoose = require("mongoose");
require("dotenv").config();
const User = require("../models/user");
const Post = require("../models/post");

async function migrate() {
  try {
    console.log("🚀 Starting mentions migration...");
    await mongoose.connect(process.env.MONGODB_URI);
    console.log("✅ Connected to MongoDB");

    const posts = await Post.find({ mentions: { $exists: true, $not: { $size: 0 } } });
    console.log(`🔍 Found ${posts.length} posts with mentions to inspect.`);

    let updatedCount = 0;

    for (const post of posts) {
      let content = post.content || "";
      let mentions = [...post.mentions];
      let needsUpdate = false;

      const newMentions = [];

      for (const mention of mentions) {
        // If it's already an ObjectId (24 char hex), keep it
        if (/^[a-fA-F0-9]{24}$/.test(mention)) {
          newMentions.push(mention);
          continue;
        }

        // Try to find user by old username
        // We use the raw collection query because the field might be commented out in the schema
        const user = await mongoose.connection.db.collection('users').findOne({ username: mention });

        if (user) {
          const userId = user._id.toString();
          newMentions.push(userId);
          
          // Replace @username with @userId in content
          const escapedUsername = mention.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
          const regex = new RegExp(`@${escapedUsername}\\b`, 'g');
          content = content.replace(regex, `@${userId}`);
          
          needsUpdate = true;
        } else {
          // User not found, keep as is or remove? User wants to decommission username.
          // If we can't find them, we keep the original string to avoid data loss, 
          // but it won't resolve in the new UI.
          newMentions.push(mention);
        }
      }

      if (needsUpdate) {
        post.content = content;
        post.mentions = newMentions;
        await post.save();
        updatedCount++;
        console.log(`✅ Updated post ${post._id}`);
      }
    }

    console.log(`\n🎉 Migration completed!`);
    console.log(`📊 Posts updated: ${updatedCount}`);
    
    process.exit(0);
  } catch (error) {
    console.error("❌ Migration failed:", error);
    process.exit(1);
  }
}

migrate();
