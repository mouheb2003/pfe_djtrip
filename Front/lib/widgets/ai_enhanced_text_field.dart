import 'package:flutter/material.dart';
import '../services/ai_text_service.dart';
import 'ai_text_widgets.dart';

// Reusable text field with AI text processing capabilities
class AiEnhancedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final int minLines;
  final bool enabled;
  final InputDecoration? decoration;
  final TextStyle? style;
  final Function(String)? onChanged;
  final VoidCallback? onEditingComplete;
  final bool showAiButtons;
  final bool showTranslateOnly;

  const AiEnhancedTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.minLines = 1,
    this.enabled = true,
    this.decoration,
    this.style,
    this.onChanged,
    this.onEditingComplete,
    this.showAiButtons = true,
    this.showTranslateOnly = false,
  });

  @override
  State<AiEnhancedTextField> createState() => _AiEnhancedTextFieldState();
}

class _AiEnhancedTextFieldState extends State<AiEnhancedTextField> {
  bool _isProcessingAi = false;
  bool _showAiButtons = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (_showAiButtons != hasText) {
      setState(() {
        _showAiButtons = hasText;
      });
    }
    widget.onChanged?.call(widget.controller.text);
  }

  Future<void> _rewriteText() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessingAi = true);

    final result = await AiTextService.rewriteText(text);

    if (!mounted) return;

    setState(() => _isProcessingAi = false);

    if (result['success'] == true) {
      _showAiPreview(text, result['result'], 'rewrite');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to rewrite text'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  Future<void> _improveText() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessingAi = true);

    final result = await AiTextService.improveText(text);

    if (!mounted) return;

    setState(() => _isProcessingAi = false);

    if (result['success'] == true) {
      _showAiPreview(text, result['result'], 'improve');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to improve text'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LanguageSelectorBottomSheet(
        onLanguageSelected: (lang) => _translateText(lang),
      ),
    );
  }

  Future<void> _translateText(String lang) async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isProcessingAi = true);

    final result = await AiTextService.translateText(text, lang);

    if (!mounted) return;

    setState(() => _isProcessingAi = false);

    if (result['success'] == true) {
      _showAiPreview(text, result['result'], 'translate');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to translate text'),
          backgroundColor: const Color(0xFFFF4757),
        ),
      );
    }
  }

  void _showAiPreview(String original, String processed, String action) {
    showDialog(
      context: context,
      builder: (context) => AiTextPreviewDialog(
        originalText: original,
        processedText: processed,
        action: action,
        onAccept: () {
          Navigator.pop(context);
          setState(() {
            widget.controller.text = processed;
          });
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          enabled: widget.enabled,
          style: widget.style,
          decoration: widget.decoration ??
              InputDecoration(
                hintText: widget.hintText,
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4B63FF)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
          onEditingComplete: widget.onEditingComplete,
        ),
        if (widget.showAiButtons && _showAiButtons && !_isProcessingAi) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              AiActionButton(
                icon: Icons.translate,
                tooltip: 'Translate',
                onPressed: _showLanguageSelector,
              ),
              if (!widget.showTranslateOnly) ...[
                const SizedBox(width: 6),
                AiActionButton(
                  icon: Icons.auto_fix_high,
                  tooltip: 'Rewrite',
                  onPressed: _rewriteText,
                ),
                const SizedBox(width: 6),
                AiActionButton(
                  icon: Icons.spellcheck,
                  tooltip: 'Improve',
                  onPressed: _improveText,
                ),
              ],
            ],
          ),
        ],
        if (_isProcessingAi)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4B63FF)),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Processing...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C757D),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
