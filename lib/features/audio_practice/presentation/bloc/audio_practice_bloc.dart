import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/user_session.dart';
import '../../../../shared/utils/permission_handler.dart';
import '../../../../shared/utils/audio_service.dart';
import '../../domain/repositories/practice_repository.dart';
import 'audio_practice_event.dart';
import 'audio_practice_state.dart';

class AudioPracticeBloc extends Bloc<AudioPracticeEvent, AudioPracticeState> {
  final PracticeRepository practiceRepository;
  final PermissionHandler permissionHandler;
  final AudioService? audioService;

  AudioPracticeBloc({
    required this.practiceRepository,
    required this.permissionHandler,
    this.audioService,
  }) : super(const AudioPracticeInitial()) {
    on<StartRecordingEvent>(_onStartRecording);
    on<StopRecordingEvent>(_onStopRecording);
    on<AnalyzePerformanceEvent>(_onAnalyzePerformance);
    on<ResetEvent>(_onReset);
  }

  Future<void> _onStartRecording(
    StartRecordingEvent event,
    Emitter<AudioPracticeState> emit,
  ) async {
    final hasPermission = await permissionHandler.requestAudioPermission();
    if (!hasPermission) {
      emit(const AudioPracticeError('Microphone permission is required to record audio.'));
      return;
    }


    try {
      if (audioService != null) {
        await audioService!.startRecording();
      }
      emit(const AudioRecording());
    } catch (e) {
      emit(AudioPracticeError('Failed to start recording: ${e.toString()}'));
    }
  }

  Future<void> _onStopRecording(
    StopRecordingEvent event,
    Emitter<AudioPracticeState> emit,
  ) async {
    emit(const AudioAnalyzing());
    try {
      final resolvedUserId = event.userId ??
          int.tryParse(UserSession.currentUser?.id ?? '');
      if (resolvedUserId == null) {
        emit(const AudioPracticeError(
            'No active user session. Please sign in before recording.'));
        return;
      }

      String recordedPath = event.audioPath;
      if (recordedPath.isEmpty && audioService != null) {
        final path = await audioService!.stopRecording();
        if (path != null && path.isNotEmpty) {
          recordedPath = path;
        }
      }

      if (recordedPath.isEmpty) {
        emit(const AudioPracticeError(
            'No audio was captured. Please speak or sing clearly into your microphone.'));
        return;
      }

      final result = await practiceRepository.analyzePerformance(
        recordedPath,
        userId: resolvedUserId,
        exerciseId: event.exerciseId,
      );
      emit(AudioAnalysisComplete(result));
    } catch (e) {
      emit(AudioPracticeError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onAnalyzePerformance(
    AnalyzePerformanceEvent event,
    Emitter<AudioPracticeState> emit,
  ) async {
    emit(const AudioAnalyzing());
    try {
      final resolvedUserId = event.userId ??
          int.tryParse(UserSession.currentUser?.id ?? '');
      if (resolvedUserId == null) {
        emit(const AudioPracticeError(
            'No active user session. Please sign in before recording.'));
        return;
      }

      final result = await practiceRepository.analyzePerformance(
        event.audioPath,
        userId: resolvedUserId,
        exerciseId: event.exerciseId,
      );
      emit(AudioAnalysisComplete(result));
    } catch (e) {
      emit(AudioPracticeError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  void _onReset(ResetEvent event, Emitter<AudioPracticeState> emit) {
    emit(const AudioPracticeInitial());
  }
}
