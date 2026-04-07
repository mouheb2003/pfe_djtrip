export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000';

export const END_POINT = {
  lieux: '/api/lieux',
  lieuById: (id) => `/api/lieux/${id}`,
  uploadLieuImages: '/api/lieux/upload-images',
  urgences: '/api/urgences',
  users: '/api/users',
  userById: (id) => `/api/users/${id}`,
  updateUserStatus: (id) => `/api/users/${id}/status`,
  toggleUserRole: (id) => `/api/users/${id}/status`,
  banUser: (id) => `/api/users/${id}/ban`,
  unbanUser: (id) => `/api/users/${id}/unban`,
  posts: '/api/posts/admin',
  postById: (id) => `/api/posts/admin/${id}`,
  activites: '/api/activites/admin',
  activiteById: (id) => `/api/activites/admin/${id}`,
  messageConversations: '/api/messages/conversations',
  messageWith: (partnerId) => `/api/messages/with/${partnerId}`,
};
