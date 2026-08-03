import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:esteticaybellezastrani/app/config/map_config.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static SupabaseClient get client => _client;
  static User? get currentUser => _client.auth.currentUser;

  // ── Caché de Sesión & Rate-Limiting para Geocoding ──
  static final Map<String, LatLng> _geocodeCache = {};
  static DateTime? _lastGeocodeAt;
  static DateTime? _edgeRetryAfter;

  /// Autenticación e ingreso de usuario
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registro de un nuevo Usuario (Paciente) en Supabase + crear perfil + crear paciente
  static Future<AuthResponse> signUpUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
  }) async {
    final String normalizedRole = (role.toLowerCase() == 'paciente' ||
            role.toLowerCase() == 'cliente')
        ? 'Paciente'
        : role;

    debugPrint('🔐 [signUpUser] Registrando usuario: email=$email role=$normalizedRole');

    // 1. Registrar en auth.users
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': normalizedRole,
      },
    );

    final user = response.user;
    if (user == null) {
      debugPrint('❌ [signUpUser] auth.signUp devolvió user=null');
      return response;
    }

    debugPrint('✅ [signUpUser] auth.user creado id=${user.id}');

    // 2. Crear o asegurar perfil en profiles
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': email,
        'full_name': fullName,
        'role': normalizedRole,
        'phone': phone ?? '',
        'activo': false,
        'payment_completed': false,
        'evaluation_passed': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      debugPrint('✅ [signUpUser] profiles upsertado correctamente para ${user.id}');
    } catch (e) {
      debugPrint('❌ [signUpUser] ERROR profiles.upsert: $e');
      try {
        await _client.from('profiles').update({
          'role': normalizedRole,
          'full_name': fullName,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
        debugPrint('✅ [signUpUser] profiles.update fallback ok');
      } catch (e2) {
        debugPrint('❌ [signUpUser] FALLBACK profiles.update ERROR: $e2');
      }
    }

    // 3. Crear registro en tabla pacientes
    if (normalizedRole == 'Paciente') {
      try {
        await _client.from('pacientes').upsert({
          'profile_id': user.id,
          'activo': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'profile_id');
        debugPrint('✅ [signUpUser] pacientes upsertado correctamente para ${user.id}');
      } catch (e) {
        debugPrint('❌ [signUpUser] ERROR pacientes.upsert: $e');
        try {
          await _client.from('pacientes').insert({
            'profile_id': user.id,
            'activo': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          debugPrint('✅ [signUpUser] pacientes.insert fallback ok');
        } catch (e2) {
          debugPrint('❌ [signUpUser] FALLBACK pacientes.insert ERROR: $e2');
        }
      }
    }

    return response;
  }

  /// Geocodifica una dirección libre a coordenadas con Caché y Throttling (Rate Limiting)
  static Future<LatLng?> geocodeAddress(String address) async {
    final sanitized = _sanitizeAddress(address);
    if (sanitized == null) return null;

    final cacheKey = sanitized.toLowerCase();
    if (_geocodeCache.containsKey(cacheKey)) {
      debugPrint('📍 [Geocoding Cache Hit]: $sanitized');
      return _geocodeCache[cacheKey];
    }

    await _respectRateLimit();

    // 1. Intentar vía Supabase Edge Function
    LatLng? position = await _geocodeViaEdgeFunction(sanitized);

    // 2. Fallback directo a Nominatim si Edge Function falla u offline
    position ??= await _geocodeViaNominatimFallback(sanitized);

    if (position != null) {
      _geocodeCache[cacheKey] = position;
    }

    return position;
  }

  static String? _sanitizeAddress(String? address) {
    if (address == null) return null;
    final cleaned = address.trim();
    if (cleaned.isEmpty || cleaned.length < 3) return null;
    return cleaned;
  }

  static Future<void> _respectRateLimit() async {
    final last = _lastGeocodeAt;
    if (last == null) {
      _lastGeocodeAt = DateTime.now();
      return;
    }
    final elapsed = DateTime.now().difference(last).inMilliseconds;
    if (elapsed < kGeocodeMinIntervalMs) {
      final waitMs = kGeocodeMinIntervalMs - elapsed;
      debugPrint('⏳ [Geocoding Rate Limit] Esperando ${waitMs}ms...');
      await Future.delayed(Duration(milliseconds: waitMs));
    }
    _lastGeocodeAt = DateTime.now();
  }

  static Future<LatLng?> _geocodeViaEdgeFunction(String address) async {
    final retryAfter = _edgeRetryAfter;
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
      return null;
    }

    try {
      final response = await _client.functions
          .invoke('geocode-address', body: {'address': address})
          .timeout(const Duration(seconds: 5));

      final data = response.data;
      if (data is Map<String, dynamic> && data['found'] == true) {
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
      return null;
    } catch (e) {
      _edgeRetryAfter = DateTime.now().add(const Duration(seconds: 60));
      debugPrint('⚠️ Supabase Edge Function geocode-address no disponible: $e');
      return null;
    }
  }

  static Future<LatLng?> _geocodeViaNominatimFallback(String address) async {
    try {
      // Si la dirección no menciona Cagua o Aragua, añadir sufijo para contextualizar
      String query = address;
      if (!query.toLowerCase().contains('cagua') && !query.toLowerCase().contains('aragua')) {
        query = '$address, Cagua, Aragua, Venezuela';
      }

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );
      final resp = await http.get(url, headers: {
        'User-Agent': kNominatimUserAgent,
        'Accept-Language': 'es',
      }).timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final results = json.decode(resp.body) as List;
        if (results.isNotEmpty) {
          final first = results.first;
          final lat = double.tryParse(first['lat'].toString());
          final lng = double.tryParse(first['lon'].toString());
          if (lat != null && lng != null) {
            return LatLng(lat, lng);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Fallback Nominatim error: $e');
    }
    return null;
  }

  static void clearGeocodeCache() {
    _geocodeCache.clear();
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS INTERNOS DE RESOLUCIÓN DE IDs
  // ══════════════════════════════════════════════════════════════

  /// Obtiene el UUID propio de la tabla `pacientes` a partir del profile_id (usuario_id)
  static Future<String?> _getPacienteId(String profileId) async {
    try {
      final res = await _client
          .from('pacientes')
          .select('id')
          .eq('usuario_id', profileId)
          .maybeSingle();
      final id = res?['id'] as String?;
      debugPrint('🔍 [_getPacienteId] profileId=$profileId → pacienteId=$id');
      return id;
    } catch (e) {
      debugPrint('❌ [_getPacienteId] ERROR: $e');
      return null;
    }
  }

  /// Asegura que exista un registro en `pacientes` y devuelve su UUID
  static Future<String?> _ensurePaciente(String profileId) async {
    // 1. Intentar obtener el existente
    String? pacienteId = await _getPacienteId(profileId);
    if (pacienteId != null) return pacienteId;

    // 2. No existe → crearlo
    debugPrint('📝 [_ensurePaciente] No existe paciente para $profileId, creando...');
    try {
      final res = await _client.from('pacientes').insert({
        'usuario_id': profileId,
        'activo': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select('id').maybeSingle();
      pacienteId = res?['id'] as String?;
      debugPrint('✅ [_ensurePaciente] Paciente creado id=$pacienteId');
      return pacienteId;
    } catch (e) {
      debugPrint('❌ [_ensurePaciente] ERROR insertando paciente: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // CREAR SOLICITUD + PAGO + TRANSACCIÓN (AL APROBARSE QUALIFY)
  // ══════════════════════════════════════════════════════════════

  /// Lee el monto de depósito configurado en la tabla `configuracion_sistema`
  static Future<double> _getDepositoReserva() async {
    try {
      final res = await _client
          .from('configuracion_sistema')
          .select('valor')
          .eq('clave', 'deposito_reserva')
          .maybeSingle();
      return double.tryParse(res?['valor']?.toString() ?? '30.00') ?? 30.00;
    } catch (_) {
      return 30.00;
    }
  }

  /// Devuelve el id de la dirección principal del paciente en `direcciones_paciente`
  static Future<String?> _getDireccionPrincipal(String pacienteId) async {
    try {
      final res = await _client
          .from('direcciones_paciente')
          .select('id')
          .eq('paciente_id', pacienteId)
          .eq('es_principal', true)
          .maybeSingle();
      return res?['id'] as String?;
    } catch (e) {
      debugPrint('⚠️ [_getDireccionPrincipal] $e');
      return null;
    }
  }

  /// Obtiene el primer servicio activo de la tabla `servicios`
  static Future<Map<String, dynamic>?> _getServicioActivo() async {
    try {
      final res = await _client
          .from('servicios')
          .select('id, nombre, precio_base')
          .eq('activo', true)
          .limit(1)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('⚠️ [_getServicioActivo] $e');
      return null;
    }
  }

  /// Crea la cadena: `solicitudes` → `pagos` → `transacciones`
  /// Se llama una única vez al aprobarse la evaluación Qualify.
  static Future<String?> createSolicitudAndPayment({
    required String profileId,
    required String stripePaymentRef,
  }) async {
    debugPrint('📦 [createSolicitudAndPayment] profileId=$profileId');

    // 1. Resolver IDs necesarios
    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      debugPrint('❌ [createSolicitudAndPayment] No se pudo obtener pacienteId');
      return null;
    }

    final direccionId = await _getDireccionPrincipal(pacienteId);
    final servicio    = await _getServicioActivo();
    final deposito    = await _getDepositoReserva();

    final servicioId   = servicio?['id'] as String?;
    final precioBase   = (servicio?['precio_base'] as num?)?.toDouble() ?? 0.0;

    if (servicioId == null) {
      debugPrint('❌ [createSolicitudAndPayment] No hay servicios activos en la BD');
      return null;
    }
    if (direccionId == null) {
      debugPrint('⚠️ [createSolicitudAndPayment] Sin dirección principal, continuando...');
    }

    // 2. Crear solicitud (estado BORRADOR — fecha_programada se define después)
    String? solicitudId;
    try {
      final solRes = await _client.from('solicitudes').insert({
        'paciente_id':       pacienteId,
        'servicio_id':       servicioId,
        'direccion_id':      direccionId,   // puede ser null si no hay dirección aún
        'estado':            'BORRADOR',
        'deposito_requerido': deposito,
        'deposito_pagado':   true,
      }).select('id').maybeSingle();
      solicitudId = solRes?['id'] as String?;
      debugPrint('✅ [createSolicitudAndPayment] solicitud creada id=$solicitudId');
    } catch (e) {
      debugPrint('❌ [createSolicitudAndPayment] ERROR solicitudes.insert: $e');
      return null;
    }

    if (solicitudId == null) return null;

    // 3. Crear pago (obligación comercial vinculada a la solicitud)
    try {
      await _client.from('pagos').insert({
        'solicitud_id':    solicitudId,
        'monto_total':     precioBase,
        'deposito':        deposito,
        'saldo_pendiente': (precioBase - deposito).clamp(0, double.infinity),
        'estado':          precioBase <= deposito ? 'PAGADO' : 'PARCIAL',
      });
      debugPrint('✅ [createSolicitudAndPayment] pago registrado');
    } catch (e) {
      debugPrint('❌ [createSolicitudAndPayment] ERROR pagos.insert: $e');
    }

    // 4. Crear transacción (movimiento financiero real del depósito Stripe)
    try {
      await _client.from('transacciones').insert({
        'solicitud_id':       solicitudId,
        'paciente_id':        pacienteId,
        'tipo_transaccion':   'DEPÓSITO',
        'monto':              deposito,
        'moneda':             'USD',
        'estado':             'APROBADO',
        'stripe_payment_id':  stripePaymentRef,
        'stripe_payment_intent': stripePaymentRef,
        'fecha_transaccion':  DateTime.now().toIso8601String(),
      });
      debugPrint('✅ [createSolicitudAndPayment] transacción DEPÓSITO registrada');
    } catch (e) {
      debugPrint('❌ [createSolicitudAndPayment] ERROR transacciones.insert: $e');
    }

    return solicitudId;
  }

  // ══════════════════════════════════════════════════════════════
  // ACTUALIZAR PERFIL Y PACIENTE
  // ══════════════════════════════════════════════════════════════

  /// Actualizar datos del paciente en `profiles` (y asegurar registro en `pacientes`)
  static Future<Map<String, dynamic>> updateProfileData({
    required String userId,
    required String fullName,
    required String phone,
    required String address,
    required double latitude,
    required double longitude,
    bool? activo,
    bool? paymentCompleted,
    bool? evaluationPassed,
  }) async {
    debugPrint('📝 [updateProfileData] Iniciando para userId=$userId');

    // ── 1. Update en profiles (la fila ya existe por el trigger de auth) ──
    final Map<String, dynamic> profileUpdate = {
      'full_name': fullName,
      'phone': phone,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'role': 'Paciente',
      'role_id': 1,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (activo != null) profileUpdate['activo'] = activo;
    if (paymentCompleted != null) profileUpdate['payment_completed'] = paymentCompleted;
    if (evaluationPassed != null) profileUpdate['evaluation_passed'] = evaluationPassed;

    try {
      await _client.from('profiles').update(profileUpdate).eq('id', userId);
      debugPrint('✅ [updateProfileData] profiles actualizado');
    } catch (e) {
      debugPrint('❌ [updateProfileData] ERROR profiles.update: $e');
      // Fallback upsert si la fila no existía aún
      try {
        final upsertData = Map<String, dynamic>.from(profileUpdate);
        upsertData['id'] = userId;
        upsertData['email'] = _client.auth.currentUser?.email ?? '';
        upsertData['created_at'] = DateTime.now().toIso8601String();
        await _client.from('profiles').upsert(upsertData, onConflict: 'id');
        debugPrint('✅ [updateProfileData] profiles.upsert fallback ok');
      } catch (e2) {
        debugPrint('❌ [updateProfileData] FALLBACK profiles.upsert ERROR: $e2');
        return {'error': e2.toString()};
      }
    }

    // ── 2. Asegurar registro en pacientes usando usuario_id ──
    try {
      // Upsert usando la constraint única en usuario_id
      await _client.from('pacientes').upsert({
        'usuario_id': userId,
        'activo': activo ?? false,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'usuario_id');
      debugPrint('✅ [updateProfileData] pacientes upsertado (usuario_id=$userId)');
    } catch (e) {
      debugPrint('❌ [updateProfileData] ERROR pacientes.upsert: $e');
      // Fallback insert
      try {
        await _client.from('pacientes').insert({
          'usuario_id': userId,
          'activo': activo ?? false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ [updateProfileData] pacientes.insert fallback ok');
      } catch (e2) {
        debugPrint('❌ [updateProfileData] FALLBACK pacientes.insert ERROR: $e2');
      }
    }

    // ── 3. Releer perfil actualizado ──
    try {
      final result = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      debugPrint('📖 [updateProfileData] Perfil releído: $result');
      return result ?? profileUpdate;
    } catch (e) {
      debugPrint('⚠️ [updateProfileData] No se pudo releer perfil: $e');
      return profileUpdate;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // GUARDAR DIRECCIÓN DEL PACIENTE
  // ══════════════════════════════════════════════════════════════

  /// Guarda dirección en `direcciones_paciente` usando el UUID de pacientes
  static Future<String?> savePatientAddress({
    required String profileId,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    debugPrint('📍 [savePatientAddress] profileId=$profileId');

    // Necesitamos el UUID de la tabla pacientes (no el profileId directamente)
    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      debugPrint('❌ [savePatientAddress] No se pudo obtener/crear pacienteId');
      return null;
    }

    try {
      // Primero marcar las anteriores como no principales
      await _client.from('direcciones_paciente')
          .update({'es_principal': false})
          .eq('paciente_id', pacienteId);
    } catch (_) {}

    try {
      final res = await _client.from('direcciones_paciente').insert({
        'paciente_id': pacienteId,
        'direccion': address,
        'latitud': latitude,
        'longitud': longitude,
        'es_principal': true,
        // ciudad/estado/codigo_postal son ahora nullable tras el ALTER TABLE del SQL
      }).select('id').maybeSingle();
      final dirId = res?['id'] as String?;
      debugPrint('✅ [savePatientAddress] Dirección guardada id=$dirId');
      return dirId;
    } catch (e) {
      debugPrint('❌ [savePatientAddress] ERROR: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // REGISTRAR PAGO / CUOTA INICIAL
  // ══════════════════════════════════════════════════════════════

  /// Registra el pago de la cuota inicial actualizando profiles.payment_completed
  /// (pagos y transacciones requieren solicitud_id, que se crea cuando hay cita)
  static Future<void> registerInitialPayment({
    required String profileId,
    required double amount,
    required String paymentReference,
  }) async {
    debugPrint('💳 [registerInitialPayment] profileId=$profileId monto=$amount ref=$paymentReference');

    // Actualizar flag payment_completed en profiles
    try {
      await _client.from('profiles').update({
        'payment_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', profileId);
      debugPrint('✅ [registerInitialPayment] payment_completed=true en profiles');
    } catch (e) {
      debugPrint('❌ [registerInitialPayment] ERROR profiles.update: $e');
    }

    // Actualizar activo en pacientes
    try {
      await _client.from('pacientes').update({
        'activo': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('usuario_id', profileId);
      debugPrint('✅ [registerInitialPayment] pacientes.activo=true');
    } catch (e) {
      debugPrint('❌ [registerInitialPayment] ERROR pacientes.update: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // GUARDAR EVALUACIÓN DE SALUD (CUESTIONARIO)
  // ══════════════════════════════════════════════════════════════

  /// Guarda las respuestas del cuestionario en `evaluaciones_salud` + `respuestas_salud`
  /// El esquema real requiere: paciente_id → pacientes.id, cuestionario_id bigint, pregunta_id bigint
  static Future<bool> saveHealthEvaluation({
    required String profileId,
    required String serviceName,
    required Map<String, String> answers,
  }) async {
    debugPrint('📋 [saveHealthEvaluation] profileId=$profileId servicio=$serviceName');

    if (profileId.isEmpty || profileId == 'invitado_test') {
      debugPrint('⚠️ [saveHealthEvaluation] profileId inválido, abortando.');
      return false;
    }

    // 1. Obtener UUID real del paciente en tabla pacientes
    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      debugPrint('❌ [saveHealthEvaluation] No se pudo obtener pacienteId');
      return false;
    }

    // 2. Obtener o crear cuestionario genérico para el servicio
    int? cuestionarioId;
    try {
      final cRes = await _client
          .from('cuestionarios')
          .select('id')
          .eq('nombre', serviceName)
          .maybeSingle();
      if (cRes != null) {
        cuestionarioId = cRes['id'] as int?;
      } else {
        // Crear cuestionario si no existe
        final newC = await _client.from('cuestionarios').insert({
          'nombre': serviceName,
          'descripcion': 'Cuestionario para el servicio: $serviceName',
          'activo': true,
          'version': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select('id').maybeSingle();
        cuestionarioId = newC?['id'] as int?;
      }
      debugPrint('📋 [saveHealthEvaluation] cuestionarioId=$cuestionarioId');
    } catch (e) {
      debugPrint('❌ [saveHealthEvaluation] ERROR obteniendo cuestionario: $e');
      return false;
    }

    if (cuestionarioId == null) {
      debugPrint('❌ [saveHealthEvaluation] cuestionarioId nulo, abortando');
      return false;
    }

    // 3. Insertar en evaluaciones_salud
    String? evalId;
    try {
      final evalRes = await _client.from('evaluaciones_salud').insert({
        'paciente_id': pacienteId,
        'cuestionario_id': cuestionarioId,
        'version_cuestionario': 1,
        'estado': 'Completado',
        'fecha_evaluacion': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select('id').maybeSingle();
      evalId = evalRes?['id'] as String?;
      debugPrint('✅ [saveHealthEvaluation] Evaluación insertada id=$evalId');
    } catch (e) {
      debugPrint('❌ [saveHealthEvaluation] ERROR evaluaciones_salud.insert: $e');
      return false;
    }

    // 4. Insertar respuestas en respuestas_salud
    // El esquema real usa pregunta_id bigint y campos separados por tipo
    if (evalId != null && answers.isNotEmpty) {
      for (final entry in answers.entries) {
        // Intentar parsear pregunta_id como bigint; si no es número usar null
        int? preguntaIdInt;
        try {
          preguntaIdInt = int.parse(entry.key);
        } catch (_) {
          // pregunta_id texto → buscar o crear en tabla preguntas
          try {
            final pRes = await _client
                .from('preguntas')
                .select('id')
                .eq('pregunta', entry.key)
                .maybeSingle();
            preguntaIdInt = pRes?['id'] as int?;
            if (preguntaIdInt == null) {
              final newP = await _client.from('preguntas').insert({
                'pregunta': entry.key,
                'tipo_respuesta': 'TEXTO',
                'obligatoria': false,
                'activo': true,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              }).select('id').maybeSingle();
              preguntaIdInt = newP?['id'] as int?;
            }
          } catch (_) {}
        }

        if (preguntaIdInt == null) continue;

        try {
          await _client.from('respuestas_salud').insert({
            'evaluacion_id': evalId,
            'pregunta_id': preguntaIdInt,
            'respuesta_texto': entry.value,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('⚠️ [saveHealthEvaluation] Error guardando respuesta pregunta=$preguntaIdInt: $e');
        }
      }
      debugPrint('✅ [saveHealthEvaluation] Respuestas guardadas en respuestas_salud');
    }

    // 5. Actualizar evaluation_passed en profiles
    try {
      await _client.from('profiles').update({
        'evaluation_passed': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', profileId);
      debugPrint('✅ [saveHealthEvaluation] evaluation_passed=true en profiles');
    } catch (e) {
      debugPrint('⚠️ [saveHealthEvaluation] ERROR actualizando profiles: $e');
    }

    return true;
  }

  // ══════════════════════════════════════════════════════════════
  // GUARDAR DICTAMEN QUALIFY (VALIDACIÓN TELEMEDICINA)
  // ══════════════════════════════════════════════════════════════

  /// Guarda el resultado de la evaluación Qualify en `validaciones_telemedicina`
  /// Usa pacientes.id (no profiles.id) y las columnas reales del esquema
  static Future<void> saveQualifyTestValidation({
    required String profileId,
    required bool aprobado,
  }) async {
    debugPrint('🏥 [saveQualifyTestValidation] profileId=$profileId aprobado=$aprobado');

    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      debugPrint('❌ [saveQualifyTestValidation] No se pudo obtener pacienteId');
      return;
    }

    // Verificar si ya existe una validación para este paciente
    try {
      final existing = await _client
          .from('validaciones_telemedicina')
          .select('id')
          .eq('paciente_id', pacienteId)
          .maybeSingle();

      if (existing != null) {
        // Actualizar la existente
        await _client.from('validaciones_telemedicina').update({
          'estado': aprobado ? 'APROBADA' : 'RECHAZADA',
          'codigo_referencia': 'QUALIFY_TEST_${DateTime.now().millisecondsSinceEpoch}',
          'observaciones': 'Evaluación simulada en Modo Prueba Qualify',
          'fecha_validacion': DateTime.now().toIso8601String(),
          'fecha_vencimiento': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existing['id']);
        debugPrint('✅ [saveQualifyTestValidation] Validación actualizada');
      } else {
        // Insertar nueva
        await _client.from('validaciones_telemedicina').insert({
          'paciente_id': pacienteId,
          'proveedor': 'Qualify',
          'estado': aprobado ? 'APROBADA' : 'RECHAZADA',
          'codigo_referencia': 'QUALIFY_TEST_${DateTime.now().millisecondsSinceEpoch}',
          'observaciones': 'Evaluación simulada en Modo Prueba Qualify',
          'fecha_validacion': DateTime.now().toIso8601String(),
          'fecha_vencimiento': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ [saveQualifyTestValidation] Validación insertada');
      }
    } catch (e) {
      debugPrint('❌ [saveQualifyTestValidation] ERROR: $e');
    }

    // Actualizar profiles
    try {
      await _client.from('profiles').update({
        'activo': aprobado,
        'evaluation_passed': aprobado,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', profileId);
      debugPrint('✅ [saveQualifyTestValidation] profiles actualizado');
    } catch (e) {
      debugPrint('❌ [saveQualifyTestValidation] ERROR profiles.update: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // CONSULTAR ESTADO DEL FLUJO DEL PACIENTE
  // ══════════════════════════════════════════════════════════════

  /// Verifica pago, cuestionario y evaluación médica del paciente
  static Future<Map<String, dynamic>> checkPatientFlowStatus({
    required String profileId,
  }) async {
    bool paymentCompleted = false;
    bool hasCompletedQuestionnaire = false;
    String evaluationStatus = 'PENDIENTE';

    // 1. Leer profile
    try {
      final profile = await _client
          .from('profiles')
          .select('payment_completed, evaluation_passed, activo')
          .eq('id', profileId)
          .maybeSingle();
      if (profile != null) {
        paymentCompleted = profile['payment_completed'] == true;
      }
    } catch (e) {
      debugPrint('⚠️ [checkPatientFlowStatus] Error leyendo profiles: $e');
    }

    // 2. Buscar evaluaciones_salud usando paciente_id (UUID de pacientes)
    try {
      final pacienteId = await _getPacienteId(profileId);
      if (pacienteId != null) {
        final eval = await _client
            .from('evaluaciones_salud')
            .select('estado')
            .eq('paciente_id', pacienteId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (eval != null) {
          hasCompletedQuestionnaire = true;
          debugPrint('📋 [checkPatientFlowStatus] Cuestionario encontrado: $eval');
        }

        // 3. Validación telemedicina
        final val = await _client
            .from('validaciones_telemedicina')
            .select('estado')
            .eq('paciente_id', pacienteId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (val != null) {
          hasCompletedQuestionnaire = true;
          final st = val['estado']?.toString().toUpperCase();
          if (st == 'APROBADA' || st == 'RECHAZADA') {
            evaluationStatus = st!;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [checkPatientFlowStatus] Error leyendo evaluaciones: $e');
    }

    debugPrint('📊 [checkPatientFlowStatus] payment=$paymentCompleted '
        'questionnaire=$hasCompletedQuestionnaire evalStatus=$evaluationStatus');

    return {
      'paymentCompleted': paymentCompleted,
      'hasCompletedQuestionnaire': hasCompletedQuestionnaire,
      'evaluationStatus': evaluationStatus,
    };
  }

  // ══════════════════════════════════════════════════════════════
  // UTILIDADES GENERALES
  // ══════════════════════════════════════════════════════════════

  /// Obtener los roles disponibles de la tabla `roles`
  static Future<List<Map<String, dynamic>>> fetchRoles() async {
    try {
      final data = await _client.from('roles').select().eq('activo', true);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      try {
        final fallback = await _client.from('roles').select();
        return List<Map<String, dynamic>>.from(fallback);
      } catch (_) {
        return [];
      }
    }
  }

  /// Obtener el perfil del usuario actual desde `profiles`
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      return await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Cerrar sesión
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Enviar enlace de restablecimiento de contraseña
  static Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }
}
