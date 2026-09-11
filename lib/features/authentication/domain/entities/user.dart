import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String role;
  final String name;
  final String level;
  final int sessionsPlayed;
  final int averageAccuracy;
  final List<String> badges;
  final int streak;

  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
    required this.level,
    required this.sessionsPlayed,
    required this.averageAccuracy,
    required this.badges,
    required this.streak,
  });

  bool get isTrainer => role.toUpperCase() == 'TRAINER' || email.toLowerCase().contains('trainer');

  @override
  List<Object> get props => [
        id,
        email,
        role,
        name,
        level,
        sessionsPlayed,
        averageAccuracy,
        badges,
        streak,
      ];
}
