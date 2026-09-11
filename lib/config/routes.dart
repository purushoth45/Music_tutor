import 'package:go_router/go_router.dart';
import '../features/authentication/presentation/pages/splash_screen.dart';
import '../features/authentication/presentation/pages/onboarding_screen.dart';
import '../features/authentication/presentation/pages/login_screen.dart';
import '../features/authentication/presentation/pages/trainer_signup_screen.dart';
import '../features/dashboard/presentation/pages/main_tabs_screen.dart';
import '../features/dashboard/presentation/pages/dashboard_screen.dart';
import '../features/dashboard/presentation/pages/second_tab_wrapper_screen.dart';
import '../features/midi_practice/presentation/pages/midi_practice_screen.dart';
import '../features/profile/presentation/pages/profile_screen.dart';
import '../features/settings/presentation/pages/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/trainer-signup',
      builder: (context, state) => const TrainerSignupScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainTabsScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/audio-practice',
              builder: (context, state) => const SecondTabWrapperScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/midi-practice',
      builder: (context, state) => const MidiPracticeScreen(),
    ),
  ],
);
