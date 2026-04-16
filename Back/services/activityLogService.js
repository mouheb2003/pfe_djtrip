const ActivityLog = require("../models/ActivityLog");
const User = require("../models/user");
const { generateLog } = require("../utils/logTemplates");

async function resolveActorName({ actorId, actorName }) {
  if (actorName && String(actorName).trim()) {
    return String(actorName).trim();
  }

  if (!actorId) {
    return "Utilisateur inconnu";
  }

  const user = await User.findById(actorId).select("fullname").lean();
  return user?.fullname?.trim() || "Utilisateur";
}

async function createActivityLog({
  actorId,
  actorName,
  action,
  targetType,
  targetId,
  metadata = {},
  templateKey,
}) {
  if (!actorId || !action || !targetType || !targetId || !templateKey) {
    throw new Error(
      "Missing required fields: actorId, action, targetType, targetId, templateKey",
    );
  }

  const finalActorName = await resolveActorName({ actorId, actorName });

  const description = generateLog(templateKey, {
    actor: finalActorName,
    date: new Date(),
    ...metadata,
  });

  const log = await ActivityLog.create({
    actorId,
    actorName: finalActorName,
    action,
    targetType,
    targetId,
    metadata,
    description,
  });

  return log;
}

async function listActivityLogs({
  page = 1,
  limit = 20,
  actorId,
  action,
  targetType,
  startDate,
  endDate,
  search,
} = {}) {
  const safePage = Math.max(parseInt(page, 10) || 1, 1);
  const safeLimit = Math.min(Math.max(parseInt(limit, 10) || 20, 1), 100);
  const skip = (safePage - 1) * safeLimit;

  const filter = {};
  if (actorId) filter.actorId = actorId;
  if (action) filter.action = action;
  if (targetType) filter.targetType = targetType;

  if (startDate || endDate) {
    filter.createdAt = {};
    if (startDate) {
      const start = new Date(startDate);
      if (!Number.isNaN(start.getTime())) filter.createdAt.$gte = start;
    }
    if (endDate) {
      const end = new Date(endDate);
      if (!Number.isNaN(end.getTime())) filter.createdAt.$lte = end;
    }
    if (Object.keys(filter.createdAt).length === 0) delete filter.createdAt;
  }

  if (search && String(search).trim()) {
    filter.description = { $regex: String(search).trim(), $options: "i" };
  }

  const [data, total] = await Promise.all([
    ActivityLog.find(filter)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(safeLimit)
      .lean(),
    ActivityLog.countDocuments(filter),
  ]);

  const normalizedData = data.map((row) => {
    if (row.action !== "api_request") return row;

    const method = row?.metadata?.method;
    const endpoint = row?.metadata?.endpoint;
    if (!method || !endpoint) return row;

    return {
      ...row,
      description: generateLog("api_request", {
        actor: row.actorName || "Utilisateur",
        method,
        endpoint,
        date: row.createdAt || new Date(),
      }),
    };
  });

  return {
    data: normalizedData,
    pagination: {
      page: safePage,
      limit: safeLimit,
      total,
      totalPages: Math.max(Math.ceil(total / safeLimit), 1),
    },
  };
}

module.exports = {
  createActivityLog,
  listActivityLogs,
};
