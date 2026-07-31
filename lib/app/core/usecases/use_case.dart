import 'package:fpdart/fpdart.dart';
import '../error/failures.dart';

/// Contrato base para todos los Use Cases de la aplicación.
///
/// [Type] = Tipo de retorno exitoso
/// [Params] = Parámetros de entrada
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// Use Case sin parámetros (e.g. GetCurrentUser, SignOut)
abstract class NoParamsUseCase<Type> {
  Future<Either<Failure, Type>> call();
}

/// Clase sentinel para UseCases sin parámetros
class NoParams {
  const NoParams();
}
