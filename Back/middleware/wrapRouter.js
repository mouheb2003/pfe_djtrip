// ✅ ADDED
const asyncHandler = require("./asyncHandler");

function wrapLayer(layer) {
  if (!layer) return;

  if (layer.route && Array.isArray(layer.route.stack)) {
    layer.route.stack.forEach((routeLayer) => {
      routeLayer.handle = asyncHandler(routeLayer.handle);
    });
    return;
  }

  if (
    layer.name === "router" &&
    layer.handle &&
    Array.isArray(layer.handle.stack)
  ) {
    layer.handle.stack.forEach(wrapLayer);
    return;
  }

  if (typeof layer.handle === "function") {
    layer.handle = asyncHandler(layer.handle);
  }
}

module.exports = function wrapRouter(router) {
  if (!router || !Array.isArray(router.stack)) return router;
  router.stack.forEach(wrapLayer);
  return router;
};
