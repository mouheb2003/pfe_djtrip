import { Delete, Get, Post, Put } from './function';
import { END_POINT } from './endPoint';

export async function getLieux() {
  const data = await Get(END_POINT.lieux);

  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.lieux)) return data.lieux;
  if (Array.isArray(data?.data)) return data.data;
  if (Array.isArray(data?.results)) return data.results;

  return [];
}

export async function createLieu(payload) {
  const data = await Post(END_POINT.lieux, payload);
  return data?.lieu ?? data;
}

export async function uploadLieuImages(files) {
  if (!files?.length) return [];

  const formData = new FormData();
  files.forEach((file) => formData.append('images', file));

  const data = await Post(END_POINT.uploadLieuImages, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });

  if (Array.isArray(data?.images)) {
    return data.images.map((item) => item?.url).filter(Boolean);
  }

  return [];
}

export async function getUrgences() {
  try {
    const data = await Get(END_POINT.urgences);

    if (Array.isArray(data)) return data;
    if (Array.isArray(data?.urgences)) return data.urgences;
    if (Array.isArray(data?.data)) return data.data;
    if (Array.isArray(data?.results)) return data.results;

    return [];
  } catch {
    return [];
  }
}

export async function getLieuById(id) {
  if (!id) return null;

  try {
    const data = await Get(END_POINT.lieuById(id));
    return data?.lieu ?? data;
  } catch {
    const lieux = await getLieux();
    return lieux.find((lieu) => lieu?._id === id) ?? null;
  }
}

export async function getUsers() {
  const data = await Get(`${END_POINT.users}?_t=${Date.now()}`);

  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.users)) return data.users;
  if (Array.isArray(data?.data)) return data.data;
  if (Array.isArray(data?.results)) return data.results;

  return [];
}

export async function getUserById(id) {
  if (!id) return null;

  const data = await Get(END_POINT.userById(id));
  return data?.user ?? data;
}

export async function toggleUserRole(id) {
  if (!id) return null;

  const data = await Put(END_POINT.toggleUserRole(id));
  return data?.user ?? data;
}

export async function updateUserStatus(id, statusOrPayload) {
  if (!id || !statusOrPayload) return null;

  const payload =
    typeof statusOrPayload === 'string' ? { accountStatus: statusOrPayload } : statusOrPayload;

  const data = await Put(END_POINT.updateUserStatus(id), payload);
  return data?.user ?? data;
}

export async function banUser(id, reason) {
  if (!id || !reason) return null;

  const data = await Put(END_POINT.banUser(id), { banReason: reason });
  return data?.user ?? data;
}

export async function unbanUser(id) {
  if (!id) return null;

  const data = await Put(END_POINT.unbanUser(id), { accountStatus: 'active' });
  return data?.user ?? data;
}

export async function deleteUser(id) {
  if (!id) return null;

  return Delete(END_POINT.userById(id));
}

export async function getPublications() {
  const data = await Get(END_POINT.posts);

  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.posts)) return data.posts;
  if (Array.isArray(data?.data)) return data.data;
  if (Array.isArray(data?.results)) return data.results;

  return [];
}

export async function createPublication(payload) {
  const data = await Post(END_POINT.posts, payload);
  return data?.post ?? data;
}

export async function updatePublication(id, payload) {
  if (!id) return null;

  const data = await Put(END_POINT.postById(id), payload);
  return data?.post ?? data;
}

export async function deletePublication(id) {
  if (!id) return null;

  return Delete(END_POINT.postById(id));
}

export async function getActivitesAdmin() {
  const data = await Get(END_POINT.activites);

  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.activites)) return data.activites;
  if (Array.isArray(data?.activities)) return data.activities;
  if (Array.isArray(data?.data)) return data.data;
  if (Array.isArray(data?.results)) return data.results;

  return [];
}

export async function createActiviteAdmin(payload) {
  const data = await Post(END_POINT.activites, payload);
  return data?.activite ?? data;
}

export async function updateActiviteAdmin(id, payload) {
  if (!id) return null;

  const data = await Put(END_POINT.activiteById(id), payload);
  return data?.activite ?? data;
}

export async function deleteActiviteAdmin(id) {
  if (!id) return null;

  return Delete(END_POINT.activiteById(id));
}

export async function getMessageConversations() {
  const data = await Get(END_POINT.messageConversations);
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.conversations)) return data.conversations;
  if (Array.isArray(data?.data)) return data.data;
  return [];
}

export async function getMessagesWith(partnerId) {
  if (!partnerId) return [];

  const data = await Get(END_POINT.messageWith(partnerId));
  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.messages)) return data.messages;
  if (Array.isArray(data?.data)) return data.data;
  return [];
}

export async function sendMessageTo(partnerId, content, options = {}) {
  if (!partnerId || !content?.trim()) return null;

  const data = await Post(END_POINT.messageWith(partnerId), {
    content: content.trim(),
    message_type: options.messageType ?? 'text',
  });
  return data?.message ?? data;
}

export async function editMessageById(messageId, content) {
  if (!messageId || !content?.trim()) return null;

  const data = await Put(END_POINT.messageById(messageId), {
    content: content.trim(),
  });
  return data?.message ?? data;
}

export async function deleteMessageById(messageId) {
  if (!messageId) return null;

  return Delete(END_POINT.messageById(messageId));
}

export async function getSystemLogs(filters = {}) {
  const params = {};

  if (filters.source && filters.source.trim()) params.targetType = filters.source.trim();
  if (filters.search && filters.search.trim()) params.search = filters.search.trim();
  if (filters.start) params.start = filters.start;
  if (filters.end) params.end = filters.end;
  if (filters.limit) params.limit = filters.limit;
  if (filters.page) params.page = filters.page;
  if (filters.action && filters.action.trim()) params.action = filters.action.trim();

  const data = await Get(END_POINT.activityLogs, { params });

  const logs = Array.isArray(data?.logs)
    ? data.logs.map((item) => ({
        id: item?._id ?? item?.id,
        timestamp: item?.createdAt,
        level: 'info',
        source: item?.targetType ?? '-',
        action: item?.action ?? '-',
        userId: item?.actorName ?? item?.actorId ?? '-',
        userType: item?.actorId ?? '-',
        message: item?.description ?? '-',
      }))
    : [];

  return {
    logs,
    total: Number(data?.pagination?.total ?? data?.total ?? 0),
    page: Number(data?.pagination?.page ?? data?.page ?? 1),
    limit: Number(data?.pagination?.limit ?? data?.limit ?? filters.limit ?? 100),
  };
}

export async function getAdminComments(filters = {}) {
  try {
    const params = {};
    if (filters.page) params.page = filters.page;
    if (filters.limit) params.limit = filters.limit;
    if (filters.postId) params.postId = filters.postId;
    if (filters.search) params.search = filters.search;

    console.log('Fetching admin comments from:', END_POINT.adminComments, 'with params:', params);
    const data = await Get(END_POINT.adminComments, { params });
    console.log('Admin comments response:', data);

    if (Array.isArray(data)) return data;
    if (Array.isArray(data?.comments)) return data.comments;
    if (Array.isArray(data?.data)) return data.data;
    if (Array.isArray(data?.results)) return data.results;

    return [];
  } catch (error) {
    console.error('Error in getAdminComments:', error);
    throw error;
  }
}

export async function adminDeleteComment(id) {
  if (!id) return null;
  return Delete(END_POINT.adminCommentById(id));
}
