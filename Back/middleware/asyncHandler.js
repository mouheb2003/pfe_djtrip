// ✅ ADDED
module.exports = function asyncHandler(fn) {
  if (typeof fn !== "function") return fn;
  if (fn.__isAsyncWrapped) return fn;

  const wrapped =
    fn.length === 4
      ? function wrappedAsyncErrorHandler(err, req, res, next) {
          try {
            const result = fn(err, req, res, next);
            if (result && typeof result.then === "function") {
              result.catch(next);
            }
          } catch (error) {
            next(error);
          }
        }
      : function wrappedAsyncHandler(req, res, next) {
          try {
            const result = fn(req, res, next);
            if (result && typeof result.then === "function") {
              result.catch(next);
            }
          } catch (error) {
            next(error);
          }
        };

  wrapped.__isAsyncWrapped = true;
  return wrapped;
};
