import axios from 'axios';

import { CONFIG } from 'src/global-config';
import { getBackendUrl } from 'src/services/backend';

// ----------------------------------------------------------------------

const axiosInstance = axios.create({
  baseURL: CONFIG.serverUrl,
  timeout: 10000,
});

axiosInstance.interceptors.request.use((config) => {
  config.baseURL = getBackendUrl();

  // Add JWT token to headers if available
  const accessToken = sessionStorage.getItem('jwt_access_token');
  if (accessToken) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }

  return config;
});

axiosInstance.interceptors.response.use(
  (response) => response,
  (error) => Promise.reject((error.response && error.response.data) || 'Something went wrong!')
);

export default axiosInstance;

// ----------------------------------------------------------------------

export const fetcher = async (args) => {
  try {
    const [url, config] = Array.isArray(args) ? args : [args];

    const res = await axiosInstance.get(url, { ...config });

    return res.data;
  } catch (error) {
    console.error('Failed to fetch:', error);
    throw error;
  }
};

// ----------------------------------------------------------------------

export const endpoints = {
  chat: '/api/v1/chat',
  kanban: '/api/v1/kanban',
  calendar: '/api/v1/calendar',
  auth: {
    me: '/api/v1/users/me',
    signIn: '/api/v1/users/signin',
    signUp: '/api/v1/users/signup',
  },
  mail: {
    list: '/api/v1/mail/list',
    details: '/api/v1/mail/details',
    labels: '/api/v1/mail/labels',
  },
  post: {
    list: '/api/v1/post/list',
    details: '/api/v1/post/details',
    latest: '/api/v1/post/latest',
    search: '/api/v1/post/search',
  },
  product: {
    list: '/api/v1/product/list',
    details: '/api/v1/product/details',
    search: '/api/v1/product/search',
  },
};
