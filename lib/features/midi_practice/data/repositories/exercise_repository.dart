import '../../domain/models/exercise_model.dart';

class ExerciseRepository {
  static const List<PracticeExercise> exercises = [
    // 🟢 BEGINNER EXERCISES
    PracticeExercise(
      id: 'beg_1',
      title: 'Single Key Finder',
      description: 'Locate Middle C, E4, and G4 on the keyboard',
      level: SkillLevel.beginner,
      notes: ['C4', 'E4', 'G4'],
      targetBpm: 50,
      aiTip: 'Take your time finding each key. Look at the two black key clusters to anchor your Middle C.',
    ),
    PracticeExercise(
      id: 'beg_2',
      title: '4-Note Finger Drill',
      description: 'Basic right-hand finger placement (C-D-E-F)',
      level: SkillLevel.beginner,
      notes: ['C4', 'D4', 'E4', 'F4'],
      targetBpm: 60,
      aiTip: 'Keep your wrist relaxed and drop each finger naturally onto the center of the key.',
    ),
    PracticeExercise(
      id: 'beg_3',
      title: 'C Major Scale (1 Octave)',
      description: '8-note ascending scale (C4 to C5)',
      level: SkillLevel.beginner,
      notes: ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5'],
      targetBpm: 70,
      aiTip: 'Tuck your thumb under finger 3 after playing E4 to seamlessly transition to F4.',
    ),

    // 🟡 MODERATE EXERCISES
    PracticeExercise(
      id: 'mod_1',
      title: 'Primary Triad Chords',
      description: 'Play C Major, F Major, and G Major triads',
      level: SkillLevel.moderate,
      notes: ['C4', 'E4', 'G4', 'F4', 'A4', 'C5', 'G4', 'B4', 'D5'],
      targetBpm: 85,
      aiTip: 'Press all 3 notes of the chord simultaneously. Listen for balanced tone across fingers.',
    ),
    PracticeExercise(
      id: 'mod_2',
      title: 'G Major Scale & Arpeggio',
      description: 'F# key precision scale and broken arpeggio',
      level: SkillLevel.moderate,
      notes: ['G4', 'A4', 'B4', 'C5', 'D5', 'E5', 'F#5', 'G5'],
      targetBpm: 95,
      aiTip: 'Pay special attention to reaching the black F# key smoothly with your ring finger.',
    ),
    PracticeExercise(
      id: 'mod_3',
      title: 'Melodic Motif Drill',
      description: 'Syncopated melody pattern with changing rhythms',
      level: SkillLevel.moderate,
      notes: ['E4', 'D4', 'C4', 'D4', 'E4', 'E4', 'E4', 'D4', 'D4', 'E4', 'G4'],
      targetBpm: 100,
      aiTip: 'Maintain a steady internal pulse. Count 1-and-2-and aloud if needed.',
    ),

    // 🔴 PRO EXERCISES
    PracticeExercise(
      id: 'pro_1',
      title: 'Jazz ii-V-I 7th Chords',
      description: 'Advanced Dm7 -> G7 -> Cmaj7 smooth voicings',
      level: SkillLevel.pro,
      notes: ['D4', 'F4', 'A4', 'C5', 'G4', 'B4', 'D5', 'F5', 'C4', 'E4', 'G4', 'B4'],
      targetBpm: 110,
      aiTip: 'Minimize hand movement between chord changes by using smooth voice leading.',
    ),
    PracticeExercise(
      id: 'pro_2',
      title: '16th Note Arpeggio Speed Run',
      description: '2-octave fluid arpeggios across C Major and A Minor',
      level: SkillLevel.pro,
      notes: ['C4', 'E4', 'G4', 'C5', 'E5', 'G5', 'C6', 'A4', 'C5', 'E5', 'A5', 'C6', 'E6', 'A6'],
      targetBpm: 130,
      aiTip: 'Focus on weight distribution and smooth arm rotation to eliminate accents on thumb turns.',
    ),
    PracticeExercise(
      id: 'pro_3',
      title: 'Polyrhythmic Counterpoint',
      description: 'Syncopated counterpoint melody with rapid hand switches',
      level: SkillLevel.pro,
      notes: ['C4', 'G4', 'E4', 'C5', 'B4', 'G4', 'D5', 'F5', 'E5', 'C5', 'A4', 'F4', 'G4', 'B4', 'C5'],
      targetBpm: 140,
      aiTip: 'Isolate finger independence. Maintain microtonal precision and dynamic control.',
    ),
  ];

  static List<PracticeExercise> getAllExercises() {
    return exercises;
  }

  static List<PracticeExercise> getExercisesByLevel(SkillLevel level) {
    return exercises.where((e) => e.level == level).toList();
  }
}
