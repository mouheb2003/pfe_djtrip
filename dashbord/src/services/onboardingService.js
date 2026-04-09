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

export const onboardingService = {
  // Get pending approvals
  getPendingApprovals: async (page = 1, limit = 20, filters = {}) => {
    try {
      const params = {
        limit,
        skip: (page - 1) * limit,
        ...filters,
      };
      
      const response = await apiClient.get('/onboarding/approvals/pending', { params });
      
      return response.data;
    } catch (error) {
      console.error('Error getting pending approvals:', error);
      throw error;
    }
  },

  // Approve organizer
  approveOrganizer: async (organizerId) => {
    try {
      const response = await apiClient.post(`/onboarding/approvals/${organizerId}/approve`);
      return response.data;
    } catch (error) {
      console.error('Error approving organizer:', error);
      throw error;
    }
  },

  // Reject organizer
  rejectOrganizer: async (organizerId, rejectionReason) => {
    try {
      const response = await apiClient.post(`/onboarding/approvals/${organizerId}/reject`, {
        rejection_reason: rejectionReason,
      });
      return response.data;
    } catch (error) {
      console.error('Error rejecting organizer:', error);
      throw error;
    }
  },

  // Get onboarding statistics
  getOnboardingStats: async () => {
    try {
      const response = await apiClient.get('/onboarding/stats');
      return response.data;
    } catch (error) {
      console.error('Error getting onboarding stats:', error);
      throw error;
    }
  },

  // Get organizer details
  getOrganizerDetails: async (organizerId) => {
    try {
      const response = await apiClient.get(`/onboarding/approvals/${organizerId}/details`);
      return response.data;
    } catch (error) {
      console.error('Error getting organizer details:', error);
      throw error;
    }
  },

  // Bulk approve organizers
  bulkApproveOrganizers: async (organizerIds) => {
    try {
      const response = await apiClient.post('/onboarding/approvals/bulk-approve', {
        organizerIds,
      });
      return response.data;
    } catch (error) {
      console.error('Error bulk approving organizers:', error);
      throw error;
    }
  },

  // Bulk reject organizers
  bulkRejectOrganizers: async (organizerIds, rejectionReason) => {
    try {
      const response = await apiClient.post('/onboarding/approvals/bulk-reject', {
        organizerIds,
        rejection_reason: rejectionReason,
      });
      return response.data;
    } catch (error) {
      console.error('Error bulk rejecting organizers:', error);
      throw error;
    }
  },

  // Get approval timeline
  getApprovalTimeline: async (organizerId) => {
    try {
      const response = await apiClient.get(`/onboarding/approvals/${organizerId}/timeline`);
      return response.data;
    } catch (error) {
      console.error('Error getting approval timeline:', error);
      throw error;
    }
  },

  // Export pending approvals
  exportPendingApprovals: async (filters = {}) => {
    try {
      const response = await apiClient.get('/onboarding/approvals/pending/export', {
        params: filters,
        responseType: 'blob',
      });
      
      // Create download link
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', 'pending-approvals.csv');
      document.body.appendChild(link);
      link.click();
      link.remove();
      
      return { success: true };
    } catch (error) {
      console.error('Error exporting pending approvals:', error);
      throw error;
    }
  },
};
