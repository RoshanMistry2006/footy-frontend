import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  // 🌍 API base URL
  static const String baseUrl = "https://footy-backend-yka8.onrender.com";

  // 🔐 Get Firebase ID token (cross-platform)
  static Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? await user.getIdToken() : null;
  }

  // 🧠 Internal helper to add headers
  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  // ⚙️ GET request (with safe timeout)
  static Future<http.Response> get(String path) async {
    final headers = await _headers();
    final uri = Uri.parse("$baseUrl$path");
    // ✅ iOS-friendly: prevent infinite hang by adding timeout
    return http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
  }

  // ⚙️ POST request (with safe timeout)
  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    final uri = Uri.parse("$baseUrl$path");
    return http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
  }

  // ⚙️ DELETE request (with safe timeout)
  static Future<http.Response> delete(String path) async {
    final headers = await _headers();
    final uri = Uri.parse("$baseUrl$path");
    return http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
  }
}
