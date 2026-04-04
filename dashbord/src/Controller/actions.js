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
  const data = await Get(END_POINT.users);

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
    typeof statusOrPayload === 'string'
      ? { accountStatus: statusOrPayload }
      : statusOrPayload;

  const data = await Put(END_POINT.updateUserStatus(id), payload);
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

export async function sendMessageTo(partnerId, content) {
  if (!partnerId || !content?.trim()) return null;

  const data = await Post(END_POINT.messageWith(partnerId), { content: content.trim() });
  return data?.message ?? data;
}
