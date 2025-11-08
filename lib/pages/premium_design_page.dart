import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

const String baseUrl = "https://footy-backend-yka8.onrender.com";

class PremiumDesignPage extends StatefulWidget {
  final String answerId;
  final String answerText;
  final String date;

  const PremiumDesignPage({
    super.key,
    required this.answerId,
    required this.answerText,
    required this.date,
  });

  @override
  State<PremiumDesignPage> createState() => _PremiumDesignPageState();
}

class _PremiumDesignPageState extends State<PremiumDesignPage>
    with SingleTickerProviderStateMixin {
  // ---------- STYLE STATE ----------
  Color bgColor = Colors.white;
  Color textColor = Colors.black;
  bool isBold = false;
  bool isItalic = false;

  bool hasOutline = false;
  Color outlineColor = Colors.amber;

  bool hasShadow = false;
  Color glowColor = Colors.amber;

  bool loading = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ---------- AUTH HEADERS ----------
  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ---------- CONFIRM & ACTIVATE ----------
  Future<void> _confirm() async {
    setState(() => loading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("💳 Processing fake payment...")),
    );

    await Future.delayed(const Duration(seconds: 2));
    final paymentSuccess = true;

    if (!paymentSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Payment failed")),
      );
      setState(() => loading = false);
      return;
    }

    final style = {
      "backgroundColor": "#${bgColor.value.toRadixString(16)}",
      "textColor": "#${textColor.value.toRadixString(16)}",
      "bold": isBold,
      "italic": isItalic,
      "outline": hasOutline,
      "outlineColor": "#${outlineColor.value.toRadixString(16)}",
      "shadow": hasShadow,
      "glowColor": "#${glowColor.value.toRadixString(16)}",
    };

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/premium/activate"),
        headers: await _headers(),
        body: jsonEncode({
          "answerId": widget.answerId,
          "date": widget.date,
          "style": style,
        }),
      );

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Premium style applied successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        debugPrint("❌ Backend error: ${res.body}");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to activate premium: ${res.body}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("💥 Error activating premium: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (mounted) setState(() => loading = false);
  }

  // ---------- BUILD UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "Customize Your Answer",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ---------- LIVE PREVIEW ----------
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1 + (_pulseController.value * 0.02);
              final opacity = 0.8 + (_pulseController.value * 0.2);
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(18),
                      border: hasOutline
                          ? Border.all(color: outlineColor, width: 2.0)
                          : null,
                      boxShadow: hasShadow
                          ? [
                              BoxShadow(
                                color: glowColor.withOpacity(0.45),
                                blurRadius: 25,
                                spreadRadius: 3,
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      widget.answerText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontWeight:
                            isBold ? FontWeight.bold : FontWeight.normal,
                        fontStyle:
                            isItalic ? FontStyle.italic : FontStyle.normal,
                        shadows: hasShadow
                            ? [
                                Shadow(
                                  color: glowColor.withOpacity(0.6),
                                  blurRadius: 6,
                                  offset: const Offset(1, 1),
                                ),
                              ]
                            : [],
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const Divider(color: Colors.white24, height: 32),

          // ---------- BACKGROUND COLOR ----------
          const Text("Background Color",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final color in [
                  Colors.white,
                  Colors.black,
                  Colors.grey.shade900,
                  Colors.blue.shade900,
                  Colors.teal.shade800,
                  Colors.green.shade100,
                  Colors.yellow.shade100,
                  Colors.orange.shade200,
                  Colors.purple.shade100,
                  Colors.pink.shade200,
                  Colors.red.shade100,
                ])
                  GestureDetector(
                    onTap: () => setState(() => bgColor = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: bgColor == color
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.8),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                        border: Border.all(
                          color: bgColor == color
                              ? Colors.white
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                      width: 36,
                      height: 36,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ---------- TEXT COLOR ----------
          const Text("Text Color",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final color in [
                  Colors.white,
                  Colors.black,
                  Colors.blue,
                  Colors.tealAccent,
                  Colors.greenAccent,
                  Colors.redAccent,
                  Colors.amber,
                  Colors.purpleAccent,
                  Colors.pinkAccent,
                ])
                  GestureDetector(
                    onTap: () => setState(() => textColor = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                        boxShadow: textColor == color
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.8),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )
                              ]
                            : [],
                        border: Border.all(
                          color: textColor == color
                              ? Colors.white
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                      width: 36,
                      height: 36,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ---------- TEXT STYLE TOGGLES ----------
          _toggleCard("Bold Text", Icons.format_bold, isBold,
              (v) => setState(() => isBold = v)),
          _toggleCard("Italic Text", Icons.format_italic, isItalic,
              (v) => setState(() => isItalic = v)),
          _toggleCard("Add Shadow / Glow", Icons.flare, hasShadow,
              (v) => setState(() => hasShadow = v)),

          if (hasShadow) ...[
            const SizedBox(height: 12),
            const Text("Glow Color",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final color in [
                    Colors.white,
                    Colors.amber,
                    Colors.tealAccent,
                    Colors.pinkAccent,
                    Colors.blueAccent,
                    Colors.greenAccent,
                    Colors.redAccent,
                    Colors.purpleAccent,
                  ])
                    GestureDetector(
                      onTap: () => setState(() => glowColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: glowColor == color
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.8),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                          border: Border.all(
                            color: glowColor == color
                                ? Colors.white
                                : Colors.white24,
                            width: 2,
                          ),
                        ),
                        width: 36,
                        height: 36,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          _toggleCard("Add Outline", Icons.border_outer, hasOutline,
              (v) => setState(() => hasOutline = v)),

          if (hasOutline) ...[
            const SizedBox(height: 8),
            const Text("Outline Color",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final color in [
                    Colors.white,
                    Colors.black,
                    Colors.amber,
                    Colors.red,
                    Colors.blue,
                    Colors.teal,
                    Colors.green,
                    Colors.purpleAccent,
                    Colors.pinkAccent,
                  ])
                    GestureDetector(
                      onTap: () => setState(() => outlineColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: outlineColor == color
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.8),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                          border: Border.all(
                            color: outlineColor == color
                                ? Colors.white
                                : Colors.white24,
                            width: 2,
                          ),
                        ),
                        width: 36,
                        height: 36,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),

          // ---------- CONFIRM BUTTON ----------
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF00BFA5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              shadowColor: Colors.tealAccent.withOpacity(0.5),
              elevation: 10,
            ),
            onPressed: loading ? null : _confirm,
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child:
                        CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    "Apply Style",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8),
                  ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _toggleCard(
      String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Card(
      color: const Color(0xFF161A1F),
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: Colors.tealAccent),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.tealAccent,
        ),
      ),
    );
  }
}
