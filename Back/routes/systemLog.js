const express = require("express");
const router = express.Router();

const { verifyToken, verifyAdmin } = require("../middleware/auth");
const systemLogController = require("../controllers/systemLog");
const wrapRouter = require("../middleware/wrapRouter");

router.get("/", verifyToken, verifyAdmin, systemLogController.getSystemLogs);

module.exports = wrapRouter(router);
