import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_client.dart';

class ChatService {
  IO.Socket? socket;

  // =====================================================
  // DEBATE REQUESTS
  // =====================================================

  Future<void> sendRequest(String toUid, String topic, String commentText) async {
    final res = await ApiClient.post('/chats/request', {
      'toUid': toUid,
      'topic': topic,
      'commentText': commentText,
    });

    if (res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body);
        throw Exception(body['error'] ?? 'Failed to send request');
      } catch (_) {
        throw Exception('Failed to send request (${res.statusCode})');
      }
    }
  }

  Future<List<dynamic>> getRequests() async {
    final res = await ApiClient.get('/chats/requests');

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch requests (${res.statusCode})');
    }

    final body = jsonDecode(res.body);
    List<dynamic> list = body is List
        ? body
        : (body is Map && body.containsKey('requests') ? body['requests'] as List<dynamic> : []);

    final now = DateTime.now();
    return list.where((r) {
      if (r['status'] == 'declined') return false;
      if (r['expiresAt'] != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(r['expiresAt'] as int);
        if (now.isAfter(expiry)) return false;
      }
      return true;
    }).toList();
  }

  Future<List<dynamic>> getSentRequests() async {
    final res = await ApiClient.get('/chats/sent');

    if (res.statusCode != 200) {
      throw Exception('Failed to fetch sent requests (${res.statusCode})');
    }

    final body = jsonDecode(res.body);
    List<dynamic> list = body is List
        ? body
        : (body is Map && body.containsKey('requests') ? body['requests'] as List<dynamic> : []);

    final now = DateTime.now();
    return list.where((r) {
      if (r['status'] == 'declined') return false;
      if (r['expiresAt'] != null) {
        final expiry = DateTime.fromMillisecondsSinceEpoch(r['expiresAt'] as int);
        if (now.isAfter(expiry)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> respond(String requestId, String action) async {
    final res = await ApiClient.post('/chats/respond', {
      'requestId': requestId,
      'action': action,
    });

    if (res.statusCode != 200 && res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body);
        throw Exception(body['error'] ?? 'Failed to respond to request');
      } catch (_) {
        throw Exception('Failed to respond (${res.statusCode})');
      }
    }
  }

  Future<void> markSeen() async {
    final res = await ApiClient.post('/chats/mark-seen', {});
    if (res.statusCode != 200) {
      throw Exception('Failed to mark as seen: ${res.body}');
    }
  }

  // =====================================================
  // CHAT MESSAGES
  // =====================================================

  Future<List<dynamic>> getMessages(String chatId) async {
    final res = await ApiClient.get('/chats/$chatId/messages');

    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        throw Exception(body['error'] ?? 'Failed to fetch messages');
      } catch (_) {
        throw Exception('Failed to fetch messages (${res.statusCode})');
      }
    }

    return jsonDecode(res.body);
  }

  Future<void> sendMessage(String chatId, String text) async {
    final res = await ApiClient.post('/chats/$chatId/messages', {'text': text});

    if (res.statusCode != 201) {
      try {
        final body = jsonDecode(res.body);
        throw Exception(body['error'] ?? 'Failed to send message');
      } catch (_) {
        throw Exception('Failed to send message (${res.statusCode})');
      }
    }
  }

  // =====================================================
  // SOCKET.IO REAL-TIME
  // =====================================================

  void connectSocket(String tokenUid) {
    socket = IO.io(
      ApiClient.baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'tokenUid': tokenUid})
          .enableReconnection()
          .build(),
    );

    socket!.onConnect((_) => print('Socket connected for user: $tokenUid'));
    socket!.onDisconnect((_) => print('Socket disconnected'));
    socket!.on('chat:accepted', (data) => print('Debate request accepted: $data'));
    socket!.on('chat:declined', (data) => print('Debate request declined: $data'));
    socket!.connect();
  }

  void joinChat(String chatId) => socket?.emit('join-chat', chatId);
  void leaveChat(String chatId) => socket?.emit('leave-chat', chatId);
  void onMessage(void Function(dynamic) handler) => socket?.on('chat:message', handler);

  void dispose() {
    socket?.disconnect();
    socket?.dispose();
    socket = null;
  }
}
