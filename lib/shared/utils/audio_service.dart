import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  late final Record _recorder;
  String? _recordingPath;

  AudioService() {
    _recorder = Record();
  }

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final recordingPath =
            '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
        
        await _recorder.start(
          path: recordingPath,
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          samplingRate: 16000,
        );
        
        _recordingPath = recordingPath;
      } else {
        throw Exception('Audio recording permission not granted');
      }
    } catch (e) {
      throw Exception('Failed to start recording: $e');
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      return path ?? _recordingPath;
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
