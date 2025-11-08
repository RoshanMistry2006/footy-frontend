import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class DebateRequestButton extends StatefulWidget {
  final String toUid;
  final String topic;
  final String commentText; // ✅ new field for the challenged comment

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
    setState(() => _sending = true);
    try {
      await ChatService()
          .sendRequest(widget.toUid, widget.topic, widget.commentText); // ✅ 3 args

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Debate request sent!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      setState(() => _sending = false);
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

