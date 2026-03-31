import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_client.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  List<Map<String, dynamic>> questions = [];
  bool loading = true;
  String? error;

  final _dateCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _dateCtrl.text = tomorrow.toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() { loading = true; error = null; });
    try {
      final res = await ApiClient.get('/questions');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() => questions = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => error = 'Failed to load (${res.statusCode})');
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _createQuestion() async {
    final date = _dateCtrl.text.trim();
    final text = _textCtrl.text.trim();
    if (date.isEmpty || text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final res = await ApiClient.post('/questions', {'date': date, 'text': text});
      if (res.statusCode == 201) {
        _textCtrl.clear();
        final next = DateTime.parse(date).add(const Duration(days: 1));
        _dateCtrl.text = next.toIso8601String().substring(0, 10);
        _showSnack('Created for $date', success: true);
        await _loadQuestions();
      } else {
        final body = jsonDecode(res.body);
        _showSnack(body['error'] ?? 'Failed', success: false);
      }
    } catch (e) {
      _showSnack('Error: $e', success: false);
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _toggleActive(String date, bool currentlyActive) async {
    try {
      final res = await ApiClient.patch('/questions/$date', {'isActive': !currentlyActive});
      if (res.statusCode == 200) {
        _showSnack(!currentlyActive ? 'Activated!' : 'Deactivated', success: true);
        await _loadQuestions();
      } else {
        final body = jsonDecode(res.body);
        _showSnack(body['error'] ?? 'Failed', success: false);
      }
    } catch (e) {
      _showSnack('Error: $e', success: false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      backgroundColor: success ? Colors.teal.shade700 : Colors.redAccent.shade700,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Admin Panel',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadQuestions),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildCreateCard(),
                    const SizedBox(height: 24),
                    Text('Questions (${questions.length})',
                        style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    ...questions.map(_buildQuestionTile),
                  ],
                ),
    );
  }

  Widget _buildCreateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create new question',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 14),
          TextField(
            controller: _dateCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Date (YYYY-MM-DD)', Icons.calendar_today),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: _inputDecoration('Question text', Icons.help_outline),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _createQuestion,
              icon: _submitting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add),
              label: const Text('Create Question'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTile(Map<String, dynamic> q) {
    final date = q['date'] as String? ?? '';
    final text = q['text'] as String? ?? '';
    final isActive = q['isActive'] as bool? ?? false;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final isToday = date == today;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.tealAccent.withOpacity(0.5) : Colors.white12,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(date, style: TextStyle(
                    color: isToday ? Colors.tealAccent : Colors.white54,
                    fontSize: 12, fontWeight: FontWeight.w600,
                  )),
                  if (isToday) ...[const SizedBox(width: 6), _chip('TODAY', Colors.tealAccent)],
                  if (isActive) ...[const SizedBox(width: 6), _chip('ACTIVE', Colors.greenAccent)],
                ]),
                const SizedBox(height: 4),
                Text(text,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: (_) => _toggleActive(date, isActive),
            activeColor: Colors.tealAccent,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: const Color(0xFF0B0D10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00BFA5))),
    );
  }
}
