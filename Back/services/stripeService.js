const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

/**
 * Stripe Service
 * Handles all interactions with Stripe payment gateway
 * 
 * Documentation: https://stripe.com/docs/api
 */

/**
 * Create a Stripe Checkout session
 * @param {Object} sessionData - Session configuration
 * @param {number} sessionData.amount - Amount in smallest currency unit (cents for USD/EUR)
 * @param {string} sessionData.currency - Currency code (usd, eur, etc.)
 * @param {string} sessionData.description - Product description
 * @param {string} sessionData.successUrl - URL to redirect after successful payment
 * @param {string} sessionData.cancelUrl - URL to redirect after cancelled payment
 * @param {Object} sessionData.metadata - Metadata to attach to session (userId, bookingId, etc.)
 * @returns {Promise<Object>} Checkout session with URL
 */
async function createCheckoutSession(sessionData) {
  try {
    const {
      amount,
      currency = 'usd',
      description,
      successUrl,
      cancelUrl,
      metadata = {},
    } = sessionData;

    // Validation
    if (!amount || amount <= 0) {
      throw new Error('Amount must be greater than 0');
    }

    if (!description) {
      throw new Error('Description is required');
    }

    if (!successUrl || !cancelUrl) {
      throw new Error('Success and cancel URLs are required');
    }

    console.log('[STRIPE] Creating checkout session:', {
      amount,
      currency,
      description,
      metadata,
    });

    // Create Stripe Checkout session
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: currency,
            product_data: {
              name: description,
              description: description,
            },
            unit_amount: amount, // Amount in cents
          },
          quantity: 1,
        },
      ],
      mode: 'payment', // One-time payment (use 'subscription' for recurring)
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: metadata,
      customer_email: metadata.email || undefined,
      expires_at: Math.floor(Date.now() / 1000) + 1800, // Expire in 30 minutes
    });

    console.log('[STRIPE] Checkout session created:', {
      sessionId: session.id,
      url: session.url,
      metadata: session.metadata,
    });

    return {
      success: true,
      sessionId: session.id,
      url: session.url,
      metadata: session.metadata,
    };
  } catch (error) {
    console.error('[STRIPE] Error creating checkout session:', error.message);
    console.error('[STRIPE] Error type:', error.type);
    
    // Handle specific Stripe errors
    if (error.type === 'StripeCardError') {
      throw new Error(`Card error: ${error.message}`);
    } else if (error.type === 'StripeInvalidRequestError') {
      throw new Error(`Invalid request: ${error.message}`);
    } else if (error.type === 'StripeAPIError') {
      throw new Error(`Stripe API error: ${error.message}`);
    } else if (error.type === 'StripeConnectionError') {
      throw new Error('Network error: Could not connect to Stripe');
    } else if (error.type === 'StripeRateLimitError') {
      throw new Error('Too many requests to Stripe');
    }
    
    throw new Error(error.message || 'Failed to create checkout session');
  }
}

/**
 * Retrieve a checkout session by ID
 * @param {string} sessionId - Stripe session ID
 * @returns {Promise<Object>} Session details
 */
async function getCheckoutSession(sessionId) {
  try {
    console.log('[STRIPE] Retrieving checkout session:', sessionId);

    const session = await stripe.checkout.sessions.retrieve(sessionId);

    console.log('[STRIPE] Session retrieved:', {
      id: session.id,
      payment_status: session.payment_status,
      status: session.status,
      metadata: session.metadata,
    });

    return session;
  } catch (error) {
    console.error('[STRIPE] Error retrieving session:', error.message);
    throw new Error(error.message || 'Failed to retrieve checkout session');
  }
}

/**
 * Process Stripe webhook event
 * @param {string} signature - Stripe signature from headers
 * @param {string} payload - Raw webhook payload
 * @returns {Promise<Object>} Processed event data
 */
async function processWebhook(signature, payload) {
  try {
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    
    if (!webhookSecret) {
      throw new Error('STRIPE_WEBHOOK_SECRET is not configured');
    }

    console.log('[STRIPE WEBHOOK] Processing webhook...');

    // Verify webhook signature
    const event = stripe.webhooks.constructEvent(
      payload,
      signature,
      webhookSecret
    );

    console.log('[STRIPE WEBHOOK] Event verified:', {
      type: event.type,
      id: event.id,
    });

    return event;
  } catch (error) {
    console.error('[STRIPE WEBHOOK] Signature verification failed:', error.message);
    throw new Error('Invalid webhook signature');
  }
}

/**
 * Create a payment intent (alternative to Checkout for custom flows)
 * @param {Object} paymentIntentData - Payment intent configuration
 * @param {number} paymentIntentData.amount - Amount in cents
 * @param {string} paymentIntentData.currency - Currency code
 * @param {Object} paymentIntentData.metadata - Metadata
 * @returns {Promise<Object>} Payment intent with client secret
 */
async function createPaymentIntent(paymentIntentData) {
  try {
    const { amount, currency = 'usd', metadata = {} } = paymentIntentData;

    console.log('[STRIPE] Creating payment intent:', { amount, currency, metadata });

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      metadata,
      automatic_payment_methods: {
        enabled: true,
      },
    });

    console.log('[STRIPE] Payment intent created:', {
      id: paymentIntent.id,
      client_secret: paymentIntent.client_secret,
      status: paymentIntent.status,
    });

    return {
      success: true,
      id: paymentIntent.id,
      clientSecret: paymentIntent.client_secret,
      status: paymentIntent.status,
    };
  } catch (error) {
    console.error('[STRIPE] Error creating payment intent:', error.message);
    throw new Error(error.message || 'Failed to create payment intent');
  }
}

/**
 * Refund a payment
 * @param {string} paymentIntentId - Stripe payment intent ID
 * @param {number} amount - Amount to refund in cents (optional, full refund if not provided)
 * @returns {Promise<Object>} Refund details
 */
async function refundPayment(paymentIntentId, amount) {
  try {
    console.log('[STRIPE] Processing refund:', { paymentIntentId, amount });

    const refundParams = {
      payment_intent: paymentIntentId,
    };

    // Partial refund if amount specified
    if (amount) {
      refundParams.amount = amount;
    }

    const refund = await stripe.refunds.create(refundParams);

    console.log('[STRIPE] Refund processed:', {
      id: refund.id,
      amount: refund.amount,
      status: refund.status,
    });

    return {
      success: true,
      id: refund.id,
      amount: refund.amount,
      status: refund.status,
    };
  } catch (error) {
    console.error('[STRIPE] Error processing refund:', error.message);
    throw new Error(error.message || 'Failed to process refund');
  }
}

/**
 * Get payment intent details
 * @param {string} paymentIntentId - Stripe payment intent ID
 * @returns {Promise<Object>} Payment intent details
 */
async function getPaymentIntent(paymentIntentId) {
  try {
    console.log('[STRIPE] Retrieving payment intent:', paymentIntentId);

    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    console.log('[STRIPE] Payment intent retrieved:', {
      id: paymentIntent.id,
      status: paymentIntent.status,
      amount: paymentIntent.amount,
    });

    return paymentIntent;
  } catch (error) {
    console.error('[STRIPE] Error retrieving payment intent:', error.message);
    throw new Error(error.message || 'Failed to retrieve payment intent');
  }
}

module.exports = {
  createCheckoutSession,
  getCheckoutSession,
  processWebhook,
  createPaymentIntent,
  refundPayment,
  getPaymentIntent,
};
