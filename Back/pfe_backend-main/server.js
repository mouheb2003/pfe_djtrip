require("dotenv").config();
const express = require("express");
const db = require("./config/db");
const userRoutes = require("./routes/user");
const testFilesRoutes = require("./routes/testfiles");
const touristeRoutes = require("./routes/touriste");
const organisatorRoutes = require("./routes/organisator");

const app = express();

// Middleware
app.use(express.json());

// Root route
app.get("/", (req, res) => {
  res.json({
    message: "Welcome to Travelo API",
    endpoints: {
      users: "/api/users",
      touristes: "/api/touristes",
      organisators: "/api/organisators",
      test: "/api/test",
    },
  });
});

// Routes
app.use("/api/users", userRoutes);
app.use("/api/touristes", touristeRoutes);
app.use("/api/organisators", organisatorRoutes);
app.use("/api/test", testFilesRoutes);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
//hhh
