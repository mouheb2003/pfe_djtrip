import axios from 'axios';

import { API_BASE_URL } from './endPoint';
import { getBackendUrl } from 'src/services/backend';
import { JWT_STORAGE_KEY } from 'src/auth/context/jwt/constant';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
});

apiClient.interceptors.request.use((config) => {
  config.baseURL = getBackendUrl();

  const token = sessionStorage.getItem(JWT_STORAGE_KEY);
  console.log('[API] Request to:', config.url, 'Token present:', !!token);

  if (token) {
    config.headers = {
      ...config.headers,
      Authorization: `Bearer ${token}`,
    };
  } else {
    console.warn('[API] No token found in sessionStorage');
  }

  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error?.code === 'ECONNABORTED') {
      return Promise.reject(new Error('Request timeout: backend did not respond in time'));
    }

    return Promise.reject(error);
  }
);

export async function Get(endpoint, config = {}) {
  const response = await apiClient.get(endpoint, config);
  return response.data;
}

export async function Post(endpoint, payload = {}, config = {}) {
  const response = await apiClient.post(endpoint, payload, config);
  return response.data;
}

export async function Put(endpoint, payload = {}, config = {}) {
  const response = await apiClient.put(endpoint, payload, config);
  return response.data;
}

export async function Delete(endpoint, config = {}) {
  const response = await apiClient.delete(endpoint, config);
  return response.data;
}
