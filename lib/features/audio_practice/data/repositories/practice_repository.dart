import '../datasources/practice_datasource.dart';
import '../../domain/entities/analysis_result.dart';

class PracticeRepository {
  final PracticeDataSource practiceDataSource;

  PracticeRepository({required this.practiceDataSource});

  Future<AnalysisResult> analyzePerformance(
    String audioPath, {
    int userId = 1,
    String? exerciseId,
  }) async {
    return await practiceDataSource.analyzePerformance(
      audioPath,
      userId: userId,
      exerciseId: exerciseId,
    );
  }
}
