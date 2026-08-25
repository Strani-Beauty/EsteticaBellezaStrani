import 'package:equatable/equatable.dart';

/// Face map del especialista para un tratamiento en ejecución.
/// Carga el mapa existente del paciente (si lo hay) o el que el especialista
/// haya guardado vinculado al tratamiento.
class FaceMapEspecialistaEntity extends Equatable {
  final String? id;
  final String? tratamientoId;
  final String? pacienteId;
  final String? servicioId;
  final String? tipoMapa;
  final String? imagenBaseUrl;
  final String? observaciones;
  final List<Map<String, dynamic>> puntos;

  const FaceMapEspecialistaEntity({
    this.id,
    this.tratamientoId,
    this.pacienteId,
    this.servicioId,
    this.tipoMapa,
    this.imagenBaseUrl,
    this.observaciones,
    this.puntos = const [],
  });

  bool get existe => id != null && id!.isNotEmpty;

  FaceMapEspecialistaEntity copyWith({
    String? id,
    String? tratamientoId,
    String? pacienteId,
    String? servicioId,
    String? tipoMapa,
    String? imagenBaseUrl,
    String? observaciones,
    List<Map<String, dynamic>>? puntos,
  }) {
    return FaceMapEspecialistaEntity(
      id: id ?? this.id,
      tratamientoId: tratamientoId ?? this.tratamientoId,
      pacienteId: pacienteId ?? this.pacienteId,
      servicioId: servicioId ?? this.servicioId,
      tipoMapa: tipoMapa ?? this.tipoMapa,
      imagenBaseUrl: imagenBaseUrl ?? this.imagenBaseUrl,
      observaciones: observaciones ?? this.observaciones,
      puntos: puntos ?? this.puntos,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tratamientoId,
        pacienteId,
        servicioId,
        tipoMapa,
        imagenBaseUrl,
        observaciones,
        puntos,
      ];
}