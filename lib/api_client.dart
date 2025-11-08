import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  // change this depending on your environment
  static const String baseUrl = "https://footy-backend-yka8.onrender.com"; 

  static Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    return user != null ? await user.getIdToken() : null;
  }

  static Future<http.Response> get(String path) async {
    final token = await _getToken();
    return http.get(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final token = await _getToken();
    return http.post(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String path) async {
    final token = await _getToken();
    return http.delete(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );
  }
}
