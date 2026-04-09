import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

class TermsOfUseScreen extends StatefulWidget {
  const TermsOfUseScreen({super.key});

  @override
  State<TermsOfUseScreen> createState() => _TermsOfUseScreenState();
}

class _TermsOfUseScreenState extends State<TermsOfUseScreen> {
  bool _hasAcceptedTerms = false;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _termsSections = [
    {
      'number': '1',
      'title': 'Acceptance of Agreement',
      'content': 'By accessing and using the DJTrip platform, you acknowledge that you have read, understood, and agree to be bound by these Terms of Use and our Privacy Policy. If you do not agree to these terms, you must not access or use our services.',
    },
    {
      'number': '2',
      'title': 'User Responsibilities',
      'subsections': [
        {
          'subtitle': 'AGE REQUIREMENTS',
          'content': 'Users must be at least 18 years of age to create an account and make bookings through the DJTrip platform. By using our service, you confirm that you meet this age requirement.',
        },
        {
          'subtitle': 'ACCOUNT ACCURACY',
          'content': 'You are responsible for maintaining the accuracy of your account information. You must provide complete and accurate information during registration and keep your account details up to date.',
        },
      ],
    },
    {
      'number': '3',
      'title': 'Booking & Payments',
      'content': 'DJTrip acts as an intermediary platform connecting travelers with activity organizers. All prices displayed are subject to change without prior notice. Payment processing is handled through secure third-party payment providers.',
    },
    {
      'number': '4',
      'title': 'Limitation of Liability',
      'content': 'DJTrip shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from your use of the service.',
    },
    {
      'number': '5',
      'title': 'Service Availability',
      'content': 'We strive to maintain high service availability but cannot guarantee uninterrupted access. DJTrip reserves the right to modify, suspend, or discontinue any part of the service at any time without prior notice.',
    },
    {
      'number': '6',
      'title': 'Intellectual Property',
      'content': 'All content, trademarks, service marks, logos, and other intellectual property displayed on the DJTrip platform are the exclusive property of DJTrip or its licensors. You may not use, copy, reproduce, or distribute any of this content without prior written permission.',
    },
    {
      'number': '7',
      'title': 'Termination',
      'content': 'DJTrip reserves the right to terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever, including if you breach the Terms of Use.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkTermsAcceptance();
  }

  Future<void> _checkTermsAcceptance() async {
    final accepted = await AuthService.hasAcceptedTerms();
    if (mounted) {
      setState(() {
        _hasAcceptedTerms = accepted;
      });
    }
  }

  Future<void> _acceptTerms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.acceptTermsOfUse();
      if (mounted) {
        setState(() {
          _hasAcceptedTerms = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terms accepted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting terms: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadPDF() async {
    try {
      // In a real app, this would download the actual PDF
      await Clipboard.setData(const ClipboardData(text: 'Terms of Use - DJTrip Platform'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terms copied to clipboard (PDF download would be implemented here)'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'DJTrip',
              style: TextStyle(
                color: Color(0xFF4B63FF),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Terms of Use',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE8E5FF),
            child: const Icon(
              Icons.person,
              color: Color(0xFF4B63FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4B63FF), Color(0xFF6B7FFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4B63FF).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.balance,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terms of Use',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'v2.0 - Jan 2024',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Terms Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _termsSections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final section = _termsSections[index];
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${section['number']}.',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4B63FF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              section['title'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      if (section['subsections'] != null) ...[
                        ...section['subsections'].map<Widget>((subsection) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  subsection['subtitle'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF4B63FF),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subsection['content'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }).toList(),
                      ] else ...[
                        Text(
                          section['content'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),

          // Bottom Buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _acceptTerms,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B63FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            '1. Accept Terms',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _downloadPDF,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4B63FF),
                      side: const BorderSide(color: Color(0xFF4B63FF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '2. Download PDF',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
