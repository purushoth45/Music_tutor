import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/analysis_result.dart';
import '../../../../core/api_config.dart';

class PracticeDataSource {
  final http.Client? client;

  PracticeDataSource({this.client});

  /// Uploads practice audio recording to backend FastAPI service `/api/audio-ai/analyze`.
  Future<AnalysisResult> analyzePerformance(
    String audioPath, {
    int userId = 1,
    String? exerciseId,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/audio-ai/analyze');

    if (audioPath.isEmpty) {
      throw Exception('Audio recording path is empty. Please record audio first.');
    }

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(ApiConfig.headers);
    request.fields['user_id'] = userId.toString();
    if (exerciseId != null && exerciseId.isNotEmpty) {
      request.fields['exercise_id'] = exerciseId;
    }
    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    final streamedResponse = client != null
        ? await client!.send(request)
        : await request.send();

    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode == 200) {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      // Parse structured notes list
      final rawNotes = data['notes'] as List<dynamic>?;
      List<NoteDetection> notesList = [];
      if (rawNotes != null && rawNotes.isNotEmpty) {
        notesList = rawNotes.map((n) {
          if (n is Map<String, dynamic>) {
            return NoteDetection(
              note: n['note']?.toString() ?? '',
              accuracy: (n['accuracy'] as num?)?.toInt() ?? 80,
            );
          }
          return NoteDetection(note: n.toString(), accuracy: 80);
        }).toList();
      } else if (data['detected_notes'] is List) {
        final detected = data['detected_notes'] as List<dynamic>;
        final acc = (data['accuracy_score'] as num?)?.toInt() ?? 80;
        notesList = detected
            .map((n) => NoteDetection(note: n.toString(), accuracy: acc))
            .toList();
      }

      // Parse target and detected notes lists
      final targetNotes = (data['target_notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      final detectedNotes = (data['detected_notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      // Parse coaching tips
      final coachingTips = (data['coaching_tips'] as List<dynamic>? ??
              data['detailed_feedback'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      final pitchAccuracy = (data['pitch_accuracy'] as num?)?.toInt() ??
          (data['accuracy_score'] as num?)?.toInt() ??
          0;
      final noteAccuracy = (data['note_accuracy'] as num?)?.toInt() ??
          (data['accuracy_score'] as num?)?.toInt() ??
          0;
      final timingAccuracy = (data['timing_accuracy'] as num?)?.toInt() ??
          (data['timing_score'] as num?)?.toInt() ??
          0;
      final stability = (data['stability_score'] as num?)?.toDouble() ?? 0.0;
      final overallScore = (data['overall_score'] as num?)?.toInt() ??
          ((pitchAccuracy + noteAccuracy) ~/ 2);
      final feedback = data['feedback'] as String? ?? "Analysis completed.";

      return AnalysisResult(
        accuracy: pitchAccuracy,
        stability: stability,
        notes: notesList,
        feedback: feedback,
        targetNotes: targetNotes,
        detectedNotes: detectedNotes,
        noteAccuracy: noteAccuracy,
        pitchAccuracy: pitchAccuracy,
        timingAccuracy: timingAccuracy,
        overallScore: overallScore,
        coachingTips: coachingTips,
      );
    } else {
      throw Exception(
        'Backend analysis failed (Status ${streamedResponse.statusCode}): $responseBody',
      );
    }
  }
}

