import '../../../../core/api_client.dart';
import '../../../../core/api_config.dart';
import '../../domain/entities/user.dart';

class AuthDataSource {
  final ApiClient _apiClient;

  AuthDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<User> login(String email, String password) async {
    final normalizedEmail = email.toLowerCase().trim();

    // Pure REST HTTP call to Python FastAPI backend (http://localhost:8000/api/auth/login)
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'email': normalizedEmail,
        'password': password,
      },
    );

    if (response is Map && response.containsKey('access_token')) {
      ApiConfig.authToken = response['access_token'].toString();

      final String roleStr = response['role']?.toString().toUpperCase() ?? 'TRAINEE';
      final String emailStr = response['email']?.toString() ?? normalizedEmail;
      final String fullNameStr = response['full_name']?.toString() ?? response['username']?.toString() ?? emailStr.split('@').first;
      final String? rawUserId = response['user_id']?.toString();
      if (rawUserId == null || rawUserId.isEmpty) {
        throw Exception('Authentication failed: Missing user_id from database response.');
      }

      return User(
        id: rawUserId,
        email: emailStr,
        role: roleStr,
        name: fullNameStr,
        level: roleStr == 'TRAINER' ? 'Master Instructor' : 'Beginner',
        sessionsPlayed: 0,
        averageAccuracy: 0,
        badges: const ['Ear Trainer'],
        streak: 1,
      );
    } else {
      throw Exception('Invalid email or password.');
    }
  }


  Future<Map<String, dynamic>> createTrainee({
    required String fullName,
    required String email,
    required String password,
    String? username,
    String skillLevel = 'BEGINNER',
  }) async {
    final computedUsername = username ?? (email.contains('@') ? email.split('@').first : email);
    final response = await _apiClient.post(
      '/auth/create-trainee',
      body: {
        'username': computedUsername,
        'full_name': fullName,
        'email': email,
        'password': password,
        'skill_level': skillLevel.toUpperCase(),
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }
}
