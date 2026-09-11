import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_tutor/features/authentication/domain/entities/user.dart';
import 'package:music_tutor/features/authentication/data/repositories/auth_repository.dart';
import 'package:music_tutor/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:music_tutor/features/authentication/presentation/bloc/auth_event.dart';
import 'package:music_tutor/features/authentication/presentation/bloc/auth_state.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('AuthBloc Tests', () {
    late AuthBloc authBloc;
    late MockAuthRepository mockAuthRepository;

    const mockUser = User(
      id: 'mt-7721',
      email: 'student1@musictutor.ai',
      role: 'TRAINEE',
      name: 'Music Learner',
      level: 'Intermediate • Level 5',
      sessionsPlayed: 12,
      averageAccuracy: 85,
      badges: ['Perfect Pitch'],
      streak: 15,
    );

    setUp(() {
      mockAuthRepository = MockAuthRepository();
      authBloc = AuthBloc(authRepository: mockAuthRepository);
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, const AuthInitial());
    });

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthAuthenticated] when LoginEvent succeeds',
      setUp: () {
        when(() => mockAuthRepository.login(any(), any()))
            .thenAnswer((_) async => mockUser);
      },
      build: () => authBloc,
      act: (bloc) => bloc.add(const LoginEvent(email: 'learner@tutor.com', password: 'password')),
      expect: () => [
        const AuthLoading(),
        const AuthAuthenticated(mockUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [AuthLoading, AuthError] when LoginEvent throws exception',
      setUp: () {
        when(() => mockAuthRepository.login(any(), any()))
            .thenThrow(Exception('Invalid credentials'));
      },
      build: () => authBloc,
      act: (bloc) => bloc.add(const LoginEvent(email: 'error@tutor.com', password: 'password')),
      expect: () => [
        const AuthLoading(),
        const AuthError('Invalid credentials'),
      ],
    );
  });
}
