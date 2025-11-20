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

  bool _hasNewComments = false;

  final _controller = TextEditingController();
  String? replyingTo;
  String? replyingToName;
  final Set<String> _expanded = {};
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
    if (mounted) setState(() => loading = false);
  }

  Future<void> _postComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (_containsBannedWord(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please avoid using offensive language',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Comment posted',
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
        await _loadComments();
      } else {
        final bodyData = jsonDecode(res.body);
        final errorMsg = bodyData['error']?.toString() ?? "Unknown error";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.redAccent.withOpacity(0.85),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, st) {
      debugPrint("💥 Error posting comment: $e\n$st");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Colors.redAccent.withOpacity(0.85),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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

    // 🔵 Connected
    _socket!.onConnect((_) {
      _socket!.emit('join-answer', widget.answerId);
      debugPrint("🟢 Joined thread for ${widget.answerId}");
    });

    // 🔄 FIX 1 — Reconnect handler (VERY important!)
    _socket!.onReconnect((_) {
      _socket!.emit('join-answer', widget.answerId);
      debugPrint("🔄 Reconnected & rejoined thread for ${widget.answerId}");
    });

    // 🔻 FIX 2 — Disconnect handler
    _socket!.onDisconnect((_) {
      debugPrint("🔴 Socket disconnected");
    });

    // 🟢 Show banner when new comment arrives
    _socket!.on('comment:created', (data) {
      if (mounted) setState(() => _hasNewComments = true);
      debugPrint("💬 New comment detected — banner shown.");
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
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFA5),
        title: const Text(
          "Discussion",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.tealAccent.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.forum, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.answerText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _hasNewComments
                      ? Padding(
                          key: const ValueKey('newCommentsBanner'),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: GestureDetector(
                            onTap: () async {
                              await _loadComments();
                              if (mounted) setState(() => _hasNewComments = false);
                            },
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width - 32,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.tealAccent.withOpacity(0.4),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.chat_bubble_outline,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "New comments available – Tap to refresh",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

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

  Widget _buildInput(ThemeData theme) {
    return Container(
      color: const Color(0xFF111418), // 👈 fills bottom area with same gray tone
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF111418), // 👈 matches background color
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 6,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: replyingTo == null
                        ? "Write a comment..."
                        : "Replying to @$replyingToName",
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Color(0xFF1A1D21), // input background
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _postComment,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.tealAccent.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    "Post",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



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
    final bool isMaxDepth = depth >= 3;

    final bgColor = const Color(0xFF14181C);
    final borderGlow =
        c.userId == currentUid ? Colors.tealAccent : Colors.amberAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderGlow.withOpacity(0.4),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: borderGlow.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: borderGlow.withOpacity(0.9),
                  child: Text(
                    c.displayName?.substring(0, 1).toUpperCase() ?? "?",
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.displayName ?? "Anonymous",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              c.text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: fontSize,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (!isMaxDepth)
                  TextButton.icon(
                    icon:
                        const Icon(Icons.reply, color: Colors.tealAccent, size: 16),
                    label: const Text(
                      "Reply",
                      style: TextStyle(color: Colors.tealAccent, fontSize: 13),
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
                          ? Colors.grey
                          : Colors.amberAccent,
                      size: 16,
                    ),
                    label: Text(
                      challengedUserIds.contains(c.userId)
                          ? "Challenged"
                          : "Challenge",
                      style: TextStyle(
                        color: challengedUserIds.contains(c.userId)
                            ? Colors.grey
                            : Colors.amberAccent,
                        fontSize: 13,
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
                                SnackBar(
                                  content: const Text(
                                    'Challenge sent',
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
                              setState(() {
                                challengedUserIds.add(c.userId ?? "");
                              });
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error: $e',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: Colors.redAccent.withOpacity(0.85),
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                  ),
              ],
            ),
            if (hasReplies)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(left: 12),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
