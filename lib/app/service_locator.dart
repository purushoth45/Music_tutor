import 'package:get_it/get_it.dart';
import '../features/authentication/data/datasources/auth_datasource.dart';
import '../features/authentication/data/repositories/auth_repository.dart';
import '../features/authentication/presentation/bloc/auth_bloc.dart';
import '../features/audio_practice/data/datasources/practice_datasource.dart';
import '../features/audio_practice/data/repositories/practice_repository.dart';
import '../features/audio_practice/presentation/bloc/audio_practice_bloc.dart';
import '../features/midi_practice/presentation/bloc/midi_practice_bloc.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';
import '../shared/utils/audio_service.dart';
import '../shared/utils/permission_handler.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Services
  getIt.registerSingleton<AudioService>(AudioService());
  getIt.registerSingleton<PermissionHandler>(PermissionHandler());

  // Data Sources
  getIt.registerSingleton<AuthDataSource>(AuthDataSource());
  getIt.registerSingleton<PracticeDataSource>(PracticeDataSource());

  // Repositories
  getIt.registerSingleton<AuthRepository>(
    AuthRepository(authDataSource: getIt<AuthDataSource>()),
  );
  getIt.registerSingleton<PracticeRepository>(
    PracticeRepository(practiceDataSource: getIt<PracticeDataSource>()),
  );

  // BLoCs
  getIt.registerSingleton<AuthBloc>(
    AuthBloc(authRepository: getIt<AuthRepository>()),
  );
  getIt.registerSingleton<AudioPracticeBloc>(
    AudioPracticeBloc(
      practiceRepository: getIt<PracticeRepository>(),
      permissionHandler: getIt<PermissionHandler>(),
      audioService: getIt<AudioService>(),
    ),
  );
  getIt.registerSingleton<MidiPracticeBloc>(
    MidiPracticeBloc(),
  );
  getIt.registerSingleton<ProfileBloc>(
    ProfileBloc(),
  );
}
