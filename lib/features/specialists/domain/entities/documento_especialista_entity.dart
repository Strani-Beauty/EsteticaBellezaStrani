import 'package:equatable/equatable.dart';

enum EstadoDocumento { pendiente, aprobado, rechazado, vencido }

class DocumentoEspecialistaEntity extends Equatable {
  final String id;                // UUID
  final String especialistaId;   // FK especialistas.id
  final String tipoDocumento;    // 'cedula' | 'licencia' | 'diploma' | 'seguro'
  final String? storageUrl;      // URL en Supabase Storage bucket privado
  final int versionDocumento;    // Versión del documento
  final EstadoDocumento estado;
  final DateTime? fechaVencimiento;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DocumentoEspecialistaEntity({
    required this.id,
    required this.especialistaId,
    required this.tipoDocumento,
    this.storageUrl,
    required this.versionDocumento,
    required this.estado,
    this.fechaVencimiento,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isVigente =>
      estado == EstadoDocumento.aprobado &&
      (fechaVencimiento == null || fechaVencimiento!.isAfter(DateTime.now()));

  @override
  List<Object?> get props => [id, especialistaId, tipoDocumento, versionDocumento, estado];
}
