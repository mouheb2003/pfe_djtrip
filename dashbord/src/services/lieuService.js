import axios from 'src/lib/axios';
import { buildApiPath } from 'src/services/backend';

export const lieuService = {
  // Get all lieux
  getAllLieux: async (params = {}) => {
    try {
      const response = await axios.get(buildApiPath('/lieux'), { params });
      return response.data;
    } catch (error) {
      console.error('Error getting lieux:', error);
      throw error;
    }
  },

  // Get lieu details
  getLieuDetails: async (id) => {
    try {
      const response = await axios.get(buildApiPath(`/lieux/${id}`));
      return response.data;
    } catch (error) {
      console.error('Error getting lieu details:', error);
      throw error;
    }
  },

  // Create new lieu (admin only)
  createLieu: async (lieuData) => {
    try {
      const response = await axios.post(buildApiPath('/lieux'), lieuData);
      return response.data;
    } catch (error) {
      console.error('Error creating lieu:', error);
      throw error;
    }
  },

  // Update lieu (admin only)
  updateLieu: async (id, lieuData) => {
    try {
      const response = await axios.put(buildApiPath(`/lieux/${id}`), lieuData);
      return response.data;
    } catch (error) {
      console.error('Error updating lieu:', error);
      throw error;
    }
  },

  // Delete lieu (admin only)
  deleteLieu: async (id) => {
    try {
      const response = await axios.delete(buildApiPath(`/lieux/${id}`));
      return response.data;
    } catch (error) {
      console.error('Error deleting lieu:', error);
      throw error;
    }
  },

  // Upload images for a lieu
  uploadLieuImages: async (id, files) => {
    try {
      const formData = new FormData();
      files.forEach((file) => {
        formData.append('files', file);
      });
      const response = await axios.post(
        buildApiPath(`/lieux/${id}/upload-images`),
        formData,
        {
          headers: { 'Content-Type': 'multipart/form-data' },
        }
      );
      return response.data;
    } catch (error) {
      console.error('Error uploading images:', error);
      throw error;
    }
  },

  // Get featured lieux
  getFeaturedLieux: async () => {
    try {
      const response = await axios.get(buildApiPath('/lieux?is_featured=true'));
      return response.data;
    } catch (error) {
      console.error('Error getting featured lieux:', error);
      throw error;
    }
  },

  // Get lieux by type
  getLieuxByType: async (type) => {
    try {
      const response = await axios.get(buildApiPath(`/lieux?type=${type}`));
      return response.data;
    } catch (error) {
      console.error('Error getting lieux by type:', error);
      throw error;
    }
  },
};
