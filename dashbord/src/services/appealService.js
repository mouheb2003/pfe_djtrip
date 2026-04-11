import axios from 'src/lib/axios';
import { buildApiPath } from 'src/services/backend';




export const appealService = {
  // Get all appeals (admin)
  getAllAppeals: async (params = {}) => {
    try {
      const response = await axios.get(buildApiPath('/appeals/admin'), { params });
      return response.data;
    } catch (error) {
      console.error('Error getting appeals:', error);
      throw error;
    }
  },

  // Get appeal details
  getAppealDetails: async (id) => {
    try {
      const response = await axios.get(buildApiPath(`/appeals/admin/${id}`));
      return response.data;
    } catch (error) {
      console.error('Error getting appeal details:', error);
      throw error;
    }
  },

  // Update appeal status
  updateAppealStatus: async (id, status, adminResponse) => {
    try {
      const response = await axios.patch(buildApiPath(`/appeals/admin/${id}`), {
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
      const response = await axios.get(buildApiPath('/appeals/admin/stats'));
      return response.data;
    } catch (error) {
      console.error('Error getting appeal stats:', error);
      throw error;
    }
  },

  // Delete appeal
  deleteAppeal: async (id) => {
    try {
      const response = await axios.delete(buildApiPath(`/appeals/admin/${id}`));
      return response.data;
    } catch (error) {
      console.error('Error deleting appeal:', error);
      throw error;
    }
  },

  // Get user appeals
  getUserAppeals: async (params = {}) => {
    try {
      const response = await axios.get(buildApiPath('/appeals/me'), { params });
      return response.data;
    } catch (error) {
      console.error('Error getting user appeals:', error);
      throw error;
    }
  },

  // Submit appeal
  submitAppeal: async (appealData) => {
    try {
      const response = await axios.post(buildApiPath('/appeals'), appealData);
      return response.data;
    } catch (error) {
      console.error('Error submitting appeal:', error);
      throw error;
    }
  },

  // Submit appeal without authentication (suspended/banned users)
  submitAnonymousAppeal: async (appealData) => {
    try {
      const response = await axios.post(buildApiPath('/appeals/anonymous'), appealData);
      return response.data;
    } catch (error) {
      console.error('Error submitting anonymous appeal:', error);
      throw error;
    }
  },
};
