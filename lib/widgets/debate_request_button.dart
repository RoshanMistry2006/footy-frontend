import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ for haptic feedback
import '../services/chat_service.dart';

class DebateRequestButton extends StatefulWidget {
  final String toUid;
  final String topic;
  final String commentText;

  const DebateRequestButton({
    super.key,
    required this.toUid,
    required this.topic,
    required this.commentText,
  });

  @override
  State<DebateRequestButton> createState() => _DebateRequestButtonState();
}

class _DebateRequestButtonState extends State<DebateRequestButton> {
  bool _sending = false;

  Future<void> _send() async {
    FocusScope.of(context).unfocus(); // ✅ hides keyboard before showing SnackBars (iOS fix)
    HapticFeedback.lightImpact(); // ✅ subtle vibration for iOS

    setState(() => _sending = true);
    try {
      await ChatService().sendRequest(widget.toUid, widget.topic, widget.commentText);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Debate request sent!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.black.withOpacity(0.85),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Debate request sent!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.black.withOpacity(0.85),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _sending ? null : _send,
      style: TextButton.styleFrom(
        foregroundColor: Colors.green.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      child: _sending
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text("Challenge", style: TextStyle(fontSize: 13)),
    );
  }
}


