import '../features/authentication/domain/entities/user.dart';

class UserSession {
  static User? currentUser;

  static bool get isTrainer {
    if (currentUser != null) {
      return currentUser!.isTrainer;
    }
    return false;
  }
}
