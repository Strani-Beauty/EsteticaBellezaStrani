import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/cuestionario_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/estado_salud_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/evaluacion_salud_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/paciente_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TipoRespuestaPregunta → BD', () {
    test('mapea a los valores del enum public.tipo_respuesta_enum', () {
      expect(TipoRespuestaPregunta.siNo.toDb(), 'SI_NO');
      expect(TipoRespuestaPregunta.texto.toDb(), 'TEXTO');
      expect(TipoRespuestaPregunta.numero.toDb(), 'NUMERO');
      expect(TipoRespuestaPregunta.decimal.toDb(), 'DECIMAL');
      expect(TipoRespuestaPregunta.fecha.toDb(), 'FECHA');
      expect(TipoRespuestaPregunta.lista.toDb(), 'LISTA');
      expect(TipoRespuestaPregunta.multiple.toDb(), 'MULTIPLE');
      expect(TipoRespuestaPregunta.archivo.toDb(), 'ARCHIVO');
      expect(TipoRespuestaPregunta.imagen.toDb(), 'IMAGEN');
    });

    test('fromDb es tolerante a mayúsculas/minúsculas y con fallback TEXTO', () {
      expect(TipoRespuestaPreguntaX.fromDb('si_no'), TipoRespuestaPregunta.siNo);
      expect(TipoRespuestaPreguntaX.fromDb('MULTIPLE'), TipoRespuestaPregunta.multiple);
      expect(TipoRespuestaPreguntaX.fromDb(null), TipoRespuestaPregunta.texto);
      expect(TipoRespuestaPreguntaX.fromDb('DESCONOCIDO'), TipoRespuestaPregunta.texto);
    });
  });

  group('ResultadoEvaluacion → BD', () {
    test('mapea apto/requiereRevision/noApto', () {
      expect(ResultadoEvaluacion.apto.toDb(), 'APTO');
      expect(ResultadoEvaluacion.requiereRevision.toDb(), 'REQUIERE_REVISION');
      expect(ResultadoEvaluacion.noApto.toDb(), 'NO_APTO');
    });

    test('fromDb devuelve null para valores desconocidos', () {
      expect(ResultadoEvaluacionX.fromDb('APTO'), ResultadoEvaluacion.apto);
      expect(ResultadoEvaluacionX.fromDb('PENDIENTE'), isNull);
    });
  });

  group('ResultadoEvaluacionRegistrada.fromJson', () {
    test('parsea resultado y riesgos de la RPC', () {
      final r = ResultadoEvaluacionRegistrada.fromJson({
        'id': 'eval-1',
        'resultado': 'REQUIERE_REVISION',
        'version_cuestionario': 2,
        'fecha_evaluacion': '2026-08-18T12:00:00.000Z',
        'riesgos': [
          {'pregunta_id': 1, 'etiqueta': 'Alergia', 'critico': false},
        ],
      });
      expect(r.evaluacionId, 'eval-1');
      expect(r.resultado, ResultadoEvaluacion.requiereRevision);
      expect(r.versionCuestionario, 2);
      expect(r.riesgos.single.preguntaId, 1);
      expect(r.riesgos.single.critico, isFalse);
    });
  });

  group('Gate RN-020 (validación vigente)', () {
    ValidacionTelemedicinaEntity validacion(String estado, {DateTime? vencimiento}) =>
        ValidacionTelemedicinaEntity(
          id: 'v1',
          pacienteId: 'p1',
          proveedor: 'Telemedicina',
          estado: estado,
          fechaVencimiento: vencimiento,
          createdAt: DateTime(2026, 1, 1),
        );

    test('vigente si APROBADA con vencimiento futuro', () {
      final v = validacion('APROBADA',
          vencimiento: DateTime.now().add(const Duration(days: 30)));
      expect(v.vigente, isTrue);
      expect(v.bloqueaReserva, isFalse);
    });

    test('vencida si APROBADA pero pasó el vencimiento', () {
      final v = validacion('APROBADA',
          vencimiento: DateTime.now().subtract(const Duration(days: 1)));
      expect(v.vigente, isFalse);
      expect(v.vencida, isTrue);
      expect(v.bloqueaReserva, isTrue);
    });

    test('bloquea reserva si PENDIENTE o RECHAZADA', () {
      expect(validacion('PENDIENTE').bloqueaReserva, isTrue);
      expect(validacion('RECHAZADA').bloqueaReserva, isTrue);
    });
  });

  group('EstadoSaludEntity.habilitado (requisito 12/13)', () {
    EstadoSaludEntity estado({
      bool payment = true,
      bool cuestionario = true,
      String resultado = 'APTO',
      String validacion = 'APROBADA',
      DateTime? vencimiento,
    }) =>
        EstadoSaludEntity(
          paymentCompleted: payment,
          cuestionarioCompletado: cuestionario,
          evaluacionResultado: resultado,
          validacionEstado: validacion,
          proveedor: 'Telemedicina',
          fechaVencimiento: vencimiento ?? DateTime.now().add(const Duration(days: 300)),
        );

    test('habilitado con validación vigente', () {
      expect(estado().habilitado, isTrue);
      expect(estado().siguientePaso, contains('habilitado'));
    });

    test('no habilitado si validación vencida', () {
      final e = estado(
        vencimiento: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(e.validacionVencida, isTrue);
      expect(e.habilitado, isFalse);
      expect(e.siguientePaso, contains('venció'));
    });

    test('siguiente paso depende del estado', () {
      expect(estado(payment: false).siguientePaso, contains('cuota inicial'));
      expect(estado(cuestionario: false).siguientePaso, contains('cuestionario'));
      expect(estado(validacion: 'RECHAZADA').siguientePaso, contains('rechazada'));
    });
  });

  group('RiesgoSentinel / RiesgoDetectado (JSON)', () {
    test('RiesgoSentinel.fromJson mapea detonante/etiqueta/critico', () {
      final r = RiesgoSentinel.fromJson({
        'detonante': 'SI',
        'etiqueta': 'Embarazo o lactancia',
        'critico': true,
      });
      expect(r.detonante, 'SI');
      expect(r.etiqueta, 'Embarazo o lactancia');
      expect(r.critico, isTrue);
    });

    test('RiesgoDetectado.fromJson mapea pregunta_id', () {
      final r = RiesgoDetectado.fromJson({
        'pregunta_id': 3,
        'etiqueta': 'Condición médica',
        'critico': false,
      });
      expect(r.preguntaId, 3);
      expect(r.etiqueta, 'Condición médica');
    });
  });

  group('PacienteEntity.edad', () {
    test('calcula edad a partir de fecha_nacimiento', () {
      final nacimiento = DateTime(1990, 5, 20);
      final p = PacienteEntity(
        id: 'p1',
        profileId: 'u1',
        fechaNacimiento: nacimiento,
        activo: true,
        createdAt: DateTime(2026, 1, 1),
      );
      final hoy = DateTime.now();
      var esperada = hoy.year - 1990;
      if (hoy.month < 5 || (hoy.month == 5 && hoy.day < 20)) esperada--;
      expect(p.edad, esperada);
      expect(p.genero, isNull);
    });
  });
}