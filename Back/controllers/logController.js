const { listActivityLogs } = require("../services/activityLogService");

exports.getLogs = async (req, res) => {
  try {
    const { page, limit, action, targetType, startDate, endDate, search } =
      req.query;

    const result = await listActivityLogs({
      page,
      limit,
      action,
      targetType,
      startDate,
      endDate,
      search,
    });

    return res.status(200).json({
      success: true,
      pagination: result.pagination,
      filters: {
        action: action || null,
        targetType: targetType || null,
        search: search || null,
        startDate: startDate || null,
        endDate: endDate || null,
      },
      logs: result.data,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Failed to retrieve activity logs",
      error: error.message,
    });
  }
};

exports.getLogsByUser = async (req, res) => {
  try {
    const { userId } = req.params;
    const requesterId = req.user?.userId;
    const requesterType = req.user?.userType;

    if (requesterType !== "Admin" && String(requesterId) !== String(userId)) {
      return res.status(403).json({
        success: false,
        message: "Access denied for this user's logs",
      });
    }

    const { page, limit, action, targetType, startDate, endDate, search } =
      req.query;

    const result = await listActivityLogs({
      page,
      limit,
      actorId: userId,
      action,
      targetType,
      startDate,
      endDate,
      search,
    });

    return res.status(200).json({
      success: true,
      userId,
      pagination: result.pagination,
      filters: {
        action: action || null,
        targetType: targetType || null,
        search: search || null,
        startDate: startDate || null,
        endDate: endDate || null,
      },
      logs: result.data,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Failed to retrieve user activity logs",
      error: error.message,
    });
  }
};
