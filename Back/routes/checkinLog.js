const express = require('express');
const router = express.Router();
const CheckinLog = require('../models/checkinLog');
const {
  verifyToken,
  verifyOrganisator
} = require('../middleware/auth');

/**
 * Routes pour les logs de check-in (Audit)
 * Accessible uniquement aux organisateurs et admins
 */

// GET /checkin-logs/statistics
// Récupérer les statistiques de check-in
router.get(
  '/statistics',
  verifyToken,
  verifyOrganisator,
  async (req, res) => {
    try {
      const { organiserId, activityId, startDate, endDate } = req.query;
      const userId = req.user.userId;

      const stats = await CheckinLog.getStats({
        organiserId: organiserId || userId,
        activityId,
        startDate,
        endDate,
      });

      res.status(200).json({
        success: true,
        data: stats[0] || { stats: [], total: 0 },
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Error retrieving check-in statistics',
        error: error.message,
      });
    }
  }
);

// GET /checkin-logs/hourly/:activityId
// Récupérer les statistiques horaires pour une activité (dashboard)
router.get(
  '/hourly/:activityId',
  verifyToken,
  verifyOrganisator,
  async (req, res) => {
    try {
      const { activityId } = req.params;
      const { date } = req.query;

      const targetDate = date ? new Date(date) : new Date();

      const hourlyStats = await CheckinLog.getHourlyStats(
        activityId,
        targetDate
      );

      res.status(200).json({
        success: true,
        data: hourlyStats,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Error retrieving hourly statistics',
        error: error.message,
      });
    }
  }
);

// GET /checkin-logs/organizer
// Récupérer les logs de check-in pour un organisateur
router.get(
  '/organizer',
  verifyToken,
  verifyOrganisator,
  async (req, res) => {
    try {
      const userId = req.user.userId;
      const {
        limit = 50,
        skip = 0,
        status,
        startDate,
        endDate,
      } = req.query;

      const logs = await CheckinLog.getByOrganiser(userId, {
        limit: parseInt(limit),
        skip: parseInt(skip),
        status,
        startDate,
        endDate,
      });

      res.status(200).json({
        success: true,
        data: logs,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Error retrieving organizer check-in logs',
        error: error.message,
      });
    }
  }
);

// GET /checkin-logs/activity/:activityId
// Récupérer les logs de check-in pour une activité
router.get(
  '/activity/:activityId',
  verifyToken,
  verifyOrganisator,
  async (req, res) => {
    try {
      const { activityId } = req.params;
      const { limit = 50, skip = 0, status } = req.query;

      const logs = await CheckinLog.getByActivity(activityId, {
        limit: parseInt(limit),
        skip: parseInt(skip),
        status,
      });

      res.status(200).json({
        success: true,
        data: logs,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Error retrieving activity check-in logs',
        error: error.message,
      });
    }
  }
);

module.exports = router;
