import axios from 'src/lib/axios';
import { buildApiPath } from 'src/services/backend';

const API = {
  userNotifications: buildApiPath('/notifications'),
  adminNotifications: buildApiPath('/notifications/admin'),
  unreadCount: buildApiPath('/notifications/unread-count'),
  markAllRead: buildApiPath('/notifications/read-all'),
  one: (id) => buildApiPath(`/notifications/${id}`),
  markRead: (id) => buildApiPath(`/notifications/${id}/read`),
  bulk: buildApiPath('/notifications/bulk'),
};

export const notificationService = {
  // Get notifications for current user
  getUserNotifications: async (params = {}) => {
    try {
      const response = await axios.get(API.userNotifications, { params });
      return response.data;
    } catch (error) {
      console.error('Error getting user notifications:', error);
      throw error;
    }
  },

  // Get all notifications (admin)
  getAllNotifications: async (params = {}) => {
    try {
      const response = await axios.get(API.adminNotifications, { params });
      return response.data;
    } catch (error) {
      console.error('Error getting notifications:', error);
      throw error;
    }
  },

  // Create notification
  createNotification: async (notificationData) => {
    try {
      const response = await axios.post(API.userNotifications, notificationData);
      return response.data;
    } catch (error) {
      console.error('Error creating notification:', error);
      throw error;
    }
  },

  // Create bulk notifications
  createBulkNotifications: async (notifications) => {
    try {
      const response = await axios.post(API.bulk, { notifications });
      return response.data;
    } catch (error) {
      console.error('Error creating bulk notifications:', error);
      throw error;
    }
  },

  // Delete notification
  deleteNotification: async (id) => {
    try {
      const response = await axios.delete(API.one(id));
      return response.data;
    } catch (error) {
      console.error('Error deleting notification:', error);
      throw error;
    }
  },

  // Mark notification as read
  markAsRead: async (id) => {
    try {
      const response = await axios.patch(API.markRead(id));
      return response.data;
    } catch (error) {
      console.error('Error marking notification as read:', error);
      throw error;
    }
  },

  // Mark all notifications as read
  markAllAsRead: async () => {
    try {
      const response = await axios.patch(API.markAllRead);
      return response.data;
    } catch (error) {
      console.error('Error marking all notifications as read:', error);
      throw error;
    }
  },

  // Get unread count for current user
  getUnreadCount: async () => {
    try {
      const response = await axios.get(API.unreadCount);
      return response.data;
    } catch (error) {
      console.error('Error getting unread count:', error);
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
