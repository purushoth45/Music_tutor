import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/routes.dart';
import '../features/authentication/presentation/bloc/auth_bloc.dart';
import '../features/audio_practice/presentation/bloc/audio_practice_bloc.dart';
import '../features/midi_practice/presentation/bloc/midi_practice_bloc.dart';
import '../features/profile/presentation/bloc/profile_bloc.dart';
import '../shared/themes/app_theme.dart';
import '../shared/themes/theme_controller.dart';
import 'service_locator.dart';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => getIt<AuthBloc>(),
        ),
        BlocProvider<AudioPracticeBloc>(
          create: (context) => getIt<AudioPracticeBloc>(),
        ),
        BlocProvider<MidiPracticeBloc>(
          create: (context) => getIt<MidiPracticeBloc>(),
        ),
        BlocProvider<ProfileBloc>(
          create: (context) => getIt<ProfileBloc>(),
        ),
      ],
      child: ListenableBuilder(
        listenable: themeController,
        builder: (context, child) {
          return MaterialApp.router(
            title: 'Music Tutor',
            theme: AppTheme.getThemeData(
              isDark: false,
              primary: themeController.primaryColor,
              secondary: themeController.secondaryColor,
            ),
            darkTheme: AppTheme.getThemeData(
              isDark: true,
              primary: themeController.primaryColor,
              secondary: themeController.secondaryColor,
            ),
            themeMode: themeController.themeMode,
            routerConfig: appRouter,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
