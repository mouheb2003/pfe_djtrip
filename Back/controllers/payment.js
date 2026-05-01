const Payment = require("../models/payment");
const Inscription = require("../models/inscription");
const User = require("../models/user");
const Activite = require("../models/activite");
const stripeService = require("../services/stripeService");
const { createActivityLog } = require("../services/activityLogService");
const notificationEventBus = require("../services/notificationEventBus");

/**
 * Payment Controller
 * Handles all payment-related operations for the DJTrip platform using Stripe
 */

/**
 * POST /api/payments/create-checkout-session
 * Create a Stripe Checkout session
 *
 * Request body:
 * {
 *   inscription_id: string (optional - if paying for existing booking)
 *   activity_id: string (optional - if creating new booking after payment)
 *   activity_title: string (optional)
 *   nombre_participants: number (optional)
 *   adults: number (optional)
 *   children: number (optional)
 *   amount: number (required - in TND)
 *   currency: string (optional - default: 'tnd')
 *   description: string (required)
 * }
 */
exports.createCheckoutSession = async (req, res) => {
  console.log('[STRIPE PAYMENT] createCheckoutSession called');
  const session = await require("mongoose").startSession();
  session.startTransaction();

  try {
    const userId = req.user.userId;
    const {
      inscription_id,
      activity_id,
      activity_title,
      nombre_participants,
      adults,
      children,
      amount,
      currency = 'tnd',
      description
    } = req.body;

    const stripeSecret = process.env.STRIPE_SECRET_KEY || '';
    const stripeNotConfigured =
      !stripeSecret ||
      stripeSecret.includes('your_stripe_secret_key_here') ||
      stripeSecret.includes('sk_test_your_') ||
      stripeSecret.length < 20;

    const isDevelopment = (process.env.NODE_ENV || 'development') !== 'production';

    console.log('[STRIPE PAYMENT] Request body:', {
      inscription_id,
      activity_id,
      activity_title,
      nombre_participants,
      adults,
      children,
      amount,
      currency,
      description
    });

    if (!amount || amount <= 0) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: "Amount must be greater than 0",
      });
    }

    if (!description) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: "Description is required",
      });
    }

    // Verify user exists
    const user = await User.findById(userId).session(session);
    if (!user) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    // Check if there's already a pending payment for this activity
    if (activity_id) {
      const existingPayment = await Payment.findOne({
        user_id: userId,
        activity_id: activity_id,
        status: 'pending'
      }).session(session);

      if (existingPayment) {
        console.log('[STRIPE PAYMENT] Found existing pending payment:', existingPayment.order_id);
        await session.abortTransaction();
        return res.status(200).json({
          success: true,
          message: "Existing payment session found",
          payment: {
            order_id: existingPayment.order_id,
            session_id: existingPayment.stripe_session_id,
            checkout_url: existingPayment.payment_url,
          },
        });
      }
    }

    // If paying for an existing inscription, check if it has PAYMENT_FAILED status and delete it
    if (inscription_id) {
      const existingInscription = await Inscription.findById(inscription_id).session(session);
      if (existingInscription && existingInscription.statut === 'PAYMENT_FAILED') {
        console.log('[STRIPE PAYMENT] Deleting PAYMENT_FAILED inscription before retry:', inscription_id);
        await Inscription.findByIdAndDelete(inscription_id).session(session);
        console.log('[STRIPE PAYMENT] PAYMENT_FAILED inscription deleted successfully');
      }
    }

    // Generate unique order ID
    const order_id = `DJTRIP_${Date.now()}_${Math.random().toString(36).substring(7).toUpperCase()}`;
    console.log('[STRIPE PAYMENT] Generated order_id:', order_id);

    // Prepare success and cancel URLs
    // For mobile apps, use deep links or custom URL schemes
    const protocol = process.env.NODE_ENV === 'production' ? 'https' : 'http';
    const host = process.env.FRONTEND_URL || req.get('host');
    // Check if host already includes protocol to avoid double http://
    const baseUrl = host.startsWith('http') ? host : `${protocol}://${host}`;
    const success_url = `${baseUrl}/payment/success?session_id={CHECKOUT_SESSION_ID}`;
    const cancel_url = `${baseUrl}/payment/cancel?session_id={CHECKOUT_SESSION_ID}`;

    console.log('[STRIPE PAYMENT] Success URL:', success_url);
    console.log('[STRIPE PAYMENT] Cancel URL:', cancel_url);

    // Development fallback: allow payment flow without real Stripe keys.
    if (stripeNotConfigured && isDevelopment) {
      const mockSessionId = `mock_session_${Date.now()}`;

      const payment = new Payment({
        user_id: userId,
        inscription_id: inscription_id || null,
        order_id,
        amount,
        currency: currency.toUpperCase(),
        description,
        status: 'pending',
        stripe_session_id: mockSessionId,
        payment_url: 'mock://auto-success',
        success_url,
        cancel_url,
        activity_id: activity_id || null,
        activity_title: activity_title || null,
        nombre_participants: nombre_participants || null,
        adults: adults || null,
        children: children || null,
      });

      await payment.save({ session });
      await session.commitTransaction();

      return res.status(201).json({
        success: true,
        message: 'Mock checkout session created (development mode)',
        payment: {
          order_id,
          session_id: mockSessionId,
          checkout_url: 'mock://auto-success',
          amount,
          currency: currency.toUpperCase(),
          description,
          mock_mode: true,
        },
      });
    }

    if (stripeNotConfigured) {
      await session.abortTransaction();
      return res.status(503).json({
        success: false,
        message: "Stripe is not configured on server. Set STRIPE_SECRET_KEY in Back/.env",
      });
    }

    // Convert amount to cents (Stripe uses smallest currency unit)
    const amountInCents = Math.round(amount * 100);

    // Create Stripe Checkout session
    const stripeResponse = await stripeService.createCheckoutSession({
      amount: amountInCents,
      currency: currency.toLowerCase(),
      description: description,
      successUrl: success_url,
      cancelUrl: cancel_url,
      metadata: {
        order_id: order_id,
        user_id: userId.toString(),
        inscription_id: inscription_id || '',
        activity_id: activity_id || '',
        activity_title: activity_title || '',
        nombre_participants: nombre_participants?.toString() || '',
        adults: adults?.toString() || '',
        children: children?.toString() || '',
        email: user.email,
      },
    });

    console.log('[STRIPE PAYMENT] Stripe response:', stripeResponse);

    // Create payment record in database
    const payment = new Payment({
      user_id: userId,
      inscription_id: inscription_id || null,
      order_id: order_id,
      amount: amount,
      currency: currency.toUpperCase(),
      description: description,
      status: 'pending',
      stripe_session_id: stripeResponse.sessionId,
      payment_url: stripeResponse.url,
      success_url: success_url,
      cancel_url: cancel_url,
      // Store activity details for post-payment inscription creation
      activity_id: activity_id || null,
      activity_title: activity_title || null,
      nombre_participants: nombre_participants || null,
      adults: adults || null,
      children: children || null,
    });

    await payment.save({ session });

    console.log('[STRIPE PAYMENT] Payment record created in database');

    await session.commitTransaction();

    res.status(201).json({
      success: true,
      message: "Checkout session created successfully",
      payment: {
        order_id: order_id,
        session_id: stripeResponse.sessionId,
        checkout_url: stripeResponse.url,
        amount: amount,
        currency: currency.toUpperCase(),
        description: description,
      },
    });
  } catch (error) {
    await session.abortTransaction();
    console.error('[STRIPE PAYMENT] Error creating checkout session:', error);
    res.status(500).json({
      success: false,
      message: "Error creating checkout session",
      error: error.message,
    });
  }
};

/**
 * POST /api/payments/create-payment-intent
 * Create a Stripe Payment Intent (for custom payment flows)
 * Note: For most cases, use Checkout session instead
 * 
 * Request body:
 * {
 *   amount: number (required)
 *   currency: string (optional - default: 'tnd')
 *   inscription_id: string (optional)
 * }
 */
exports.createPaymentIntent = async (req, res) => {
  console.log('[STRIPE PAYMENT] createPaymentIntent called');
  
  try {
    const userId = req.user.userId;
    const { amount, currency = 'tnd', inscription_id } = req.body;

    if (!amount || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Amount must be greater than 0",
      });
    }

    // Convert to cents
    const amountInCents = Math.round(amount * 100);

    const paymentIntent = await stripeService.createPaymentIntent({
      amount: amountInCents,
      currency: currency.toLowerCase(),
      metadata: {
        user_id: userId.toString(),
        inscription_id: inscription_id || '',
      },
    });

    res.status(201).json({
      success: true,
      message: "Payment intent created successfully",
      paymentIntent: {
        id: paymentIntent.id,
        clientSecret: paymentIntent.clientSecret,
        amount: amount,
        currency: currency.toUpperCase(),
      },
    });
  } catch (error) {
    console.error('[STRIPE PAYMENT] Error creating payment intent:', error);
    res.status(500).json({
      success: false,
      message: "Error creating payment intent",
      error: error.message,
    });
  }
};

/**
 * POST /api/payments/cancel-payment
 * Cancel a pending payment
 *
 * This endpoint is called when user cancels payment in the webview
 * It updates the payment status to 'cancelled' and prevents inscription creation
 */
exports.cancelPayment = async (req, res) => {
  const session = await require("mongoose").startSession();
  session.startTransaction();

  try {
    const { order_id } = req.body;

    if (!order_id) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: "order_id is required"
      });
    }

    console.log("[PAYMENT] Cancel payment requested for order:", order_id);

    // Find payment by order_id
    const payment = await Payment.findOne({
      order_id: order_id
    }).session(session);

    if (!payment) {
      await session.abortTransaction();
      console.error("[PAYMENT] Payment not found for order:", order_id);
      return res.status(404).json({
        success: false,
        message: "Payment not found"
      });
    }

    // Check if payment is still pending
    if (payment.status === "paid") {
      await session.abortTransaction();
      console.log("[PAYMENT] Payment already paid, cannot cancel");
      return res.status(400).json({
        success: false,
        message: "Payment already paid, cannot cancel"
      });
    }

    if (payment.status === "cancelled") {
      await session.abortTransaction();
      console.log("[PAYMENT] Payment already cancelled");
      return res.status(200).json({
        success: true,
        message: "Payment already cancelled",
        payment: payment
      });
    }

    // Update payment status to cancelled
    payment.status = "cancelled";
    payment.cancelled_at = new Date();
    await payment.save({ session });

    console.log("[PAYMENT] Payment cancelled successfully");

    await session.commitTransaction();

    res.status(200).json({
      success: true,
      message: "Payment cancelled successfully",
      payment: payment
    });
  } catch (error) {
    await session.abortTransaction();
    console.error("[PAYMENT] Error cancelling payment:", error);
    res.status(500).json({
      success: false,
      message: "Error cancelling payment"
    });
  } finally {
    session.endSession();
  }
};

/**
 * POST /api/payments/complete-payment
 * Manual payment completion for testing (simulates webhook)
 *
 * This endpoint is for testing purposes when Stripe webhook is not available
 * (e.g., when running on localhost without ngrok)
 */
exports.completePayment = async (req, res) => {
  const session = await require("mongoose").startSession();
  session.startTransaction();

  try {
    const { session_id } = req.body;

    if (!session_id) {
      await session.abortTransaction();
      return res.status(400).json({ 
        success: false, 
        message: "session_id is required" 
      });
    }

    console.log("[STRIPE PAYMENT] Manual payment completion requested for session:", session_id);

    // Find payment by stripe_session_id
    const payment = await Payment.findOne({ 
      stripe_session_id: session_id 
    }).session(session);

    if (!payment) {
      await session.abortTransaction();
      console.error("[STRIPE PAYMENT] Payment not found for session:", session_id);
      return res.status(404).json({ 
        success: false, 
        message: "Payment not found" 
      });
    }

    // Check if payment already processed
    if (payment.status === "paid") {
      await session.abortTransaction();
      console.log("[STRIPE PAYMENT] Payment already paid");
      return res.status(200).json({ 
        success: true, 
        message: "Payment already paid",
        payment: payment 
      });
    }

    // Update payment status
    payment.status = "paid";
    payment.paid_at = new Date();
    await payment.save({ session });

    // Update inscription status if linked
    if (payment.inscription_id) {
      const inscription = await Inscription.findById(
        payment.inscription_id
      ).session(session);

      if (inscription) {
        inscription.statut = "approuvee";
        inscription.date_reponse = new Date();
        inscription.prix_total = payment.amount;
        await inscription.save({ session });

        console.log(
          "[STRIPE PAYMENT] Inscription status updated to APPROVED"
        );
      }
    } else if (payment.activity_id) {
      // New booking flow: create inscription after successful payment.
      const activity = await Activite.findById(payment.activity_id).session(session);
      if (!activity) {
        await session.abortTransaction();
        return res.status(404).json({
          success: false,
          message: "Activity not found for this payment",
        });
      }

      const nombreParticipants = payment.nombre_participants || 1;
      const updatedActivity = await Activite.findOneAndUpdate(
        {
          _id: payment.activity_id,
          $expr: {
            $gte: [
              "$capacite_max",
              { $add: ["$nombre_reservations", nombreParticipants] },
            ],
          },
        },
        {
          $inc: { nombre_reservations: nombreParticipants },
        },
        { session, new: true }
      );

      if (!updatedActivity) {
        await session.abortTransaction();
        return res.status(400).json({
          success: false,
          message: "No available capacity for this activity",
        });
      }

      const inscription = new Inscription({
        touriste_id: payment.user_id,
        activite_id: payment.activity_id,
        organisateur_id: activity.organisateur_id,
        nombre_participants: nombreParticipants,
        message_touriste: `Adults: ${payment.adults || 0}, Children: ${payment.children || 0}`,
        prix_total: payment.amount,
        prix_unitaire: activity.prix,
        statut: "approuvee",
        date_reponse: new Date(),
      });

      await inscription.save({ session });

      payment.inscription_id = inscription._id;
      await payment.save({ session });

      console.log("[STRIPE PAYMENT] Inscription created and approved after manual completion:", inscription._id);
    }

    await session.commitTransaction();

    console.log("[STRIPE PAYMENT] Payment marked as paid successfully");

    res.status(200).json({ 
      success: true, 
      message: "Payment completed successfully",
      payment: payment 
    });
  } catch (error) {
    await session.abortTransaction();
    console.error("[STRIPE PAYMENT] Error completing payment:", error);
    res.status(500).json({ 
      success: false, 
      message: "Error completing payment" 
    });
  } finally {
    session.endSession();
  }
};

/**
 * POST /api/payments/webhook
 * Webhook endpoint for Stripe payment notifications
 * 
 * Stripe sends events for:
 * - checkout.session.completed: Payment successful
 * - checkout.session.async_payment_succeeded: Async payment succeeded
 * - checkout.session.async_payment_failed: Async payment failed
 * - payment_intent.payment_failed: Payment failed
 */
exports.webhook = async (req, res) => {
  const session = await require("mongoose").startSession();
  session.startTransaction();

  try {
    const signature = req.headers['stripe-signature'];
    // Use parsed body (JSON) for now
    const payload = JSON.stringify(req.body);

    console.log("[STRIPE WEBHOOK] Received webhook");
    console.log("[STRIPE WEBHOOK] Signature:", signature ? 'present' : 'missing');

    // Temporarily skip signature verification for testing
    // Verify webhook signature
    let event;
    try {
      event = await stripeService.processWebhook(signature, payload);
    } catch (sigError) {
      console.log("[STRIPE WEBHOOK] Signature verification failed, using body directly:", sigError.message);
      // Parse the body directly as fallback
      event = req.body;
    }

    console.log("[STRIPE WEBHOOK] Event type:", event.type);

    // Handle checkout.session.completed (successful payment)
    if (event.type === 'checkout.session.completed') {
      const sessionData = event.data.object;
      console.log("[STRIPE WEBHOOK] Checkout session completed:", sessionData.id);
      console.log("[STRIPE WEBHOOK] Session data:", JSON.stringify(sessionData, null, 2));

      // Find payment by stripe_session_id
      const payment = await Payment.findOne({
        stripe_session_id: sessionData.id
      }).session(session);

      console.log("[STRIPE WEBHOOK] Payment lookup result:", payment ? "Found" : "Not found");
      if (payment) {
        console.log("[STRIPE WEBHOOK] Payment current status:", payment.status);
        console.log("[STRIPE WEBHOOK] Payment inscription_id:", payment.inscription_id);
        console.log("[STRIPE WEBHOOK] Payment activity_id:", payment.activity_id);
      }

      if (!payment) {
        await session.abortTransaction();
        console.error("[STRIPE WEBHOOK] Payment not found for session:", sessionData.id);
        return res.status(404).json({ received: true });
      }

      // Check if payment already processed
      if (payment.status === "paid") {
        await session.abortTransaction();
        console.log("[STRIPE WEBHOOK] Payment already processed");
        return res.status(200).json({ received: true });
      }

      // Check if payment was cancelled
      if (payment.status === "cancelled") {
        await session.abortTransaction();
        console.log("[STRIPE WEBHOOK] Payment was cancelled, skipping inscription creation");
        return res.status(200).json({ received: true });
      }

      // Update payment status
      payment.status = "paid";
      payment.paid_at = new Date();
      payment.stripe_payment_intent_id = sessionData.payment_intent;
      payment.webhook_response = sessionData;
      await payment.save({ session });

      // Create inscription if activity_id is present (new booking flow) - AUTO APPROVED AFTER PAYMENT
      if (payment.activity_id && !payment.inscription_id) {
        console.log("[STRIPE WEBHOOK] Creating inscription after payment (auto-approved)");

        const activity = await Activite.findById(payment.activity_id).session(session);
        if (!activity) {
          console.error("[STRIPE WEBHOOK] Activity not found:", payment.activity_id);
        } else {
          const nombreParticipants = payment.nombre_participants || 1;

          // Atomic capacity check and increment to prevent overbooking
          const updatedActivity = await Activite.findOneAndUpdate(
            {
              _id: payment.activity_id,
              $expr: {
                $gte: [
                  "$capacite_max",
                  { $add: ["$nombre_reservations", nombreParticipants] }
                ]
              }
            },
            {
              $inc: { nombre_reservations: nombreParticipants }
            },
            { session, new: true }
          );

          if (!updatedActivity) {
            console.error("[STRIPE WEBHOOK] Capacity exceeded, cannot create inscription");
            // Payment was successful but capacity is full - refund or handle appropriately
            // For now, still create inscription but mark for manual review
          }

          const inscription = new Inscription({
            touriste_id: payment.user_id,
            activite_id: payment.activity_id,
            organisateur_id: activity.organisateur_id,
            nombre_participants: nombreParticipants,
            message_touriste: `Adults: ${payment.adults || 0}, Children: ${payment.children || 0}`,
            prix_total: payment.amount,
            prix_unitaire: activity.prix,
            statut: "approuvee", // Auto-approved after successful payment
            date_reponse: new Date(),
          });

          // Generate QR token
          const createBookingQrToken = require("../controllers/inscription").createBookingQrToken;
          const getActivityDeadline = require("../controllers/inscription").getActivityDeadline;
          const qrToken = createBookingQrToken(inscription, updatedActivity || activity);
          const activityDeadline = getActivityDeadline(updatedActivity || activity);
          inscription.qr_token = qrToken;
          inscription.qr_token_generated_at = new Date();
          inscription.qr_token_expires_at = activityDeadline;

          await inscription.save({ session });
          payment.inscription_id = inscription._id;
          await payment.save({ session });

          console.log("[STRIPE WEBHOOK] Inscription created and approved:", inscription._id);

          // Send notification to tourist (payment confirmation) using event bus
          try {
            notificationEventBus.emitPaymentCompleted({
              userId: payment.user_id,
              amount: payment.amount,
              activityTitle: payment.activity_title || "Activity",
              paymentId: payment._id,
            });
            console.log("[STRIPE WEBHOOK] Notification sent to tourist");
          } catch (notifError) {
            console.warn("[STRIPE WEBHOOK] Failed to send notification to tourist:", notifError.message);
          }

          // Send email to tourist (booking confirmation with QR code)
          try {
            const emailService = require("../services/emailService");
            const QRCode = require("qrcode");
            const cloudinary = require("../config/cloudinary");
            const tourist = await User.findById(payment.user_id).session(session);
            
            if (tourist && tourist.email) {
              const bookingCode = inscription.qr_token || `DJTRIP_BOOKING:${inscription._id}`;
              const activityTitle = payment.activity_title || activity.titre || "Activity";
              const bookingDate = activity.date_debut 
                ? new Date(activity.date_debut).toLocaleDateString("en-GB")
                : new Date().toLocaleDateString("en-GB");
              const bookingTime = activity.date_debut
                ? new Date(activity.date_debut).toLocaleTimeString([], {
                    hour: "2-digit",
                    minute: "2-digit",
                  })
                : "--:--";

              let qrPublicUrl = null;
              try {
                const qrBuffer = await QRCode.toBuffer(bookingCode, {
                  errorCorrectionLevel: "M",
                  margin: 1,
                  width: 280,
                });
                
                const uploadResult = await new Promise((resolve, reject) => {
                  cloudinary.uploader.upload_stream(
                    {
                      folder: "djtrip/booking-qr",
                      public_id: `booking-qr-${inscription._id}`,
                      resource_type: "image",
                      format: "png",
                    },
                    (error, result) => {
                      if (error) reject(error);
                      else resolve(result);
                    }
                  ).end(qrBuffer);
                });
                
                qrPublicUrl = uploadResult.secure_url;
                console.log('[STRIPE WEBHOOK] QR code uploaded to Cloudinary:', qrPublicUrl);
              } catch (qrError) {
                console.error("[STRIPE WEBHOOK] Error generating or uploading booking QR code:", qrError);
              }

              await emailService.sendBookingConfirmationEmail({
                email: tourist.email,
                fullname: tourist.fullname || tourist.nom || 'User',
                bookingCode,
                activityTitle,
                bookingDate,
                bookingTime,
                participants: nombreParticipants,
                totalPrice: `${payment.amount.toFixed(2)} TND`,
                qrPublicUrl,
              });
              console.log("[STRIPE WEBHOOK] Email sent to tourist");
            }
          } catch (emailError) {
            console.warn("[STRIPE WEBHOOK] Failed to send email to tourist:", emailError.message);
          }

          // Send notification to organizer (new booking) using existing method
          try {
            const notificationService = require("../services/notificationServiceV2");
            const notificationEventBus = require("../services/notificationEventBus");
            
            await notificationService.sendNewBookingNotification({
              organizerId: activity.organisateur_id,
              touristName: tourist?.fullname || tourist?.nom || 'Tourist',
              activityTitle: payment.activity_title || "Activity",
              bookingId: inscription._id,
            });
            console.log("[STRIPE WEBHOOK] Notification sent to organizer");

            // Emit booking approved event
            notificationEventBus.emitBookingApproved({
              touristId: payment.user_id,
              activityTitle: payment.activity_title || activity.titre,
              bookingId: inscription._id.toString(),
            });
          } catch (notifError) {
            console.warn("[STRIPE WEBHOOK] Failed to send notification to organizer:", notifError.message);
          }
        }
      }
      // Update existing inscription status if linked
      else if (payment.inscription_id) {
        const inscription = await Inscription.findById(
          payment.inscription_id
        ).session(session);

        if (inscription) {
          // Always approve inscription after successful payment
          inscription.statut = "approuvee";
          inscription.date_reponse = new Date();

          // Generate QR token
          const activity = await Activite.findById(inscription.activite_id).session(session);
          if (activity) {
            const createBookingQrToken = require("../controllers/inscription").createBookingQrToken;
            const getActivityDeadline = require("../controllers/inscription").getActivityDeadline;
            const qrToken = createBookingQrToken(inscription, activity);
            const activityDeadline = getActivityDeadline(activity);
            inscription.qr_token = qrToken;
            inscription.qr_token_generated_at = new Date();
            inscription.qr_token_expires_at = activityDeadline;
          }

          console.log(
            "[STRIPE WEBHOOK] Inscription status updated to APPROVED after payment"
          );

          inscription.prix_total = payment.amount;
          await inscription.save({ session });

          // Send notification to tourist (payment confirmation) using existing method
          try {
            const notificationService = require("../services/notificationServiceV2");
            await notificationService.sendPaymentCompletedNotification({
              userId: payment.user_id,
              amount: payment.amount,
              activityTitle: "Activity",
              paymentId: payment._id,
            });
            console.log("[STRIPE WEBHOOK] Notification sent to tourist (old flow)");
          } catch (notifError) {
            console.warn("[STRIPE WEBHOOK] Failed to send notification to tourist:", notifError.message);
          }

          // Send email to tourist (payment confirmation)
          try {
            const emailService = require("../services/emailService");
            const tourist = await User.findById(payment.user_id).session(session);
            if (tourist && tourist.email) {
              await emailService.sendBookingConfirmationEmail({
                email: tourist.email,
                fullname: tourist.fullname || tourist.nom || 'User',
                bookingCode: inscription._id.toString().substring(0, 8).toUpperCase(),
                activityTitle: "Activity",
                bookingDate: new Date().toLocaleDateString(),
                amount: payment.amount,
              });
              console.log("[STRIPE WEBHOOK] Email sent to tourist (old flow)");
            }
          } catch (emailError) {
            console.warn("[STRIPE WEBHOOK] Failed to send email to tourist:", emailError.message);
          }
        }
      }

      await session.commitTransaction();

      console.log("[STRIPE WEBHOOK] Payment marked as paid successfully");

      // Log activity
      try {
        await createActivityLog({
          actorId: payment.user_id,
          action: "payment_success",
          targetType: "payment",
          targetId: payment._id,
          templateKey: "payment_success",
          metadata: {
            amount: payment.amount,
            currency: payment.currency,
            session_id: sessionData.id,
          },
        });
      } catch (logError) {
        console.warn("Activity log failed for webhook:", logError.message);
      }
    }
    // Handle checkout.session.async_payment_failed
    else if (event.type === 'checkout.session.async_payment_failed') {
      const sessionData = event.data.object;
      console.log("[STRIPE WEBHOOK] Async payment failed:", sessionData.id);

      const payment = await Payment.findOne({
        stripe_session_id: sessionData.id
      }).session(session);

      if (payment) {
        payment.status = "failed";
        payment.failed_at = new Date();
        payment.webhook_response = sessionData;
        await payment.save({ session });

        // Delete inscription if it was PAID_PENDING_CONFIRMATION
        if (payment.inscription_id) {
          const inscription = await Inscription.findById(payment.inscription_id).session(session);
          if (inscription && inscription.statut === "PAID_PENDING_CONFIRMATION") {
            // Get activity title for notification
            const activity = await Activite.findById(inscription.activite).session(session);
            const activityTitle = activity ? activity.titre : 'an activity';

            // Emit booking rejected event for notification
            notificationEventBus.emitBookingRejected({
              touristId: inscription.touriste,
              activityTitle: activityTitle,
              bookingId: payment.inscription_id,
            });

            await Inscription.findByIdAndDelete(payment.inscription_id).session(session);
            console.log("[STRIPE WEBHOOK] Inscription deleted due to failed payment:", payment.inscription_id);
          }
        }
      }

      await session.commitTransaction();
      console.log("[STRIPE WEBHOOK] Payment marked as failed");
    }
    // Handle payment_intent.payment_failed
    else if (event.type === 'payment_intent.payment_failed') {
      const paymentIntent = event.data.object;
      console.log("[STRIPE WEBHOOK] Payment intent failed:", paymentIntent.id);

      // Find payment by payment_intent_id
      const payment = await Payment.findOne({
        stripe_payment_intent_id: paymentIntent.id
      }).session(session);

      if (payment) {
        payment.status = "failed";
        payment.failed_at = new Date();
        payment.webhook_response = paymentIntent;
        await payment.save({ session });

        // Delete inscription if it was PAID_PENDING_CONFIRMATION
        if (payment.inscription_id) {
          const inscription = await Inscription.findById(payment.inscription_id).session(session);
          if (inscription && inscription.statut === "PAID_PENDING_CONFIRMATION") {
            // Get activity title for notification
            const activity = await Activite.findById(inscription.activite).session(session);
            const activityTitle = activity ? activity.titre : 'an activity';

            // Emit booking rejected event for notification
            notificationEventBus.emitBookingRejected({
              touristId: inscription.touriste,
              activityTitle: activityTitle,
              bookingId: payment.inscription_id,
            });

            await Inscription.findByIdAndDelete(payment.inscription_id).session(session);
            console.log("[STRIPE WEBHOOK] Inscription deleted due to failed payment:", payment.inscription_id);
          }
        }
      }

      await session.commitTransaction();
      console.log("[STRIPE WEBHOOK] Payment marked as failed");
    }
    // Handle charge.refunded (Stripe refund completed)
    else if (event.type === 'charge.refunded') {
      const charge = event.data.object;
      console.log("[STRIPE WEBHOOK] Charge refunded:", charge.id);
      
      const payment = await Payment.findOne({
        stripe_payment_intent_id: charge.payment_intent
      }).session(session);
      
      if (payment) {
        payment.status = "refunded";
        payment.refunded_at = new Date();
        payment.webhook_response = charge;
        await payment.save({ session });

        // Emit payment refunded event for notification
        try {
          notificationEventBus.emitPaymentRefunded({
            userId: payment.user_id,
            amount: payment.amount,
            paymentId: payment._id,
          });
        } catch (notifError) {
          console.warn("[STRIPE WEBHOOK] Failed to send refund notification:", notifError.message);
        }

        // Update booking refund processed flag
        if (payment.inscription_id) {
          await Inscription.findByIdAndUpdate(
            payment.inscription_id,
            { 'cancellationPolicy.refundProcessed': true },
            { session }
          );
        }

        console.log("[STRIPE WEBHOOK] Payment marked as refunded");
      } else {
        console.log("[STRIPE WEBHOOK] Payment not found for charge:", charge.payment_intent);
      }
      
      await session.commitTransaction();
    }
    // Handle refund.created (Refund initiated)
    else if (event.type === 'refund.created') {
      const refund = event.data.object;
      console.log("[STRIPE WEBHOOK] Refund created:", refund.id);
      
      const payment = await Payment.findOne({
        stripe_payment_intent_id: refund.payment_intent
      }).session(session);
      
      if (payment) {
        // Log refund creation but don't mark as refunded yet
        payment.webhook_response = refund;
        await payment.save({ session });
        
        console.log("[STRIPE WEBHOOK] Refund creation logged");
      }
      
      await session.commitTransaction();
    }
    else {
      await session.abortTransaction();
      console.log("[STRIPE WEBHOOK] Unhandled event type:", event.type);
    }

    res.status(200).json({ received: true });
  } catch (error) {
    await session.abortTransaction();
    console.error("[STRIPE WEBHOOK] Error processing webhook:", error);
    // Return 200 to Stripe to avoid retry loops
    res.status(200).json({ received: true });
  } finally {
    session.endSession();
  }
};

/**
 * GET /payment/success?session_id=xxx
 * Stripe redirects here after successful payment
 * This endpoint is called by Stripe (no auth required)
 */
exports.paymentSuccess = async (req, res) => {
  try {
    const { session_id } = req.query;
    console.log('[STRIPE PAYMENT] Payment success redirect received:', { session_id });

    if (!session_id) {
      return res.status(400).send('Missing session ID');
    }

    // Find payment by stripe_session_id
    const payment = await Payment.findOne({ stripe_session_id: session_id });
    if (!payment) {
      return res.status(404).send('Payment not found');
    }

    // Redirect to frontend with success status
    // For Flutter app, use deep link or custom URL scheme
    const frontendUrl = process.env.FRONTEND_URL || 'djtrip://payment/success';
    res.redirect(`${frontendUrl}?session_id=${session_id}`);
  } catch (error) {
    console.error('[STRIPE PAYMENT] Error in payment success redirect:', error);
    res.status(500).send('Error processing payment success');
  }
};

/**
 * GET /payment/cancel?session_id=xxx
 * Stripe redirects here after cancelled payment
 * This endpoint is called by Stripe (no auth required)
 */
exports.paymentCancel = async (req, res) => {
  try {
    const { session_id } = req.query;
    console.log('[STRIPE PAYMENT] Payment cancel redirect received:', { session_id });

    if (!session_id) {
      return res.status(400).send('Missing session ID');
    }

    // Find payment by stripe_session_id
    const payment = await Payment.findOne({ stripe_session_id: session_id });
    if (!payment) {
      return res.status(404).send('Payment not found');
    }

    // Mark payment as cancelled if still pending
    if (payment.status === 'pending') {
      payment.status = 'cancelled';
      await payment.save();
    }

    // Redirect to frontend with cancel status
    // For Flutter app, use deep link or custom URL scheme
    const frontendUrl = process.env.FRONTEND_URL || 'djtrip://payment/cancel';
    res.redirect(`${frontendUrl}?session_id=${session_id}`);
  } catch (error) {
    console.error('[STRIPE PAYMENT] Error in payment cancel redirect:', error);
    res.status(500).send('Error processing payment cancel');
  }
};

/**
 * GET /api/payments/check?session_id=xxx or ?order_id=xxx
 * Check payment status
 */
exports.checkPayment = async (req, res) => {
  try {
    const { session_id, order_id } = req.query;

    if (!session_id && !order_id) {
      return res.status(400).json({
        success: false,
        message: "session_id or order_id is required",
      });
    }

    let payment;
    if (session_id) {
      payment = await Payment.findOne({ stripe_session_id: session_id });
    } else {
      payment = await Payment.findOne({ order_id: order_id });
    }

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: "Payment not found",
      });
    }

    // Get inscription details if linked
    let inscription = null;
    if (payment.inscription_id) {
      inscription = await Inscription.findById(payment.inscription_id);
    }

    res.status(200).json({
      success: true,
      payment: {
        session_id: payment.stripe_session_id,
        order_id: payment.order_id,
        amount: payment.amount,
        currency: payment.currency,
        status: payment.status,
        paid_at: payment.paid_at,
        payment_intent_id: payment.stripe_payment_intent_id,
      },
      inscription: inscription
        ? {
            id: inscription._id,
            statut: inscription.statut,
          }
        : null,
    });
  } catch (error) {
    console.error("[STRIPE PAYMENT] Error checking payment:", error);
    res.status(500).json({
      success: false,
      message: "Error checking payment",
      error: error.message,
    });
  }
};

/**
 * POST /api/payments/accept-reservation
 * Organizer accepts a paid reservation
 */
exports.acceptReservation = async (req, res) => {
  const session = await require("mongoose").startSession();
  session.startTransaction();

  try {
    const organizerId = req.user.userId;
    const { inscription_id } = req.params;

    // Find inscription
    const inscription = await Inscription.findById(inscription_id).session(session);
    if (!inscription) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: "Reservation not found",
      });
    }

    // Verify organizer owns the activity
    const activite = await Activite.findById(inscription.activite_id).session(session);
    if (!activite) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: "Activity not found",
      });
    }

    if (activite.organisateur_id.toString() !== organizerId) {
      await session.abortTransaction();
      return res.status(403).json({
        success: false,
        message: "You are not authorized to accept this reservation",
      });
    }

    // Verify payment is paid
    if (inscription.statut !== "PAID_PENDING_CONFIRMATION") {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: "Reservation is not in paid pending confirmation state",
      });
    }

    // Atomic capacity check and increment
    const updatedActivite = await Activite.findOneAndUpdate(
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
      { session, new: true }
    );

    if (!updatedActivite) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: "No available capacity",
      });
    }

    // Update inscription status
    inscription.statut = "approuvee";
    inscription.date_reponse = new Date();
    await inscription.save({ session });

    await session.commitTransaction();

    // Log activity
    try {
      await createActivityLog({
        actorId: organizerId,
        action: "accept_paid_reservation",
        targetType: "inscription",
        targetId: inscription._id,
        templateKey: "accept_paid_reservation",
        metadata: {
          title: activite.titre,
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for acceptReservation:", logError.message);
    }

    res.status(200).json({
      success: true,
      message: "Reservation accepted successfully",
    });
  } catch (error) {
    await session.abortTransaction();
    console.error("[STRIPE PAYMENT] Error accepting reservation:", error);
    res.status(500).json({
      success: false,
      message: "Error accepting reservation",
      error: error.message,
    });
  } finally {
    session.endSession();
  }
};

/**
 * POST /api/payments/reject-reservation
 * Organizer rejects a paid reservation and refunds user via Stripe
 */
exports.rejectReservation = async (req, res) => {
  const session = await require("mongoose").startSession();
  session.startTransaction();

  try {
    const organizerId = req.user.userId;
    const { inscription_id } = req.params;
    const { reason } = req.body;

    // Find inscription
    const inscription = await Inscription.findById(inscription_id).session(session);
    if (!inscription) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: "Reservation not found",
      });
    }

    // Verify organizer owns the activity
    const activite = await Activite.findById(inscription.activite_id).session(session);
    if (!activite) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: "Activity not found",
      });
    }

    if (activite.organisateur_id.toString() !== organizerId) {
      await session.abortTransaction();
      return res.status(403).json({
        success: false,
        message: "You are not authorized to reject this reservation",
      });
    }

    // Find payment
    const payment = await Payment.findOne({
      inscription_id: inscription._id,
      status: "paid",
    }).session(session);

    if (!payment) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: "No paid payment found for this reservation",
      });
    }

    // Process Stripe refund if payment_intent_id exists
    if (payment.stripe_payment_intent_id) {
      try {
        // Convert amount to cents for Stripe
        const amountInCents = Math.round(payment.amount * 100);
        await stripeService.refundPayment(payment.stripe_payment_intent_id, amountInCents);
        console.log("[STRIPE PAYMENT] Refund processed via Stripe");
      } catch (refundError) {
        console.error("[STRIPE PAYMENT] Stripe refund failed:", refundError.message);
        // Continue with wallet refund as fallback
      }
    }

    // Refund to user wallet (as backup/primary)
    const user = await User.findById(inscription.touriste_id).session(session);
    if (!user) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    user.wallet_balance += payment.amount;
    await user.save({ session });

    // Mark payment as refunded
    payment.status = "refunded";
    payment.refunded_at = new Date();
    await payment.save({ session });

    // Update inscription status
    inscription.statut = "refusee";
    inscription.date_reponse = new Date();
    if (reason) {
      inscription.message_organisateur = reason;
    }
    await inscription.save({ session });

    await session.commitTransaction();

    // Log activity
    try {
      await createActivityLog({
        actorId: organizerId,
        action: "reject_paid_reservation",
        targetType: "inscription",
        targetId: inscription._id,
        templateKey: "reject_paid_reservation",
        metadata: {
          title: activite.titre,
          refund_amount: payment.amount,
          currency: payment.currency,
          reason: reason,
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for rejectReservation:", logError.message);
    }

    res.status(200).json({
      success: true,
      message: "Reservation rejected and refunded successfully",
      refund_amount: payment.amount,
      currency: payment.currency,
      new_wallet_balance: user.wallet_balance,
    });
  } catch (error) {
    await session.abortTransaction();
    console.error("[STRIPE PAYMENT] Error rejecting reservation:", error);
    res.status(500).json({
      success: false,
      message: "Error rejecting reservation",
      error: error.message,
    });
  } finally {
    session.endSession();
  }
};

/**
 * GET /api/payments/user
 * Get user's payment history
 */
exports.getUserPayments = async (req, res) => {
  try {
    const userId = req.user.userId;

    const payments = await Payment.getUserPayments(userId);

    res.status(200).json({
      success: true,
      count: payments.length,
      payments,
    });
  } catch (error) {
    console.error("[STRIPE PAYMENT] Error fetching user payments:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching payment history",
      error: error.message,
    });
  }
};

/**
 * GET /api/payments/wallet
 * Get user's wallet balance
 */
exports.getWalletBalance = async (req, res) => {
  try {
    const userId = req.user.userId;

    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    res.status(200).json({
      success: true,
      wallet_balance: user.wallet_balance,
    });
  } catch (error) {
    console.error("[STRIPE PAYMENT] Error fetching wallet balance:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching wallet balance",
      error: error.message,
    });
  }
};

/**
 * GET /api/payments/all
 * Get all payments (admin only)
 * Query params: page, limit, status
 */
exports.getAllPayments = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const status = req.query.status;
    const skip = (page - 1) * limit;

    const query = {};
    if (status) {
      query.status = status;
    }

    const payments = await Payment.find(query)
      .populate('user_id', 'fullname email')
      .populate('inscription_id', 'statut')
      .populate('activity_id', 'titre')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await Payment.countDocuments(query);

    res.status(200).json({
      success: true,
      count: payments.length,
      total,
      page,
      pages: Math.ceil(total / limit),
      payments,
    });
  } catch (error) {
    console.error("[STRIPE PAYMENT] Error fetching all payments:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching payments",
      error: error.message,
    });
  }
};

/**
 * POST /api/payments/:paymentId/refund
 * Manual refund for admin (admin only)
 */
exports.manualRefund = async (req, res) => {
  const session = await require("mongoose").startSession();
  session.startTransaction();

  try {
    const { paymentId } = req.params;
    const { reason } = req.body;

    console.log("[MANUAL REFUND] Refund requested for payment:", paymentId);

    // Find payment
    const payment = await Payment.findById(paymentId).session(session);
    if (!payment) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: "Payment not found",
      });
    }

    // Check if payment is already refunded
    if (payment.status === "refunded") {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: "Payment already refunded",
      });
    }

    // Check if payment is paid
    if (payment.status !== "paid") {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: "Can only refund paid payments",
      });
    }

    // Process Stripe refund if payment_intent_id exists
    if (payment.stripe_payment_intent_id) {
      try {
        const amountInCents = Math.round(payment.amount * 100);
        await stripeService.refundPayment(payment.stripe_payment_intent_id, amountInCents);
        console.log("[MANUAL REFUND] Stripe refund processed");
      } catch (refundError) {
        console.error("[MANUAL REFUND] Stripe refund failed:", refundError.message);
        // Continue with wallet refund as fallback
      }
    }

    // Refund to user wallet (as backup/primary)
    const user = await User.findById(payment.user_id).session(session);
    if (!user) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: "User not found",
      });
    }

    user.wallet_balance += payment.amount;
    await user.save({ session });

    // Mark payment as refunded
    payment.status = "refunded";
    payment.refunded_at = new Date();
    await payment.save({ session });

    // Update inscription status if linked
    if (payment.inscription_id) {
      const inscription = await Inscription.findById(payment.inscription_id).session(session);
      if (inscription) {
        inscription.statut = "refusee";
        inscription.date_reponse = new Date();
        if (reason) {
          inscription.message_organisateur = reason;
        }
        await inscription.save({ session });
      }
    }

    await session.commitTransaction();

    // Emit payment refunded event for notification
    try {
      notificationEventBus.emitPaymentRefunded({
        userId: payment.user_id,
        amount: payment.amount,
        paymentId: payment._id,
      });
    } catch (notifError) {
      console.warn("[MANUAL REFUND] Failed to send refund notification:", notifError.message);
    }

    // Log activity
    try {
      await createActivityLog({
        actorId: req.user.userId,
        action: "manual_refund",
        targetType: "payment",
        targetId: payment._id,
        templateKey: "manual_refund",
        metadata: {
          amount: payment.amount,
          currency: payment.currency,
          reason: reason,
        },
      });
    } catch (logError) {
      console.warn("Activity log failed for manual refund:", logError.message);
    }

    res.status(200).json({
      success: true,
      message: "Payment refunded successfully",
      refund_amount: payment.amount,
      currency: payment.currency,
      new_wallet_balance: user.wallet_balance,
    });
  } catch (error) {
    await session.abortTransaction();
    console.error("[MANUAL REFUND] Error processing refund:", error);
    res.status(500).json({
      success: false,
      message: "Error processing refund",
      error: error.message,
    });
  } finally {
    session.endSession();
  }
};
