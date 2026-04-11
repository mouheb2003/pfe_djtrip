const systemLogStore = require("../services/systemLogStore");

exports.getSystemLogs = async (req, res) => {
  try {
    const { level, source, search, start, end, limit, page } = req.query;

    const result = systemLogStore.queryLogs({
      level,
      source,
      search,
      start,
      end,
      limit,
      page,
    });

    res.status(200).json({
      success: true,
      total: result.total,
      page: result.page,
      limit: result.limit,
      logs: result.data,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to retrieve system logs",
      error: error.message,
    });
  }
};
