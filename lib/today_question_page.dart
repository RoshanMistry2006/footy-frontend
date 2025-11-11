import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'comment_thread_page.dart';
import 'profile_page.dart';
import '../pages/premium_design_page.dart';
import '../pages/all_debate_requests_page.dart'; // ✅ Import for debate requests

const String _origin = "https://footy-backend-yka8.onrender.com";

class TodayQuestionPage extends StatefulWidget {
  const TodayQuestionPage({super.key});

  @override
  State<TodayQuestionPage> createState() => _TodayQuestionPageState();
}

class _TodayQuestionPageState extends State<TodayQuestionPage> {
  String? questionText;
  bool loading = true;
  String? error;

  List<Answer> answers = [];
  String? myVotedAnswerId;
  final _answerCtrl = TextEditingController();
  bool posting = false;

  IO.Socket? _socket;
  bool isAdmin = false;
  Map<String, dynamic>? winner;
  final String currentDate = DateTime.now().toIso8601String().substring(0, 10);

  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  int _newChallengesCount = 0;

  @override
  void initState() {
    super.initState();
    debugPrint("👤 Logged in user UID: ${FirebaseAuth.instance.currentUser?.uid}");
    _bootstrap();
    _connectSocket();
    _checkAdminClaim();
    _listenToDebateRequests();
  }

  // ---------- Helpers ----------
  String _api(String path) => '$_origin/api$path';

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken(true);
    if (token == null) throw Exception("⚠️ No Firebase token found – please log in again.");
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<void> _bootstrap() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await Future.wait([
        _loadQuestion(),
        _loadAnswers(),
        _loadMyVote(),
        _getWinner(silent: true),
      ]);
      _startCountdown();
    } catch (e, st) {
      debugPrint("💥 Bootstrap error: $e\n$st");
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadQuestion() async {
    final res = await http.get(
      Uri.parse(_api("/questions/$currentDate")),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      setState(() => questionText = jsonDecode(res.body)["text"]);
    } else {
      throw Exception("Question fetch failed: ${res.statusCode} ${res.body}");
    }
  }

  Future<void> _loadAnswers() async {
    try {
      final res = await http.get(
        Uri.parse(_api("/questions/$currentDate/answers")),
        headers: await _headers(),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final rawList = (body is List)
            ? body
            : (body is Map && body['answers'] is List)
                ? body['answers']
                : <dynamic>[];

        final parsed = rawList
            .whereType<Map<String, dynamic>>()
            .map((e) => Answer.fromJson(e))
            .toList();

        setState(() {
          answers = parsed..sort((a, b) => (b.votes).compareTo(a.votes));
        });
      } else if (res.statusCode == 404) {
        setState(() => answers = []);
      } else {
        throw Exception("Answers fetch failed: ${res.statusCode} ${res.body}");
      }
    } catch (e, st) {
      debugPrint("💥 _loadAnswers error: $e\n$st");
      setState(() => error = e.toString());
    }
  }

  Future<void> _loadMyVote() async {
    final res = await http.get(
      Uri.parse(_api("/questions/$currentDate/vote")),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      setState(() => myVotedAnswerId = jsonDecode(res.body)["answerId"]);
    } else {
      setState(() => myVotedAnswerId = null);
    }
  }

  Future<void> _submitAnswer() async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      posting = true;
      error = null;
    });

    try {
      final res = await http.post(
        Uri.parse(_api("/questions/$currentDate/answers")),
        headers: await _headers(),
        body: jsonEncode({"text": text}),
      );

      if (res.statusCode == 201) {
        _answerCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Answer submitted!")),
        );
        await _loadAnswers();
      } else {
        setState(() => error = "Post failed: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      setState(() => error = "Network error: $e");
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }

  Future<void> _vote(String answerId) async {
    final res = await http.post(
      Uri.parse(_api("/questions/$currentDate/answers/$answerId/vote")),
      headers: await _headers(),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      setState(() => myVotedAnswerId = answerId);
      await _loadAnswers();
    }
  }

  Future<void> _unvote() async {
    final res = await http.delete(
      Uri.parse(_api("/questions/$currentDate/vote")),
      headers: await _headers(),
    );
    if (res.statusCode == 200 || res.statusCode == 204) {
      setState(() => myVotedAnswerId = null);
      await _loadAnswers();
    }
  }

  void _startCountdown() {
    final now = DateTime.now();
    final nextReset = DateTime(now.year, now.month, now.day + 1);
    setState(() => _timeLeft = nextReset.difference(now));

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = nextReset.difference(DateTime.now());
      if (diff.isNegative) {
        _countdownTimer?.cancel();
        setState(() => _timeLeft = Duration.zero);
        _bootstrap();
      } else {
        setState(() => _timeLeft = diff);
      }
    });
  }

  void _listenToDebateRequests() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('debateRequests')
        .where('toUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      if (mounted) setState(() => _newChallengesCount = snapshot.docs.length.clamp(0, 99));
    });
  }

  Future<void> _connectSocket() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    _socket = IO.io(
      _origin,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableReconnection()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _socket!.emit('join-day', currentDate);
        debugPrint("[SOCKET] Joined $currentDate");
      })
      ..on('chat:request', (_) => setState(() => _newChallengesCount++))
      ..on('challenge:received', (_) => setState(() => _newChallengesCount++))
      ..on('answer:created', (_) => _loadAnswers())
      ..connect();
  }

  // ---------- Colors ----------
  Color _getComplementaryColor(Color color) {
    final r = (255 - color.red) * 0.85 + 30;
    final g = (255 - color.green) * 0.85 + 30;
    final b = (255 - color.blue) * 0.85 + 30;
    return Color.fromARGB(
      255,
      r.clamp(0, 255).toInt(),
      g.clamp(0, 255).toInt(),
      b.clamp(0, 255).toInt(),
    );
  }

  Color _getReadableTextColor(Color bg) {
    final brightness = (bg.red * 0.299 + bg.green * 0.587 + bg.blue * 0.114) / 255;
    return brightness > 0.7 ? Colors.black : Colors.white;
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  Future<void> _checkAdminClaim() async {
    final res = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
    setState(() => isAdmin = res?.claims?['admin'] == true);
  }

  Future<void> _getWinner({bool silent = false}) async {
    try {
      final res = await http.get(
        Uri.parse(_api("/questions/$currentDate/winner")),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        setState(() => winner = jsonDecode(res.body));
      } else {
        setState(() => winner = null);
      }
    } catch (_) {}
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) return const Center(child: CircularProgressIndicator());

    final user = FirebaseAuth.instance.currentUser;
    final hasAnswered = answers.any((a) => a.userId == user?.uid);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Today's Question",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _buildQuestionCard(theme),
            const SizedBox(height: 12),
            hasAnswered ? _buildAlreadyAnsweredNotice() : _buildAnswerInput(theme),
            const SizedBox(height: 8),
            Expanded(
              child: answers.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Be the first to answer!"),
                      ),
                    )
                  : ListView(children: answers.map((a) => _buildAnswerTile(context, a)).toList()),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00BFA5), Color(0xFF009688)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: const Row(
        children: [
          Icon(Icons.sports_soccer, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text('BallTalk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              tooltip: 'Debate Requests',
              icon: const Icon(Icons.mail_outline),
              onPressed: () {
                setState(() => _newChallengesCount = 0);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AllDebateRequestsPage()),
                );
              },
            ),
            if (_newChallengesCount > 0)
              Positioned(
                right: 10,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      _newChallengesCount > 9 ? '9+' : '$_newChallengesCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
        IconButton(icon: const Icon(Icons.person), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()))),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _bootstrap),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          },
        ),
      ],
    );
  }

  Widget _buildQuestionCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.tealAccent.withOpacity(0.25), blurRadius: 25, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Text(
            questionText ?? "No question found.",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer, color: Colors.tealAccent, size: 18),
              const SizedBox(width: 6),
              Text(
                _timeLeft.inSeconds > 0
                    ? "Next question in ${_formatDuration(_timeLeft)}"
                    : "New question coming soon...",
                style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyAnsweredNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: const Text(
        "✅ You’ve already submitted your answer for today.",
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAnswerInput(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _answerCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Write your answer...",
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            minimumSize: const Size(70, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: posting ? null : _submitAnswer,
          child: posting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text("Post"),
        ),
      ],
    );
  }

  Widget _buildAnswerTile(BuildContext context, Answer a) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final isMine = a.userId == user?.uid;
    final isVoted = myVotedAnswerId == a.id;

    final bgColor = a.isPremium
        ? Color(int.tryParse(a.premiumStyle?['backgroundColor']?.replaceAll('#', '0xff') ?? '') ?? 0xFFFFF9C4)
        : theme.colorScheme.surface;

    final outlineColor = a.isPremium
        ? Color(int.tryParse(a.premiumStyle?['outlineColor']?.replaceAll('#', '0xff') ?? '') ?? Colors.amber.value)
        : theme.dividerColor.withOpacity(0.3);

    final textColor = _getReadableTextColor(bgColor);
    final complementary = _getComplementaryColor(bgColor);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineColor, width: a.isPremium ? 2.0 : 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        // ✅ Title
        title: a.isPremium
            ? _buildPremiumText(a)
            : Text(
                a.text,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),

        // ✅ Subtitle
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "by ${a.displayName ?? 'Anonymous'} • ${a.votes} vote${a.votes == 1 ? '' : 's'}",
              style: TextStyle(
                color: complementary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isMine && !a.isPremium)
              TextButton.icon(
                onPressed: () => _upgradeAnswer(a),
                icon: const Icon(Icons.star_border, size: 16),
                label: const Text("Upgrade", style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(foregroundColor: complementary),
              ),
          ],
        ),

        // ✅ On Tap
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommentThreadPage(
              date: currentDate,
              answerId: a.id,
              answerText: a.text,
            ),
          ),
        ),

        // ✅ Trailing button
        trailing: isVoted
            ? OutlinedButton.icon(
                icon: Icon(Icons.check, color: complementary),
                label: Text("Voted", style: TextStyle(color: complementary)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: complementary)),
                onPressed: _unvote,
              )
            : FilledButton.icon(
                icon: const Icon(Icons.how_to_vote),
                label: const Text("Vote"),
                style: FilledButton.styleFrom(
                  backgroundColor: complementary,
                  foregroundColor: _getReadableTextColor(complementary),
                ),
                onPressed: isMine ? null : () => _vote(a.id),
              ),
      ),
    );
  }


  // ---------- Upgrade / Premium ----------
  Future<void> _upgradeAnswer(Answer a) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumDesignPage(
          answerId: a.id,
          answerText: a.text,
          date: currentDate,
        ),
      ),
    );

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Premium style applied!")),
      );
      await _loadAnswers();
    }
  }

  Widget _buildPremiumText(Answer a) {
    final style = a.premiumStyle ?? {};
    final textColor = Color(
      int.tryParse(style['textColor']?.replaceAll('#', '0xff') ?? '') ?? 0xFFFFFFFF,
    );
    final glowColor = Color(
      int.tryParse(style['glowColor']?.replaceAll('#', '0xff') ?? '') ?? 0x00000000,
    );
    final bold = style['bold'] == true;
    final italic = style['italic'] == true;
    final hasShadow = style['shadow'] == true;

    return Text(
      a.text,
      style: TextStyle(
        color: textColor,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        shadows: hasShadow
            ? [
                Shadow(
                  color: glowColor.withOpacity(0.6),
                  blurRadius: 6,
                  offset: const Offset(1, 1),
                ),
              ]
            : [],
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _socket?.emit('leave-day', currentDate);
    _socket?.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }
}

// ---------- Model ----------
class Answer {
  final String id;
  final String text;
  final String userId;
  final String? displayName;
  final int votes;
  final bool isPremium;
  final Map<String, dynamic>? premiumStyle;

  Answer({
    required this.id,
    required this.text,
    required this.userId,
    required this.votes,
    this.displayName,
    this.isPremium = false,
    this.premiumStyle,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      id: json["id"] ?? "",
      text: json["text"] ?? "",
      userId: json["userId"] ?? "",
      votes: (json["votes"] as num?)?.toInt() ?? 0,
      displayName: json["displayName"],
      isPremium: json["isPremium"] ?? false,
      premiumStyle: (json["premiumStyle"] as Map<String, dynamic>?) ?? {},
    );
  }
}
