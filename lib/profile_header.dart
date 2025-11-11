import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_page.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return SafeArea( // ✅ prevents overlap with iOS notch or status bar
      top: true,
      bottom: false,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text("Unknown user"),
              subtitle: const Text("No profile data"),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final displayName = (data['displayName'] ?? 'Anonymous') as String;
          final team = (data['favoriteTeam'] ?? 'No team set') as String;

          return ListTile(
            leading: CircleAvatar(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              ),
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("Team: $team"),
            trailing: const Icon(Icons.edit),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
          );
        },
      ),
    );
  }
}
