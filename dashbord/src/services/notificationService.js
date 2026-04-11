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

export const notificationService = {
  // Get all notifications (admin)
  getAllNotifications: async (params = {}) => {
    try {
      const response = await apiClient.get('/admin/notifications', { params });
      return response.data;
    } catch (error) {
      console.error('Error getting notifications:', error);
      throw error;
    }
  },

  // Create notification
  createNotification: async (notificationData) => {
    try {
      const response = await apiClient.post('/notifications', notificationData);
      return response.data;
    } catch (error) {
      console.error('Error creating notification:', error);
      throw error;
    }
  },

  // Create bulk notifications
  createBulkNotifications: async (notifications) => {
    try {
      const response = await apiClient.post('/notifications/bulk', { notifications });
      return response.data;
    } catch (error) {
      console.error('Error creating bulk notifications:', error);
      throw error;
    }
  },

  // Delete notification
  deleteNotification: async (id) => {
    try {
      const response = await apiClient.delete(`/notifications/${id}`);
      return response.data;
    } catch (error) {
      console.error('Error deleting notification:', error);
      throw error;
    }
  },

  // Mark notification as read
  markAsRead: async (id) => {
    try {
      const response = await apiClient.patch(`/notifications/${id}/read`);
      return response.data;
    } catch (error) {
      console.error('Error marking notification as read:', error);
      throw error;
    }
  },

  // Mark all notifications as read
  markAllAsRead: async () => {
    try {
      const response = await apiClient.patch('/notifications/read-all');
      return response.data;
    } catch (error) {
      console.error('Error marking all notifications as read:', error);
      throw error;
    }
  },

  // Get notification statistics
  getNotificationStats: async () => {
    try {
      // This would call a stats endpoint if available
      const mockStats = {
        total: 1250,
        unread: 45,
        today: 23,
        highPriority: 8,
        byType: {
          booking: 450,
          message: 320,
          review: 180,
          system: 150,
          appeal: 80,
          activity: 70,
        }
      };
      return mockStats;
    } catch (error) {
      console.error('Error getting notification stats:', error);
      throw error;
    }
  },
};
