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
  const data = await Get(END_POINT.urgences);

  if (Array.isArray(data)) return data;
  if (Array.isArray(data?.urgences)) return data.urgences;
  if (Array.isArray(data?.data)) return data.data;
  if (Array.isArray(data?.results)) return data.results;

  return [];
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

export async function deleteUser(id) {
  if (!id) return null;

  return Delete(END_POINT.userById(id));
}
