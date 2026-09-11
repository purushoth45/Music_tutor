import '../datasources/auth_datasource.dart';
import '../../domain/entities/user.dart';

class AuthRepository {
  final AuthDataSource authDataSource;

  AuthRepository({required this.authDataSource});

  Future<User> login(String email, String password) async {
    return await authDataSource.login(email, password);
  }
}
