const express = require("express");
const router = express.Router();

const logController = require("../controllers/logController");
const { verifyToken } = require("../middleware/auth");
const wrapRouter = require("../middleware/wrapRouter");

// GET /logs -> all logs (admin recommended, but access can be controlled in controller later)
router.get("/", verifyToken, logController.getLogs);

// GET /logs/:userId -> logs for one user (self or admin)
router.get("/:userId", verifyToken, logController.getLogsByUser);

module.exports = wrapRouter(router);
