import 'package:flutter_test/flutter_test.dart';
import 'package:esteticaybellezastrani/features/specialists/domain/entities/especialista_entity.dart';

void main() {
  group('EstadoVerificacion', () {
    test('toDb mapea cada estado a su string de BD', () {
      expect(EstadoVerificacion.pendiente.toDb, 'PENDIENTE');
      expect(EstadoVerificacion.enRevision.toDb, 'EN_REVISION');
      expect(EstadoVerificacion.aprobado.toDb, 'APROBADO');
      expect(EstadoVerificacion.rechazado.toDb, 'RECHAZADO');
      expect(EstadoVerificacion.bloqueado.toDb, 'BLOQUEADO');
    });

    test('fromDb resuelve strings conocidos (case-insensitive)', () {
      expect(EstadoVerificacion.fromDb('PENDIENTE'), EstadoVerificacion.pendiente);
      expect(EstadoVerificacion.fromDb('en_revision'), EstadoVerificacion.enRevision);
      expect(EstadoVerificacion.fromDb('APROBADO'), EstadoVerificacion.aprobado);
      expect(EstadoVerificacion.fromDb('rechazado'), EstadoVerificacion.rechazado);
      expect(EstadoVerificacion.fromDb('BLOQUEADO'), EstadoVerificacion.bloqueado);
    });

    test('fromDb devuelve null para valor nulo o desconocido', () {
      expect(EstadoVerificacion.fromDb(null), isNull);
      expect(EstadoVerificacion.fromDb('OTRO'), isNull);
    });
  });

  group('EspecialistaEntity', () {
    EspecialistaEntity build({EstadoVerificacion estado = EstadoVerificacion.pendiente}) {
      return EspecialistaEntity(
        id: 'esp-1',
        usuarioId: 'user-1',
        estadoVerificacion: estado,
        disponible: false,
        activo: false,
        createdAt: DateTime(2026, 8, 13),
      );
    }

    test('isPending es true cuando el estado es pendiente', () {
      expect(build(estado: EstadoVerificacion.pendiente).isPending, isTrue);
    });

    test('isApproved es false cuando el estado es pendiente', () {
      expect(build(estado: EstadoVerificacion.pendiente).isApproved, isFalse);
    });

    test('isApproved es true cuando el estado es aprobado', () {
      expect(build(estado: EstadoVerificacion.aprobado).isApproved, isTrue);
    });

    test('copyWith permite cambiar estadoVerificacion y disponible', () {
      final entity = build();
      final updated = entity.copyWith(
        estadoVerificacion: EstadoVerificacion.aprobado,
        disponible: true,
        activo: true,
      );
      expect(updated.estadoVerificacion, EstadoVerificacion.aprobado);
      expect(updated.disponible, isTrue);
      expect(updated.activo, isTrue);
      expect(updated.isApproved, isTrue);
      expect(updated.id, entity.id);
      expect(updated.usuarioId, entity.usuarioId);
    });

    test('copyWith conserva campos no modificados', () {
      final entity = build(estado: EstadoVerificacion.rechazado);
      final updated = entity.copyWith(disponible: true);
      expect(updated.estadoVerificacion, EstadoVerificacion.rechazado);
      expect(updated.numeroLicencia, entity.numeroLicencia);
    });

    test('props incluye los campos relevantes para igualdad', () {
      final entity = build();
      expect(
        entity.props,
        [
          'esp-1',
          'user-1',
          null,
          null,
          EstadoVerificacion.pendiente,
          null,
          null,
          null,
          null,
          null,
          false,
          false,
          false,
          null,
          null,
          null,
        ],
      );
    });

    test('dos entidades con distinta licencia no son iguales', () {
      final a = build();
      final b = a.copyWith(numeroLicencia: 'LIC-999');
      expect(a, isNot(equals(b)));
    });
  });
}
