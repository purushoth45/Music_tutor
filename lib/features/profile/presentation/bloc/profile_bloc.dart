import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/user_session.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(const ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
  }

  Future<void> _onLoadProfile(LoadProfileEvent event, Emitter<ProfileState> emit) async {
    emit(const ProfileLoading());
    final current = UserSession.currentUser;
    if (current != null) {
      emit(ProfileLoaded(current));
    } else {
      emit(const ProfileError('No authenticated user profile available.'));
    }
  }
}

