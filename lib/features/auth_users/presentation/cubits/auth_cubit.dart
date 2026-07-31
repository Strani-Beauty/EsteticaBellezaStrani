import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final ProfileEntity profile;
  const AuthAuthenticated(this.profile);
  @override
  List<Object?> get props => [profile];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  final String? code;
  const AuthError(this.message, {this.code});
  @override
  List<Object?> get props => [message, code];
}

class AuthEmailConfirmationSent extends AuthState {
  final String email;
  const AuthEmailConfirmationSent(this.email);
  @override
  List<Object?> get props => [email];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────

/// AuthCubit gestiona el ciclo de vida de autenticación.
/// Reemplaza todo el setState() del _LoginScreenState original.
class AuthCubit extends Cubit<AuthState> {
  final IAuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(const AuthInitial());

  // ── Inicialización (comprobar sesión activa al arrancar) ────
  Future<void> checkCurrentSession() async {
    emit(const AuthLoading());
    final result = await _authRepository.getCurrentProfile();
    result.fold(
      (failure) => emit(const AuthUnauthenticated()),
      (profile) => emit(AuthAuthenticated(profile)),
    );
  }

  // ── Sign In ─────────────────────────────────────────────────
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(const AuthLoading());
    final result = await _authRepository.signIn(
      email: email,
      password: password,
    );
    result.fold(
      (failure) {
        if (failure.code == 'email_not_confirmed') {
          emit(AuthEmailConfirmationSent(email));
        } else {
          emit(AuthError(failure.message, code: failure.code));
        }
      },
      (profile) => emit(AuthAuthenticated(profile)),
    );
  }

  // ── Sign Up ─────────────────────────────────────────────────
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String rolNombre,
    String? phone,
  }) async {
    emit(const AuthLoading());
    final result = await _authRepository.signUp(
      email: email,
      password: password,
      fullName: fullName,
      rolNombre: rolNombre,
      phone: phone,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message, code: failure.code)),
      (profile) {
        // Si requiere confirmación de correo → estado especial
        if (!profile.activo) {
          emit(AuthEmailConfirmationSent(email));
        } else {
          emit(AuthAuthenticated(profile));
        }
      },
    );
  }

  // ── Update Profile ──────────────────────────────────────────
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? address,
    double? latitude,
    double? longitude,
    bool? activo,
    bool? paymentCompleted,
    bool? evaluationPassed,
  }) async {
    emit(const AuthLoading());
    final result = await _authRepository.updateProfile(
      userId: userId,
      fullName: fullName,
      phone: phone,
      address: address,
      latitude: latitude,
      longitude: longitude,
      activo: activo,
      paymentCompleted: paymentCompleted,
      evaluationPassed: evaluationPassed,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (profile) => emit(AuthAuthenticated(profile)),
    );
  }

  // ── Sign Out ────────────────────────────────────────────────
  Future<void> signOut() async {
    emit(const AuthLoading());
    final result = await _authRepository.signOut();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(const AuthUnauthenticated()),
    );
  }

  // ── Reset Password ──────────────────────────────────────────
  Future<void> resetPassword(String email) async {
    await _authRepository.resetPassword(email);
  }

  // ── Getters de conveniencia ─────────────────────────────────
  ProfileEntity? get currentProfile =>
      state is AuthAuthenticated ? (state as AuthAuthenticated).profile : null;

  bool get isAuthenticated => state is AuthAuthenticated;
  bool get isLoading => state is AuthLoading;
}
