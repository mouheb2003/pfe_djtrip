/**
 * Refund Decision Engine
 * Determines refund rules based on business logic for activity bookings
 */
class RefundDecisionEngine {
  /**
   * Decide refund based on context
   * 
   * @param {Object} context - Decision context
   * @param {string} context.user_role - "tourist" | "organizer" | "admin"
   * @param {string} context.action - "cancel" | "delete_activity" | "auto_approve_timeout" | "activity_started"
   * @param {number} context.time_before_activity_hours - Hours before activity starts (negative if already started)
   * @param {string} context.activity_status - "pending" | "approved" | "cancelled" | "started" | "completed"
   * @param {string} context.payment_status - "paid" | "pending" | "failed" | "refunded"
   * 
   * @returns {Object} Decision result
   */
  static decideRefund(context) {
    const {
      user_role,
      action,
      time_before_activity_hours,
      activity_status,
      payment_status
    } = context;

    // Rule 5: If payment status is not "paid" → NO REFUND
    if (payment_status !== 'paid') {
      return {
        refund_type: 'none',
        refund_percentage: 0,
        reason: 'Payment not completed - no refund applicable',
        stripe_action: 'no_refund'
      };
    }

    // Rule 1: If organizer deletes the activity OR activity is not approved before start time → FULL REFUND (100%)
    if (action === 'delete_activity' || (action === 'auto_approve_timeout' && time_before_activity_hours <= 0)) {
      return {
        refund_type: 'full',
        refund_percentage: 100,
        reason: 'Organizer deleted activity or approval timeout - full refund',
        stripe_action: 'refund'
      };
    }

    // Rule 2: If activity reaches start time without approval → FULL REFUND (100%)
    if (action === 'auto_approve_timeout' && activity_status !== 'approved') {
      return {
        refund_type: 'full',
        refund_percentage: 100,
        reason: 'Activity reached start time without approval - full refund',
        stripe_action: 'refund'
      };
    }

    // Rule 4: If tourist already participated or activity started → NO REFUND
    if (action === 'activity_started' || activity_status === 'started' || activity_status === 'completed' || time_before_activity_hours < 0) {
      return {
        refund_type: 'none',
        refund_percentage: 0,
        reason: 'Activity already started or tourist participated - no refund',
        stripe_action: 'no_refund'
      };
    }

    // Rule 3: If tourist cancels
    if (action === 'cancel' && user_role === 'tourist') {
      // If cancellation is more than 24 hours before activity → PARTIAL REFUND (85%)
      if (time_before_activity_hours > 24) {
        return {
          refund_type: 'partial',
          refund_percentage: 85,
          reason: 'Tourist cancelled more than 24 hours before activity - 85% refund (15% platform fee)',
          stripe_action: 'refund'
        };
      }
      
      // If cancellation is less than 24 hours before activity → 70% REFUND (30% platform fee)
      if (time_before_activity_hours <= 24 && time_before_activity_hours > 0) {
        return {
          refund_type: 'partial',
          refund_percentage: 70,
          reason: 'Tourist cancelled less than 24 hours before activity - 70% refund (30% platform fee)',
          stripe_action: 'refund'
        };
      }
    }

    // Default: No refund for unspecified scenarios
    return {
      refund_type: 'none',
      refund_percentage: 0,
      reason: 'No refund policy applies to this scenario',
      stripe_action: 'no_refund'
    };
  }

  /**
   * Process refund with Stripe integration
   * 
   * @param {string} paymentIntentId - Stripe payment intent ID
   * @param {number} refundPercentage - Percentage to refund (0-100)
   * @param {string} reason - Refund reason
   * @returns {Promise<Object>} Refund result
   */
  static async processRefund(paymentIntentId, refundPercentage, reason) {
    const stripeService = require('./stripeService');
    
    try {
      // Calculate refund amount
      const payment = await stripeService.getPaymentIntent(paymentIntentId);
      const originalAmount = payment.amount;
      const refundAmount = Math.floor((originalAmount * refundPercentage) / 100);

      // If refund percentage is 0, no refund needed
      if (refundPercentage === 0 || refundAmount === 0) {
        return {
          success: true,
          refunded: false,
          refundAmount: 0,
          message: 'No refund required (0%)'
        };
      }

      // If full refund, refund entire amount
      if (refundPercentage === 100) {
        const refund = await stripeService.refundPayment(paymentIntentId);
        return {
          success: true,
          refunded: true,
          refundAmount: refund.amount,
          refundPercentage: 100,
          message: 'Full refund processed'
        };
      }

      // Partial refund
      const refund = await stripeService.refundPayment(paymentIntentId, refundAmount);
      return {
        success: true,
        refunded: true,
        refundAmount: refund.amount,
        refundPercentage: refundPercentage,
        message: `Partial refund processed (${refundPercentage}%)`
      };
    } catch (error) {
      console.error('[REFUND ENGINE] Error processing refund:', error);
      return {
        success: false,
        refunded: false,
        error: error.message,
        message: 'Refund processing failed'
      };
    }
  }

  /**
   * Validate decision context
   * 
   * @param {Object} context - Decision context
   * @returns {Object} Validation result
   */
  static validateContext(context) {
    const required = ['user_role', 'action', 'time_before_activity_hours', 'activity_status', 'payment_status'];
    const missing = required.filter(field => context[field] === undefined || context[field] === null);
    
    if (missing.length > 0) {
      return {
        valid: false,
        missing,
        message: `Missing required fields: ${missing.join(', ')}`
      };
    }

    const validRoles = ['tourist', 'organizer', 'admin'];
    if (!validRoles.includes(context.user_role)) {
      return {
        valid: false,
        message: `Invalid user_role: ${context.user_role}. Must be one of: ${validRoles.join(', ')}`
      };
    }

    const validActions = ['cancel', 'delete_activity', 'auto_approve_timeout', 'activity_started'];
    if (!validActions.includes(context.action)) {
      return {
        valid: false,
        message: `Invalid action: ${context.action}. Must be one of: ${validActions.join(', ')}`
      };
    }

    if (typeof context.time_before_activity_hours !== 'number') {
      return {
        valid: false,
        message: 'time_before_activity_hours must be a number'
      };
    }

    return {
      valid: true
    };
  }
}

module.exports = RefundDecisionEngine;
