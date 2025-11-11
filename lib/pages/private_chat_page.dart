import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivateChatPage extends StatefulWidget {
  final String chatId;
  final String debateTopic;
  final String opponentName;

  const PrivateChatPage({
    super.key,
    required this.chatId,
    required this.debateTopic,
    required this.opponentName,
  });

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final ChatService _chat = ChatService();
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  List messages = [];
  bool _loading = true;
  DateTime _lastHaptic = DateTime.now().subtract(const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      _chat.connectSocket(_uid);
      _chat.joinChat(widget.chatId);

      // ✅ iOS-safe: Guard setState + lifecycle for socket events
      _chat.onMessage((data) {
        if (!mounted) return;
        setState(() => messages.add(data));
        _scrollToBottom();

        // ✅ Gentle throttling for iOS haptics (prevents stutter)
        final now = DateTime.now();
        if (now.difference(_lastHaptic).inMilliseconds > 250) {
          HapticFeedback.selectionClick();
          _lastHaptic = now;
        }
      });

      final loadedMessages = await _chat.getMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        messages = loadedMessages;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("💥 Chat load failed: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    try {
      await _chat.sendMessage(widget.chatId, text);
      _ctrl.clear();

      // ✅ Slightly delayed haptic to ensure proper trigger on iOS
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) HapticFeedback.lightImpact();
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final error = e.toString();
      if (error.contains("banned words")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Your message contains banned words."),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ $error"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _chat.leaveChat(widget.chatId);
    _chat.socket?.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 6,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.opponentName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '"${widget.debateTopic}"',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C0C0C), Color(0xFF121212)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                        ? const Center(
                            child: Text(
                              "No messages yet. Start the debate!",
                              style: TextStyle(color: Colors.white60),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: messages.length,
                            itemBuilder: (_, i) {
                              final m = messages[i];
                              return _buildMessageBubble(m, primary);
                            },
                          ),
              ),
              _buildInputBar(primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> m, Color primary) {
    final isMe = m['senderUid'] == _uid;
    final messageText = m['text'] ?? '';

    final bubbleGradient = isMe
        ? const LinearGradient(
            colors: [Color(0xFF00BFA5), Color(0xFF00FFB0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF1E1E1E), Color(0xFF292929)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      margin: EdgeInsets.only(
        top: 6,
        bottom: 6,
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
      ),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: bubbleGradient,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: isMe
                    ? Colors.tealAccent.withOpacity(0.4)
                    : Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              messageText,
              style: TextStyle(
                color: isMe ? Colors.black : Colors.white,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(Color primary) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          border: const Border(
            top: BorderSide(color: Colors.tealAccent, width: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.tealAccent.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Type your argument...',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTapDown: (_) => HapticFeedback.mediumImpact(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BFA5), Color(0xFF00FFB0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _send,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
