import 'package:equatable/equatable.dart';

abstract class AudioPracticeEvent extends Equatable {
  const AudioPracticeEvent();

  @override
  List<Object?> get props => [];
}

class StartRecordingEvent extends AudioPracticeEvent {
  const StartRecordingEvent();
}

class StopRecordingEvent extends AudioPracticeEvent {
  final String audioPath;
  final String? exerciseId;
  final int? userId;

  const StopRecordingEvent([
    this.audioPath = '',
    this.exerciseId,
    this.userId,
  ]);

  @override
  List<Object?> get props => [audioPath, exerciseId, userId];
}

class ResetEvent extends AudioPracticeEvent {
  const ResetEvent();
}

class AnalyzePerformanceEvent extends AudioPracticeEvent {
  final String audioPath;
  final String? exerciseId;
  final int? userId;

  const AnalyzePerformanceEvent(
    this.audioPath, {
    this.exerciseId,
    this.userId,
  });

  @override
  List<Object?> get props => [audioPath, exerciseId, userId];
}

