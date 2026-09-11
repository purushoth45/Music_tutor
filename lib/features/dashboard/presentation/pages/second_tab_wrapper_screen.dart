import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/user_session.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import 'practice_hub_screen.dart';
import 'trainer_students_screen.dart';

class SecondTabWrapperScreen extends StatelessWidget {
  const SecondTabWrapperScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isTrainer = (state is AuthAuthenticated && state.user.isTrainer) || UserSession.isTrainer;

        if (isTrainer) {
          return const TrainerStudentsScreen();
        }
        return const PracticeHubScreen();
      },
    );
  }
}
