# Stripe Payment Migration Guide

## Overview
This guide documents the migration from Flouci/Paymee to Stripe payment system for the DJTrip platform.

## Changes Made

### Backend Changes

#### 1. Removed Paymee Service
- **Deleted**: `Back/services/paymeeService.js`
- All Paymee-specific logic has been removed

#### 2. Created Stripe Service
- **Created**: `Back/services/stripeService.js`
- Functions:
  - `createCheckoutSession()` - Creates Stripe Checkout session
  - `getCheckoutSession()` - Retrieves session details
  - `processWebhook()` - Verifies and processes Stripe webhooks
  - `createPaymentIntent()` - Creates Payment Intent (for custom flows)
  - `refundPayment()` - Processes Stripe refunds
  - `getPaymentIntent()` - Retrieves Payment Intent details

#### 3. Updated Payment Controller
- **Modified**: `Back/controllers/payment.js`
- Changes:
  - `createPayment()` → `createCheckoutSession()` - Creates Stripe Checkout session
  - Added `createPaymentIntent()` - For custom payment flows
  - Updated `webhook()` - Handles Stripe webhook events
  - Updated `paymentSuccess()` - Uses session_id instead of token
  - Updated `paymentCancel()` - Uses session_id instead of token
  - Updated `checkPayment()` - Uses session_id instead of token
  - Updated `rejectReservation()` - Includes Stripe refund logic

#### 4. Updated Payment Routes
- **Modified**: `Back/routes/payment.js`
- New endpoints:
  - `POST /api/payments/create-checkout-session` - Create Stripe Checkout session
  - `POST /api/payments/create-payment-intent` - Create Payment Intent
  - `POST /api/payments/webhook` - Stripe webhook endpoint
  - `GET /payment/success` - Stripe success redirect
  - `GET /payment/cancel` - Stripe cancel redirect
  - `GET /api/payments/check?session_id=xxx` - Check payment status

#### 5. Updated Payment Model
- **Modified**: `Back/models/payment.js`
- New fields:
  - `stripe_session_id` - Stripe Checkout session ID
  - `stripe_payment_intent_id` - Stripe Payment Intent ID (for refunds)
  - `currency` - Payment currency (USD, EUR, etc.)
  - `description` - Payment description
  - `success_url` - Success redirect URL
  - `cancel_url` - Cancel redirect URL
- Removed fields:
  - `token` - Paymee token
  - `checksum_validated` - Paymee checksum validation
  - `transaction_id` - Paymee transaction ID
- Updated methods:
  - `findBySessionId()` - Find by Stripe session ID
  - Removed `markAsPaid()`, `markAsFailed()`, `markAsRefunded()`

#### 6. Updated Environment Variables
- **Modified**: `Back/.env.example`
- New variables:
  ```
  STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key_here
  STRIPE_WEBHOOK_SECRET=whsec_your_webhook_signing_secret_here
  STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
  ```
- Removed variables:
  ```
  PAYMEE_API_KEY
  PAYMEE_WEBHOOK_SECRET
  PAYMEE_MODE
  PAYMEE_WEBHOOK_URL
  ```

### Frontend Changes

#### 1. Updated Payment Service
- **Modified**: `Front/lib/services/payment_service.dart`
- Changes:
  - Added `createCheckoutSession()` - Calls Stripe Checkout endpoint
  - Added `launchStripeCheckout()` - Opens Stripe Checkout in browser
  - Updated `checkPayment()` - Uses session_id instead of token
  - Removed `processPayment()` - Not needed for Stripe Checkout
  - Updated all log messages to use `[STRIPE PAYMENT]` prefix
  - Added `url_launcher` dependency import

#### 2. Created New Payment Screen
- **Created**: `Front/lib/screens/payment/stripe_payment_screen.dart`
- Features:
  - Creates Stripe Checkout session
  - Launches Stripe Checkout in external browser
  - Polls payment status every 3 seconds
  - Handles success/failure/cancellation
  - Shows loading and error states
  - Auto-checks payment status after browser launch

#### 3. Old WebView Screen
- **Kept**: `Front/lib/screens/payment/payment_webview_screen.dart`
- **Note**: This screen is for Paymee and can be deleted after migration is confirmed

## Setup Instructions

### 1. Get Stripe API Keys

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/)
2. Sign up or log in
3. Navigate to **Developers** → **API keys**
4. Copy the following keys:
   - **Secret key** (starts with `sk_test_` for test mode)
   - **Publishable key** (starts with `pk_test_` for test mode)
   - **Webhook signing secret** (after setting up webhook)

### 2. Configure Backend Environment Variables

Add the following to your `Back/.env` file:

```env
# Stripe Payment Configuration
STRIPE_SECRET_KEY=sk_test_your_actual_secret_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_actual_webhook_secret_here
STRIPE_PUBLISHABLE_KEY=pk_test_your_actual_publishable_key_here

# For production, use live keys:
# STRIPE_SECRET_KEY=sk_live_your_live_secret_key
# STRIPE_WEBHOOK_SECRET=whsec_your_live_webhook_secret
```

### 3. Set Up Stripe Webhook

1. In Stripe Dashboard, go to **Developers** → **Webhooks**
2. Click **Add endpoint**
3. Enter your webhook URL:
   - Local development: Use ngrok or similar tunneling service
   - Example: `https://your-ngrok-url.ngrok.io/api/payments/webhook`
4. Select events to listen for:
   - `checkout.session.completed`
   - `checkout.session.async_payment_succeeded`
   - `checkout.session.async_payment_failed`
   - `payment_intent.payment_failed`
5. Copy the **Signing secret** and add it to your `.env` file as `STRIPE_WEBHOOK_SECRET`

### 4. Install Backend Dependencies

The Stripe SDK was already installed:
```bash
npm install stripe
```

### 5. Update Frontend Dependencies

Add `url_launcher` to your `Front/pubspec.yaml`:

```yaml
dependencies:
  url_launcher: ^6.3.0
```

Then run:
```bash
cd Front
flutter pub get
```

### 6. Configure Frontend URL Scheme (for Deep Links)

For mobile apps, you may want to use deep links to return to the app after payment. Update your `FRONTEND_URL` in backend `.env`:

```env
FRONTEND_URL=djtrip://payment
```

## Testing Instructions

### Test Mode vs Live Mode

Stripe provides test mode for development:
- **Test mode**: Uses test keys (`sk_test_`, `pk_test_`)
- **Live mode**: Uses live keys (`sk_live_`, `pk_live_`)

Always test in test mode before going live.

### Test Cards

Stripe provides test cards for testing different scenarios:

| Card Number | Description |
|-------------|-------------|
| 4242 4242 4242 4242 | Successful payment |
| 4000 0025 0000 3155 | Requires authentication |
| 4000 0000 0000 9995 | Insufficient funds |
| 4000 0000 0000 0002 | Card declined |
| 4000 0000 0000 0069 | Expired card |

For all test cards:
- **Expiry**: Any future date (e.g., 12/34)
- **CVC**: Any 3 digits
- **ZIP**: Any 5 digits

### Step-by-Step Testing

#### 1. Start Backend Server

```bash
cd Back
npm run dev
```

#### 2. Start Flutter App

```bash
cd Front
flutter run
```

#### 3. Test Payment Flow

1. **Create a Booking/Inscription**
   - Navigate to an activity
   - Book the activity
   - Note the inscription ID

2. **Initiate Payment**
   - Use the new `StripePaymentScreen` in your app
   - Pass required parameters:
     ```dart
     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => StripePaymentScreen(
           inscriptionId: 'your_inscription_id',
           amount: 50.00,
           currency: 'USD',
           description: 'Activity Booking Payment',
         ),
       ),
     );
     ```

3. **Complete Payment in Browser**
   - The app will open Stripe Checkout in your default browser
   - Use test card: `4242 4242 4242 4242`
   - Enter any expiry date (future), CVC (any 3 digits), and ZIP (any 5 digits)
   - Click "Pay"

4. **Verify Payment Success**
   - The app should automatically detect payment success
   - Check backend logs for webhook events
   - Verify payment status in database:
     ```bash
     # MongoDB query
     db.payments.findOne({ order_id: "DJTRIP_..." })
     ```
   - Verify inscription status updated to `PAID_PENDING_CONFIRMATION`

5. **Test Cancellation**
   - Initiate another payment
   - Close the browser window or click "Cancel" in Stripe Checkout
   - Verify payment status is `cancelled`

6. **Test Failure Scenarios**
   - Use card `4000 0000 0000 0002` (declined)
   - Verify payment status is `failed`
   - Check webhook logs for failure event

#### 4. Test Webhook

1. Use Stripe CLI or dashboard to send test webhook events:
   ```bash
   stripe trigger checkout.session.completed
   ```
2. Verify backend logs show webhook received
3. Check database for payment status update

#### 5. Test Refund Flow

1. Accept a paid reservation as organizer
2. Reject the reservation
3. Verify:
   - Stripe refund is processed
   - Wallet balance is updated
   - Payment status is `refunded`

### Debugging

#### Backend Logs

Check backend console for:
- `[STRIPE]` - Stripe service logs
- `[STRIPE PAYMENT]` - Payment controller logs
- `[STRIPE WEBHOOK]` - Webhook processing logs

#### Frontend Logs

Check Flutter console for:
- `[STRIPE PAYMENT SERVICE]` - Payment service logs
- `[STRIPE PAYMENT]` - Payment screen logs

#### Common Issues

**Issue**: Webhook signature verification fails
- **Solution**: Ensure `STRIPE_WEBHOOK_SECRET` matches the webhook signing secret in Stripe Dashboard

**Issue**: Payment status not updating
- **Solution**: Check webhook is receiving events, verify database connection

**Issue**: Browser not opening
- **Solution**: Ensure `url_launcher` is properly configured, check platform permissions

**Issue**: Payment session creation fails
- **Solution**: Verify `STRIPE_SECRET_KEY` is correct, check backend logs for error details

## Production Deployment

### 1. Switch to Live Mode

1. In Stripe Dashboard, toggle to **Live mode**
2. Get live API keys
3. Update `.env` with live keys:
   ```env
   STRIPE_SECRET_KEY=sk_live_your_live_secret_key
   STRIPE_WEBHOOK_SECRET=whsec_your_live_webhook_secret
   STRIPE_PUBLISHABLE_KEY=pk_live_your_publishable_key
   ```

### 2. Update Webhook URL

1. Delete test webhook endpoint
2. Create new webhook endpoint with production URL
3. Copy new webhook signing secret
4. Update `STRIPE_WEBHOOK_SECRET` in production environment

### 3. Update Frontend URL

Update `FRONTEND_URL` in production environment to use your actual app's deep link scheme or web URL.

### 4. Test Live Payments

Before going live:
- Make a small test payment with real card
- Verify all webhook events are received
- Check refund flow works
- Verify email notifications (if configured)

## API Reference

### POST /api/payments/create-checkout-session

Creates a Stripe Checkout session.

**Request Body:**
```json
{
  "inscription_id": "optional_inscription_id",
  "amount": 50.00,
  "currency": "USD",
  "description": "Activity Booking Payment"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Checkout session created successfully",
  "payment": {
    "order_id": "DJTRIP_1234567890_ABC123",
    "session_id": "cs_test_abc123...",
    "checkout_url": "https://checkout.stripe.com/pay/...",
    "amount": 50.00,
    "currency": "USD",
    "description": "Activity Booking Payment"
  }
}
```

### GET /api/payments/check?session_id=xxx

Checks payment status.

**Query Parameters:**
- `session_id` (optional): Stripe session ID
- `order_id` (optional): Order ID

**Response:**
```json
{
  "success": true,
  "payment": {
    "session_id": "cs_test_abc123...",
    "order_id": "DJTRIP_1234567890_ABC123",
    "amount": 50.00,
    "currency": "USD",
    "status": "paid",
    "paid_at": "2024-01-15T10:30:00.000Z",
    "payment_intent_id": "pi_abc123..."
  },
  "inscription": {
    "id": "inscription_id",
    "statut": "PAID_PENDING_CONFIRMATION"
  }
}
```

### POST /api/payments/webhook

Webhook endpoint for Stripe events.

**Headers:**
- `stripe-signature`: Stripe webhook signature

**Events Handled:**
- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.async_payment_failed`
- `payment_intent.payment_failed`

## Security Best Practices

1. **Never expose secret keys**: Only use publishable keys in frontend
2. **Verify webhook signatures**: Always verify Stripe webhook signatures
3. **Use HTTPS**: Always use HTTPS in production
4. **Validate amounts**: Always validate payment amounts before processing
5. **Idempotency**: Use Stripe idempotency keys to prevent duplicate charges
6. **Rate limiting**: Implement rate limiting on payment endpoints
7. **Logging**: Log all payment events for debugging and auditing

## Migration Checklist

- [x] Remove Paymee service file
- [x] Create Stripe service
- [x] Update payment controller
- [x] Update payment routes
- [x] Update payment model
- [x] Update .env.example
- [x] Update Flutter payment service
- [x] Create Stripe payment screen
- [ ] Get Stripe API keys
- [ ] Configure backend environment variables
- [ ] Set up Stripe webhook
- [ ] Install url_launcher dependency
- [ ] Test payment flow with test cards
- [ ] Test webhook events
- [ ] Test refund flow
- [ ] Switch to live mode (when ready)
- [ ] Update production webhook URL
- [ ] Test live payments
- [ ] Remove old Paymee WebView screen (after confirmation)

## Support

For issues with Stripe integration:
- [Stripe Documentation](https://stripe.com/docs)
- [Stripe API Reference](https://stripe.com/docs/api)
- [Stripe Checkout Guide](https://stripe.com/docs/payments/checkout)
- [Stripe Webhooks Guide](https://stripe.com/docs/webhooks)

For issues with DJTrip integration:
- Check backend logs for `[STRIPE]` prefixed messages
- Check Flutter logs for `[STRIPE PAYMENT]` prefixed messages
- Verify environment variables are set correctly
- Verify webhook endpoint is accessible
