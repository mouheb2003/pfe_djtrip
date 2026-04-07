const MAX_LOGS = Number(process.env.SYSTEM_LOG_MAX || 2000);

const logs = [];
let nextId = 1;
let consoleCaptureInstalled = false;

const originalConsole = {
  log: console.log.bind(console),
  info: console.info.bind(console),
  warn: console.warn.bind(console),
  error: console.error.bind(console),
};

function stringifyArg(arg) {
  if (arg instanceof Error) {
    return arg.stack || arg.message;
  }

  if (typeof arg === "string") {
    return arg;
  }

  try {
    return JSON.stringify(arg);
  } catch (_err) {
    return String(arg);
  }
}

function normalizeLevel(level) {
  const value = String(level || "info").toLowerCase();
  if (["info", "warn", "error", "debug"].includes(value)) return value;
  return "info";
}

function addLog({
  level = "info",
  source = "system",
  message = "",
  action,
  userId,
  userType,
  method,
  path,
  statusCode,
  durationMs,
  requestId,
}) {
  const entry = {
    id: nextId++,
    timestamp: new Date().toISOString(),
    level: normalizeLevel(level),
    source: String(source || "system"),
    message: String(message || ""),
    action: action ? String(action) : null,
    userId: userId ? String(userId) : null,
    userType: userType ? String(userType) : null,
    method: method ? String(method).toUpperCase() : null,
    path: path ? String(path) : null,
    statusCode:
      typeof statusCode === "number" && Number.isFinite(statusCode)
        ? statusCode
        : null,
    durationMs:
      typeof durationMs === "number" && Number.isFinite(durationMs)
        ? durationMs
        : null,
    requestId: requestId ? String(requestId) : null,
  };

  logs.push(entry);

  if (logs.length > MAX_LOGS) {
    logs.splice(0, logs.length - MAX_LOGS);
  }

  return entry;
}

function installConsoleCapture() {
  if (consoleCaptureInstalled) return;
  consoleCaptureInstalled = true;

  const bind = (method, level) => {
    const original = originalConsole[method];
    console[method] = (...args) => {
      try {
        const message = args.map(stringifyArg).join(" ");
        addLog({ level, source: "console", message });
      } catch (_err) {
        // Never block real logging if capture fails
      }
      original(...args);
    };
  };

  bind("log", "info");
  bind("info", "info");
  bind("warn", "warn");
  bind("error", "error");

  addLog({
    level: "info",
    source: "system",
    message: "Console capture initialized",
  });
}

function queryLogs({
  level,
  source,
  search,
  start,
  end,
  limit = 200,
  page = 1,
} = {}) {
  const safeLimit = Math.min(Math.max(Number(limit) || 200, 1), 1000);
  const safePage = Math.max(Number(page) || 1, 1);

  let filtered = logs;

  if (level && level !== "all") {
    const wanted = String(level).toLowerCase();
    filtered = filtered.filter((item) => item.level === wanted);
  }

  if (source && source !== "all") {
    const wanted = String(source).toLowerCase();
    filtered = filtered.filter((item) =>
      item.source.toLowerCase().includes(wanted),
    );
  }

  if (search) {
    const q = String(search).toLowerCase();
    filtered = filtered.filter((item) =>
      [
        item.message,
        item.action,
        item.userId,
        item.userType,
        item.method,
        item.path,
        item.requestId,
        item.statusCode != null ? String(item.statusCode) : "",
      ]
        .join(" ")
        .toLowerCase()
        .includes(q),
    );
  }

  if (start) {
    const startDate = new Date(start);
    if (!Number.isNaN(startDate.getTime())) {
      filtered = filtered.filter(
        (item) => new Date(item.timestamp) >= startDate,
      );
    }
  }

  if (end) {
    const endDate = new Date(end);
    if (!Number.isNaN(endDate.getTime())) {
      filtered = filtered.filter((item) => new Date(item.timestamp) <= endDate);
    }
  }

  const total = filtered.length;
  const ordered = [...filtered].reverse();
  const startIndex = (safePage - 1) * safeLimit;
  const data = ordered.slice(startIndex, startIndex + safeLimit);

  return {
    total,
    page: safePage,
    limit: safeLimit,
    data,
  };
}

module.exports = {
  addLog,
  queryLogs,
  installConsoleCapture,
};
