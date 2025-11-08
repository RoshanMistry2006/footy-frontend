import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../services/chat_service.dart';

const String baseUrl = "https://footy-backend-yka8.onrender.com";

class CommentThreadPage extends StatefulWidget {
  final String date;
  final String answerId;
  final String answerText;

  const CommentThreadPage({
    super.key,
    required this.date,
    required this.answerId,
    required this.answerText,
  });

  @override
  State<CommentThreadPage> createState() => _CommentThreadPageState();
}

class _CommentThreadPageState extends State<CommentThreadPage> {
  List<Comment> comments = [];
  bool loading = true;
  String? error;
  IO.Socket? _socket;

  final _controller = TextEditingController();
  String? replyingTo;
  String? replyingToName;
  final Set<String> _expanded = {};

  // ✅ NEW: Track who’s already been challenged
  final Set<String> challengedUserIds = {};

  final List<String> _bannedWords = [
    "fuck",
    "shit",
    "bitch",
    "idiot",
    "retard",
    "racist",
    "hate",
    "faggot",
    "cunt",
    "asshole",
    "whore",
  ];

  bool _containsBannedWord(String text) =>
      _bannedWords.any((w) => text.toLowerCase().contains(w));

  @override
  void initState() {
    super.initState();
    _loadComments();
    _connectSocket();
  }

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken(true);
    if (token == null) throw Exception("⚠️ No Firebase token found.");
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ---------- LOAD COMMENTS ----------
  Future<void> _loadComments() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse(
            "$baseUrl/api/questions/${widget.date}/answers/${widget.answerId}/comments"),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        comments = data.map((e) => Comment.fromJson(e)).toList();
        comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else {
        error = "Failed (${res.statusCode})";
      }
    } catch (e) {
      error = e.toString();
    }
    setState(() => loading = false);
  }

  // ---------- POST COMMENT ----------
  Future<void> _postComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_containsBannedWord(text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("⚠️ Please avoid using offensive language."),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final Map<String, dynamic> payload = {"text": text};
    if (replyingTo != null && replyingTo!.isNotEmpty) {
      payload["parentId"] = replyingTo;
    }

    try {
      final res = await http.post(
        Uri.parse(
            "$baseUrl/api/questions/${widget.date}/answers/${widget.answerId}/comments"),
        headers: await _headers(),
        body: jsonEncode(payload),
      );

      if (res.statusCode == 201) {
        _controller.clear();
        setState(() {
          replyingTo = null;
          replyingToName = null;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("✅ Comment posted!")));
        await _loadComments();
      } else {
        final bodyData = jsonDecode(res.body);
        final errorMsg = bodyData['error']?.toString() ?? "Unknown error";
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("❌ $errorMsg")));
      }
    } catch (e, st) {
      debugPrint("💥 Error posting comment: $e\n$st");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ---------- SOCKET ----------
  void _connectSocket() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setQuery({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _socket!.emit('join-answer', widget.answerId);
      debugPrint("🟢 Joined thread for ${widget.answerId}");
    });

    _socket!.on('comment:created', (data) {
      final c = Comment.fromJson(Map<String, dynamic>.from(data));
      if (mounted) setState(() => comments.add(c));
    });

    _socket!.on('comment:deleted', (data) {
      final id = data['id'] as String?;
      if (mounted && id != null) {
        setState(() => comments.removeWhere((c) => c.id == id));
      }
    });

    _socket!.connect();
  }

  @override
  void dispose() {
    _socket?.emit('leave-answer', widget.answerId);
    _socket?.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        title: const Text(
          "Discussion",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: theme.colorScheme.surface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.answerText,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.grey),
                Expanded(
                  child: comments.isEmpty
                      ? const Center(
                          child: Text(
                            "No comments yet — start the discussion!",
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(12),
                          children: _buildThread(comments),
                        ),
                ),
                _buildInput(theme),
              ],
            ),
    );
  }

  // ---------- INPUT ----------
  Widget _buildInput(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyingToName != null)
          Container(
            color: theme.colorScheme.primary.withOpacity(0.15),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Replying to @$replyingToName",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  onPressed: () =>
                      setState(() => {replyingTo = null, replyingToName = null}),
                ),
              ],
            ),
          ),
        Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: replyingTo == null
                        ? "Write a comment..."
                        : "Replying...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _postComment,
                style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary),
                child: const Text("Post"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- THREAD ----------
  List<Widget> _buildThread(List<Comment> all) {
    final Map<String?, List<Comment>> tree = {};
    for (final c in all) {
      tree.putIfAbsent(c.parentId, () => []).add(c);
    }

    List<Widget> buildLevel(String? parentId, int depth) {
      final nodes = tree[parentId] ?? [];
      return nodes
          .map((c) => Padding(
                padding: EdgeInsets.only(left: depth * 24.0, top: 6, bottom: 6),
                child: _commentCard(c, depth, tree, buildLevel),
              ))
          .toList();
    }

    return buildLevel(null, 0);
  }

  // ---------- COMMENT CARD ----------
  Widget _commentCard(
    Comment c,
    int depth,
    Map<String?, List<Comment>> tree,
    List<Widget> Function(String?, int) buildLevel,
  ) {
    final replies = tree[c.id] ?? [];
    final hasReplies = replies.isNotEmpty;
    final isExpanded = _expanded.contains(c.id);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final int cappedDepth = depth.clamp(0, 4);
    final double fontSize = (16 - cappedDepth * 1.4).clamp(10.0, 16.0);
    final double avatarRadius = (18 - cappedDepth * 1.3).clamp(9.0, 16.0);
    final double buttonFontSize = (13 - cappedDepth * 0.8).clamp(9.0, 13.0);
    final bool isMaxDepth = depth >= 3;

    final bgColor = Color.lerp(Colors.grey.shade900, Colors.grey.shade800, depth / 4);
    final textColor = Colors.white.withOpacity(0.9);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade700, width: 0.8),
      ),
      child: Padding(
        padding: EdgeInsets.all((8 - cappedDepth * 1.2).clamp(3.0, 8.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    c.displayName?.substring(0, 1).toUpperCase() ?? "?",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize - 3,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.displayName ?? "Anonymous",
                    style: TextStyle(
                      fontSize: fontSize - 1,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                c.text,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.2,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  if (!isMaxDepth)
                    TextButton.icon(
                      icon: Icon(Icons.reply,
                          size: buttonFontSize + 1,
                          color: Theme.of(context).colorScheme.primary),
                      label: Text(
                        "Reply",
                        style: TextStyle(
                            fontSize: buttonFontSize,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      onPressed: () {
                        setState(() {
                          replyingTo = c.id;
                          replyingToName = c.displayName ?? "user";
                        });
                      },
                    ),
                  if (c.userId != currentUid)
                    TextButton.icon(
                      icon: Icon(
                        Icons.sports_martial_arts,
                        color: challengedUserIds.contains(c.userId)
                            ? Colors.grey.shade600
                            : Colors.amber.shade700,
                        size: buttonFontSize + 1,
                      ),
                      label: Text(
                        challengedUserIds.contains(c.userId)
                            ? "Challenged"
                            : "Challenge",
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          color: challengedUserIds.contains(c.userId)
                              ? Colors.grey.shade600
                              : Colors.amber.shade700,
                        ),
                      ),
                      onPressed: challengedUserIds.contains(c.userId)
                          ? null
                          : () async {
                              try {
                                await ChatService().sendRequest(
                                  c.userId ?? "",
                                  widget.answerText,
                                  "",
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("✅ Challenge sent!")),
                                );
                                setState(() {
                                  challengedUserIds.add(c.userId ?? "");
                                });
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("❌ Error: $e")),
                                );
                              }
                            },
                    ),
                ],
              ),
            ),
            if (hasReplies)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Column(children: buildLevel(c.id, depth + 1)),
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            if (hasReplies)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      if (isExpanded) {
                        _expanded.remove(c.id);
                      } else {
                        _expanded.add(c.id!);
                      }
                    });
                  },
                  child: Text(
                    isExpanded ? "Hide replies" : "View replies",
                    style: TextStyle(fontSize: fontSize - 2, color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- MODEL ----------
class Comment {
  final String id;
  final String text;
  final String? parentId;
  final String? displayName;
  final String? answerId;
  final String? userId;
  final DateTime createdAt;
  final bool isPremium;
  final Map<String, dynamic>? premiumStyle;
  final int depth;

  Comment({
    required this.id,
    required this.text,
    this.parentId,
    this.displayName,
    this.answerId,
    this.userId,
    required this.createdAt,
    this.isPremium = false,
    this.premiumStyle,
    this.depth = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    DateTime ts;
    try {
      if (json['createdAt'] is Map && json['createdAt']['_seconds'] != null) {
        ts = DateTime.fromMillisecondsSinceEpoch(
            json['createdAt']['_seconds'] * 1000);
      } else {
        ts = DateTime.now();
      }
    } catch (_) {
      ts = DateTime.now();
    }

    return Comment(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      parentId: json['parentId'],
      displayName: json['displayName'],
      answerId: json['answerId'],
      userId: json['userId'],
      createdAt: ts,
      isPremium: json['isPremium'] ?? false,
      premiumStyle: json['premiumStyle'] ?? {},
      depth: json['depth'] ?? 0,
    );
  }
}
