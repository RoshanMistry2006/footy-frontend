import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _teamCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _displayNameCtrl.dispose();
    _teamCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();
      final displayName = _displayNameCtrl.text.trim();
      final team = _teamCtrl.text.trim();

      // ✅ Create user in Firebase Auth
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = cred.user!;
      final uid = user.uid;

      // ✅ Set displayName in Firebase profile
      await user.updateDisplayName(displayName);
      await user.reload();

      // ✅ Store in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'favoriteTeam': team,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Account created! Please sign in.")),
        );

        Navigator.pushReplacementNamed(context, '/login');
      }
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        message = 'The email address is already in use by another account.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format.';
      } else if (e.code == 'weak-password') {
        message = 'Password should be at least 6 characters long.';
      }

      setState(() => _error = message);
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_soccer, size: 70, color: Color(0xFF00BFA5)),
                  const SizedBox(height: 12),
                  Text(
                    "Create your BallTalk account",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ⚠️ Error text
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                      ),
                    ),

                  // 🧑 Display Name
                  TextFormField(
                    controller: _displayNameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      "Display name",
                      Icons.person_outline,
                      theme,
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),

                  // ⚽ Team
                  TextFormField(
                    controller: _teamCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      "Favorite team",
                      Icons.shield_outlined,
                      theme,
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 16),

                  // 📧 Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      "Email",
                      Icons.email_outlined,
                      theme,
                    ),
                    validator: (v) =>
                        v != null && v.contains("@") ? null : "Invalid email",
                  ),
                  const SizedBox(height: 16),

                  // 🔒 Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      "Password",
                      Icons.lock_outline,
                      theme,
                    ),
                    validator: (v) =>
                        v != null && v.length >= 6 ? null : "Min 6 characters",
                  ),
                  const SizedBox(height: 16),

                  // 🔁 Confirm Password
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration(
                      "Confirm password",
                      Icons.lock,
                      theme,
                    ),
                    validator: (v) =>
                        v == _passwordCtrl.text ? null : "Passwords don’t match",
                  ),
                  const SizedBox(height: 30),

                  // 🚀 Register Button
                  FilledButton(
                    onPressed: _loading ? null : _register,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Create Account",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // 🔙 Go to login
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SignInPage()),
                      );
                    },
                    child: Text(
                      "Already have an account? Sign in",
                      style: TextStyle(
                        color: primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🔧 Shared input decoration
  InputDecoration _inputDecoration(
      String label, IconData icon, ThemeData theme) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: theme.colorScheme.primary),
      filled: true,
      fillColor: theme.colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: theme.colorScheme.primary,
          width: 1.2,
        ),
      ),
    );
  }
}


