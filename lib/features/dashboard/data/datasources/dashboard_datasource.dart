import '../../../../core/api_client.dart';

class RemoteDashboardSummary {
  final String username;
  final String? fullName;
  final String role;
  final String skillLevel;
  final int streakDays;
  final int totalSessionsPlayed;
  final int averageAccuracy;
  final int badgesCount;
  final String aiCoachMessage;
  final String? currentAssignment;
  final List<dynamic> recentSessions;

  RemoteDashboardSummary({
    required this.username,
    this.fullName,
    required this.role,
    required this.skillLevel,
    required this.streakDays,
    required this.totalSessionsPlayed,
    required this.averageAccuracy,
    required this.badgesCount,
    required this.aiCoachMessage,
    this.currentAssignment,
    required this.recentSessions,
  });

  factory RemoteDashboardSummary.fromJson(Map<String, dynamic> json) {
    return RemoteDashboardSummary(
      username: json['username']?.toString() ?? 'Learner',
      fullName: json['full_name']?.toString(),
      role: json['role']?.toString() ?? 'TRAINEE',
      skillLevel: json['skill_level']?.toString() ?? 'BEGINNER',
      streakDays: json['streak_days'] ?? 0,
      totalSessionsPlayed: json['total_sessions_played'] ?? 0,
      averageAccuracy: json['average_accuracy'] ?? 0,
      badgesCount: json['badges_count'] ?? 0,
      aiCoachMessage: json['ai_coach_message']?.toString() ?? 'Keep up the practice!',
      currentAssignment: json['current_assignment']?.toString(),
      recentSessions: json['recent_sessions'] is List ? json['recent_sessions'] : [],
    );
  }
}


class DashboardDataSource {
  final ApiClient _apiClient;

  DashboardDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<RemoteDashboardSummary> getSummary(int userId) async {
    final response = await _apiClient.get('/dashboard/summary?user_id=$userId');
    return RemoteDashboardSummary.fromJson(Map<String, dynamic>.from(response as Map));
  }
}
