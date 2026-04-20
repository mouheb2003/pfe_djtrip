# Paymee Payment System - Implementation Guide

## 🎯 Overview

This guide explains the complete implementation of the Paymee payment system for the DJTrip tourism platform. The system allows users to pay for activity bookings using Paymee (Tunisian payment gateway) in sandbox mode for local development.

## 🏗️ Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  Flutter    │         │   Backend   │         │   Paymee    │
│   App       │────────▶│   (Node.js) │────────▶│   Sandbox   │
└─────────────┘         └─────────────┘         └─────────────┘
      │                        │                        │
      │                        │                        │
      │  WebView Payment       │  Webhook Notification  │
      ▼                        ▼                        ▼
   Payment Screen      ──────▶   Update DB   ◀────────  Payment Success
```

## 📁 File Structure

### Backend (Node.js)

```
Back/
├── models/
│   ├── payment.js          # Payment model with Paymee integration
│   ├── user.js             # Updated with wallet_balance field
│   └── inscription.js      # Updated with payment_id field
├── services/
│   └── paymeeService.js     # Paymee API integration service
├── controllers/
│   └── payment.js          # Payment controller with all endpoints
├── routes/
│   └── payment.js          # Payment routes
└── .env.example            # Environment variables template
```

### Frontend (Flutter)

```
Front/lib/
├── services/
│   └── payment_service.dart        # Payment API service
├── screens/payment/
│   └── payment_webview_screen.dart # WebView payment screen
└── pubspec.yaml                    # Updated with webview_flutter
```

## 🔧 Backend Implementation

### 1. Payment Model

**File**: `Back/models/payment.js`

The Payment model stores all Paymee transactions with the following fields:
- `token`: Paymee payment token (unique identifier)
- `order_id`: Our system's order ID
- `user_id`: Reference to the user
- `inscription_id`: Reference to the booking (optional)
- `amount`: Payment amount in TND
- `status`: Payment status (pending, paid, failed, cancelled, refunded)
- `payment_url`: Paymee payment URL
- `webhook_response`: Webhook data from Paymee
- `checksum_validated`: Security validation flag

### 2. User Model Update

**File**: `Back/models/user.js`

Added `wallet_balance` field for refunds:
```javascript
wallet_balance: {
  type: Number,
  default: 0,
  min: 0,
}
```

### 3. Inscription Model Update

**File**: `Back/models/inscription.js`

Added:
- `PAID_PENDING_CONFIRMATION` status for paid bookings awaiting organizer approval
- `payment_id` field to link payment to booking

### 4. Paymee Service

**File**: `Back/services/paymeeService.js`

Key functions:
- `createPayment()`: Creates payment with Paymee
- `getPaymentDetails()`: Fetches payment status
- `processWebhook()`: Validates webhook checksum
- `validateChecksum()`: MD5 checksum validation
- `generateOrderId()`: Generates unique order IDs

### 5. Payment Controller

**File**: `Back/controllers/payment.js`

Endpoints:
- `POST /api/payments/create`: Create new payment
- `POST /api/payments/webhook`: Paymee webhook (no auth required)
- `GET /api/payments/check`: Check payment status
- `POST /api/payments/:inscription_id/accept`: Accept paid reservation
- `POST /api/payments/:inscription_id/reject`: Reject and refund
- `GET /api/payments/user`: Get user payment history
- `GET /api/payments/wallet`: Get wallet balance

### 6. Payment Routes

**File**: `Back/routes/payment.js`

All payment routes registered under `/api/payments`.

## 📱 Frontend Implementation

### 1. Payment Service

**File**: `Front/lib/services/payment_service.dart`

Methods:
- `createPayment()`: Create payment via backend
- `checkPayment()`: Check payment status
- `getUserPayments()`: Get payment history
- `getWalletBalance()`: Get wallet balance
- `acceptReservation()`: Accept reservation (organizer)
- `rejectReservation()`: Reject and refund (organizer)

### 2. Payment WebView Screen

**File**: `Front/lib/screens/payment/payment_webview_screen.dart`

Features:
- Opens Paymee payment URL in WebView
- Detects payment completion via URL patterns
- Polls payment status from backend
- Shows loading indicators
- Handles errors gracefully
- Returns payment result to caller

## 🔐 Security Features

### 1. Checksum Validation

Paymee uses MD5 checksum validation:
```javascript
md5(token + payment_status + API_KEY)
```

This prevents webhook tampering and ensures requests come from Paymee.

### 2. API Key Storage

API keys are stored in backend environment variables only:
```env
PAYMEE_API_KEY=your_paymee_sandbox_api_key
PAYMEE_WEBHOOK_SECRET=your_paymee_webhook_secret
```

### 3. Transaction Safety

All critical operations use MongoDB transactions:
- Payment creation
- Reservation acceptance
- Reservation rejection with refund

### 4. Duplicate Prevention

- Checks for existing payments before creating new ones
- Prevents double payment for same booking
- Webhook deduplication via status check

## 🌐 Environment Configuration

### Backend (.env)

```env
# Paymee Payment Configuration
PAYMEE_API_KEY=your_paymee_sandbox_api_key
PAYMEE_WEBHOOK_SECRET=your_paymee_webhook_secret
PAYMEE_MODE=sandbox  # sandbox or production
PAYMEE_WEBHOOK_URL=https://your-ngrok-url.ngrok.io/api/payments/webhook

# Frontend URL for payment redirects
FRONTEND_URL=http://localhost:3000
```

### Flutter (pubspec.yaml)

```yaml
dependencies:
  webview_flutter: ^4.4.4
```

## 🧪 Local Testing with ngrok

### 1. Install ngrok

Download from: https://ngrok.com/download

### 2. Start ngrok

```bash
ngrok http 3000
```

This will give you a URL like: `https://xxxx-xxxx.ngrok.io`

### 3. Update Environment Variables

Set `PAYMEE_WEBHOOK_URL` in your `.env`:
```env
PAYMEE_WEBHOOK_URL=https://xxxx-xxxx.ngrok.io/api/payments/webhook
```

### 4. Paymee Sandbox Test Account

- **Phone**: 11111111
- **Password**: 11111111

## 📊 Payment Flow

### 1. User Books Activity

```
User ──▶ Create Booking (Inscription)
       ──▶ Status: en_attente
```

### 2. User Initiates Payment

```
User ──▶ POST /api/payments/create
       ──▶ Backend calls Paymee API
       ──▶ Returns payment_url + order_id
       ──▶ Opens WebView with payment_url
```

### 3. User Pays in WebView

```
WebView ──▶ Paymee Payment Page
        ──▶ User completes payment
        ──▶ Paymee redirects to /loader
        ──▶ WebView detects completion
        ──▶ Calls /api/payments/check
```

### 4. Paymee Webhook (Async)

```
Paymee ──▶ POST /api/payments/webhook
        ──▶ Validate checksum
        ──▶ Update payment status: paid
        ──▶ Update inscription status: PAID_PENDING_CONFIRMATION
```

### 5. Organizer Accepts

```
Organizer ──▶ POST /api/payments/:inscription_id/accept
          ──▶ Atomic capacity check + increment
          ──▶ Update inscription status: approuvee
          ──▶ Generate QR code
```

### 6. Organizer Rejects (Refund)

```
Organizer ──▶ POST /api/payments/:inscription_id/reject
          ──▶ Mark payment as refunded
          ──▶ Add amount to user wallet_balance
          ──▶ Update inscription status: refusee
```

## 🎨 UI Flow

### Payment Screen States

1. **Loading**: WebView is loading payment page
2. **Processing**: Payment completed, checking status
3. **Success**: Payment successful, booking confirmed
4. **Failed**: Payment failed
5. **Pending**: Payment still processing
6. **Error**: Network or technical error

### Booking Status Flow

```
en_attente ──▶ PAID_PENDING_CONFIRMATION ──▶ approuvee
   │                  │
   │                  └──▶ refusee (with refund)
   │
   └──▶ annulee (cancelled before payment)
```

## 🔍 Debugging

### Backend Logs

```javascript
console.log('[PAYMEE] Creating payment:', { order_id, amount });
console.log('[PAYMEE] Payment created successfully:', { token, payment_url });
console.log('[PAYMENT WEBHOOK] Received webhook:', { token, payment_status });
```

### Flutter Logs

```dart
print('[PAYMENT] Payment created successfully');
print('[PAYMENT WEBVIEW] Payment status retrieved');
print('[PAYMENT] Error creating payment: $e');
```

### Common Issues

1. **Webhook not received**: Check ngrok URL and firewall
2. **Checksum validation fails**: Verify API_KEY in .env
3. **Payment stuck pending**: Check Paymee sandbox status
4. **WebView not loading**: Ensure webview_flutter is installed

## 📊 Database Schema Updates

### Payment Collection

```javascript
{
  _id: ObjectId,
  token: String (unique),
  order_id: String (unique),
  user_id: ObjectId (ref: User),
  inscription_id: ObjectId (ref: Inscription),
  amount: Number,
  status: String (enum: pending, paid, failed, cancelled, refunded),
  payment_url: String,
  webhook_response: Object,
  checksum_validated: Boolean,
  payment_method: String,
  transaction_id: String,
  paid_at: Date,
  failed_at: Date,
  refunded_at: Date,
  createdAt: Date,
  updatedAt: Date
}
```

### User Collection (Updated)

```javascript
{
  // ... existing fields
  wallet_balance: Number (default: 0, min: 0)
}
```

### Inscription Collection (Updated)

```javascript
{
  // ... existing fields
  statut: String (enum: en_attente, approuvee, refusee, annulee, verifie, PAID_PENDING_CONFIRMATION),
  payment_id: ObjectId (ref: Payment)
}
```

## 🚀 Deployment Checklist

### Pre-Production

- [ ] Switch to Paymee production API
- [ ] Update webhook URL to production domain
- [ ] Verify SSL certificate for webhook
- [ ] Test all payment flows
- [ ] Verify refund mechanism
- [ ] Check transaction logs
- [ ] Test webhook signature validation

### Production

- [ ] Set `PAYMEE_MODE=production`
- [ ] Use production API key
- [ ] Configure production webhook URL
- [ ] Enable monitoring and alerts
- [ ] Set up payment failure notifications
- [ ] Review rate limiting
- [ ] Test with real payments (small amounts)

## 🎁 Bonus Features Implemented

### 1. Auto-Cancel After 1 Hour

Use a cron job to cancel pending payments:
```javascript
// Add to cron jobs
cron.schedule('0 * * * *', async () => {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  await Payment.updateMany(
    { 
      status: 'pending', 
      createdAt: { $lt: oneHourAgo } 
    },
    { status: 'cancelled' }
  );
});
```

### 2. Prevent Double Payment

Already implemented in controller:
```javascript
const existingPayment = await Payment.findOne({
  inscription_id,
  status: { $in: ["pending", "paid"] }
});
```

### 3. Loading States

Flutter WebView shows loading indicators during:
- Initial page load
- Payment status check
- Error recovery

### 4. Payment Event Logging

All payment events logged via `createActivityLog()`:
- Payment created
- Payment success
- Payment failed
- Reservation accepted
- Reservation rejected with refund

## 📞 Support

For Paymee API documentation:
- Sandbox: https://sandbox.paymee.tn/docs/api
- Production: https://app.paymee.tn/docs/api

## 🔄 Migration from Existing System

If you have existing bookings without payment:

```javascript
// Migration script to add payment_id to existing inscriptions
async function migrateExistingBookings() {
  const inscriptions = await Inscription.find({
    payment_id: { $exists: false },
    statut: 'approuvee'
  });
  
  for (const inscription of inscriptions) {
    // Create payment record for existing bookings
    const payment = new Payment({
      token: `LEGACY_${inscription._id}`,
      order_id: `LEGACY_${Date.now()}`,
      user_id: inscription.touriste_id,
      inscription_id: inscription._id,
      amount: inscription.prix_total,
      status: 'paid',
      payment_method: 'legacy',
      paid_at: inscription.date_reponse || inscription.createdAt,
      checksum_validated: true,
    });
    await payment.save();
    
    inscription.payment_id = payment._id;
    await inscription.save();
  }
}
```

## 📝 API Reference

### POST /api/payments/create

**Request**:
```json
{
  "inscription_id": "optional_booking_id",
  "amount": 50.0,
  "description": "Payment for activity"
}
```

**Response**:
```json
{
  "success": true,
  "payment": {
    "token": "paymee_token",
    "order_id": "DJTRIP_123456",
    "payment_url": "https://sandbox.paymee.tn/payment/xxx",
    "amount": 50.0,
    "status": "pending"
  }
}
```

### POST /api/payments/webhook

**Request** (from Paymee):
```json
{
  "token": "paymee_token",
  "payment_status": "paid",
  "checksum": "md5_hash",
  "transaction_id": "txn_123"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Webhook processed successfully"
}
```

### GET /api/payments/check

**Query Params**: `order_id` or `token`

**Response**:
```json
{
  "success": true,
  "payment": {
    "token": "paymee_token",
    "order_id": "DJTRIP_123456",
    "amount": 50.0,
    "status": "paid",
    "paid_at": "2024-01-15T10:30:00Z",
    "payment_method": "credit_card",
    "transaction_id": "txn_123"
  },
  "inscription": {
    "id": "booking_id",
    "statut": "PAID_PENDING_CONFIRMATION"
  }
}
```

## ✅ Testing Checklist

### Unit Tests

- [ ] Payment model validation
- [ ] Checksum validation logic
- [ ] Order ID generation
- [ ] Wallet balance calculations

### Integration Tests

- [ ] Create payment with Paymee
- [ ] Webhook processing
- [ ] Payment status check
- [ ] Reservation acceptance
- [ ] Reservation rejection with refund

### End-to-End Tests

- [ ] Complete booking flow
- [ ] Payment success flow
- [ ] Payment failure flow
- [ ] Refund flow
- [ ] Double payment prevention

---

**Last Updated**: January 2026
**Version**: 1.0.0
