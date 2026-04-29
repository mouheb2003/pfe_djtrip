import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../services/invoice_service.dart';
import 'invoice_screen.dart';
import '../tourist/tourist_main_screen.dart';

/// Payment Success Screen
/// Displays payment success message with option to view invoice
class PaymentSuccessScreen extends StatelessWidget {
  final String paymentId;
  final String? orderId;
  final double amount;
  final String currency;
  final DateTime paymentDate;
  final String? inscriptionId;
  final String? activityTitle;

  const PaymentSuccessScreen({
    super.key,
    required this.paymentId,
    this.orderId,
    required this.amount,
    this.currency = 'TND',
    required this.paymentDate,
    this.inscriptionId,
    this.activityTitle,
  });

  Future<void> _viewInvoice(BuildContext context) async {
    try {
      final invoiceService = InvoiceService();
      
      // Check if invoice already exists
      Map<String, dynamic>? invoice;
      try {
        invoice = await invoiceService.getInvoiceByPaymentId(paymentId);
      } catch (e) {
        // Invoice doesn't exist, generate a new one
        print('[PAYMENT SUCCESS] Invoice not found, generating new one: $e');
      }
      
      // Generate invoice if not exists
      if (invoice == null) {
        try {
          invoice = await invoiceService.generateInvoice(paymentId);
        } catch (e) {
          // If invoice already exists error, try to get it again
          if (e.toString().contains('Invoice already exists')) {
            print('[PAYMENT SUCCESS] Invoice already exists, retrieving it');
            invoice = await invoiceService.getInvoiceByPaymentId(paymentId);
          } else {
            rethrow;
          }
        }
      }
      
      if (!context.mounted) return;
      
      // Auto-send invoice by email
      try {
        await invoiceService.sendInvoiceByEmail(invoice!['_id']);
        print('[PAYMENT SUCCESS] Invoice email sent successfully');
      } catch (e) {
        print('[PAYMENT SUCCESS] Failed to send invoice email: $e');
        // Don't block navigation if email fails
      }
      
      if (!context.mounted) return;
      
      // Navigate to invoice screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceScreen(invoice: invoice!),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = '$amount $currency';
    final formattedDate = DateFormat('MMM dd, yyyy • HH:mm').format(paymentDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note, color: AppColors.primary),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const TouristMainScreen(initialIndex: 2),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                
                // Success Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 60,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Success Message
                const Text(
                  'Payment Successful ✅',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'Your payment has been processed successfully',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Payment Details Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Amount
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Amount Paid',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formattedAmount,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Transaction Details
                      _DetailRow(
                        icon: Icons.receipt_long,
                        label: 'Transaction ID',
                        value: orderId ?? paymentId,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _DetailRow(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value: formattedDate,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _DetailRow(
                        icon: Icons.payment,
                        label: 'Method',
                        value: 'Credit Card',
                      ),
                      
                      if (activityTitle != null) ...[
                        const SizedBox(height: 16),
                        _DetailRow(
                          icon: Icons.surfing,
                          label: 'Activity',
                          value: activityTitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // View Invoice Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => _viewInvoice(context),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text(
                      'View Invoice',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Done Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
