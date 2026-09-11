import 'package:equatable/equatable.dart';

class NoteDetection extends Equatable {
  final String note;
  final int accuracy;

  const NoteDetection({
    required this.note,
    required this.accuracy,
  });

  @override
  List<Object> get props => [note, accuracy];
}

class AnalysisResult extends Equatable {
  final int accuracy;
  final double stability;
  final List<NoteDetection> notes;
  final String feedback;
  final List<String> targetNotes;
  final List<String> detectedNotes;
  final int noteAccuracy;
  final int pitchAccuracy;
  final int timingAccuracy;
  final int overallScore;
  final List<String> coachingTips;

  const AnalysisResult({
    required this.accuracy,
    required this.stability,
    required this.notes,
    required this.feedback,
    this.targetNotes = const [],
    this.detectedNotes = const [],
    this.noteAccuracy = 0,
    this.pitchAccuracy = 0,
    this.timingAccuracy = 0,
    this.overallScore = 0,
    this.coachingTips = const [],
  });

  String get targetNotesDisplay =>
      targetNotes.isEmpty ? 'C4 → D4 → E4 → G4' : targetNotes.join(' → ');

  String get detectedNotesDisplay =>
      detectedNotes.isNotEmpty
          ? detectedNotes.join(' → ')
          : (notes.isNotEmpty ? notes.map((n) => n.note).join(' → ') : 'None detected');

  @override
  List<Object> get props => [
        accuracy,
        stability,
        notes,
        feedback,
        targetNotes,
        detectedNotes,
        noteAccuracy,
        pitchAccuracy,
        timingAccuracy,
        overallScore,
        coachingTips,
      ];
}
