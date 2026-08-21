import 'package:equatable/equatable.dart';

/// Servicio elegido por el paciente para su solicitud de reserva.
/// `cantidad` permite repetir el servicio en la misma solicitud.
class ServicioSeleccionadoEntity extends Equatable {
  final String servicioId;
  final String nombre;
  final double precioBase;
  final int cantidad;

  const ServicioSeleccionadoEntity({
    required this.servicioId,
    required this.nombre,
    required this.precioBase,
    this.cantidad = 1,
  });

  double get subtotal => precioBase * cantidad;

  ServicioSeleccionadoEntity copyWith({int? cantidad}) {
    return ServicioSeleccionadoEntity(
      servicioId: servicioId,
      nombre: nombre,
      precioBase: precioBase,
      cantidad: cantidad ?? this.cantidad,
    );
  }

  @override
  List<Object?> get props => [servicioId, nombre, precioBase, cantidad];
}
