import axios from 'axios';

const API_BASE_URL = 'http://localhost:3000/api/v1';

// Create axios instance with auth
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
});

// Add auth token to requests
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('adminToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Handle response errors
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expired, redirect to login
      localStorage.removeItem('adminToken');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const appealService = {
  // Get all appeals (admin)
  getAllAppeals: async (params = {}) => {
    try {
      const response = await apiClient.get('/admin/appeals', { params });
      return response.data;
    } catch (error) {
      console.error('Error getting appeals:', error);
      throw error;
    }
  },

  // Get appeal details
  getAppealDetails: async (id) => {
    try {
      const response = await apiClient.get(`/admin/appeals/${id}`);
      return response.data;
    } catch (error) {
      console.error('Error getting appeal details:', error);
      throw error;
    }
  },

  // Update appeal status
  updateAppealStatus: async (id, status, adminResponse) => {
    try {
      const response = await apiClient.patch(`/admin/appeals/${id}`, {
        status,
        admin_response: adminResponse,
      });
      return response.data;
    } catch (error) {
      console.error('Error updating appeal status:', error);
      throw error;
    }
  },

  // Get appeal statistics
  getAppealStats: async () => {
    try {
      const response = await apiClient.get('/admin/appeals/stats');
      return response.data;
    } catch (error) {
      console.error('Error getting appeal stats:', error);
      throw error;
    }
  },

  // Delete appeal
  deleteAppeal: async (id) => {
    try {
      const response = await apiClient.delete(`/admin/appeals/${id}`);
      return response.data;
    } catch (error) {
      console.error('Error deleting appeal:', error);
      throw error;
    }
  },

  // Get user appeals
  getUserAppeals: async (params = {}) => {
    try {
      const response = await apiClient.get('/appeals/me', { params });
      return response.data;
    } catch (error) {
      console.error('Error getting user appeals:', error);
      throw error;
    }
  },

  // Submit appeal
  submitAppeal: async (appealData) => {
    try {
      const response = await apiClient.post('/appeals', appealData);
      return response.data;
    } catch (error) {
      console.error('Error submitting appeal:', error);
      throw error;
    }
  },
};
