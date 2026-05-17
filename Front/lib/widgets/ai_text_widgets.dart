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
  final VoidCallback? onReturn; // Option to go back/undo

  const AiTextPreviewDialog({
    super.key,
    required this.originalText,
    required this.processedText,
    required this.action,
    required this.onAccept,
    required this.onCancel,
    this.onReturn,
  });

  @override
  State<AiTextPreviewDialog> createState() => _AiTextPreviewDialogState();
}

class _AiTextPreviewDialogState extends State<AiTextPreviewDialog> {
  @override
  Widget build(BuildContext context) {
    final isTranslation = widget.action == 'translate';
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B63FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getActionIcon(widget.action),
                      color: const Color(0xFF4B63FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _getActionTitle(widget.action),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B2352),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'ORIGINAL TEXT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Text(
                  widget.originalText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    isTranslation ? 'TRANSLATION' : 'AI SUGGESTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isTranslation ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (isTranslation)
                    const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF3B82F6)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isTranslation 
                      ? const Color(0xFFEFF6FF) 
                      : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isTranslation 
                        ? const Color(0xFFDBEAFE) 
                        : const Color(0xFFD1FAE5),
                  ),
                ),
                child: Text(
                  widget.processedText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B63FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.onReturn != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: widget.onReturn,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Back to options'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4B63FF),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
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
        return Icons.auto_awesome;
    }
  }

  String _getActionTitle(String action) {
    switch (action) {
      case 'translate':
        return 'Translation';
      case 'rewrite':
        return 'AI Rewriting';
      case 'improve':
        return 'AI Correction';
      default:
        return 'AI Assistant';
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
