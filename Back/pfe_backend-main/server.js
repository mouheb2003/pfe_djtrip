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

// CORS - Permettre les requêtes depuis l'appareil mobile
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept, Authorization",
  );
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }
  next();
});

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
