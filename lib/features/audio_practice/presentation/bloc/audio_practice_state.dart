import 'package:equatable/equatable.dart';
import '../../domain/entities/analysis_result.dart';

abstract class AudioPracticeState extends Equatable {
  const AudioPracticeState();

  @override
  List<Object?> get props => [];
}

class AudioPracticeInitial extends AudioPracticeState {
  const AudioPracticeInitial();
}

class AudioRecording extends AudioPracticeState {
  const AudioRecording();
}

class AudioAnalyzing extends AudioPracticeState {
  const AudioAnalyzing();
}

class AudioAnalysisComplete extends AudioPracticeState {
  final AnalysisResult result;
  const AudioAnalysisComplete(this.result);

  @override
  List<Object?> get props => [result];
}

class AudioPracticeError extends AudioPracticeState {
  final String message;
  const AudioPracticeError(this.message);

  @override
  List<Object?> get props => [message];
}
