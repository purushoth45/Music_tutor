import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    try {
      final response = await _client.get(uri, headers: ApiConfig.headers);
      return _processResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    try {
      final response = await _client.post(
        uri,
        headers: ApiConfig.headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _processResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  dynamic _processResponse(http.Response response) {
    final bodyString = response.body;
    final jsonBody = bodyString.isNotEmpty ? jsonDecode(bodyString) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonBody;
    } else {
      final message = jsonBody is Map && jsonBody.containsKey('detail')
          ? jsonBody['detail'].toString()
          : 'Server request failed (${response.statusCode})';
      throw Exception(message);
    }
  }
}
