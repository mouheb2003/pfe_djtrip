import 'package:flutter/material.dart';
import '../../models/user.dart';
import 'profile_completion_screen.dart';

class PreferencesOnboardingScreen extends StatefulWidget {
  final User user;

  const PreferencesOnboardingScreen({super.key, required this.user});

  @override
  State<PreferencesOnboardingScreen> createState() =>
      _PreferencesOnboardingScreenState();
}

class _PreferencesOnboardingScreenState
    extends State<PreferencesOnboardingScreen> {
  // Available preferences list
  final List<String> availablePreferences = [
    'Beaches',
    'Mountains',
    'Cities',
    'Adventure',
    'Culture',
    'Gastronomy',
    'Nature',
    'History',
    'Shopping',
    'Sport',
    'Relaxation',
    'Family travel',
    'Couple travel',
    'Solo travel',
    'Photography',
    'Hiking',
    'Diving',
    'Camping',
    'Luxury',
    'Budget friendly',
  ];

  Set<String> selectedPreferences = {};
  final bool _canSkip = true;

  void _continueToProfile() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileCompletionScreen(
          user: widget.user,
          preferences: selectedPreferences.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFFF6B1A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canSkip)
            TextButton(
              onPressed: _continueToProfile,
              child: Text(
                'Skip',
                style: TextStyle(color: Color(0xFFFF6B1A), fontSize: 16),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator (Step 0 of the onboarding)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(
                  4,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Color(0xFFFF6B1A)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6B1A).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_outline,
                          size: 64,
                          color: Color(0xFFFF6B1A),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),

                    // Title
                    Text(
                      'Your travel preferences',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Select your interests to personalize your recommendations',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 32),

                    // Preferences chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availablePreferences.map((preference) {
                        final isSelected = selectedPreferences.contains(
                          preference,
                        );
                        return FilterChip(
                          label: Text(preference),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedPreferences.add(preference);
                              } else {
                                selectedPreferences.remove(preference);
                              }
                            });
                          },
                          selectedColor: Color(0xFFFF6B1A).withOpacity(0.2),
                          checkmarkColor: Color(0xFFFF6B1A),
                          backgroundColor: Colors.grey[200],
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Color(0xFFFF6B1A)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? Color(0xFFFF6B1A)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Selected preferences summary
                    if (selectedPreferences.isNotEmpty) ...[
                      SizedBox(height: 32),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF6B1A).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Color(0xFFFF6B1A).withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Color(0xFFFF6B1A),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '${selectedPreferences.length} preference(s) selected',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF6B1A),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: selectedPreferences.map((pref) {
                                return Chip(
                                  label: Text(
                                    pref,
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  deleteIcon: Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    setState(() {
                                      selectedPreferences.remove(pref);
                                    });
                                  },
                                  backgroundColor: Color(
                                    0xFFFF6B1A,
                                  ).withOpacity(0.1),
                                  labelStyle: TextStyle(
                                    color: Color(0xFFFF6B1A),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 24),

                    // Info note
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your preferences help us recommend trips that match your interests. You can modify them at any time in your profile.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _continueToProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF6B1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    selectedPreferences.isEmpty ? 'Skip' : 'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
