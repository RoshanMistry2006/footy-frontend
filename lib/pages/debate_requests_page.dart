import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'private_chat_page.dart';
import 'sent_debate_requests_page.dart'; // ✅ new import for Sent tab

/// ----------------------------------------------------------
///  MAIN WRAPPER: 2 tabs → Incoming + Sent Requests
/// ----------------------------------------------------------
class AllDebateRequestsPage extends StatelessWidget {
  const AllDebateRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text(
            'Debate Requests',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Incoming"),
              Tab(text: "Sent"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DebateRequestsPage(), // incoming
            SentDebateRequestsPage(), // sent
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------
///  INCOMING REQUESTS PAGE (your original file’s content)
/// ----------------------------------------------------------
class DebateRequestsPage extends StatefulWidget {
  const DebateRequestsPage({super.key});

  @override
  State<DebateRequestsPage> createState() => _DebateRequestsPageState();
}

class _DebateRequestsPageState extends State<DebateRequestsPage> {
  final _chat = ChatService();
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _chat.getRequests();

      // ✅ Filter out declined & expired requests
      final now = DateTime.now();
      final filtered = data.where((r) {
        final status = r['status'] ?? '';
        if (status == 'declined') return false;
        if (r['expiresAt'] != null) {
          final expiry =
              DateTime.fromMillisecondsSinceEpoch(r['expiresAt'] as int);
          if (now.isAfter(expiry)) return false;
        }
        return true;
      }).toList();

      if (!mounted) return;
      setState(() {
        _requests = filtered;
        _loading = false;
      });

      await _markSeen();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markSeen() async {
    try {
      await _chat.markSeen();
      debugPrint("✅ Marked all debate requests as seen.");
    } catch (e) {
      debugPrint("⚠️ Failed to mark requests as seen: $e");
    }
  }

  Future<void> _respond(String id, String action) async {
    try {
      await _chat.respond(id, action);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request $action successfully!")),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _openChat(Map<String, dynamic> request) {
    if (request['status'] != 'accepted') return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrivateChatPage(
          chatId: request['chatId'] ?? request['id'],
          debateTopic: request['topic'] ?? 'Debate',
          opponentName: request['fromDisplayName'] ?? 'Opponent',
        ),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _error != null
              ? _buildError(theme)
              : _requests.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: primary,
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _requests.length,
                        itemBuilder: (context, i) {
                          final r = _requests[i];
                          final status = (r['status'] ?? '').toString();
                          final glowColor = status == 'accepted'
                              ? Colors.greenAccent
                              : status == 'declined'
                                  ? Colors.redAccent
                                  : Colors.tealAccent;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF111111),
                                  status == 'accepted'
                                      ? const Color(0xFF003322)
                                      : status == 'declined'
                                          ? const Color(0xFF330000)
                                          : const Color(0xFF1A1A1A),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor.withOpacity(0.35),
                                  blurRadius: 12,
                                  spreadRadius: 1.5,
                                ),
                              ],
                              border: Border.all(
                                color: glowColor.withOpacity(0.7),
                                width: 1.4,
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _openChat(r),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              title: Text(
                                r['topic'] ?? 'Unknown topic',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: "From: ",
                                          style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13),
                                        ),
                                        TextSpan(
                                          text: r['fromDisplayName'] ?? 'Unknown',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (r['commentText'] != null &&
                                      r['commentText'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text(
                                        '"${r['commentText']}"',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontStyle: FontStyle.italic,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: _buildStatusWidget(r, status, glowColor),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  // ---------- EMPTY STATE ----------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.mark_chat_unread, color: Colors.white38, size: 60),
            SizedBox(height: 10),
            Text(
              "No debate requests yet.",
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- ERROR WIDGET ----------
  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              "❌ Failed to load requests:\n$_error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
              ),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- STATUS DISPLAY ----------
  Widget _buildStatusWidget(
      Map<String, dynamic> r, String status, Color glowColor) {
    if (status == 'pending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Accept',
            icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
            onPressed: () => _respond(r['id'], 'accept'),
          ),
          IconButton(
            tooltip: 'Decline',
            icon: const Icon(Icons.cancel, color: Colors.redAccent),
            onPressed: () => _respond(r['id'], 'decline'),
          ),
        ],
      );
    } else if (status == 'accepted') {
      // ✅ Show expiry countdown
      String expiryText = '';
      if (r['expiresAt'] != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(r['expiresAt']);
        final remaining = expiry.difference(DateTime.now());
        if (remaining.isNegative) {
          expiryText = 'Expired';
        } else {
          final hours = remaining.inHours;
          expiryText = 'Expires in ${hours}h';
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: glowColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: glowColor.withOpacity(0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: glowColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (expiryText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                expiryText,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}

