import 'package:flutter/foundation.dart';

class ApiConfig {
  // Development LAN URL for Physical Android Device connected via Wi-Fi/LAN
  static const String devLanUrl = 'http://172.25.81.63:8000/api';

  // Base URL pointing to Python FastAPI server
  static String get baseUrl {
    const customUrl = String.fromEnvironment('API_BASE_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    // Real Android device connecting to Mac backend over LAN
    return devLanUrl;
  }

  static String? authToken;

  static Map<String, String> get headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $authToken';
    }
    return map;
  }
}
