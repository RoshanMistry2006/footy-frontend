import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

const baseUrl = "https://footy-backend-yka8.onrender.com";

class ChatService {
  IO.Socket? socket;

  // =====================================================
  // 🔐 AUTH HEADERS
  // =====================================================
  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken(true);
    if (token == null) throw Exception("User not authenticated.");
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // =====================================================
  // 📨 DEBATE REQUESTS
  // =====================================================

  Future<void> sendRequest(String toUid, String topic, String commentText) async {
    print("📤 Sending debate request to $toUid about '$topic'");
    final headers = await _headers();

    final res = await http.post(
      Uri.parse('$baseUrl/api/chats/request'),
      headers: headers,
      body: jsonEncode({
        'toUid': toUid,
        'topic': topic,
        'commentText': commentText,
      }),
    );

    print("📥 Response status: ${res.statusCode}");
    print("📥 Response body: ${res.body}");

    if (res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body);
        final error = body['error'] ?? 'Failed to send request';
        throw Exception(error);
      } catch (_) {
        throw Exception('Failed to send request (${res.statusCode})');
      }
    }
  }

  /// 📨 Fetch all incoming debate requests (where current user is recipient)
  Future<List<dynamic>> getRequests() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final res = await http.get(
      Uri.parse('$baseUrl/api/chats/requests?uid=$uid'),
      headers: await _headers(),
    );

    print("📩 GET /api/chats/requests → ${res.statusCode}");
    print("📦 Response body: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch requests (${res.statusCode})');
    }

    final body = jsonDecode(res.body);
    List<dynamic> list = [];

    if (body is List) {
      list = body;
    } else if (body is Map && body.containsKey('requests')) {
      list = body['requests'] as List<dynamic>;
    }

    // ✅ Filter expired & declined requests client-side
    final now = DateTime.now();
    list = list.where((r) {
      final status = r['status'] ?? '';
      if (status == 'declined') return false;
      if (r['expiresAt'] != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(r['expiresAt'] as int);
        if (now.isAfter(expiry)) return false;
      }
      return true;
    }).toList();

    return list;
  }

  /// 📨 Fetch all SENT debate requests (where current user is requester)
  Future<List<dynamic>> getSentRequests() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final res = await http.get(
      Uri.parse('$baseUrl/api/chats/sent?uid=$uid'),
      headers: await _headers(),
    );

    print("📩 GET /api/chats/sent → ${res.statusCode}");
    print("📦 Response body: ${res.body}");

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch sent requests (${res.statusCode})');
    }

    final body = jsonDecode(res.body);
    List<dynamic> list = [];

    if (body is List) {
      list = body;
    } else if (body is Map && body.containsKey('requests')) {
      list = body['requests'] as List<dynamic>;
    }

    // ✅ Filter expired requests client-side
    final now = DateTime.now();
    list = list.where((r) {
      final status = r['status'] ?? '';
      if (status == 'declined') return false;
      if (r['expiresAt'] != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(r['expiresAt'] as int);
        if (now.isAfter(expiry)) return false;
      }
      return true;
    }).toList();

    return list;
  }

  /// ✅ Respond to debate request
  Future<void> respond(String requestId, String action) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/chats/respond'),
      headers: await _headers(),
      body: jsonEncode({'requestId': requestId, 'action': action}),
    );

    print("📩 POST /respond [$action] → ${res.statusCode}");
    print("📦 Body: ${res.body}");

    if (res.statusCode != 200 && res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body);
        final error = body['error'] ?? 'Failed to respond to request';
        throw Exception(error);
      } catch (_) {
        throw Exception('Failed to respond (${res.statusCode})');
      }
    }
  }

  Future<void> markSeen() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/chats/mark-seen'),
      headers: await _headers(),
    );

    print("👁️ POST /mark-seen → ${res.statusCode}");
    if (res.statusCode != 200) {
      throw Exception("Failed to mark as seen: ${res.body}");
    }
  }

  // =====================================================
  // 💬 CHAT MESSAGES
  // =====================================================

  Future<List<dynamic>> getMessages(String chatId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/chats/$chatId/messages'),
      headers: await _headers(),
    );

    print("💬 GET /messages ($chatId) → ${res.statusCode}");

    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        final error = body['error'] ?? 'Failed to fetch messages';
        throw Exception(error);
      } catch (_) {
        throw Exception('Failed to fetch messages (${res.statusCode})');
      }
    }

    return jsonDecode(res.body);
  }

  Future<void> sendMessage(String chatId, String text) async {
    final headers = await _headers();

    print("📤 Sending message to chat $chatId → $text");

    final res = await http.post(
      Uri.parse('$baseUrl/api/chats/$chatId/messages'),
      headers: headers,
      body: jsonEncode({'text': text}),
    );

    print("📥 Message send status: ${res.statusCode}");
    print("📥 Message response: ${res.body}");

    if (res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body);
        final error = body['error'] ?? 'Failed to send message';
        throw Exception(error);
      } catch (_) {
        throw Exception('Failed to send message (${res.statusCode})');
      }
    }
  }

  // =====================================================
  // ⚡ SOCKET.IO REAL-TIME
  // =====================================================

  void connectSocket(String tokenUid) {
    socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'tokenUid': tokenUid})
          .enableReconnection()
          .build(),
    );

    socket!.onConnect((_) {
      print("⚡ Socket connected for user: $tokenUid");
    });

    socket!.onDisconnect((_) {
      print("⚠️ Socket disconnected");
    });

    socket!.on('chat:accepted', (data) {
      print("🎉 Your debate request was accepted → $data");
    });

    socket!.on('chat:declined', (data) {
      print("🚫 Your debate request was declined → $data");
    });

    socket!.connect();
  }

  void joinChat(String chatId) {
    socket?.emit('join-chat', chatId);
    print("🔵 Joined chat room $chatId");
  }

  void leaveChat(String chatId) {
    socket?.emit('leave-chat', chatId);
    print("🔴 Left chat room $chatId");
  }

  void onMessage(void Function(dynamic) handler) {
    socket?.on('chat:message', handler);
  }

  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
  }
}


