# 🔍 AUDIT COMPLET + AMÉLIORATION - Système DJTrip

**Date** : 2026-04-11  
**Architecture** : Node.js + Express + MongoDB + Socket.io  
**Scope** : Backend API complet

---

## 📊 1. AUDIT GLOBAL - Architecture Existantes

### 1.1 Structure Actuelle

```
Back/
├── config/          # Configuration (DB, Cloudinary, Firebase)
├── controllers/     # Logique métier (14 fichiers)
├── middleware/      # Middleware (15 fichiers)
├── models/          # Schémas Mongoose (14 fichiers)
├── routes/          # Routes Express (16 fichiers)
├── services/        # Services métier (14 fichiers)
├── utils/           # Utilitaires
├── validators/      # Validation Joi
└── server.js        # Point d'entrée
```

### 1.2 Stack Technique

| Composant | Version | Status |
|-----------|---------|--------|
| Node.js | - | ✅ |
| Express | ^5.2.1 | ✅ |
| MongoDB | ^9.2.2 | ✅ |
| JWT | ^9.0.3 | ✅ |
| Socket.io | ^4.8.3 | ✅ |
| Firebase Admin | ^13.8.0 | ✅ |
| Nodemailer | ^8.0.1 | ✅ |
| Cloudinary | ^2.9.0 | ✅ |
| BullMQ | ❌ MANQUANT | ⚠️ |
| Redis | ❌ MANQUANT | ⚠️ |

---

## 🐛 2. DÉTECTION BUGS POTENTIELS

### 2.1 Race Conditions (CRITICAL)

#### ❌ Bug #1: Overbooking lors de l'approval simultané

**Emplacement** : `Back/controllers/inscription.js` → `approuverInscription`

**Problème** :
```javascript
// Ligne 503-509
const placesDisponibles = activite.capacite_max - activite.nombre_reservations;
if (inscription.nombre_participants > placesDisponibles) {
  return res.status(400).json({ message: "..." });
}

// GAP DE TEMPS ICI - Race condition possible !

await inscription.approuver(message_organisateur);

// Ligne 521-523
await Activite.findByIdAndUpdate(inscription.activite_id, {
  $inc: { nombre_reservations: inscription.nombre_participants },
});
```

**Scénario** :
1. Organisateur A voit 5 places disponibles
2. Organisateur B voit 5 places disponibles
3. Les deux approuvent simultanément
4. Résultat : 10 participants pour une capacité de 5

**Solution** : Opération atomique avec `findOneAndUpdate`
```javascript
const updatedActivite = await Activite.findOneAndUpdate(
  {
    _id: inscription.activite_id,
    $expr: { $gte: ["$capacite_max", { $add: ["$nombre_reservations", inscription.nombre_participants] }] }
  },
  {
    $inc: { nombre_reservations: inscription.nombre_participants }
  },
  { new: true }
);

if (!updatedActivite) {
  return res.status(400).json({ message: "Plus de places disponibles" });
}
```

---

#### ❌ Bug #2: Double check-in (déjà partiellement fixé)

**Emplacement** : `Back/controllers/inscription.js` → `verifyInscription`

**Status** : ✅ DÉJÀ FIXÉ avec `findOneAndUpdate` atomique

**Code existant** (correct) :
```javascript
const updatedBooking = await Inscription.findOneAndUpdate(
  {
    _id: inscriptionId,
    statut: 'approuvee',
    qr_used_at: { $exists: false },
  },
  {
    $set: {
      statut: 'verifie',
      qr_used_at: new Date(),
    },
  },
  { new: true }
);
```

---

### 2.2 Problèmes de Cohérence des Données

#### ❌ Bug #3: Incohérence `nombre_reservations` lors de l'annulation

**Emplacement** : `Back/controllers/inscription.js` → `annulerInscription`

**Problème** :
```javascript
// Ligne 684-693
const wasApproved = inscription.statut === "approuvee";
const nombreParticipants = inscription.nombre_participants;

await inscription.annuler();

if (wasApproved) {
  await Activite.findByIdAndUpdate(inscription.activite_id, {
    $inc: { nombre_reservations: -nombreParticipants },
  });
}
```

**Issue** : Pas de transaction atomique. Si l'annulation échoue après le décrément, les données sont incohérentes.

**Solution** : Transaction MongoDB
```javascript
const session = await mongoose.startSession();
session.startTransaction();

try {
  const inscription = await Inscription.findById(inscriptionId).session(session);
  
  if (inscription.statut === "approuvee") {
    await Activite.findByIdAndUpdate(
      inscription.activite_id,
      { $inc: { nombre_reservations: -inscription.nombre_participants } },
      { session }
    );
  }
  
  inscription.statut = "annulee";
  await inscription.save({ session });
  
  await session.commitTransaction();
} catch (error) {
  await session.abortTransaction();
  throw error;
}
```

---

#### ❌ Bug #4: Pas de validation de prix lors de la création

**Emplacement** : `Back/controllers/inscription.js` → `createInscription`

**Problème** :
```javascript
// Ligne 277
const prixTotal = activite.prix * nombreParticipants;
```

**Issue** : Le prix de l'activité peut changer entre la création et l'approval. Le prix_total n'est pas figé.

**Solution** : Stocker le prix au moment de la réservation
```javascript
const inscription = new Inscription({
  // ...
  prix_unitaire: activite.prix, // PRIX FIGÉ
  prix_total: activite.prix * nombreParticipants,
});
```

---

### 2.3 Problèmes de Sécurité

#### ❌ Bug #5: Pas de rate limiting sur les endpoints critiques

**Emplacement** : `Back/server.js` → Routes

**Problème** :
```javascript
// Ligne 121-126
const { authLimiter, apiLimiter } = require("./middleware/rateLimit");
app.use("/api", apiLimiter);
app.use("/api/v1/users/signin", authLimiter);
app.use("/api/v1/users/signup", authLimiter);
app.use("/api/v1/users/forgot-password", authLimiter);
```

**Issue** : Pas de rate limiting sur :
- Création de bookings (spam)
- Approval (abuse)
- Check-in (fraude)

**Solution** :
```javascript
const bookingLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 heure
  max: 10, // Max 10 bookings/heure
  message: "Trop de réservations. Réessayez plus tard."
});

app.use("/api/v1/inscriptions", bookingLimiter);
```

---

#### ❌ Bug #6: Pas d'idempotency sur les actions critiques

**Emplacement** : Tous les endpoints POST/PUT

**Problème** : Un utilisateur peut envoyer la même requête plusieurs fois (double booking, double approval).

**Solution** : Idempotency keys
```javascript
// Middleware idempotency
exports.idempotency = async (req, res, next) => {
  const idempotencyKey = req.headers['x-idempotency-key'];
  if (!idempotencyKey) return next();
  
  const cached = await redis.get(`idempotency:${idempotencyKey}`);
  if (cached) return res.status(200).json(JSON.parse(cached));
  
  res.sendResponse = res.json;
  res.json = (data) => {
    redis.setex(`idempotency:${idempotencyKey}`, 86400, JSON.stringify(data));
    res.sendResponse(data);
  };
  
  next();
};
```

---

### 2.4 Problèmes de Performance

#### ❌ Bug #7: N+1 queries dans les listes

**Emplacement** : `Back/controllers/inscription.js` → `getInscriptionsByOrganisateur`

**Problème** :
```javascript
const inscriptions = await Inscription.find(filter)
  .populate("touriste_id", "fullname email avatar num_tel pays_origine age")
  .populate("activite_id", "titre date_debut date_fin lieu prix")
  .sort({ createdAt: -1 });
```

**Issue** : Pas de pagination, pas de projection, peut retourner des milliers de documents.

**Solution** : Pagination + Projection
```javascript
const page = parseInt(req.query.page) || 1;
const limit = parseInt(req.query.limit) || 20;
const skip = (page - 1) * limit;

const inscriptions = await Inscription.find(filter)
  .select("touriste_id activite_id statut nombre_participants prix_total date_demande")
  .populate("touriste_id", "fullname email avatar")
  .populate("activite_id", "titre date_debut lieu")
  .skip(skip)
  .limit(limit)
  .sort({ createdAt: -1 });
```

---

#### ❌ Bug #8: Index manquants pour les requêtes fréquentes

**Emplacement** : `Back/models/inscription.js`

**Problème** : Index existants mais incomplets
```javascript
// Ligne 104-107
inscriptionSchema.index({ touriste_id: 1, statut: 1 });
inscriptionSchema.index({ activite_id: 1, statut: 1 });
inscriptionSchema.index({ organisateur_id: 1, statut: 1 });
inscriptionSchema.index({ qr_token: 1 }, { sparse: true });
```

**Index manquants** :
```javascript
// Pour l'auto-expiration
inscriptionSchema.index({ statut: 1, date_demande: 1 });
inscriptionSchema.index({ activite_id: 1, statut: 1, date_demande: 1 });

// Pour les stats
inscriptionSchema.index({ organisateur_id: 1, statut: 1, prix_total: 1 });

// TTL index pour auto-cleanup des tokens expirés
inscriptionSchema.index({ qr_token_expires_at: 1 }, { 
  expireAfterSeconds: 0,
  partialFilterExpression: { qr_token: { $exists: true } }
});
```

---

## 🧠 3. AMÉLIORATION LOGIQUE MÉTIER

### 3.1 Workflow Booking Amélioré

#### ✅ Amélioration #1: Politique d'annulation avec pénalités

**Nouveau modèle** :
```javascript
const inscriptionSchema = new mongoose.Schema({
  // ... champs existants
  
  // Politique d'annulation
  cancellationPolicy: {
    canCancel: { type: Boolean, default: true },
    cancellationDeadline: { type: Date }, // Date limite d'annulation
    cancellationFee: { type: Number, default: 0 }, // % du prix
    refundAmount: { type: Number, default: 0 }, // Montant à rembourser
    cancelledAt: { type: Date },
    cancellationReason: { type: String },
    refundProcessed: { type: Boolean, default: false },
  },
  
  // No-show tracking
  noShow: {
    isNoShow: { type: Boolean, default: false },
    markedAt: { type: Date },
    markedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Organisator' },
  },
});
```

**Logique d'annulation** :
```javascript
// Back/services/cancellationPolicy.js
class CancellationPolicy {
  static calculateRefund(booking, activity) {
    const now = new Date();
    const activityStart = new Date(activity.date_debut);
    const hoursBeforeStart = (activityStart - now) / (1000 * 60 * 60);
    
    // Politique par défaut
    if (hoursBeforeStart >= 48) {
      return { refundPercent: 100, fee: 0 };
    } else if (hoursBeforeStart >= 24) {
      return { refundPercent: 50, fee: 50 };
    } else if (hoursBeforeStart >= 12) {
      return { refundPercent: 25, fee: 75 };
    } else {
      return { refundPercent: 0, fee: 100 };
    }
  }
  
  static async cancelBooking(bookingId, reason) {
    const session = await mongoose.startSession();
    session.startTransaction();
    
    try {
      const booking = await Inscription.findById(bookingId).session(session);
      const activity = await Activite.findById(booking.activite_id).session(session);
      
      const { refundPercent, fee } = this.calculateRefund(booking, activity);
      const refundAmount = (booking.prix_total * refundPercent) / 100;
      
      booking.statut = "annulee";
      booking.cancellationPolicy = {
        canCancel: true,
        cancellationDeadline: activity.date_debut,
        cancellationFee: fee,
        refundAmount,
        cancelledAt: new Date(),
        cancellationReason: reason,
        refundProcessed: false,
      };
      
      if (booking.statut === "approuvee") {
        await Activite.findByIdAndUpdate(
          booking.activite_id,
          { $inc: { nombre_reservations: -booking.nombre_participants } },
          { session }
        );
      }
      
      await booking.save({ session });
      await session.commitTransaction();
      
      // Queue pour remboursement
      await refundQueue.add('process-refund', { bookingId, refundAmount });
      
      return { success: true, refundAmount };
    } catch (error) {
      await session.abortTransaction();
      throw error;
    }
  }
}
```

---

#### ✅ Amélioration #2: No-show detection automatique

**Logique** :
```javascript
// Back/services/noShowService.js
class NoShowService {
  static async markNoShows() {
    const now = new Date();
    const activitiesEnded = await Activite.find({
      date_fin: { $lt: now },
      statut: 'active'
    }).distinct('_id');
    
    const noShows = await Inscription.updateMany(
      {
        activite_id: { $in: activitiesEnded },
        statut: 'approuvee',
        qr_used_at: { $exists: false }
      },
      {
        $set: {
          'noShow.isNoShow': true,
          'noShow.markedAt': now
        }
      }
    );
    
    return noShows.modifiedCount;
  }
  
  static async getNoShowRate(organiserId) {
    const totalApproved = await Inscription.countDocuments({
      organisateur_id: organiserId,
      statut: 'approuvee'
    });
    
    const totalNoShow = await Inscription.countDocuments({
      organisateur_id: organiserId,
      'noShow.isNoShow': true
    });
    
    return totalApproved > 0 ? (totalNoShow / totalApproved) * 100 : 0;
  }
}
```

---

### 3.2 Approval Amélioré

#### ✅ Amélioration #3: Approval avec overbooking protection

**Nouveau controller** :
```javascript
// Back/controllers/inscription.js (amélioré)
exports.approuverInscription = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  
  try {
    const organisateurId = req.user.userId;
    const { inscriptionId } = req.params;
    const { message_organisateur } = req.body;
    
    // 1. Récupérer le booking
    const inscription = await Inscription.findById(inscriptionId).session(session);
    if (!inscription) {
      await session.abortTransaction();
      return res.status(404).json({ message: "Registration not found" });
    }
    
    // 2. Vérifier autorisation
    if (inscription.organisateur_id.toString() !== organisateurId) {
      await session.abortTransaction();
      return res.status(403).json({ message: "Unauthorized" });
    }
    
    // 3. Vérifier statut
    if (inscription.statut !== "en_attente") {
      await session.abortTransaction();
      return res.status(400).json({ message: "Already processed" });
    }
    
    // 4. ATOMIC: Vérifier et incrémenter capacité
    const activite = await Activite.findOneAndUpdate(
      {
        _id: inscription.activite_id,
        $expr: {
          $gte: [
            "$capacite_max",
            { $add: ["$nombre_reservations", inscription.nombre_participants] }
          ]
        }
      },
      {
        $inc: { nombre_reservations: inscription.nombre_participants }
      },
      { new: true, session }
    );
    
    if (!activite) {
      await session.abortTransaction();
      return res.status(400).json({
        message: "Plus de places disponibles (overbooking protection)",
        available: activite?.capacite_max - activite?.nombre_reservations || 0
      });
    }
    
    // 5. Approuver le booking
    inscription.statut = "approuvee";
    inscription.date_reponse = new Date();
    if (message_organisateur) {
      inscription.message_organisateur = message_organisateur;
    }
    
    // 6. Générer QR token
    const qrToken = createBookingQrToken(inscription, activite);
    inscription.qr_token = qrToken;
    inscription.qr_token_generated_at = new Date();
    inscription.qr_token_expires_at = getActivityDeadline(activite);
    
    await inscription.save({ session });
    await session.commitTransaction();
    
    // 7. Queue pour email et notification (async)
    await notificationQueue.add('booking-approved', {
      inscriptionId: inscription._id,
      touristeId: inscription.touriste_id,
      activityTitle: activite.titre
    });
    
    // 8. Émettre événement Socket.IO (temps réel)
    io.to(`organizer:${organisateurId}`).emit('booking:approved', {
      inscriptionId: inscription._id,
      activityTitle: activite.titre
    });
    
    res.status(200).json({
      message: "Registration approved successfully",
      inscription: await Inscription.findById(inscriptionId)
        .populate("touriste_id", "fullname email")
        .populate("activite_id", "titre date_debut")
    });
  } catch (error) {
    await session.abortTransaction();
    throw error;
  }
};
```

---

### 3.3 Check-in QR Amélioré

#### ✅ Amélioration #4: Anti-fraude multi-device

**Nouveau modèle** :
```javascript
const inscriptionSchema = new mongoose.Schema({
  // ... champs existants
  
  // Check-in security
  checkinSecurity: {
    deviceId: { type: String }, // ID du device qui a scanné
    deviceIP: { type: String }, // IP du device
    location: {
      latitude: Number,
      longitude: Number,
      accuracy: Number
    },
    checkinAttempts: { type: Number, default: 0 },
    lastAttemptAt: { type: Date },
    suspiciousActivity: { type: Boolean, default: false },
    flaggedAt: { type: Date },
    flagReason: { type: String }
  }
});
```

**Logique anti-fraude** :
```javascript
// Back/controllers/inscription.js (amélioré)
exports.verifyInscription = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  
  try {
    const { inscriptionId } = req.params;
    const organisateurId = req.user.userId;
    
    // Extraire metadata de sécurité
    const clientIP = req.ip || req.connection.remoteAddress;
    const deviceId = req.headers['x-device-id'];
    const location = req.body.location; // { latitude, longitude }
    
    // 1. ATOMIC: Vérifier et marquer comme utilisé
    const updatedBooking = await Inscription.findOneAndUpdate(
      {
        _id: inscriptionId,
        organisateur_id: organisateurId,
        statut: 'approuvee',
        qr_used_at: { $exists: false }
      },
      {
        $set: {
          statut: 'verifie',
          qr_used_at: new Date(),
          'checkinSecurity.deviceId': deviceId,
          'checkinSecurity.deviceIP': clientIP,
          'checkinSecurity.location': location,
          'checkinSecurity.checkinAttempts': 1
        }
      },
      { new: true, session }
    );
    
    if (!updatedBooking) {
      // Vérifier si déjà utilisé
      const existing = await Inscription.findById(inscriptionId).session(session);
      if (existing?.qr_used_at) {
        // Log tentative suspecte
        await Inscription.findByIdAndUpdate(inscriptionId, {
          $inc: { 'checkinSecurity.checkinAttempts': 1 },
          $set: { 'checkinSecurity.lastAttemptAt': new Date() }
        }, { session });
        
        await session.abortTransaction();
        return res.status(400).json({
          success: false,
          code: "ALREADY_VERIFIED",
          message: "Already verified",
          checkinAttempts: existing.checkinSecurity?.checkinAttempts + 1
        });
      }
      
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        code: "BOOKING_NOT_FOUND",
        message: "Booking not found"
      });
    }
    
    // 2. Log d'audit
    await CheckinLog.createLog({
      bookingId: inscriptionId,
      organiserId: organisateurId,
      touristId: updatedBooking.touriste_id,
      activityId: updatedBooking.activite_id,
      status: 'success',
      ipAddress: clientIP,
      deviceId,
      location,
      session
    });
    
    await session.commitTransaction();
    
    // 3. Notification push
    await notificationQueue.add('checkin-confirmed', {
      touristId: updatedBooking.touriste_id,
      activityTitle: updatedBooking.activite_id?.titre
    });
    
    res.status(200).json({
      success: true,
      code: "VERIFIED",
      message: "Booking verified successfully",
      data: {
        inscription: updatedBooking,
        checkedInAt: updatedBooking.qr_used_at
      }
    });
  } catch (error) {
    await session.abortTransaction();
    throw error;
  }
};
```

---

## ⚡ 4. SCALABILITÉ & ARCHITECTURE

### 4.1 Architecture Modulaire Recommandée

```
Back/
├── config/
│   ├── db.js
│   ├── redis.js
│   ├── firebase.js
│   └── cloudinary.js
├── src/
│   ├── controllers/
│   │   ├── activity.controller.js
│   │   ├── booking.controller.js
│   │   ├── user.controller.js
│   │   └── ...
│   ├── services/
│   │   ├── booking.service.js
│   │   ├── notification.service.js
│   │   ├── email.service.js
│   │   ├── cancellation.service.js
│   │   └── ...
│   ├── repositories/
│   │   ├── activity.repository.js
│   │   ├── booking.repository.js
│   │   └── ...
│   ├── models/
│   │   ├── Activity.model.js
│   │   ├── Booking.model.js
│   │   └── ...
│   ├── middleware/
│   │   ├── auth.middleware.js
│   │   ├── validation.middleware.js
│   │   ├── rateLimit.middleware.js
│   │   └── ...
│   ├── queues/
│   │   ├── email.queue.js
│   │   ├── notification.queue.js
│   │   └── ...
│   ├── websocket/
│   │   ├── socket.handler.js
│   │   └── events.js
│   ├── utils/
│   │   ├── logger.js
│   │   ├── errors.js
│   │   └── ...
│   └── routes/
│       ├── activity.routes.js
│       ├── booking.routes.js
│       └── ...
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
└── server.js
```

---

### 4.2 Pattern Repository

**Exemple** : `Back/src/repositories/booking.repository.js`
```javascript
const Inscription = require('../models/Booking.model');

class BookingRepository {
  async findById(id, options = {}) {
    const { session, populate = [] } = options;
    let query = Inscription.findById(id);
    if (session) query = query.session(session);
    if (populate.length) query = query.populate(populate);
    return query;
  }
  
  async findOne(filter, options = {}) {
    const { session, populate = [] } = options;
    let query = Inscription.findOne(filter);
    if (session) query = query.session(session);
    if (populate.length) query = query.populate(populate);
    return query;
  }
  
  async find(filter, options = {}) {
    const { session, populate = [], skip = 0, limit = 100, sort = {} } = options;
    let query = Inscription.find(filter);
    if (session) query = query.session(session);
    if (populate.length) query = query.populate(populate);
    if (skip) query = query.skip(skip);
    if (limit) query = query.limit(limit);
    if (Object.keys(sort).length) query = query.sort(sort);
    return query;
  }
  
  async create(data, options = {}) {
    const { session } = options;
    const booking = new Inscription(data);
    if (session) return await booking.save({ session });
    return await booking.save();
  }
  
  async updateOne(filter, update, options = {}) {
    const { session } = options;
    let query = Inscription.findOneAndUpdate(filter, update, { new: true });
    if (session) query = query.session(session);
    return query;
  }
  
  async atomicApprove(bookingId, participantsCount) {
    return Inscription.findOneAndUpdate(
      {
        _id: bookingId,
        statut: 'en_attente'
      },
      {
        $set: { statut: 'approuvee', date_reponse: new Date() }
      },
      { new: true }
    );
  }
  
  async atomicIncrementCapacity(activityId, participantsCount) {
    return Activite.findOneAndUpdate(
      {
        _id: activityId,
        $expr: {
          $gte: [
            "$capacite_max",
            { $add: ["$nombre_reservations", participantsCount] }
          ]
        }
      },
      {
        $inc: { nombre_reservations: participantsCount }
      },
      { new: true }
    );
  }
}

module.exports = new BookingRepository();
```

---

### 4.3 Pattern Service

**Exemple** : `Back/src/services/booking.service.js`
```javascript
const bookingRepository = require('../repositories/booking.repository');
const activityRepository = require('../repositories/activity.repository');
const notificationService = require('./notification.service');
const emailService = require('./email.service');
const { createBookingQrToken } = require('../utils/qr');
const logger = require('../utils/logger');

class BookingService {
  async createBooking(touristId, activityId, data) {
    const session = await mongoose.startSession();
    session.startTransaction();
    
    try {
      // 1. Vérifier activité
      const activity = await activityRepository.findById(activityId, { session });
      if (!activity) throw new Error('Activity not found');
      if (activity.statut !== 'active') throw new Error('Activity not active');
      
      // 2. Vérifier capacité
      const available = activity.capacite_max - activity.nombre_reservations;
      if (data.nombre_participants > available) {
        throw new Error('Not enough capacity');
      }
      
      // 3. Vérifier doublon
      const existing = await bookingRepository.findOne({
        touriste_id: touristId,
        activite_id: activityId,
        statut: { $in: ['en_attente', 'approuvee'] }
      }, { session });
      
      if (existing) throw new Error('Already booked');
      
      // 4. Créer booking
      const booking = await bookingRepository.create({
        touriste_id: touristId,
        activite_id: activityId,
        organisateur_id: activity.organisateur_id,
        nombre_participants: data.nombre_participants,
        message_touriste: data.message_touriste,
        prix_unitaire: activity.prix,
        prix_total: activity.prix * data.nombre_participants,
      }, { session });
      
      await session.commitTransaction();
      
      // 5. Notification organisateur (async)
      notificationService.notifyOrganizerNewBooking(activity.organisateur_id, booking._id);
      
      logger.info('Booking created', { bookingId: booking._id, touristId, activityId });
      
      return booking;
    } catch (error) {
      await session.abortTransaction();
      logger.error('Booking creation failed', { error: error.message });
      throw error;
    }
  }
  
  async approveBooking(organiserId, bookingId, message) {
    const session = await mongoose.startSession();
    session.startTransaction();
    
    try {
      // 1. Récupérer booking
      const booking = await bookingRepository.findById(bookingId, { session });
      if (!booking) throw new Error('Booking not found');
      if (booking.organisateur_id.toString() !== organisateurId) throw new Error('Unauthorized');
      if (booking.statut !== 'en_attente') throw new Error('Already processed');
      
      // 2. ATOMIC: Incrémenter capacité
      const activity = await bookingRepository.atomicIncrementCapacity(
        booking.activite_id,
        booking.nombre_participants
      );
      
      if (!activity) throw new Error('No capacity available');
      
      // 3. Approuver booking
      booking.statut = 'approuvee';
      booking.date_reponse = new Date();
      booking.message_organisateur = message;
      
      // 4. Générer QR
      const qrToken = createBookingQrToken(booking, activity);
      booking.qr_token = qrToken;
      booking.qr_token_generated_at = new Date();
      booking.qr_token_expires_at = activity.date_fin;
      
      await booking.save({ session });
      await session.commitTransaction();
      
      // 5. Queue email + notification (async)
      await emailQueue.add('send-confirmation', { bookingId });
      await notificationQueue.add('booking-approved', { bookingId });
      
      logger.info('Booking approved', { bookingId, organiserId });
      
      return booking;
    } catch (error) {
      await session.abortTransaction();
      logger.error('Booking approval failed', { error: error.message });
      throw error;
    }
  }
  
  async cancelBooking(touristId, bookingId, reason) {
    const session = await mongoose.startSession();
    session.startTransaction();
    
    try {
      const booking = await bookingRepository.findById(bookingId, { session });
      if (!booking) throw new Error('Booking not found');
      if (booking.touriste_id.toString() !== touristId) throw new Error('Unauthorized');
      if (booking.statut === 'annulee') throw new Error('Already cancelled');
      
      // Calculer remboursement
      const activity = await activityRepository.findById(booking.activite_id, { session });
      const refund = CancellationPolicy.calculateRefund(booking, activity);
      
      // Annuler
      booking.statut = 'annulee';
      booking.cancellationPolicy = {
        canCancel: true,
        cancellationDeadline: activity.date_debut,
        cancellationFee: refund.fee,
        refundAmount: refund.refundAmount,
        cancelledAt: new Date(),
        cancellationReason: reason,
        refundProcessed: false
      };
      
      // Décrémenter capacité si approuvé
      if (booking.statut === 'approuvee') {
        await activityRepository.updateOne(
          { _id: booking.activite_id },
          { $inc: { nombre_reservations: -booking.nombre_participants } },
          { session }
        );
      }
      
      await booking.save({ session });
      await session.commitTransaction();
      
      // Queue remboursement
      await refundQueue.add('process-refund', { bookingId, refundAmount: refund.refundAmount });
      
      logger.info('Booking cancelled', { bookingId, touristId, refundAmount: refund.refundAmount });
      
      return { booking, refundAmount: refund.refundAmount };
    } catch (error) {
      await session.abortTransaction();
      throw error;
    }
  }
}

module.exports = new BookingService();
```

---

### 4.4 Système de Queue avec BullMQ

**Installation** :
```bash
npm install bullmq ioredis
```

**Configuration** : `Back/src/queues/index.js`
```javascript
const { Queue, Worker } = require('bullmq');
const Redis = require('ioredis');

const connection = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
  maxRetriesPerRequest: null,
});

// Queues
exports.emailQueue = new Queue('emails', { connection });
exports.notificationQueue = new Queue('notifications', { connection });
exports.refundQueue = new Queue('refunds', { connection });

// Workers
require('./workers/email.worker');
require('./workers/notification.worker');
require('./workers/refund.worker');
```

**Worker Email** : `Back/src/queues/workers/email.worker.js`
```javascript
const { Worker } = require('bullmq');
const { connection } = require('../index');
const emailService = require('../../services/email.service');
const logger = require('../../utils/logger');

const emailWorker = new Worker('emails', async (job) => {
  const { type, data } = job.data;
  
  try {
    switch (type) {
      case 'booking-confirmation':
        await emailService.sendBookingConfirmationEmail(data);
        break;
      case 'booking-approved':
        await emailService.sendBookingApprovedEmail(data);
        break;
      case 'booking-rejected':
        await emailService.sendBookingRejectedEmail(data);
        break;
      case 'booking-cancelled':
        await emailService.sendBookingCancelledEmail(data);
        break;
      default:
        throw new Error(`Unknown email type: ${type}`);
    }
    
    logger.info('Email sent', { jobId: job.id, type });
  } catch (error) {
    logger.error('Email failed', { jobId: job.id, error: error.message });
    throw error; // BullMQ va retry
  }
}, { connection });

emailWorker.on('completed', (job) => {
  logger.info('Email job completed', { jobId: job.id });
});

emailWorker.on('failed', (job, err) => {
  logger.error('Email job failed', { jobId: job?.id, error: err.message });
});
```

---

## 🔔 5. NOTIFICATIONS INTELLIGENTES

### 5.1 Événements Structurés

**Payload FCM standardisé** :
```javascript
const NotificationEvents = {
  BOOKING_CREATED: {
    type: 'booking.created',
    title: 'Nouvelle réservation',
    body: '{touristName} a réservé {activityTitle}',
    data: {
      bookingId,
      touristId,
      activityId,
      activityTitle,
      touristName,
      participants,
      totalPrice
    },
    priority: 'high'
  },
  
  BOOKING_APPROVED: {
    type: 'booking.approved',
    title: 'Réservation approuvée',
    body: 'Votre réservation pour {activityTitle} a été approuvée',
    data: {
      bookingId,
      activityId,
      activityTitle,
      qrToken,
      bookingDate,
      bookingTime
    },
    priority: 'high'
  },
  
  BOOKING_REJECTED: {
    type: 'booking.rejected',
    title: 'Réservation refusée',
    body: 'Votre réservation pour {activityTitle} a été refusée',
    data: {
      bookingId,
      activityId,
      activityTitle,
      rejectionReason
    },
    priority: 'high'
  },
  
  BOOKING_CANCELLED: {
    type: 'booking.cancelled',
    title: 'Réservation annulée',
    body: '{touristName} a annulé sa réservation',
    data: {
      bookingId,
      touristId,
      activityId,
      activityTitle,
      cancellationReason,
      refundAmount
    },
    priority: 'medium'
  },
  
  CHECKIN_CONFIRMED: {
    type: 'checkin.confirmed',
    title: 'Check-in confirmé',
    body: 'Vous avez été check-in pour {activityTitle}',
    data: {
      bookingId,
      activityId,
      activityTitle,
      checkinTime
    },
    priority: 'high'
  },
  
  ACTIVITY_REMINDER: {
    type: 'activity.reminder',
    title: 'Rappel activité',
    body: 'Votre activité {activityTitle} commence dans {hoursLeft}h',
    data: {
      bookingId,
      activityId,
      activityTitle,
      activityDate,
      activityTime,
      location,
      hoursLeft
    },
    priority: 'high'
  },
  
  REVIEW_REMINDER: {
    type: 'review.reminder',
    title: 'Laissez un avis',
    body: 'Comment était votre expérience avec {activityTitle} ?',
    data: {
      bookingId,
      activityId,
      activityTitle,
      bookingDate
    },
    priority: 'low'
  }
};
```

---

### 5.2 Service Notification Amélioré

**Exemple** : `Back/src/services/notification.service.js`
```javascript
const admin = require('firebase-admin');
const notificationQueue = require('../queues');
const logger = require('../utils/logger');

class NotificationService {
  async sendToUser(userId, event, data) {
    try {
      // Récupérer FCM token
      const user = await User.findById(userId).select('fcmTokens');
      if (!user || !user.fcmTokens?.length) {
        logger.warn('No FCM tokens for user', { userId });
        return;
      }
      
      // Construire payload
      const payload = this.buildPayload(event, data);
      
      // Envoyer à tous les tokens
      const results = await Promise.allSettled(
        user.fcmTokens.map(token => 
          admin.messaging().send({
            token,
            notification: {
              title: payload.title,
              body: payload.body,
            },
            data: payload.data,
            android: { priority: payload.priority === 'high' ? 'high' : 'normal' },
            apns: { 
              payload: { 
                aps: { 
                  alert: { title: payload.title, body: payload.body },
                  badge: 1,
                  sound: 'default'
                } 
              } 
            }
          })
        )
      );
      
      // Nettoyer tokens invalides
      const invalidTokens = results
        .filter(r => r.status === 'rejected')
        .map((r, i) => user.fcmTokens[i]);
      
      if (invalidTokens.length > 0) {
        await User.findByIdAndUpdate(userId, {
          $pull: { fcmTokens: { $in: invalidTokens } }
        });
      }
      
      logger.info('Notification sent', { userId, event, successCount: results.filter(r => r.status === 'fulfilled').length });
    } catch (error) {
      logger.error('Notification failed', { userId, event, error: error.message });
      // Retry via queue
      await notificationQueue.add('retry-notification', { userId, event, data }, {
        attempts: 3,
        backoff: { type: 'exponential', delay: 2000 }
      });
    }
  }
  
  buildPayload(event, data) {
    const template = NotificationEvents[event];
    if (!template) throw new Error(`Unknown event: ${event}`);
    
    let title = template.title;
    let body = template.body;
    
    // Template substitution
    Object.keys(data).forEach(key => {
      title = title.replace(`{${key}}`, data[key]);
      body = body.replace(`{${key}}`, data[key]);
    });
    
    return {
      type: template.type,
      title,
      body,
      data: { ...template.data, ...data },
      priority: template.priority
    };
  }
  
  // Méthodes spécifiques
  async notifyOrganizerNewBooking(organiserId, bookingId) {
    const booking = await Inscription.findById(bookingId)
      .populate('touriste_id', 'fullname')
      .populate('activite_id', 'titre');
    
    await this.sendToUser(organiserId, 'BOOKING_CREATED', {
      bookingId,
      touristId: booking.touriste_id._id,
      activityId: booking.activite_id._id,
      activityTitle: booking.activite_id.titre,
      touristName: booking.touriste_id.fullname,
      participants: booking.nombre_participants,
      totalPrice: booking.prix_total
    });
  }
  
  async notifyTouristApproved(bookingId) {
    const booking = await Inscription.findById(bookingId)
      .populate('activite_id', 'titre date_debut')
      .populate('touriste_id', 'fullname');
    
    const bookingDate = new Date(booking.activite_id.date_debut).toLocaleDateString('fr-FR');
    const bookingTime = new Date(booking.activite_id.date_debut).toLocaleTimeString('fr-FR', {
      hour: '2-digit',
      minute: '2-digit'
    });
    
    await this.sendToUser(booking.touriste_id._id, 'BOOKING_APPROVED', {
      bookingId,
      activityId: booking.activite_id._id,
      activityTitle: booking.activite_id.titre,
      qrToken: booking.qr_token,
      bookingDate,
      bookingTime
    });
  }
}

module.exports = new NotificationService();
```

---

## 🔄 6. TEMPS RÉEL (Socket.IO)

### 6.1 Handler Socket.IO Amélioré

**Exemple** : `Back/src/websocket/socket.handler.js`
```javascript
const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

class SocketHandler {
  constructor(server) {
    this.io = new Server(server, {
      cors: {
        origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
        methods: ['GET', 'POST']
      }
    });
    
    this.setupMiddleware();
    this.setupEvents();
  }
  
  setupMiddleware() {
    // Auth middleware
    this.io.use(async (socket, next) => {
      try {
        const token = socket.handshake.auth.token;
        if (!token) throw new Error('No token');
        
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await User.findById(decoded.userId);
        
        if (!user) throw new Error('User not found');
        
        socket.user = user;
        socket.userId = user._id.toString();
        socket.userType = decoded.userType;
        
        next();
      } catch (error) {
        logger.error('Socket auth failed', { error: error.message });
        next(new Error('Authentication failed'));
      }
    });
  }
  
  setupEvents() {
    this.io.on('connection', (socket) => {
      logger.info('User connected', { userId: socket.userId, socketId: socket.id });
      
      // Join rooms
      socket.join(`user:${socket.userId}`);
      if (socket.userType === 'organizer') {
        socket.join(`organizer:${socket.userId}`);
      }
      
      // Booking events
      socket.on('booking:created', (data) => {
        this.io.to(`organizer:${data.organizerId}`).emit('booking:new', data);
      });
      
      socket.on('booking:approved', (data) => {
        this.io.to(`user:${data.touristId}`).emit('booking:approved', data);
      });
      
      socket.on('booking:cancelled', (data) => {
        this.io.to(`organizer:${data.organizerId}`).emit('booking:cancelled', data);
      });
      
      socket.on('checkin:scanned', (data) => {
        this.io.to(`organizer:${data.organizerId}`).emit('checkin:success', data);
      });
      
      // Activity events
      socket.on('activity:updated', (data) => {
        this.io.emit('activity:updated', data);
      });
      
      socket.on('disconnect', () => {
        logger.info('User disconnected', { userId: socket.userId, socketId: socket.id });
      });
    });
  }
  
  // Méthodes utilitaires
  emitToUser(userId, event, data) {
    this.io.to(`user:${userId}`).emit(event, data);
  }
  
  emitToOrganizer(organizerId, event, data) {
    this.io.to(`organizer:${organizerId}`).emit(event, data);
  }
  
  emitToAll(event, data) {
    this.io.emit(event, data);
  }
}

module.exports = SocketHandler;
```

---

### 6.2 Cas d'usage Temps Réel

**Dashboard Organisateur en temps réel** :
```javascript
// Dans le controller booking
exports.approuverInscription = async (req, res) => {
  // ... logique d'approval ...
  
  // Émettre en temps réel
  socketHandler.emitToOrganizer(organisateurId, 'booking:approved', {
    bookingId: booking._id,
    activityTitle: booking.activite_id.titre,
    touristName: booking.touriste_id.fullname,
    timestamp: new Date()
  });
  
  res.json({ success: true, booking });
};
```

**Frontend (écoute des événements)** :
```javascript
// Dans le frontend Flutter ou React
socket.on('booking:approved', (data) => {
  // Mettre à jour l'UI en temps réel
  updateBookingStatus(data.bookingId, 'approved');
  showNotification('Réservation approuvée', data.activityTitle);
});
```

---

## 📊 7. OBSERVABILITÉ

### 7.1 Logs Structurés (JSON)

**Logger amélioré** : `Back/src/utils/logger.js`
```javascript
const winston = require('winston');
const { combine, timestamp, printf, colorize } = winston.format;

const logFormat = printf(({ level, message, timestamp, ...meta }) => {
  return JSON.stringify({
    timestamp,
    level,
    message,
    ...meta,
    service: 'djtrip-api',
    environment: process.env.NODE_ENV || 'development'
  });
});

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: combine(
    timestamp(),
    logFormat
  ),
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

// Middleware correlation ID
exports.correlationMiddleware = (req, res, next) => {
  req.correlationId = req.headers['x-correlation-id'] || generateUUID();
  res.setHeader('x-correlation-id', req.correlationId);
  
  logger.info('Request started', {
    correlationId: req.correlationId,
    method: req.method,
    path: req.path,
    userId: req.user?.userId,
    ip: req.ip
  });
  
  const originalSend = res.send;
  res.send = function (data) {
    logger.info('Request completed', {
      correlationId: req.correlationId,
      statusCode: res.statusCode,
      responseTime: Date.now() - req.startTime
    });
    originalSend.call(this, data);
  };
  
  next();
};

module.exports = logger;
```

---

### 7.2 Monitoring & Alerting

**Métriques Prometheus** : `Back/src/utils/metrics.js`
```javascript
const client = require('prom-client');

const register = new client.Registry();

// Métriques HTTP
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

// Métriques Business
const bookingsCreated = new client.Counter({
  name: 'bookings_created_total',
  help: 'Total number of bookings created',
  labelNames: ['activity_type', 'status'],
  registers: [register]
});

const bookingsApproved = new client.Counter({
  name: 'bookings_approved_total',
  help: 'Total number of bookings approved',
  registers: [register]
});

const bookingsCancelled = new client.Counter({
  name: 'bookings_cancelled_total',
  help: 'Total number of bookings cancelled',
  labelNames: ['reason'],
  registers: [register]
});

const checkinsTotal = new client.Counter({
  name: 'checkins_total',
  help: 'Total number of check-ins',
  registers: [register]
});

const activeBookings = new client.Gauge({
  name: 'active_bookings',
  help: 'Number of active bookings',
  registers: [register]
});

// Endpoint metrics
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

module.exports = {
  register,
  httpRequestDuration,
  httpRequestsTotal,
  bookingsCreated,
  bookingsApproved,
  bookingsCancelled,
  checkinsTotal,
  activeBookings
};
```

---

## 📈 8. MÉTRIQUES BUSINESS

### 8.1 Structure MongoDB pour Stats

**Nouveau modèle** : `Back/src/models/Analytics.model.js`
```javascript
const mongoose = require('mongoose');

const dailyStatsSchema = new mongoose.Schema({
  date: {
    type: Date,
    required: true,
    unique: true
  },
  
  // Bookings
  bookings: {
    created: { type: Number, default: 0 },
    approved: { type: Number, default: 0 },
    rejected: { type: Number, default: 0 },
    cancelled: { type: Number, default: 0 },
    checkedIn: { type: Number, default: 0 },
    noShow: { type: Number, default: 0 }
  },
  
  // Revenue
  revenue: {
    total: { type: Number, default: 0 },
    refunded: { type: Number, default: 0 },
    net: { type: Number, default: 0 }
  },
  
  // Conversion
  conversion: {
    bookingRate: { type: Number, default: 0 }, // bookings / views
    approvalRate: { type: Number, default: 0 }, // approved / created
    checkinRate: { type: Number, default: 0 }, // checked-in / approved
    noShowRate: { type: Number, default: 0 } // no-show / approved
  },
  
  // Par organisateur
  organizerStats: [{
    organizerId: mongoose.Schema.Types.ObjectId,
    bookings: Number,
    revenue: Number,
    checkins: Number
  }],
  
  // Par activité
  activityStats: [{
    activityId: mongoose.Schema.Types.ObjectId,
    bookings: Number,
    revenue: Number,
    rating: Number
  }]
}, {
  timestamps: true
});

dailyStatsSchema.index({ date: 1 });

module.exports = mongoose.model('DailyStats', dailyStatsSchema);
```

---

### 8.2 Service Analytics

**Exemple** : `Back/src/services/analytics.service.js`
```javascript
const DailyStats = require('../models/Analytics.model');
const Inscription = require('../models/Booking.model');
const Activite = require('../models/Activity.model');

class AnalyticsService {
  async calculateDailyStats(date = new Date()) {
    const startOfDay = new Date(date.setHours(0, 0, 0, 0));
    const endOfDay = new Date(date.setHours(23, 59, 59, 999));
    
    // Bookings du jour
    const bookings = await Inscription.find({
      createdAt: { $gte: startOfDay, $lte: endOfDay }
    });
    
    const stats = {
      date: startOfDay,
      bookings: {
        created: bookings.filter(b => b.statut === 'en_attente').length,
        approved: bookings.filter(b => b.statut === 'approuvee').length,
        rejected: bookings.filter(b => b.statut === 'refusee').length,
        cancelled: bookings.filter(b => b.statut === 'annulee').length,
        checkedIn: bookings.filter(b => b.statut === 'verifie').length,
        noShow: bookings.filter(b => b.noShow?.isNoShow).length
      },
      revenue: {
        total: bookings.reduce((sum, b) => sum + (b.prix_total || 0), 0),
        refunded: bookings.reduce((sum, b) => sum + (b.cancellationPolicy?.refundAmount || 0), 0),
        net: 0
      },
      conversion: {
        bookingRate: 0,
        approvalRate: 0,
        checkinRate: 0,
        noShowRate: 0
      }
    };
    
    stats.revenue.net = stats.revenue.total - stats.revenue.refunded;
    
    // Calculer les taux
    const totalCreated = stats.bookings.created;
    if (totalCreated > 0) {
      stats.conversion.approvalRate = (stats.bookings.approved / totalCreated) * 100;
    }
    
    const totalApproved = stats.bookings.approved;
    if (totalApproved > 0) {
      stats.conversion.checkinRate = (stats.bookings.checkedIn / totalApproved) * 100;
      stats.conversion.noShowRate = (stats.bookings.noShow / totalApproved) * 100;
    }
    
    // Upsert
    await DailyStats.findOneAndUpdate(
      { date: startOfDay },
      stats,
      { upsert: true, new: true }
    );
    
    return stats;
  }
  
  async getConversionRate(period = '7d') {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 7);
    
    const views = await Activity.countDocuments({
      createdAt: { $gte: startDate }
    });
    
    const bookings = await Inscription.countDocuments({
      createdAt: { $gte: startDate }
    });
    
    return views > 0 ? (bookings / views) * 100 : 0;
  }
  
  async getNoShowRate(organizerId) {
    const approved = await Inscription.countDocuments({
      organisateur_id: organizerId,
      statut: 'approuvee'
    });
    
    const noShow = await Inscription.countDocuments({
      organisateur_id: organizerId,
      'noShow.isNoShow': true
    });
    
    return approved > 0 ? (noShow / approved) * 100 : 0;
  }
  
  async getEstimatedRevenue(period = '30d') {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - 30);
    
    const result = await Inscription.aggregate([
      {
        $match: {
          statut: 'approuvee',
          createdAt: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: null,
          totalRevenue: { $sum: '$prix_total' }
        }
      }
    ]);
    
    return result[0]?.totalRevenue || 0;
  }
}

module.exports = new AnalyticsService();
```

---

## 🔐 9. SÉCURITÉ AVANCÉE

### 9.1 Idempotency Keys

**Middleware** : `Back/src/middleware/idempotency.middleware.js`
```javascript
const redis = require('ioredis');
const crypto = require('crypto');

const redisClient = new Redis();

exports.idempotency = async (req, res, next) => {
  const idempotencyKey = req.headers['x-idempotency-key'];
  
  if (!idempotencyKey) {
    return next();
  }
  
  // Valider format (UUID v4)
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (!uuidRegex.test(idempotencyKey)) {
    return res.status(400).json({
      error: 'Invalid idempotency key format'
    });
  }
  
  const cacheKey = `idempotency:${req.method}:${req.path}:${idempotencyKey}`;
  
  // Vérifier si déjà traité
  const cached = await redisClient.get(cacheKey);
  if (cached) {
    const cachedResponse = JSON.parse(cached);
    return res.status(cachedResponse.status).json(cachedResponse.body);
  }
  
  // Intercepter la réponse
  const originalSend = res.send;
  res.send = function (body) {
    // Cache la réponse (24h)
    redisClient.setex(
      cacheKey,
      86400,
      JSON.stringify({
        status: res.statusCode,
        body: typeof body === 'string' ? JSON.parse(body) : body
      })
    );
    
    originalSend.call(this, body);
  };
  
  next();
};
```

---

### 9.2 Rate Limiting Avancé

**Middleware** : `Back/src/middleware/rateLimit.middleware.js`
```javascript
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const redis = require('ioredis');

const redisClient = new Redis();

// Rate limiting par endpoint
exports.createRateLimiter = (options) => {
  return rateLimit({
    store: new RedisStore({
      client: redisClient,
      prefix: 'rate-limit:'
    }),
    windowMs: options.windowMs || 60 * 1000,
    max: options.max || 100,
    message: options.message || 'Too many requests',
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: options.keyGenerator || (req) => req.ip,
    skip: options.skip || (() => false)
  });
};

// Rate limiting spécifiques
exports.authLimiter = exports.createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  message: 'Too many authentication attempts'
});

exports.bookingLimiter = exports.createRateLimiter({
  windowMs: 60 * 60 * 1000, // 1 heure
  max: 10,
  message: 'Too many booking attempts'
});

exports.checkinLimiter = exports.createRateLimiter({
  windowMs: 60 * 1000, // 1 minute
  max: 20,
  message: 'Too many check-in attempts'
});
```

---

### 9.3 Validation Stricte des Inputs

**Validators Joi** : `Back/src/validators/booking.validator.js`
```javascript
const Joi = require('joi');

const createBookingSchema = Joi.object({
  activite_id: Joi.string().required().pattern(/^[0-9a-fA-F]{24}$/),
  nombre_participants: Joi.number().integer().min(1).max(50).required(),
  message_touriste: Joi.string().max(500).allow('')
});

const approveBookingSchema = Joi.object({
  message_organisateur: Joi.string().max(500).allow('')
});

const cancelBookingSchema = Joi.object({
  reason: Joi.string().max(500).required()
});

const validateBooking = (schema) => {
  return (req, res, next) => {
    const { error } = schema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.details.map(d => d.message)
      });
    }
    next();
  };
};

module.exports = {
  createBookingSchema,
  approveBookingSchema,
  cancelBookingSchema,
  validateBooking
};
```

---

## 🧾 10. BONNES PRATIQUES

### 10.1 Structure Dossiers Professionnelle

```
Back/
├── config/              # Configuration
├── src/
│   ├── controllers/     # Controllers (logique HTTP)
│   ├── services/        # Services métier
│   ├── repositories/    # Accès données (MongoDB)
│   ├── models/          # Schémas Mongoose
│   ├── middleware/      # Middleware Express
│   ├── routes/          # Routes Express
│   ├── queues/          # BullMQ queues & workers
│   ├── websocket/       # Socket.IO handlers
│   ├── utils/           # Utilitaires (logger, errors)
│   ├── validators/      # Validation Joi
│   └── dto/             # Data Transfer Objects
├── tests/               # Tests
├── logs/                # Logs
├── scripts/             # Scripts utilitaires
└── server.js            # Point d'entrée
```

---

### 10.2 Error Handling Robuste

**Custom Errors** : `Back/src/utils/errors.js`
```javascript
class AppError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

class BadRequestError extends AppError {
  constructor(message = 'Bad Request') {
    super(message, 400);
  }
}

class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 401);
  }
}

class ForbiddenError extends AppError {
  constructor(message = 'Forbidden') {
    super(message, 403);
  }
}

class NotFoundError extends AppError {
  constructor(message = 'Not Found') {
    super(message, 404);
  }
}

class ConflictError extends AppError {
  constructor(message = 'Conflict') {
    super(message, 409);
  }
}

module.exports = {
  AppError,
  BadRequestError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError
};
```

**Error Handler** : `Back/src/middleware/errorHandler.js`
```javascript
const { AppError } = require('../utils/errors');
const logger = require('../utils/logger');

exports.errorHandler = (err, req, res, next) => {
  const { correlationId } = req;
  
  logger.error('Error occurred', {
    correlationId,
    error: err.message,
    stack: err.stack,
    statusCode: err.statusCode || 500
  });
  
  if (err.isOperational) {
    return res.status(err.statusCode).json({
      success: false,
      error: err.message,
      correlationId
    });
  }
  
  // Erreurs inattendues
  res.status(500).json({
    success: false,
    error: 'Internal server error',
    correlationId
  });
};
```

---

## 📋 11. PRIORITÉS D'AMÉLIORATION

### HIGH PRIORITY (Critique pour production)

1. ✅ **Fix race conditions** - Overbooking protection
2. ✅ **Transactions MongoDB** - Cohérence des données
3. ✅ **Rate limiting** - Protection contre abuse
4. ✅ **Idempotency** - Double actions
5. ✅ **Logs structurés** - Observabilité
6. ✅ **Error handling** - Robustesse

### MEDIUM PRIORITY (Amélioration scalabilité)

1. ⚡ **Architecture modulaire** - Services/Repositories
2. ⚡ **Système de queue** - BullMQ pour async
3. ⚡ **Pagination** - Performance requêtes
4. ⚡ **Index MongoDB** - Optimisation
5. ⚡ **Temps réel** - Socket.IO dashboard

### LOW PRIORITY (Bonus)

1. 🔔 **Notifications intelligentes** - Payload structuré
2. 📊 **Métriques business** - Analytics
3. 🧾 **Politique annulation** - Pénalités
4. 🎯 **No-show detection** - Auto-mark

---

## 🎯 12. CONCLUSION

Le système DJTrip est **fonctionnel** mais nécessite des améliorations critiques pour être **production-ready** :

### ✅ Forces
- Architecture MVC claire
- Auth JWT robuste
- Socket.IO intégré
- Firebase FCM intégré
- Logs d'audit check-in

### ❌ Faiblesses
- Race conditions (overbooking)
- Pas de transactions MongoDB
- Pas de rate limiting sur endpoints critiques
- Pas d'idempotency
- Logs non structurés
- Pas de système de queue

### 🚀 Recommandations
1. **Immédiat** : Fix race conditions + transactions
2. **Court terme** : Rate limiting + idempotency + logs structurés
3. **Moyen terme** : Architecture modulaire + BullMQ
4. **Long terme** : Analytics + monitoring avancé

---

**Audit réalisé le 2026-04-11 par Cascade AI Assistant**
