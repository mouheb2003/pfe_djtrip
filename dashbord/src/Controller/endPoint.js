export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000';

export const END_POINT = {
  lieux: '/lieux',
  lieuById: (id) => `/lieux/${id}`,
  uploadLieuImages: '/lieux/upload-images',
  urgences: '/api/urgences',
  users: '/api/users',
  userById: (id) => `/api/users/${id}`,
  toggleUserRole: (id) => `/api/users/${id}/toggle-organisateur`,
};
