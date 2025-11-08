import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'private_chat_page.dart';

class SentDebateRequestsPage extends StatefulWidget {
  const SentDebateRequestsPage({super.key});

  @override
  State<SentDebateRequestsPage> createState() => _SentDebateRequestsPageState();
}

class _SentDebateRequestsPageState extends State<SentDebateRequestsPage> {
  final _chat = ChatService();
  List<dynamic> _sent = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _chat.getSentRequests();
      setState(() {
        _sent = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D0D),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      "⚠️ Error: $_error",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                )
              : _sent.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded,
                                color: Colors.white38, size: 60),
                            SizedBox(height: 10),
                            Text(
                              "No sent requests yet.",
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: Colors.tealAccent,
                      backgroundColor: const Color(0xFF0B0D0D),
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        itemCount: _sent.length,
                        itemBuilder: (context, index) {
                          final r = _sent[index];
                          final status = (r['status'] ?? '').toString();
                          final glowColor = status == 'accepted'
                              ? Colors.greenAccent
                              : status == 'declined'
                                  ? Colors.redAccent
                                  : Colors.tealAccent;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: status == 'accepted'
                                    ? [const Color(0xFF004D40), const Color(0xFF00796B)]
                                    : status == 'declined'
                                        ? [const Color(0xFF2E0A0A), const Color(0xFF1B0000)]
                                        : [const Color(0xFF141414), const Color(0xFF0B0D0D)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor.withOpacity(0.35),
                                  blurRadius: 14,
                                  spreadRadius: 1.5,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                              border: Border.all(
                                color: glowColor.withOpacity(0.6),
                                width: 1.3,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              title: Text(
                                "To: ${r['toDisplayName'] ?? 'Unknown'}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  "Topic: ${r['topic'] ?? '—'}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: glowColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: glowColor.withOpacity(0.5),
                                      width: 1.2),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: glowColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              onTap: status == "accepted"
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PrivateChatPage(
                                            chatId: r['id'],
                                            debateTopic:
                                                r['topic'] ?? 'Debate topic',
                                            opponentName:
                                                r['toDisplayName'] ?? 'User',
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
