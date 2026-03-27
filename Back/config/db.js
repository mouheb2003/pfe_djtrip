const mongoose = require("mongoose");

const MONGODB_URI =
  process.env.MONGODB_URI || "mongodb://localhost:27017/djtrip";

const MAX_RETRIES = 5;
let retryCount = 0;

const connectWithRetry = () => {
  mongoose
    .connect(MONGODB_URI)
    .then(() => {
      console.log("✅ Connected to MongoDB");
      retryCount = 0;
    })
    .catch((err) => {
      retryCount++;
      console.error(
        `❌ Error connecting to MongoDB (attempt ${retryCount}/${MAX_RETRIES}):`,
        err.message,
      );
      if (retryCount < MAX_RETRIES) {
        console.log(`🔄 Retrying in 5 seconds...`);
        setTimeout(connectWithRetry, 5000);
      } else {
        console.error("💥 Max retries reached. Could not connect to MongoDB.");
        process.exit(1);
      }
    });
};

connectWithRetry();

mongoose.connection.on("disconnected", () => {
  console.warn("⚠️ MongoDB disconnected. Attempting to reconnect...");
  if (retryCount < MAX_RETRIES) {
    setTimeout(connectWithRetry, 5000);
  }
});

module.exports = mongoose;
