import 'package:flutter/material.dart';
import '../services/ai_text_service.dart';

// Language Selector Bottom Sheet
class LanguageSelectorBottomSheet extends StatelessWidget {
  final Function(String) onLanguageSelected;

  const LanguageSelectorBottomSheet({
    super.key,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE1E4E8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select Language',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E225E),
            ),
          ),
          const SizedBox(height: 20),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AiTextService.supportedLanguages.length,
            itemBuilder: (context, index) {
              final langCode = AiTextService.supportedLanguages.keys.elementAt(index);
              final langName = AiTextService.supportedLanguages.values.elementAt(index);
              
              return ListTile(
                title: Text(
                  langName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E225E),
                  ),
                ),
                trailing: Text(
                  langCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6C757D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onLanguageSelected(langCode);
                },
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// AI Text Preview Dialog
class AiTextPreviewDialog extends StatefulWidget {
  final String originalText;
  final String processedText;
  final String action;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  const AiTextPreviewDialog({
    super.key,
    required this.originalText,
    required this.processedText,
    required this.action,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  State<AiTextPreviewDialog> createState() => _AiTextPreviewDialogState();
}

class _AiTextPreviewDialogState extends State<AiTextPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getActionIcon(widget.action),
            color: const Color(0xFF4B63FF),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            _getActionTitle(widget.action),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E225E),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Original:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6C757D),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE1E4E8)),
              ),
              child: Text(
                widget.originalText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E225E),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Result:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00B894),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Text(
                widget.processedText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E225E),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6C757D),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: widget.onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4B63FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Accept',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'translate':
        return Icons.translate;
      case 'rewrite':
        return Icons.auto_fix_high;
      case 'improve':
        return Icons.spellcheck;
      default:
        return Icons.text_fields;
    }
  }

  String _getActionTitle(String action) {
    switch (action) {
      case 'translate':
        return 'Translation';
      case 'rewrite':
        return 'Rewritten Text';
      case 'improve':
        return 'Improved Text';
      default:
        return 'Processed Text';
    }
  }
}

// AI Action Button Widget
class AiActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AiActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isLoading ? const Color(0xFFE1E4E8) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLoading ? const Color(0xFFE1E4E8) : const Color(0xFFE1E4E8),
            ),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B63FF)),
                    ),
                  )
                : Icon(
                    icon,
                    size: 18,
                    color: const Color(0xFF4B63FF),
                  ),
          ),
        ),
      ),
    );
  }
}
