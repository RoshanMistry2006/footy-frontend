import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _teamCtrl = TextEditingController();

  bool _saving = false;
  bool _uploading = false;

  String? _photoURL;
  String? _email;

  int _totalAnswers = 0;
  int _bestAnswers = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser!;
    _email = user.email;
    final db = FirebaseFirestore.instance;

    // --- Load profile info ---
    final userRef = db.collection('users').doc(user.uid);
    final userSnap = await userRef.get();

    if (userSnap.exists) {
      final data = userSnap.data()!;
      _nameCtrl.text = (data['displayName'] ?? user.displayName ?? '') as String;
      _teamCtrl.text = (data['favoriteTeam'] ?? '') as String;
      _photoURL = data['photoURL'] ?? user.photoURL;
      _bestAnswers = (data['discussionsWon'] ?? 0) as int;
      _totalAnswers = (data['totalComments'] ?? 0) as int;
    } else {
      // fallback for first-time users
      await userRef.set({
        'displayName': user.displayName ?? '',
        'favoriteTeam': '',
        'photoURL': user.photoURL,
        'discussionsWon': 0,
        'totalComments': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    await user.updateDisplayName(_nameCtrl.text.trim());
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'displayName': _nameCtrl.text.trim(),
      'favoriteTeam': _teamCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profile updated')),
      );
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _uploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final ref = FirebaseStorage.instance.ref('profile_pics/${user.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();

      await user.updatePhotoURL(url);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'photoURL': url}, SetOptions(merge: true));

      _photoURL = url;
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Change password',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            TextField(
              controller: newPasswordCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPasswordCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPasswordCtrl.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Password changed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Password change failed: $e')));
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _teamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00BFA5), Color(0xFF009688)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Profile',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // ---------- Profile Picture ----------
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BFA5), Color(0xFF00796B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.tealAccent.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage:
                          _photoURL != null ? NetworkImage(_photoURL!) : null,
                      backgroundColor: Colors.grey.shade900,
                      child: _photoURL == null
                          ? const Icon(Icons.person,
                              size: 55, color: Colors.white70)
                          : null,
                    ),
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: _uploading ? null : _pickAndUploadPhoto,
                        backgroundColor: primary,
                        child: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.edit, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Text(
                _email ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 26),

              // ---------- Editable Fields ----------
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Display name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.grey.shade900,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _teamCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Favorite team',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.grey.shade900,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ---------- STAT CARDS ----------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                    icon: Icons.emoji_events,
                    label: "Winning Answers",
                    value: _bestAnswers.toString(),
                    color: Colors.amberAccent,
                  ),
                  _buildStatCard(
                    icon: Icons.chat_bubble_outline,
                    label: "Total Answers",
                    value: _totalAnswers.toString(),
                    color: primary,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ---------- Buttons ----------
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save changes',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: _changePassword,
                icon: const Icon(Icons.lock_outline, color: Colors.white70),
                label: const Text('Change password',
                    style: TextStyle(color: Colors.white70)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                ),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Sign out',
                    style: TextStyle(color: Colors.white)),
                onPressed: _signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade900, Colors.grey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
