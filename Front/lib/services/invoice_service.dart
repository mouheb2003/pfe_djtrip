import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

/// Invoice Service
/// Handles all invoice-related API calls for the DJTrip platform
class InvoiceService {
  final String _baseUrl;
  final http.Client _client;

  InvoiceService({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  /// Get authentication token using AuthService
  Future<String?> _getAuthToken() async {
    return await AuthService.getAccessToken();
  }

  /// Generate invoice from payment
  ///
  /// Parameters:
  /// - paymentId: Payment ID
  ///
  /// Returns: Invoice data
  Future<Map<String, dynamic>> generateInvoice(String paymentId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/invoices/generate/$paymentId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        print('[INVOICE SERVICE] Invoice generated successfully');
        return data['invoice'];
      } else {
        throw Exception(data['message'] ?? 'Failed to generate invoice');
      }
    } catch (e) {
      print('[INVOICE SERVICE] Error generating invoice: $e');
      rethrow;
    }
  }

  /// Get invoice by ID
  ///
  /// Parameters:
  /// - invoiceId: Invoice ID
  ///
  /// Returns: Invoice data
  Future<Map<String, dynamic>> getInvoice(String invoiceId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl/invoices/$invoiceId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[INVOICE SERVICE] Invoice retrieved successfully');
        return data['invoice'];
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch invoice');
      }
    } catch (e) {
      print('[INVOICE SERVICE] Error fetching invoice: $e');
      rethrow;
    }
  }

  /// Get invoice by payment ID
  ///
  /// Parameters:
  /// - paymentId: Payment ID
  ///
  /// Returns: Invoice data
  Future<Map<String, dynamic>> getInvoiceByPaymentId(String paymentId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl/invoices/payment/$paymentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[INVOICE SERVICE] Invoice retrieved by payment ID');
        return data['invoice'];
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch invoice');
      }
    } catch (e) {
      print('[INVOICE SERVICE] Error fetching invoice by payment ID: $e');
      rethrow;
    }
  }

  /// Get user invoices
  ///
  /// Parameters:
  /// - page: Page number (default: 1)
  /// - limit: Items per page (default: 10)
  ///
  /// Returns: List of invoices with pagination info
  Future<Map<String, dynamic>> getUserInvoices({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final uri = Uri.parse('$_baseUrl/invoices/user/invoices')
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });

      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[INVOICE SERVICE] User invoices retrieved');
        return {
          'invoices': data['invoices'],
          'pagination': data['pagination'],
        };
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch invoices');
      }
    } catch (e) {
      print('[INVOICE SERVICE] Error fetching user invoices: $e');
      rethrow;
    }
  }

  /// Download invoice PDF
  ///
  /// Parameters:
  /// - invoiceId: Invoice ID
  ///
  /// Returns: File path of downloaded PDF
  Future<String> downloadInvoicePDF(String invoiceId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.get(
        Uri.parse('$_baseUrl/invoices/$invoiceId/pdf'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        print('[INVOICE SERVICE] PDF downloaded successfully');

        // Request storage permissions for Android
        if (Platform.isAndroid) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            print('[INVOICE SERVICE] Storage permission not granted, trying manage external storage');
            final manageStatus = await Permission.manageExternalStorage.request();
            if (!manageStatus.isGranted) {
              print('[INVOICE SERVICE] Manage external storage permission not granted');
            }
          }
        }

        // Save to Downloads directory
        Directory directory;
        if (Platform.isAndroid) {
          // For Android, use the public Downloads directory
          directory = Directory('/storage/emulated/0/Download');
          
          // Fallback if primary path doesn't work
          if (!directory.existsSync()) {
            try {
              directory = await getExternalStorageDirectory() as Directory;
              final downloadDir = Directory('${directory.path}/Download');
              if (!await downloadDir.exists()) {
                await downloadDir.create(recursive: true);
              }
              directory = downloadDir;
            } catch (e) {
              print('[INVOICE SERVICE] Error accessing downloads directory: $e');
              directory = await getApplicationDocumentsDirectory() as Directory;
            }
          }
        } else {
          // For iOS, use app documents (iOS restricts access to system Downloads)
          directory = await getApplicationDocumentsDirectory() as Directory;
        }

        final fileName = 'invoice_$invoiceId.pdf';
        final file = File('${directory.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);

        print('[INVOICE SERVICE] PDF saved to: ${file.path}');
        return file.path;
      } else {
        throw Exception('Failed to download PDF');
      }
    } catch (e) {
      print('[INVOICE SERVICE] Error downloading PDF: $e');
      rethrow;
    }
  }

  /// Share invoice PDF
  ///
  /// Parameters:
  /// - invoiceId: Invoice ID
  Future<void> shareInvoicePDF(String invoiceId) async {
    try {
      final filePath = await downloadInvoicePDF(invoiceId);
      await Share.shareXFiles([XFile(filePath)], subject: 'Invoice from DJTrip');
    } catch (e) {
      print('[INVOICE SERVICE] Error sharing PDF: $e');
      rethrow;
    }
  }

  /// Send invoice by email
  ///
  /// Parameters:
  /// - invoiceId: Invoice ID
  Future<String> sendInvoiceByEmail(String invoiceId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/invoices/$invoiceId/send-email'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('[INVOICE SERVICE] Invoice sent by email successfully');
        return 'Invoice sent successfully';
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to send invoice');
      }
    } catch (e) {
      print('[INVOICE SERVICE] Error sending invoice by email: $e');
      rethrow;
    }
  }

  /// Delete invoice (admin only)
  ///
  /// Parameters:
  /// - invoiceId: Invoice ID
  ///
  /// Returns: Success message
  Future<String> deleteInvoice(String invoiceId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await _client.delete(
        Uri.parse('$_baseUrl/invoices/$invoiceId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('[INVOICE SERVICE] Invoice deleted successfully');
        return data['message'];
      } else {
        throw Exception(data['message'] ?? 'Failed to delete invoice');
      }
    } catch (e) {
      print('[INVOICE SERVICE] Error deleting invoice: $e');
      rethrow;
    }
  }

  /// Dispose the HTTP client
  void dispose() {
    _client.close();
  }
}
