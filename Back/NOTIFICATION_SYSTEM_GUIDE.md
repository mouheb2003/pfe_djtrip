# DJTrip Push Notification System - Complete Guide

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Folder Structure](#folder-structure)
4. [Installation & Setup](#installation--setup)
5. [Event-Driven System](#event-driven-system)
6. [Notification Types](#notification-types)
7. [User Preferences](#user-preferences)
8. [Analytics & Tracking](#analytics--tracking)
9. [Deep Linking](#deep-linking)
10. [Queue System](#queue-system)
11. [API Endpoints](#api-endpoints)
12. [Integration Guide](#integration-guide)
13. [Production Best Practices](#production-best-practices)
14. [Troubleshooting](#troubleshooting)

---

## Overview

The DJTrip push notification system is a production-ready, event-driven notification system built on Firebase Cloud Messaging (FCM) with the following features:

- **Event-Driven Architecture**: Decoupled notification logic using EventEmitter
- **Queue-Based Processing**: BullMQ + Redis for reliable, scalable notification delivery
- **Automatic Retry**: Exponential backoff for failed notifications
- **Batch Processing**: Optimized bulk sending for large audiences
- **User Preferences**: Granular control over notification types and channels
- **Analytics Tracking**: Open rate, click rate, and delivery monitoring
- **Dynamic Deep Linking**: Mobile deep links for seamless app navigation
- **Quiet Hours**: Respect user's preferred quiet periods

---

## Architecture

```
┌─────────────────┐
│   Controllers   │
│  (emit events)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Event Bus      │
│  (EventEmitter) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Notification    │
│ Worker V2       │
│ (listens to     │
│  events)        │
└────────┬────────┘
         │
         ├─────────────┐
         │             │
         ▼             ▼
┌──────────────┐  ┌──────────────┐
│  BullMQ      │  │  Database    │
│  Queue       │  │  (Notification│
│  (Redis)     │  │   Model)     │
└──────┬───────┘  └──────────────┘
       │
       ▼
┌──────────────┐
│  Firebase    │
│  FCM         │
└──────────────┘
```

---

## Folder Structure

```
Back/
├── config/
│   ├── firebase.js              # Firebase Admin SDK configuration
│   ├── redis.js                 # Redis client configuration
│   └── bullmq.js                # BullMQ queue configuration
├── models/
│   ├── notification.js          # Notification database model
│   ├── notificationPreference.js # User notification preferences
│   └── notificationAnalytics.js  # Notification analytics model
├── services/
│   ├── notificationEventBus.js  # Event emitter system
│   ├── notificationServiceV2.js # Enhanced notification service
│   ├── notificationPreferencesService.js # Preferences management
│   └── notificationAnalyticsService.js # Analytics service
├── controllers/
│   ├── notification.js          # Notification controller
│   ├── notificationPreferences.js # Preferences controller
│   └── notificationAnalytics.js # Analytics controller
├── routes/
│   ├── notification.js          # Notification routes
│   ├── notificationPreferences.js # Preferences routes
│   └── notificationAnalytics.js # Analytics routes
├── workers/
│   ├── notificationWorkerV2.js  # Event-driven notification worker
│   └── notificationWorker.js    # Legacy worker (deprecated)
└── examples/
    └── eventDrivenIntegration.js # Integration examples
```

---

## Installation & Setup

### 1. Install Dependencies

```bash
npm install bullmq ioredis firebase-admin
```

### 2. Environment Variables

Add to `.env`:

```env
# Firebase Configuration
FIREBASE_KEY_BASE64=your_base64_encoded_firebase_service_account_json_here

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0
```

### 3. Generate Firebase Service Account

1. Go to Firebase Console > Project Settings > Service Accounts
2. Click "Generate Private Key"
3. Save the JSON file
4. Encode to Base64:
   ```bash
   base64 -i firebase-service-account.json
   ```
5. Copy the output to `FIREBASE_KEY_BASE64` in `.env`

### 4. Start Redis

```bash
# Using Docker
docker run -d -p 6379:6379 redis:alpine

# Or local installation
redis-server
```

### 5. Initialize System

Add to `server.js`:

```javascript
const { initializeFirebase } = require('./services/notificationServiceV2');
const { startWorker } = require('./workers/notificationWorkerV2');
const { closeQueues } = require('./config/bullmq');

// Initialize Firebase
initializeFirebase();

// Start notification worker
startWorker();

// Graceful shutdown
process.on('SIGTERM', async () => {
  await closeQueues();
  process.exit(0);
});
```

---

## Event-Driven System

### Event Bus Usage

The notification system uses an event-driven architecture where controllers emit events instead of directly calling notification services.

#### Emit Events in Controllers

```javascript
const notificationEventBus = require('../services/notificationEventBus');

// Booking approved
notificationEventBus.emitBookingApproved({
  touristId: booking.touriste_id,
  activityTitle: booking.activite_id.titre,
  bookingId: booking._id,
});

// New message
notificationEventBus.emitMessageReceived({
  recipientId: message.recipientId,
  senderId: message.senderId,
  senderName: message.senderName,
  conversationId: message.conversationId,
  messageId: message._id,
  message: message.content,
});
```

### Available Events

| Event | Description | Payload |
|-------|-------------|---------|
| `booking.created` | New booking created | `{ organizerId, touristName, activityTitle, bookingId, touristId }` |
| `booking.approved` | Booking approved | `{ touristId, activityTitle, bookingId }` |
| `booking.rejected` | Booking rejected | `{ touristId, activityTitle, bookingId }` |
| `booking.cancelled` | Booking cancelled | `{ touristId, activityTitle, bookingId }` |
| `booking.reminder` | Booking reminder | `{ touristId, activityTitle, bookingId, activityId }` |
| `booking.checkin` | Check-in confirmed | `{ touristId, activityTitle, bookingId, activityId }` |
| `message.received` | New message | `{ recipientId, senderId, senderName, conversationId, messageId, message }` |
| `review.created` | New review | `{ organizerId, touristName, activityTitle, rating, reviewId }` |
| `review.reminder` | Review reminder | `{ touristId, activityTitle, bookingId, activityId }` |
| `follow.created` | New follower | `{ userId, followerName, followerId }` |
| `follow.accepted` | Follow accepted | `{ followerId, userName, userId }` |
| `payment.completed` | Payment completed | `{ userId, amount, activityTitle, paymentId }` |
| `payment.failed` | Payment failed | `{ userId, amount, activityTitle, paymentId }` |
| `payment.refunded` | Payment refunded | `{ userId, amount, paymentId }` |
| `activity.created` | New activity | `{ organizerId, organizerName, activityTitle, activityId, followerIds }` |
| `activity.updated` | Activity updated | `{ bookedUserIds, activityTitle, activityId }` |
| `activity.cancelled` | Activity cancelled | `{ bookedUserIds, activityTitle, activityId }` |
| `profile.updated` | Profile updated | `{ userId, userName }` |
| `profile.verified` | Profile verified | `{ userId }` |
| `appeal.created` | Appeal created | `{ userId, appealId }` |
| `appeal.resolved` | Appeal resolved | `{ userId, appealId, status }` |
| `system.announcement` | System announcement | `{ title, message, userIds, targetRole, priority, data }` |

---

## Notification Types

### Booking Notifications

```javascript
const notificationService = require('../services/notificationServiceV2');

// New booking (to organizer)
await notificationService.sendNewBookingNotification({
  organizerId: 'organizer_id',
  touristName: 'John Doe',
  activityTitle: 'Beach Party',
  bookingId: 'booking_id',
});

// Booking approved (to tourist)
await notificationService.sendBookingApprovedNotification({
  touristId: 'tourist_id',
  activityTitle: 'Beach Party',
  bookingId: 'booking_id',
});
```

### Payment Notifications

```javascript
// Payment completed
await notificationService.sendPaymentCompletedNotification({
  userId: 'user_id',
  amount: 50,
  activityTitle: 'Beach Party',
  paymentId: 'payment_id',
});

// Payment failed
await notificationService.sendPaymentFailedNotification({
  userId: 'user_id',
  amount: 50,
  activityTitle: 'Beach Party',
  paymentId: 'payment_id',
});
```

### Follow Notifications

```javascript
// New follower
await notificationService.sendNewFollowerNotification({
  userId: 'user_id',
  followerName: 'Jane Doe',
  followerId: 'follower_id',
});
```

### Activity Notifications

```javascript
// New activity (to followers)
await notificationService.sendBulkNotificationQueued({
  userIds: followerIds,
  title: 'Nouvelle activité 🎯',
  body: 'Organizer a publié "Beach Party"',
  data: {
    type: 'new_activity',
    activityId: 'activity_id',
  },
  notificationType: 'activity',
  priority: 'medium',
});
```

---

## User Preferences

### Get User Preferences

```javascript
const notificationPreferencesService = require('../services/notificationPreferencesService');

const preferences = await notificationPreferencesService.getUserPreferences(userId);
```

### Update Preferences

```javascript
// Toggle push notifications for booking
await notificationPreferencesService.togglePushNotification(userId, 'booking', true);

// Toggle email notifications for reviews
await notificationPreferencesService.toggleEmailNotification(userId, 'review', false);

// Set quiet hours
await notificationPreferencesService.setQuietHours(userId, {
  enabled: true,
  start: '22:00',
  end: '08:00',
  timezone: 'Europe/Paris',
});
```

### Preference Structure

```javascript
{
  user_id: ObjectId,
  push_enabled: true,
  email_enabled: true,
  preferences: {
    booking: { push: true, email: true },
    message: { push: true, email: false },
    review: { push: true, email: true },
    follow: { push: true, email: false },
    payment: { push: true, email: true },
    activity: { push: true, email: false },
    profile: { push: false, email: false },
    appeal: { push: true, email: true },
    system: { push: true, email: true },
  },
  quiet_hours: {
    enabled: false,
    start: '22:00',
    end: '08:00',
    timezone: 'UTC',
  },
  device_settings: {
    android: { sound: true, vibration: true, led: true },
    ios: { sound: true, badge: true, alert: true },
  }
}
```

---

## Analytics & Tracking

### Get Analytics Report

```javascript
const notificationAnalyticsService = require('../services/notificationAnalyticsService');

const report = await notificationAnalyticsService.getAnalyticsReport(
  new Date('2024-01-01'),
  new Date('2024-01-31')
);

// Returns:
{
  summaryByType: [
    {
      _id: 'booking',
      total: 1000,
      delivered: 950,
      opened: 500,
      clicked: 200,
      avg_time_to_open: 120,
      avg_time_to_click: 180
    },
    // ... more types
  ],
  overall: {
    deliveryRate: 95,
    openRate: 52.6,
    clickRate: 21.1
  }
}
```

### Track Engagement

```javascript
// Track notification open
await notificationAnalyticsService.trackOpen(analyticsId);

// Track notification click
await notificationAnalyticsService.trackClick(analyticsId, 'view_booking');
```

### Get User History

```javascript
const history = await notificationAnalyticsService.getUserHistory(userId, {
  type: 'booking',
  limit: 20,
  skip: 0,
});
```

---

## Deep Linking

The system automatically generates deep links for mobile notifications:

```javascript
// Deep link format: djtrip://screen/params
const deepLink = generateDeepLink('booking', { bookingId: '123' });
// Returns: 'djtrip://booking/123'
```

### Supported Deep Links

| Type | Deep Link Format |
|------|------------------|
| booking | `djtrip://booking/{bookingId}` |
| message | `djtrip://chat/{conversationId}` |
| activity | `djtrip://activity/{activityId}` |
| review | `djtrip://review/{reviewId}` |
| profile | `djtrip://profile/{userId}` |
| payment | `djtrip://payment/{paymentId}` |

---

## Queue System

### Queue Configuration

The system uses BullMQ with Redis for reliable job processing:

```javascript
const { addNotificationJob, getQueueStats } = require('../config/bullmq');

// Add job to queue
const job = await addNotificationJob(
  {
    type: 'single',
    payload: { userId, title, body, data, notificationType, priority },
  },
  {
    priority: 1, // 1 = urgent, 5 = normal
    delay: 0, // Delay in ms
  }
);

// Get queue statistics
const stats = await getQueueStats();
// Returns: { waiting, active, completed, failed, delayed }
```

### Retry Logic

- **Max Retries**: 3
- **Backoff**: Exponential (2s, 4s, 8s)
- **Job Removal**: After 1 hour (completed) or 24 hours (failed)

---

## API Endpoints

### Notification Preferences

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/notifications/preferences` | Get user preferences |
| PUT | `/notifications/preferences` | Update preferences |
| PUT | `/notifications/preferences/push/:type` | Toggle push for type |
| PUT | `/notifications/preferences/email/:type` | Toggle email for type |
| PUT | `/notifications/preferences/all-push` | Toggle all push |
| PUT | `/notifications/preferences/all-email` | Toggle all email |
| PUT | `/notifications/preferences/quiet-hours` | Set quiet hours |
| PUT | `/notifications/preferences/device/:device` | Update device settings |

### Notification Analytics

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/notifications/analytics/report` | Get analytics report |
| GET | `/notifications/analytics/user-history` | Get user history |
| GET | `/notifications/analytics/summary` | Get summary by type |
| POST | `/notifications/analytics/track/:analyticsId/open` | Track open |
| POST | `/notifications/analytics/track/:analyticsId/click` | Track click |

### Standard Notifications

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/notifications` | Get user notifications |
| PATCH | `/notifications/:id/read` | Mark as read |
| PATCH | `/notifications/read-all` | Mark all as read |
| GET | `/notifications/unread-count` | Get unread count |
| DELETE | `/notifications/:id` | Delete notification |

---

## Integration Guide

### Step 1: Update Existing Controllers

Replace direct notification calls with event emissions:

**Before:**
```javascript
const { sendBookingApprovedNotification } = require('../services/notificationService');
await sendBookingApprovedNotification({ touristId, activityTitle, bookingId });
```

**After:**
```javascript
const notificationEventBus = require('../services/notificationEventBus');
notificationEventBus.emitBookingApproved({ touristId, activityTitle, bookingId });
```

### Step 2: Register New Routes

Add to your main router:

```javascript
const notificationPreferencesRoutes = require('./routes/notificationPreferences');
const notificationAnalyticsRoutes = require('./routes/notificationAnalytics');

app.use('/notifications', notificationPreferencesRoutes);
app.use('/notifications', notificationAnalyticsRoutes);
```

### Step 3: Initialize Worker

Add to `server.js`:

```javascript
const { startWorker } = require('./workers/notificationWorkerV2');
startWorker();
```

### Step 4: Test Integration

```bash
# Start Redis
redis-server

# Start your server
npm start

# Test an event
curl -X POST http://localhost:3000/api/bookings/123/approve
```

---

## Production Best Practices

### 1. Environment Configuration

```env
NODE_ENV=production
FIREBASE_KEY_BASE64=<base64_encoded_key>
REDIS_HOST=redis-production.example.com
REDIS_PORT=6379
REDIS_PASSWORD=secure_password
REDIS_DB=0
```

### 2. Scaling

- **Horizontal Scaling**: Run multiple worker instances
- **Queue Partitioning**: Use separate queues for high-volume notifications
- **Rate Limiting**: Configure BullMQ limiter for burst traffic

### 3. Monitoring

- Monitor queue stats: `getQueueStats()`
- Track delivery rates via analytics
- Set up alerts for failed jobs
- Monitor Redis memory usage

### 4. Error Handling

- Invalid tokens are automatically removed
- Failed jobs retry with exponential backoff
- Worker continues even if Firebase is down
- Logs all errors for debugging

### 5. Security

- Never commit Firebase service account
- Use environment variables for secrets
- Validate all user inputs
- Implement rate limiting on API endpoints

### 6. Performance

- Use `sendBulkNotificationQueued` for >100 recipients
- Batch notifications where possible
- Use `sendBatchNotification` for very large sends (500+)
- Monitor Redis connection pool

---

## Troubleshooting

### Firebase Not Initialized

**Error**: `Firebase not initialized, skipping notification`

**Solution**:
```bash
# Check FIREBASE_KEY_BASE64 is set
echo $FIREBASE_KEY_BASE64

# Verify Base64 encoding
echo $FIREBASE_KEY_BASE64 | base64 -d | jq .
```

### Redis Connection Failed

**Error**: `Redis connection error`

**Solution**:
```bash
# Check Redis is running
redis-cli ping

# Check connection
redis-cli -h localhost -p 6379 ping
```

### Queue Not Processing

**Error**: Jobs stuck in waiting state

**Solution**:
```javascript
// Check worker is running
const stats = await getQueueStats();
console.log(stats);

// Restart worker if needed
```

### Invalid FCM Tokens

**Error**: `messaging/registration-token-not-registered`

**Solution**: Tokens are automatically removed. Ensure your app updates tokens when they change.

### Quiet Hours Not Working

**Error**: Notifications sent during quiet hours

**Solution**:
```javascript
// Check user's quiet hours settings
const preferences = await notificationPreferencesService.getUserPreferences(userId);
console.log(preferences.quiet_hours);
```

---

## Support

For issues or questions:
1. Check the logs in `logs/` directory
2. Review the troubleshooting section
3. Check BullMQ dashboard if installed
4. Verify Firebase Console for quota limits

---

## Version History

- **v2.0** - Complete refactor with event-driven architecture, BullMQ, analytics
- **v1.0** - Initial implementation with direct Firebase calls
