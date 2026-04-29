import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';

class ReminderPreferencesScreen extends StatefulWidget {
  const ReminderPreferencesScreen({Key? key}) : super(key: key);

  @override
  State<ReminderPreferencesScreen> createState() => _ReminderPreferencesScreenState();
}

class _ReminderPreferencesScreenState extends State<ReminderPreferencesScreen> {
  bool _isLoading = false;
  bool _bookingReminderEnabled = true;
  String _reminderTiming = '1h'; // '1h', '24h', 'both'

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      
      if (user != null && user.reminderPreferences != null) {
        setState(() {
          _bookingReminderEnabled = user.reminderPreferences['bookingReminder'] ?? true;
          _reminderTiming = user.reminderPreferences['reminderTiming'] ?? '1h';
        });
      }
    } catch (e) {
      debugPrint('Error loading reminder preferences: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      await ApiService.updateReminderPreferences({
        'bookingReminder': _bookingReminderEnabled,
        'reminderTiming': _reminderTiming,
      });
      
      // Refresh user data
      await userProvider.refreshUser();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving reminder preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Preferences'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Reminders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose when you want to receive reminders for your upcoming activities.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Enable/Disable toggle
                  SwitchListTile(
                    title: const Text('Enable Booking Reminders'),
                    subtitle: const Text('Receive notifications before your activities start'),
                    value: _bookingReminderEnabled,
                    onChanged: (value) {
                      setState(() {
                        _bookingReminderEnabled = value;
                      });
                    },
                  ),
                  
                  const Divider(height: 32),
                  
                  // Reminder timing options
                  const Text(
                    'Reminder Timing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  RadioListTile<String>(
                    title: const Text('1 hour before'),
                    subtitle: const Text('Get a reminder 1 hour before the activity starts'),
                    value: '1h',
                    groupValue: _reminderTiming,
                    onChanged: _bookingReminderEnabled ? (value) {
                      setState(() {
                        _reminderTiming = value!;
                      });
                    } : null,
                  ),
                  
                  RadioListTile<String>(
                    title: const Text('24 hours before'),
                    subtitle: const Text('Get a reminder 24 hours before the activity starts'),
                    value: '24h',
                    groupValue: _reminderTiming,
                    onChanged: _bookingReminderEnabled ? (value) {
                      setState(() {
                        _reminderTiming = value!;
                      });
                    } : null,
                  ),
                  
                  RadioListTile<String>(
                    title: const Text('Both (1h and 24h)'),
                    subtitle: const Text('Get reminders at both times'),
                    value: 'both',
                    groupValue: _reminderTiming,
                    onChanged: _bookingReminderEnabled ? (value) {
                      setState(() {
                        _reminderTiming = value!;
                      });
                    } : null,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePreferences,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Preferences',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
