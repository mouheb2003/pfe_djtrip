// ✅ ADDED
module.exports = function requestTimeout(timeoutMs = 15000) {
  return (req, res, next) => {
    let timedOut = false;

    const timer = setTimeout(() => {
      timedOut = true;
      if (!res.headersSent) {
        const err = new Error("Request timeout");
        err.status = 503;
        next(err);
      }
    }, timeoutMs);

    res.on("finish", () => clearTimeout(timer));
    res.on("close", () => clearTimeout(timer));

    req.isTimedOut = () => timedOut;
    next();
  };
};
