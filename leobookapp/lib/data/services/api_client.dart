// api_client.dart: HTTP client for FastAPI backend with JWT auth.
// Part of LeoBook App — Data Services
//
// Classes: ApiClient

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:leobookapp/core/config/api_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  /// Get current Supabase JWT for Authorization header
  String? get _accessToken =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  /// Build headers with optional JWT
  Map<String, String> get _headers {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = _accessToken;
    if (token != null) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  /// GET request to FastAPI
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(ApiConfig.endpoint(path)).replace(
      queryParameters: queryParams,
    );

    try {
      final response = await http.get(uri, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('[ApiClient] GET $path failed: $e');
      rethrow;
    }
  }

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      debugPrint('[ApiClient] 401 Unauthorized — token may be expired');
      throw ApiException(401, 'Authentication required or token expired');
    }

    if (response.statusCode == 429) {
      throw ApiException(429, 'Rate limit exceeded. Please try again later.');
    }

    throw ApiException(
      response.statusCode,
      'API error: ${response.statusCode} — ${response.body}',
    );
  }
}

/// Custom API exception
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
