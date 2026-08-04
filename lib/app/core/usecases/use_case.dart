import 'package:fpdart/fpdart.dart';
import '../error/failures.dart';

/// Contrato base para todos los Use Cases de la aplicación.
///
/// [T] = Tipo de retorno exitoso
/// [Params] = Parámetros de entrada
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Use Case sin parámetros (e.g. GetCurrentUser, SignOut)
abstract class NoParamsUseCase<T> {
  Future<Either<Failure, T>> call();
}

/// Clase sentinel para UseCases sin parámetros
class NoParams {
  const NoParams();
}
