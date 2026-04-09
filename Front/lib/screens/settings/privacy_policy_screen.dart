import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  bool _hasAcceptedPolicy = false;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _policySections = [
    {
      'number': '1',
      'title': 'Data Collection',
      'content': 'We collect information you provide directly to us, such as when you create an account, book an activity, or contact us. This includes personal details like name, email, phone number, and payment information.',
    },
    {
      'number': '2',
      'title': 'Data Usage',
      'subsections': [
        {
          'subtitle': 'SERVICE DELIVERY',
          'content': 'Your data is used to provide and improve our services, process bookings, communicate with you, and personalize your experience.',
        },
        {
          'subtitle': 'ANALYTICS',
          'content': 'We use analytics tools to understand how our platform is used and to improve user experience.',
        },
      ],
    },
    {
      'number': '3',
      'title': 'Data Sharing',
      'content': 'We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except as described in this policy.',
    },
    {
      'number': '4',
      'title': 'Data Security',
      'content': 'We implement appropriate technical and organizational measures to protect your personal data against unauthorized access, alteration, disclosure, or destruction.',
    },
    {
      'number': '5',
      'title': 'Cookies',
      'content': 'We use cookies and similar tracking technologies to track activity on our service and hold certain information to enhance your user experience.',
    },
    {
      'number': '6',
      'title': 'Your Rights',
      'content': 'You have the right to access, update, or delete your personal information. You may also opt out of certain communications from us.',
    },
    {
      'number': '7',
      'title': 'Policy Updates',
      'content': 'We may update this privacy policy from time to time. We will notify you of any changes by posting the new policy on this page.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _checkPolicyAcceptance();
  }

  Future<void> _checkPolicyAcceptance() async {
    final accepted = await AuthService.hasAcceptedPrivacyPolicy();
    if (mounted) {
      setState(() {
        _hasAcceptedPolicy = accepted;
      });
    }
  }

  Future<void> _acceptPolicy() async {
    setState(() => _isLoading = true);

    try {
      await AuthService.acceptPrivacyPolicy();
      if (mounted) {
        setState(() {
          _hasAcceptedPolicy = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy policy accepted successfully'),
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
            content: Text('Error accepting policy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadPDF() async {
    try {
      await Clipboard.setData(const ClipboardData(text: 'Privacy Policy - DJTrip Platform'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy policy copied to clipboard (PDF download would be implemented here)'),
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
              'Privacy Policy',
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
                  color: Color.fromRGBO(75, 99, 255, 0.2),
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
                    color: Color.fromRGBO(255, 255, 255, 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
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
                        'Privacy Policy',
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
                          color: Color.fromRGBO(255, 255, 255, 0.9),
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

          // Policy Content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _policySections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  final section = _policySections[index];
                  
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
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _acceptPolicy,
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
                        : const Text(
                            '1. Accept Policy',
                            style: TextStyle(
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
