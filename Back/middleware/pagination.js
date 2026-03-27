/**
 * Pagination Helper
 * Standardized pagination parameters and utilities
 */

const DEFAULT_PAGE = 1;
const DEFAULT_LIMIT = 10;
const MAX_LIMIT = 100;

/**
 * Extract and validate pagination parameters from query
 * @param {object} query - Express query object
 * @returns {object} - Sanitized page and limit
 */
exports.parsePagination = (query) => {
  let page = parseInt(query.page) || DEFAULT_PAGE;
  let limit = parseInt(query.limit) || DEFAULT_LIMIT;

  // Ensure page is at least 1
  page = Math.max(1, page);

  // Ensure limit is between 1 and MAX_LIMIT
  limit = Math.min(Math.max(1, limit), MAX_LIMIT);

  return { page, limit };
};

/**
 * Calculate skip value for MongoDB query
 * @param {number} page - Current page number
 * @param {number} limit - Items per page
 * @returns {number} - Skip value
 */
exports.getSkip = (page, limit) => {
  return (page - 1) * limit;
};

/**
 * Build pagination metadata
 * @param {number} page - Current page
 * @param {number} limit - Items per page
 * @param {number} total - Total items count
 * @returns {object} - Pagination metadata
 */
exports.buildMeta = (page, limit, total) => {
  const totalPages = Math.ceil(total / limit);

  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPrevPage: page > 1,
    nextPage: page < totalPages ? page + 1 : null,
    prevPage: page > 1 ? page - 1 : null,
  };
};

module.exports = exports;
