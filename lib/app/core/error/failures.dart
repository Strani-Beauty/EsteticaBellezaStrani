// ─────────────────────────────────────────────────────────────────────────────
// FAILURES — Manejo de errores tipado con sealed class (fpdart compatible)
// Úsalos en: Either<Failure, T>
// ─────────────────────────────────────────────────────────────────────────────

abstract class Failure {
  final String message;
  final String? code;
  const Failure(this.message, {this.code});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' [$code]' : ''}';
}

/// Error de servidor o red (Supabase, HTTP)
class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code});
}

/// Error de red sin conexión
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexión a internet.']);
}

/// Error de autenticación (credenciales inválidas, sesión expirada)
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

/// Error de validación de negocio (RN-020, RN-022, etc.)
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

/// Error de permisos RLS o acceso denegado
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Acceso denegado.']);
}

/// Error al procesar pago (Stripe)
class PaymentFailure extends Failure {
  const PaymentFailure(super.message, {super.code});
}

/// Error de almacenamiento (Supabase Storage)
class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.code});
}

/// Error cuando el recurso no existe
class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Recurso no encontrado.']);
}

/// Error de telemedicina / validación médica (RN-020, RN-022)
class TelemedinaFailure extends Failure {
  const TelemedinaFailure(super.message, {super.code});
}

/// Error cuando un tratamiento completado es inmutable (RN-044)
class ImmutableRecordFailure extends Failure {
  const ImmutableRecordFailure([super.message = 'Este registro ya no puede ser modificado.']);
}
