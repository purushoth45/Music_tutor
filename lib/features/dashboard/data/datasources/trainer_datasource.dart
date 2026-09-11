import '../../../../core/api_client.dart';
import '../../../../core/api_config.dart';
import '../../../midi_practice/domain/models/exercise_model.dart';

class RemoteTrainee {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final SkillLevel skillLevel;
  final int streakDays;
  final int averageAccuracy;
  final int totalSessionsPlayed;
  final String? currentAssignment;

  RemoteTrainee({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.skillLevel,
    required this.streakDays,
    required this.averageAccuracy,
    required this.totalSessionsPlayed,
    this.currentAssignment,
  });

  factory RemoteTrainee.fromJson(Map<String, dynamic> json) {
    SkillLevel parsedLevel = SkillLevel.beginner;
    final levelStr = json['skill_level']?.toString().toUpperCase();
    if (levelStr == 'MODERATE') {
      parsedLevel = SkillLevel.moderate;
    } else if (levelStr == 'PRO' || levelStr == 'ADVANCED') {
      parsedLevel = SkillLevel.pro;
    }

    return RemoteTrainee(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? json['username']?.toString() ?? 'Student',
      skillLevel: parsedLevel,
      streakDays: json['streak_days'] ?? 1,
      averageAccuracy: json['average_accuracy'] ?? 0,
      totalSessionsPlayed: json['total_sessions_played'] ?? 0,
      currentAssignment: json['current_assignment']?.toString(),
    );
  }
}

class TrainerDataSource {
  final ApiClient _apiClient;

  TrainerDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<void> _ensureTrainerToken() async {
    if (ApiConfig.authToken == null || ApiConfig.authToken!.isEmpty) {
      try {
        final res = await _apiClient.post(
          '/auth/login',
          body: {
            'email': 'spprushoth45@gmail.com',
            'password': 'trainer123',
          },
        );
        if (res is Map && res.containsKey('access_token')) {
          ApiConfig.authToken = res['access_token'].toString();
        }
      } catch (_) {}
    }
  }

  Future<List<RemoteTrainee>> getTrainees() async {
    await _ensureTrainerToken();
    try {
      final response = await _apiClient.get('/trainer/trainees');
      if (response is List) {
        return response.map((item) => RemoteTrainee.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      return [];
    } catch (e) {
      if (e.toString().contains('401') || e.toString().toLowerCase().contains('unauthorized')) {
        ApiConfig.authToken = null;
        await _ensureTrainerToken();
        final response = await _apiClient.get('/trainer/trainees');
        if (response is List) {
          return response.map((item) => RemoteTrainee.fromJson(Map<String, dynamic>.from(item))).toList();
        }
      }
      rethrow;
    }
  }

  Future<void> assignExercise({
    required int traineeId,
    required String exerciseId,
    required String notes,
  }) async {
    await _ensureTrainerToken();
    await _apiClient.post(
      '/trainer/assign-exercise',
      body: {
        'trainee_id': traineeId,
        'exercise_id': exerciseId,
        'notes': notes,
      },
    );
  }

  Future<void> assignExerciseBulk({
    required String exerciseId,
    String? skillLevel,
    required String notes,
  }) async {
    await _ensureTrainerToken();
    await _apiClient.post(
      '/trainer/assign-exercise-bulk',
      body: {
        'skill_level': skillLevel,
        'exercise_id': exerciseId,
        'notes': notes,
      },
    );
  }

  Future<void> createTrainee({
    required String fullName,
    required String email,
    required String password,
    String skillLevel = 'BEGINNER',
  }) async {
    await _ensureTrainerToken();
    final username = email.contains('@') ? email.split('@').first : email;
    await _apiClient.post(
      '/auth/create-trainee',
      body: {
        'username': username,
        'email': email,
        'password': password,
        'full_name': fullName,
        'skill_level': skillLevel.toUpperCase(),
      },
    );
  }
}
