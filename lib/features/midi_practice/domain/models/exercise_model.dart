enum SkillLevel {
  beginner,
  moderate,
  pro,
}

extension SkillLevelExtension on SkillLevel {
  String get displayName {
    switch (this) {
      case SkillLevel.beginner:
        return 'Beginner';
      case SkillLevel.moderate:
        return 'Moderate';
      case SkillLevel.pro:
        return 'Pro';
    }
  }

  String get emoji {
    switch (this) {
      case SkillLevel.beginner:
        return '🟢';
      case SkillLevel.moderate:
        return '🟡';
      case SkillLevel.pro:
        return '🔴';
    }
  }
}

class PracticeExercise {
  final String id;
  final String title;
  final String description;
  final SkillLevel level;
  final List<String> notes;
  final int targetBpm;
  final String aiTip;

  const PracticeExercise({
    required this.id,
    required this.title,
    required this.description,
    required this.level,
    required this.notes,
    required this.targetBpm,
    required this.aiTip,
  });
}
