// api_config.dart: FastAPI backend configuration.
// Part of LeoBook App — Core Config
//
// Classes: ApiConfig

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  /// FastAPI backend base URL — configurable via .env or compile-time override
  static String get baseUrl {
    // 1. Check .env
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    // 2. Compile-time constant
    const compileUrl = String.fromEnvironment('API_BASE_URL');
    if (compileUrl.isNotEmpty) return compileUrl;

    // 3. Default (local dev)
    return 'http://localhost:8000';
  }

  /// Check if API is configured
  static bool get isConfigured => baseUrl.isNotEmpty;

  /// Convenience: full endpoint URL
  static String endpoint(String path) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }
}
