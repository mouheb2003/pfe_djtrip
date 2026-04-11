const mongoose = require('mongoose');

/**
 * Modèle CheckinLog pour l'audit des check-ins
 * Enregistre tous les tentatives de check-in (succès et échecs)
 */

const checkinLogSchema = new mongoose.Schema({
  // Identifiants
  bookingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Inscription',
    required: true,
    index: true,
  },
  organiserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  touristId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  activityId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Activite',
    required: true,
  },

  // Statut du check-in
  status: {
    type: String,
    enum: ['success', 'failed', 'already_verified', 'unauthorized', 'expired', 'not_approved'],
    required: true,
    index: true,
  },

  // Raison de l'échec (si applicable)
  failureReason: {
    type: String,
  },

  // Métadonnées
  qrData: {
    type: String,
  },
  ipAddress: {
    type: String,
  },
  userAgent: {
    type: String,
  },
  location: {
    type: {
      type: String,
      enum: ['Point'],
    },
    coordinates: {
      type: [Number],
    },
  },

  // Timestamps
  timestamp: {
    type: Date,
    default: Date.now,
    index: true,
  },

  // Durée de la requête (en ms)
  duration: {
    type: Number,
  },
}, {
  timestamps: true,
});

// Index composés pour les requêtes fréquentes
checkinLogSchema.index({ timestamp: -1, status: 1 });
checkinLogSchema.index({ organiserId: 1, timestamp: -1 });
checkinLogSchema.index({ activityId: 1, timestamp: -1 });
checkinLogSchema.index({ bookingId: 1, timestamp: -1 });

/**
 * Méthode statique pour créer un log de check-in
 */
checkinLogSchema.statics.createLog = async function(data) {
  return this.create({
    ...data,
    timestamp: new Date(),
  });
};

/**
 * Méthode statique pour récupérer les logs d'un organisateur
 */
checkinLogSchema.statics.getByOrganiser = function(organiserId, options = {}) {
  const {
    limit = 50,
    skip = 0,
    status,
    startDate,
    endDate,
  } = options;

  const query = { organiserId };

  if (status) {
    query.status = status;
  }

  if (startDate || endDate) {
    query.timestamp = {};
    if (startDate) query.timestamp.$gte = new Date(startDate);
    if (endDate) query.timestamp.$lte = new Date(endDate);
  }

  return this.find(query)
    .sort({ timestamp: -1 })
    .limit(limit)
    .skip(skip)
    .populate('bookingId')
    .populate('touristId', 'fullname email avatar')
    .populate('activityId', 'titre');
};

/**
 * Méthode statique pour récupérer les logs d'une activité
 */
checkinLogSchema.statics.getByActivity = function(activityId, options = {}) {
  const {
    limit = 50,
    skip = 0,
    status,
  } = options;

  const query = { activityId };

  if (status) {
    query.status = status;
  }

  return this.find(query)
    .sort({ timestamp: -1 })
    .limit(limit)
    .skip(skip)
    .populate('bookingId')
    .populate('organiserId', 'fullname email')
    .populate('touristId', 'fullname email avatar');
};

/**
 * Méthode statique pour récupérer les statistiques de check-in
 */
checkinLogSchema.statics.getStats = function(filters = {}) {
  const {
    organiserId,
    activityId,
    startDate,
    endDate,
  } = filters;

  const matchQuery = {};

  if (organiserId) matchQuery.organiserId = organiserId;
  if (activityId) matchQuery.activityId = activityId;
  if (startDate || endDate) {
    matchQuery.timestamp = {};
    if (startDate) matchQuery.timestamp.$gte = new Date(startDate);
    if (endDate) matchQuery.timestamp.$lte = new Date(endDate);
  }

  return this.aggregate([
    { $match: matchQuery },
    {
      $group: {
        _id: '$status',
        count: { $sum: 1 },
      },
    },
    {
      $group: {
        _id: null,
        stats: {
          $push: {
            status: '$_id',
            count: '$count',
          },
        },
        total: { $sum: '$count' },
      },
    },
  ]);
};

/**
 * Méthode statique pour récupérer les check-ins par heure (pour dashboard)
 */
checkinLogSchema.statics.getHourlyStats = function(activityId, date) {
  const startOfDay = new Date(date);
  startOfDay.setHours(0, 0, 0, 0);
  
  const endOfDay = new Date(date);
  endOfDay.setHours(23, 59, 59, 999);

  return this.aggregate([
    {
      $match: {
        activityId: new mongoose.Types.ObjectId(activityId),
        status: 'success',
        timestamp: { $gte: startOfDay, $lte: endOfDay },
      },
    },
    {
      $group: {
        _id: {
          hour: { $hour: '$timestamp' },
        },
        count: { $sum: 1 },
      },
    },
    {
      $sort: { '_id.hour': 1 },
    },
  ]);
};

const CheckinLog = mongoose.model('CheckinLog', checkinLogSchema);

module.exports = CheckinLog;
