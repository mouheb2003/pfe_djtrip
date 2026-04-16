require("dotenv").config();
const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const jwt = require("jsonwebtoken");
const helmet = require("helmet");
const cors = require("cors");
const mongoSanitize = require("express-mongo-sanitize");
const mongoose = require("mongoose");
const cacheService = require("./services/cache");
const requestLogger = require("./middleware/requestLogger");
const requestTimeout = require("./middleware/requestTimeout");
const sanitizeInput = require("./middleware/sanitizeInput");
const responseNormalizer = require("./middleware/responseNormalizer");
const requestActivityLogger = require("./middleware/requestActivityLogger");
const systemLogStore = require("./services/systemLogStore");
const {
  notFoundHandler,
  globalErrorHandler,
} = require("./middleware/errorHandler");

systemLogStore.installConsoleCapture();
// Initialize database connection before route registration.

const connectDB = require("./config/db");
connectDB();
const userRoutes = require("./routes/user");
const authRoutes = require("./routes/auth");
const touristeRoutes = require("./routes/touriste");
const organisatorRoutes = require("./routes/organisator");
const activiteRoutes = require("./routes/activite");
const inscriptionRoutes = require("./routes/inscription");
const avisRoutes = require("./routes/avis");
const messageRoutes = require("./routes/message");
const lieuRoutes = require("./routes/lieu");
const postRoutes = require("./routes/post");
const commentRoutes = require("./routes/comment");
const systemLogRoutes = require("./routes/systemLog");
const logRoutes = require("./routes/logRoutes");
const appealRoutes = require("./routes/appeal");
const notificationRoutes = require("./routes/notification");
const onboardingRoutes = require("./routes/onboarding");
const checkinLogRoutes = require("./routes/checkinLog");
const Message = require("./models/message");
const User = require("./models/user");
const UserService = require("./services/user");
const emailService = require("./services/email");
const authMiddleware = require("./middleware/auth");

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET)
  throw new Error("FATAL: JWT_SECRET must be set in environment variables.");

const NODE_ENV = process.env.NODE_ENV || "development";
const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",").map((o) => o.trim())
  : [];

const app = express();
app.disable("x-powered-by");
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: NODE_ENV === "development" ? "*" : ALLOWED_ORIGINS,
    methods: ["GET", "POST"],
  },
});

// 🚀 NEW: Store io instance globally for logout access
app.set("io", io);

// ─── Body Parsing ─────────────────────────────────────────────────────────────
app.use(express.json({ limit: "1mb" }));
app.use(express.urlencoded({ extended: true, limit: "1mb" }));
app.use(responseNormalizer);
app.use(requestLogger);
app.use(requestTimeout(Number(process.env.REQUEST_TIMEOUT_MS || 15000)));

// ─── Security Headers ─────────────────────────────────────────────────────────
app.use(helmet());

// ─── CORS Configuration ────────────────────────────────────────────────────────
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, curl, postman)
    if (!origin) return callback(null, true);

    if (NODE_ENV === "development") {
      // In development: allow all origins
      return callback(null, true);
    }

    // In production: only allow listed origins
    if (ALLOWED_ORIGINS.indexOf(origin) === -1) {
      return callback(new Error("Not allowed by CORS"), false);
    }
    return callback(null, true);
  },
  credentials: true,
  methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
  allowedHeaders: [
    "Origin",
    "X-Requested-With",
    "Content-Type",
    "Accept",
    "Authorization",
    "x-request-id",
  ],
};
app.use(cors(corsOptions));

// ─── NoSQL Injection Sanitization (Express 5 safe) ──────────────────────────
// express-mongo-sanitize middleware reassigns req.query, but in Express 5
// req.query is getter-only. We sanitize in place to stay compatible.
app.use((req, res, next) => {
  if (req.body) mongoSanitize.sanitize(req.body);
  if (req.params) mongoSanitize.sanitize(req.params);
  if (req.headers) mongoSanitize.sanitize(req.headers);
  if (req.query) mongoSanitize.sanitize(req.query);
  next();
});
app.use(sanitizeInput);

// ─── Rate Limiting ────────────────────────────────────────────────────────────
const { authLimiter, apiLimiter } = require("./middleware/rateLimit");
app.use("/api", apiLimiter);
app.use("/api/v1/users/signin", authLimiter);
app.use("/api/v1/users/signup", authLimiter);
app.use("/api/v1/users/forgot-password", authLimiter);

// ─── CORS ─────────────────────────────────────────────────────────────────────
app.use((req, res, next) => {
  const origin = req.headers.origin;

  if (NODE_ENV === "development") {
    // In dev: allow all origins for ease of mobile testing
    res.header("Access-Control-Allow-Origin", "*");
  } else {
    // In production: only allow listed origins
    if (origin && ALLOWED_ORIGINS.includes(origin)) {
      res.header("Access-Control-Allow-Origin", origin);
    }
  }

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

// ─── User Activity Request Logging ───────────────────────────────────────────
// Tracks successful authenticated API movements across the app.
app.use(requestActivityLogger);

// ─── Health Check Endpoint ─────────────────────────────────────────────────────
app.get("/api/health", async (req, res) => {
  try {
    const mongoStateMap = {
      0: "disconnected",
      1: "connected",
      2: "connecting",
      3: "disconnecting",
    };
    const dbState = mongoose.connection.readyState;
    const mongoStatus = mongoStateMap[dbState] || "unknown";
    const cacheStatus = cacheService.getStatus();

    res.status(200).json({
      status: "healthy",
      timestamp: new Date().toISOString(),
      uptime: Number(process.uptime().toFixed(2)),
      memory: process.memoryUsage(),
      services: {
        database: mongoStatus,
        cache: cacheStatus.mode,
      },
      cache: cacheStatus,
      version: "1.0.0",
    });
  } catch (error) {
    res.status(503).json({
      status: "unhealthy",
      timestamp: new Date().toISOString(),
      message: "Health check failed",
      error: error.message,
    });
  }
});

// ─── Root route ───────────────────────────────────────────────────────────────
app.get("/", (req, res) => {
  res.json({
    message: "Welcome to DJTrip API",
    version: "1.0.0",
    health: "/api/health",
    documentation: "/api/v1",
    endpoints: {
      users: "/api/v1/users",
      auth: "/api/v1/auth",
      touristes: "/api/v1/touristes",
      organisators: "/api/v1/organisators",
      activites: "/api/v1/activites",
      inscriptions: "/api/v1/inscriptions",
      avis: "/api/v1/avis",
      posts: "/api/v1/posts",
      comments: "/api/v1/comments",
      messages: "/api/v1/messages",
      lieux: "/api/v1/lieux",
      systemLogs: "/api/v1/system-logs",
      activityLogs: "/api/v1/logs",
      appeals: "/api/v1/appeals",
      notifications: "/api/v1/notifications",
    },
  });
});

// ─── API v1 Routes ────────────────────────────────────────────────────────────
app.use("/api/v1/users", userRoutes);
app.use("/api/v1/auth", authRoutes);
app.use("/api/v1/touristes", touristeRoutes);
app.use("/api/v1/organisators", organisatorRoutes);
app.use("/api/v1/activites", activiteRoutes);
app.use("/api/v1/inscriptions", inscriptionRoutes);
app.use("/api/v1/avis", avisRoutes);
app.use("/api/v1/posts", postRoutes);
app.use("/api/v1/comments", commentRoutes);
app.use("/api/v1/messages", messageRoutes);
app.use("/api/v1/lieux", lieuRoutes);
app.use("/api/v1/system-logs", systemLogRoutes);
app.use("/api/v1/logs", logRoutes);
app.use("/api/v1/appeals", appealRoutes);
app.use("/api/v1/notifications", notificationRoutes);
app.use("/api/v1/onboarding", onboardingRoutes);
app.use("/api/v1/checkin-logs", checkinLogRoutes);

// ─── Refresh Token Route ──────────────────────────────────────────────────────
app.post("/api/v1/auth/refresh", authMiddleware.refreshToken);

// ─── Email Debug Endpoints ──────────────────────────────────────────────────
app.get(
  "/api/v1/debug/email/health",
  authMiddleware.verifyToken,
  authMiddleware.verifyAdmin,
  async (req, res) => {
    try {
      const health = await emailService.verifyEmailTransport();

      res.status(200).json({
        success: true,
        message: "Email transport is ready",
        ...health,
      });
    } catch (error) {
      res.status(503).json({
        success: false,
        message: "Email transport verification failed",
        error: error.message,
      });
    }
  },
);

app.post(
  "/api/v1/debug/email/test",
  authMiddleware.verifyToken,
  authMiddleware.verifyAdmin,
  async (req, res) => {
    try {
      const { to, fullname, subject, message } = req.body || {};
      const recipient = (to || req.user?.email || "").trim();

      if (!recipient) {
        return res.status(400).json({
          success: false,
          message: "Recipient email is required",
        });
      }

      const result = await emailService.sendTestEmail({
        to: recipient,
        fullname: fullname || req.user?.email || "DJTrip Admin",
        subject,
        message,
      });

      res.status(200).json({
        success: true,
        message: "Test email sent",
        ...result,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: "Failed to send test email",
        error: error.message,
      });
    }
  },
);

// ─── Backward compatible aliases (pre-v1) ────────────────────────────────────
// Some clients/tools still call routes under `/api/*` instead of `/api/v1/*`.
// Keep these aliases to avoid "Route not found".
app.use("/api/users", userRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/touristes", touristeRoutes);
app.use("/api/organisators", organisatorRoutes);
app.use("/api/activites", activiteRoutes);
app.use("/api/inscriptions", inscriptionRoutes);
app.use("/api/avis", avisRoutes);
app.use("/api/posts", postRoutes);
app.use("/api/comments", commentRoutes);
app.use("/api/messages", messageRoutes);
app.use("/api/lieux", lieuRoutes);
app.use("/api/appeals", appealRoutes);
app.use("/api/system-logs", systemLogRoutes);
app.use("/api/logs", logRoutes);
app.post("/api/auth/refresh", authMiddleware.refreshToken);

// ─── Socket.io ────────────────────────────────────────────────────────────────
io.use(async (socket, next) => {
  const token = socket.handshake.auth?.token;
  if (!token) return next(new Error("Authentication error"));

  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    const user = await UserService.getUserById(decoded.userId);
    if (!user) {
      return next(new Error("Authentication error"));
    }

    // Keep socket auth in sync with HTTP auth: if suspension has ended,
    // auto-restore account before evaluating restriction state.
    if (user.accountStatus === "suspended" && user.suspendedUntil) {
      const now = new Date();
      if (new Date(user.suspendedUntil) <= now) {
        await User.findByIdAndUpdate(user._id, {
          $set: {
            accountStatus: "active",
            suspendedUntil: null,
            suspendReason: null,
            suspendedAt: null,
          },
        });

        user.accountStatus = "active";
        user.suspendedUntil = null;
        user.suspendReason = null;
      }
    }

    const buildRestrictionError = () => {
      const err = new Error("Account restricted");
      if (user.accountStatus === "suspended") {
        const remainingSeconds = user.suspendedUntil
          ? Math.max(
              0,
              Math.ceil(
                (new Date(user.suspendedUntil).getTime() - Date.now()) / 1000,
              ),
            )
          : null;

        err.data = {
          type: "suspended",
          reason: user.suspendReason || null,
          suspendedUntil: user.suspendedUntil || null,
          remainingSeconds,
          message: user.suspendReason
            ? `Account is suspended: ${user.suspendReason}`
            : "Account is suspended. Please contact support.",
        };
      } else if (user.accountStatus === "banned") {
        err.data = {
          type: "banned",
          reason: user.banReason || null,
          message: user.banReason
            ? `Account is banned: ${user.banReason}`
            : "Account is banned. Please contact support.",
        };
      } else {
        err.data = {
          type: "inactive",
          message: "Account is inactive. Please contact support.",
        };
      }
      return err;
    };

    if (["suspended", "banned", "inactive"].includes(user.accountStatus)) {
      return next(buildRestrictionError());
    }

    if ((decoded.tokenVersion ?? 0) !== (user.tokenVersion ?? 0)) {
      const err = new Error("Session expired");
      err.data = {
        forceLogout: true,
        message: "Session expired. Please sign in again.",
      };
      return next(err);
    }

    socket.userId = decoded.userId;
    next();
  } catch {
    next(new Error("Authentication error"));
  }
});

// Emit online/offline status only to users who have had conversations with this user
async function emitStatusToPartners(userId, isOnline) {
  try {
    const [sentTo, receivedFrom] = await Promise.all([
      Message.distinct("receiver_id", { sender_id: userId }),
      Message.distinct("sender_id", { receiver_id: userId }),
    ]);
    const partnerIds = [
      ...new Set([...sentTo.map(String), ...receivedFrom.map(String)]),
    ];
    partnerIds.forEach((partnerId) => {
      io.to(`user_${partnerId}`).emit("user_status", {
        userId,
        isOnline,
        timestamp: Date.now(), // Ajouter timestamp pour debugging
      });
    });
  } catch (err) {
    console.error("Error emitting status to partners:", err);
  }
}

// 🚀 NEW: Clean up orphaned online users
async function cleanupOrphanedUsers() {
  try {
    console.log("🧹 [CLEANUP] Starting orphaned users cleanup...");

    // Get all connected sockets
    const connectedSockets = new Set();
    io.sockets.sockets.forEach((socket) => {
      if (socket.userId) {
        connectedSockets.add(socket.userId.toString());
      }
    });

    console.log(
      `📡 [CLEANUP] Currently connected users: ${Array.from(connectedSockets).join(", ")}`,
    );

    // Find all users marked as online
    const onlineUsers = await User.find({ isOnline: true })
      .select("_id email userType")
      .lean();

    console.log(
      `👥 [CLEANUP] Found ${onlineUsers.length} users marked as online`,
    );

    // Mark as offline anyone not connected
    const orphanedUsers = onlineUsers.filter(
      (user) => !connectedSockets.has(user._id.toString()),
    );

    if (orphanedUsers.length > 0) {
      console.log(
        `🔴 [CLEANUP] Found ${orphanedUsers.length} orphaned users to mark offline`,
      );

      for (const user of orphanedUsers) {
        await UserService.updateOnlineStatus(user._id, false);
        console.log(
          `✅ [CLEANUP] Marked user ${user._id} (${user.email}) as offline`,
        );

        // Notify partners
        emitStatusToPartners(user._id, false);
        console.log(`📡 [CLEANUP] Notified partners for user ${user._id}`);
      }
    } else {
      console.log(`✅ [CLEANUP] No orphaned users found`);
    }
  } catch (err) {
    console.error("❌ [CLEANUP] Error during cleanup:", err);
  }
}

// Run cleanup every 30 seconds
setInterval(cleanupOrphanedUsers, 30000);

// Run cleanup immediately on server start
setTimeout(cleanupOrphanedUsers, 5000);

io.on("connection", (socket) => {
  const userId = socket.userId;
  socket.join(`user_${userId}`);
  console.log(`📡 Socket connected for user: ${userId}`);

  // 🚀 SIMPLIFIED: Direct online status update
  UserService.updateOnlineStatus(userId, true)
    .then(() => {
      console.log(`✅ User ${userId} marked as online`);
      emitStatusToPartners(userId, true);
    })
    .catch((err) => {
      console.error(`❌ Error updating online status for ${userId}:`, err);
    });

  // 🚀 NEW: Force offline status when client explicitly disconnects
  socket.on("force_logout", async () => {
    console.log(`🔴 [FORCE LOGOUT] User ${userId} forcing logout...`);

    try {
      // Set offline in database
      await UserService.updateOnlineStatus(userId, false);
      console.log(`✅ [FORCE LOGOUT] User ${userId} marked as offline`);

      // Emit to partners
      emitStatusToPartners(userId, false);
      console.log(`📡 [FORCE LOGOUT] Emitted offline status to partners`);

      // Disconnect socket
      socket.disconnect();
      console.log(`🔌 [FORCE LOGOUT] Socket disconnected for user ${userId}`);
    } catch (err) {
      console.error(`❌ [FORCE LOGOUT] Error:`, err);
    }
  });

  socket.on("send_message", async ({ receiverId, content }) => {
    if (!content || !content.trim()) return;
    try {
      const message = new Message({
        sender_id: socket.userId,
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
      const readAt = new Date();
      await Message.updateMany(
        { sender_id: partnerId, receiver_id: socket.userId, is_read: false },
        { $set: { is_read: true, read_at: readAt } },
      );
      io.to(`user_${partnerId}`).emit("messages_read", {
        by: socket.userId,
        readAt: readAt.toISOString(),
      });
    } catch (_) {}
  });

  socket.on("typing_start", ({ receiverId }) => {
    if (receiverId)
      io.to(`user_${receiverId}`).emit("partner_typing", {
        partnerId: socket.userId,
      });
  });

  socket.on("typing_stop", ({ receiverId }) => {
    if (receiverId)
      io.to(`user_${receiverId}`).emit("partner_typing_stop", {
        partnerId: socket.userId,
      });
  });

  // ─── Audio/Video Calls (WebRTC Signaling) ─────────────────────────────────
  socket.on("call:start", ({ calleeId, type, offer }) => {
    if (!calleeId || !type) return;
    io.to(`user_${calleeId}`).emit("call:incoming", {
      callerId: socket.userId,
      type: type,
      offer: offer || null,
    });
  });

  socket.on("call:answer", ({ callerId, answer }) => {
    if (!callerId || !answer) return;
    io.to(`user_${callerId}`).emit("call:accepted", { answer });
  });

  socket.on("call:reject", ({ callerId }) => {
    if (callerId)
      io.to(`user_${callerId}`).emit("call:rejected", { by: socket.userId });
  });

  socket.on("call:hangup", ({ targetUserId }) => {
    if (targetUserId)
      io.to(`user_${targetUserId}`).emit("call:ended", { by: socket.userId });
  });

  socket.on("call:ice_candidate", ({ targetUserId, candidate }) => {
    if (targetUserId && candidate) {
      io.to(`user_${targetUserId}`).emit("call:ice", {
        candidate,
        from: socket.userId,
      });
    }
  });

  // 🚀 SIMPLIFIED: Direct offline status update
  socket.on("disconnect", () => {
    console.log(`🔌 Socket disconnected for user: ${userId}`);

    UserService.updateOnlineStatus(userId, false)
      .then(() => {
        console.log(`✅ User ${userId} marked as offline`);
        emitStatusToPartners(userId, false);
      })
      .catch((err) => {
        console.error(`❌ Error updating offline status for ${userId}:`, err);
      });
    socket.leave(`user_${userId}`);
  });
});

// ─── 404 Handler ──────────────────────────────────────────────────────────────
app.use(notFoundHandler);

// ─── Global Error Handler ─────────────────────────────────────────────────────
// Must be defined AFTER all routes and middleware
app.use(globalErrorHandler);

process.on("unhandledRejection", (reason) => {
  console.error("❌ Unhandled Promise Rejection:", reason);
});

process.on("uncaughtException", (error) => {
  console.error("❌ Uncaught Exception:", error);
});

const PORT = process.env.PORT || 3000;
server.headersTimeout = Number(process.env.SERVER_HEADERS_TIMEOUT_MS || 20000);
server.requestTimeout = Number(process.env.SERVER_REQUEST_TIMEOUT_MS || 15000);
server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT} [${NODE_ENV}]`);
});
