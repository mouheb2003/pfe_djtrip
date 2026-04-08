import { buildApiPath, getBackendUrl } from 'src/services/backend';

export const API_BASE_URL = getBackendUrl();

export const END_POINT = {
  lieux: buildApiPath('/lieux'),
  lieuById: (id) => buildApiPath(`/lieux/${id}`),
  uploadLieuImages: buildApiPath('/lieux/upload-images'),
  urgences: buildApiPath('/urgences'),
  users: buildApiPath('/users'),
  userById: (id) => buildApiPath(`/users/${id}`),
  updateUserStatus: (id) => buildApiPath(`/users/${id}/status`),
  toggleUserRole: (id) => buildApiPath(`/users/${id}/status`),
  banUser: (id) => buildApiPath(`/users/${id}/ban`),
  unbanUser: (id) => buildApiPath(`/users/${id}/unban`),
  posts: buildApiPath('/posts/admin'),
  postById: (id) => buildApiPath(`/posts/admin/${id}`),
  activites: buildApiPath('/activites/admin'),
  activiteById: (id) => buildApiPath(`/activites/admin/${id}`),
  messageConversations: buildApiPath('/messages/conversations'),
  messageWith: (partnerId) => buildApiPath(`/messages/with/${partnerId}`),
  messageById: (messageId) => buildApiPath(`/messages/${messageId}`),
  systemLogs: buildApiPath('/system-logs'),
  activityLogs: buildApiPath('/logs'),
};
