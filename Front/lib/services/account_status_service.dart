import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/shared/account_status_popup.dart';

class AccountStatusService {
  static bool _isPopupShowing = false;

  static void checkAndShowAccountStatusPopup(
    BuildContext context, {
    UserStatus? currentStatus,
    String? banReason,
    String? suspensionReason,
    DateTime? suspendedUntil,
  }) {
    // Don't show popup if already showing
    if (_isPopupShowing) {
      return;
    }

    // Don't show if account is active
    if (currentStatus == UserStatus.active || currentStatus == null) {
      return;
    }

    // Don't show if user is inactive (not banned/suspended)
    if (currentStatus == UserStatus.inactive) {
      return;
    }

    _isPopupShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AccountStatusPopup(
        status: currentStatus!,
        banReason: banReason,
        suspensionReason: suspensionReason,
        suspendedUntil: suspendedUntil,
      ),
    ).then((_) {
      _isPopupShowing = false;
    });
  }

  static void resetPopupState() {
    _isPopupShowing = false;
  }

  static bool get isPopupShowing => _isPopupShowing;
}
