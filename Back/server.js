require("dotenv").config();
const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const jwt = require("jsonwebtoken");
const db = require("./config/db");
const userRoutes = require("./routes/user");
const authRoutes = require("./routes/auth");
const testFilesRoutes = require("./routes/testfiles");
const touristeRoutes = require("./routes/touriste");
const organisatorRoutes = require("./routes/organisator");
const activiteRoutes = require("./routes/activite");
const inscriptionRoutes = require("./routes/inscription");
const avisRoutes = require("./routes/avis");
const messageRoutes = require("./routes/message");
const Message = require("./models/message");
const UserService = require("./services/user");

const JWT_SECRET = process.env.JWT_SECRET || "your_secret_key";

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

// Middleware
app.use(express.json());

const { authLimiter, apiLimiter } = require("./middleware/rateLimit");
app.use("/api", apiLimiter);
app.use("/api/users/signin", authLimiter);
app.use("/api/users/signup", authLimiter);
app.use("/api/users/forgot-password", authLimiter);

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
      auth: "/api/auth",
      touristes: "/api/touristes",
      organisators: "/api/organisators",
      activites: "/api/activites",
      inscriptions: "/api/inscriptions",
      test: "/api/test",
    },
  });
});

// Routes
app.use("/api/users", userRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/touristes", touristeRoutes);
app.use("/api/organisators", organisatorRoutes);
app.use("/api/activites", activiteRoutes);
app.use("/api/inscriptions", inscriptionRoutes);
app.use("/api/avis", avisRoutes);
app.use("/api/messages", messageRoutes);
app.use("/api/test", testFilesRoutes);

// ─── Socket.io ────────────────────────────────────────────────────────────────
io.use((socket, next) => {
  const token = socket.handshake.auth?.token;
  if (!token) return next(new Error("Authentication error"));
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    socket.userId = decoded.userId;
    next();
  } catch {
    next(new Error("Authentication error"));
  }
});

io.on("connection", (socket) => {
  const userId = socket.userId;
  socket.join(`user_${userId}`);
  UserService.updateOnlineStatus(userId, true).catch(() => {});

  socket.on("send_message", async ({ receiverId, content }) => {
    if (!content || !content.trim()) return;
    try {
      const message = new Message({
        sender_id: userId,
        receiver_id: receiverId,
        content: content.trim(),
      });
      await message.save();
      const payload = message.toObject();
      io.to(`user_${receiverId}`).emit("new_message", payload);
      socket.emit("message_sent", payload);
    } catch (err) {
      socket.emit("error", { message: err.message });
    }
  });

  socket.on("mark_read", async ({ partnerId }) => {
    try {
      await Message.updateMany(
        { sender_id: partnerId, receiver_id: userId, is_read: false },
        { is_read: true },
      );
      io.to(`user_${partnerId}`).emit("messages_read", { by: userId });
    } catch (_) {}
  });

  socket.on("typing_start", ({ receiverId }) => {
    if (receiverId) io.to(`user_${receiverId}`).emit("partner_typing", { partnerId: userId });
  });

  socket.on("typing_stop", ({ receiverId }) => {
    if (receiverId) io.to(`user_${receiverId}`).emit("partner_typing_stop", { partnerId: userId });
  });

  socket.on("disconnect", () => {
    UserService.updateOnlineStatus(userId, false).catch(() => {});
    socket.leave(`user_${userId}`);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
