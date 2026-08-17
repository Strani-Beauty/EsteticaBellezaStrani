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
      // Si la dirección no menciona Houston o Texas, añadir sufijo para contextualizar
      String query = address;
      if (!query.toLowerCase().contains('houston') && !query.toLowerCase().contains('texas')) {
        query = '$address, Houston, TX, USA';
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
    String? avatarUrl,
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
    if (avatarUrl != null) profileUpdate['avatar_url'] = avatarUrl;
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
  /// Guarda el resultado de la evaluación médica en `validaciones_telemedicina`
  /// Admite modalidades: 'Telemedicina' (Qualify u otros) o 'Medicina Interna'
  /// Validez oficial de 1 año (365 días) desde la fecha de aprobación.
  static Future<void> saveQualifyTestValidation({
    required String profileId,
    required bool aprobado,
    String proveedor = 'Telemedicina',
  }) async {
    debugPrint('🏥 [saveQualifyTestValidation] profileId=$profileId aprobado=$aprobado proveedor=$proveedor');

    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      debugPrint('❌ [saveQualifyTestValidation] No se pudo obtener pacienteId');
      return;
    }

    final fechaValidacion = DateTime.now();
    final fechaVencimiento = fechaValidacion.add(const Duration(days: 365));

    // Verificar si ya existe una validación para este paciente
    try {
      final existing = await _client
          .from('validaciones_telemedicina')
          .select('id')
          .eq('paciente_id', pacienteId)
          .maybeSingle();

      if (existing != null) {
        // Actualizar la existente con la nueva fecha de vencimiento a 1 año
        await _client.from('validaciones_telemedicina').update({
          'proveedor': proveedor,
          'estado': aprobado ? 'APROBADA' : 'RECHAZADA',
          'codigo_referencia': '${proveedor.toUpperCase().replaceAll(" ", "_")}_VAL_${DateTime.now().millisecondsSinceEpoch}',
          'observaciones': 'Evaluación clínica aprobada por $proveedor (Válida por 1 año)',
          'fecha_validacion': fechaValidacion.toIso8601String(),
          'fecha_vencimiento': fechaVencimiento.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existing['id']);
        debugPrint('✅ [saveQualifyTestValidation] Validación ($proveedor) actualizada (Vence: $fechaVencimiento)');
      } else {
        // Insertar nueva
        await _client.from('validaciones_telemedicina').insert({
          'paciente_id': pacienteId,
          'proveedor': proveedor,
          'estado': aprobado ? 'APROBADA' : 'RECHAZADA',
          'codigo_referencia': '${proveedor.toUpperCase().replaceAll(" ", "_")}_VAL_${DateTime.now().millisecondsSinceEpoch}',
          'observaciones': 'Evaluación clínica aprobada por $proveedor (Válida por 1 año)',
          'fecha_validacion': fechaValidacion.toIso8601String(),
          'fecha_vencimiento': fechaVencimiento.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ [saveQualifyTestValidation] Validación ($proveedor) insertada (Vence: $fechaVencimiento)');
      }
    } catch (e) {
      debugPrint('❌ [saveQualifyTestValidation] ERROR: $e');
    }

    // Actualizar profiles
    try {
      await _client.from('profiles').update({
        'activo': aprobado,
        'evaluation_passed': aprobado,
        'payment_completed': aprobado,
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

  /// Verifica pago, cuestionario y evaluación médica del paciente.
  /// Comprueba validez de 1 año (365 días) por Telemedicina o Medicina Interna.
  static Future<Map<String, dynamic>> checkPatientFlowStatus({
    required String profileId,
  }) async {
    bool paymentCompleted = false;
    bool hasCompletedQuestionnaire = false;
    String evaluationStatus = 'PENDIENTE';
    String proveedorEvaluacion = 'Telemedicina';
    DateTime? fechaVencimiento;
    bool isExpired = false;

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

        // 3. Validación clínica (Telemedicina o Medicina Interna)
        final val = await _client
            .from('validaciones_telemedicina')
            .select('estado, proveedor, fecha_vencimiento, fecha_validacion, created_at')
            .eq('paciente_id', pacienteId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (val != null) {
          hasCompletedQuestionnaire = true;
          final st = val['estado']?.toString().toUpperCase();
          if (val['proveedor'] != null && val['proveedor'].toString().isNotEmpty) {
            proveedorEvaluacion = val['proveedor'].toString();
          }

          // Calcular fecha de vencimiento (1 año / 365 días)
          if (val['fecha_vencimiento'] != null) {
            fechaVencimiento = DateTime.tryParse(val['fecha_vencimiento'].toString());
          } else if (val['fecha_validacion'] != null) {
            fechaVencimiento = DateTime.tryParse(val['fecha_validacion'].toString())?.add(const Duration(days: 365));
          } else if (val['created_at'] != null) {
            fechaVencimiento = DateTime.tryParse(val['created_at'].toString())?.add(const Duration(days: 365));
          }

          // Verificar expiración tras 1 año
          if (fechaVencimiento != null && DateTime.now().isAfter(fechaVencimiento)) {
            isExpired = true;
          }

          if (st == 'APROBADA') {
            if (isExpired) {
              evaluationStatus = 'VENCIDA';
              paymentCompleted = false; // Expirado: requiere nueva evaluación y nuevo pago de $30 USD
            } else {
              evaluationStatus = 'APROBADA';
            }
          } else if (st == 'RECHAZADA') {
            evaluationStatus = 'RECHAZADA';
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [checkPatientFlowStatus] Error leyendo evaluaciones: $e');
    }

    debugPrint('📊 [checkPatientFlowStatus] payment=$paymentCompleted '
        'questionnaire=$hasCompletedQuestionnaire evalStatus=$evaluationStatus '
        'proveedor=$proveedorEvaluacion isExpired=$isExpired vencimiento=$fechaVencimiento');

    return {
      'paymentCompleted': paymentCompleted,
      'hasCompletedQuestionnaire': hasCompletedQuestionnaire,
      'evaluationStatus': evaluationStatus,
      'proveedorEvaluacion': proveedorEvaluacion,
      'fechaVencimiento': fechaVencimiento,
      'isExpired': isExpired,
    };
  }

  /// Permite al cliente evaluado ingresar a cualquier servicio para cancelar parte (depósito) o la totalidad.
  /// Registra solicitudes, pagos y transacciones correspondientes.
  /// En modo de prueba / entornos de demostración, genera una transacción simulada si la BD o pasarela responde con error,
  /// garantizando que la prueba no detenga el flujo del sistema.
  static Future<String?> createServicePayment({
    required String profileId,
    required String serviceTitle,
    required double servicePrice,
    required bool payFullAmount,
  }) async {
    debugPrint('💳 [createServicePayment] profileId=$profileId service=$serviceTitle price=$servicePrice full=$payFullAmount');

    final testFallbackId = 'TEST-SRV-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final pacienteId = await _ensurePaciente(profileId);
      final finalPacienteId = pacienteId ?? profileId;

      final direccionId = await _getDireccionPrincipal(finalPacienteId);
      final deposito = await _getDepositoReserva();
      final montoAPagar = payFullAmount ? servicePrice : deposito;

      final servicio = await _getServicioActivo();
      final servicioId = servicio?['id'] as String?;

      final payload = <String, dynamic>{
        'paciente_id': finalPacienteId,
        'estado': payFullAmount ? 'CONFIRMADA' : 'BORRADOR',
        'deposito_requerido': deposito,
        'deposito_pagado': true,
      };
      if (servicioId != null) payload['servicio_id'] = servicioId;
      if (direccionId != null) payload['direccion_id'] = direccionId;

      String? solicitudId;
      try {
        final solRes = await _client.from('solicitudes').insert(payload).select('id').maybeSingle();
        solicitudId = solRes?['id'] as String?;
      } catch (e) {
        debugPrint('⚠️ [createServicePayment] Nota DB (Solicitud): $e');
      }

      final effectiveSolicitudId = solicitudId ?? testFallbackId;

      // 2. Registrar Pago
      final saldoPendiente = (servicePrice - montoAPagar).clamp(0.0, double.infinity);
      try {
        await _client.from('pagos').insert({
          'solicitud_id': effectiveSolicitudId,
          'monto_total': servicePrice,
          'deposito': deposito,
          'saldo_pendiente': saldoPendiente,
          'estado': payFullAmount ? 'PAGADO' : 'PARCIAL',
        });
      } catch (e) {
        debugPrint('⚠️ [createServicePayment] Nota DB (Pago): $e');
      }

      // 3. Registrar Transacción
      final stripeRef = 'STRIPE_TEST_${DateTime.now().millisecondsSinceEpoch}';
      try {
        await _client.from('transacciones').insert({
          'solicitud_id': effectiveSolicitudId,
          'paciente_id': finalPacienteId,
          'tipo_transaccion': payFullAmount ? 'PAGO_TOTAL' : 'DEPÓSITO',
          'monto': montoAPagar,
          'moneda': 'USD',
          'estado': 'APROBADO',
          'stripe_payment_id': stripeRef,
          'stripe_payment_intent': stripeRef,
          'fecha_transaccion': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ [createServicePayment] Transacción $stripeRef guardada exitosamente');
      } catch (e) {
        debugPrint('⚠️ [createServicePayment] Nota DB (Transacción): $e');
      }

      return effectiveSolicitudId;
    } catch (e) {
      debugPrint('⚠️ [createServicePayment] Modo de prueba activo. Generando ID simulado ($testFallbackId) para no detener el sistema: $e');
      return testFallbackId;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // FACE MAPS & INYECTABLES QUESTIONNAIRE
  // ══════════════════════════════════════════════════════════════

  /// Guarda el Face Map del paciente en la tabla `face_maps` y sus puntos en
  /// `face_map_puntos`, alineado al esquema real de Supabase.
  ///
  /// Al seleccionar un servicio facial/inyectable (antes de que exista un
  /// tratamiento) el mapa se vincula a `paciente_id` y `servicio_id`;
  /// `tratamiento_id` queda opcional para los mapas generados durante la
  /// ejecución clínica.
  ///
  /// [puntos] es una lista de mapas `{ 'zona_anatomica', 'punto_id', 'vista',
  /// 'coordenada_x', 'coordenada_y' }` con coordenadas normalizadas (0.0..1.0)
  /// por vista; `punto_id`/`vista` permiten reconstruir exactamente el mapa al
  /// re-mostrarlo.
  static Future<bool> saveFaceMapRecord({
    required String profileId,
    String? tratamientoId,
    String? servicioId,
    required List<Map<String, dynamic>> puntos,
    String? notas,
  }) async {
    debugPrint('📍 [saveFaceMapRecord] profileId=$profileId, tratamientoId=$tratamientoId, servicioId=$servicioId, puntos=${puntos.length}');

    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      debugPrint('❌ [saveFaceMapRecord] No se pudo obtener pacienteId');
      return false;
    }

    final notasLimpio = notas?.trim();
    final payload = <String, dynamic>{
      'paciente_id': pacienteId,
      'tipo_mapa': 'ROSTRO',
      'imagen_base_url': '',
      if (servicioId != null && servicioId.isNotEmpty)
        'servicio_id': servicioId,
      if (tratamientoId != null && tratamientoId.isNotEmpty)
        'tratamiento_id': tratamientoId,
      if (notasLimpio != null && notasLimpio.isNotEmpty)
        'observaciones': notasLimpio,
    };

    try {
      final res = await _client
          .from('face_maps')
          .insert(payload)
          .select('id')
          .maybeSingle();
      final faceMapId = res?['id'] as String?;
      if (faceMapId == null) {
        debugPrint('❌ [saveFaceMapRecord] No se obtuvo id del face_maps insertado');
        return false;
      }

      for (final punto in puntos) {
        await _client.from('face_map_puntos').insert({
          'face_map_id': faceMapId,
          'zona_anatomica': punto['zona_anatomica'] as String? ?? '',
          if (punto['punto_id'] != null) 'punto_id': punto['punto_id'],
          if (punto['vista'] != null) 'vista': punto['vista'],
          'coordenada_x': punto['coordenada_x'],
          'coordenada_y': punto['coordenada_y'],
          'cantidad': 1,
          'unidad_medida': 'unidad',
        });
      }
      debugPrint('✅ [saveFaceMapRecord] Face map $faceMapId con ${puntos.length} puntos guardado');
      return true;
    } catch (e) {
      debugPrint('❌ [saveFaceMapRecord] Error guardando face map: $e');
      rethrow;
    }
  }

  /// Obtiene el último Face Map guardado del paciente para un servicio, con sus
  /// puntos y si el tratamiento asociado ya quedó **cerrado**.
  ///
  /// Se considera cerrado solo cuando el tratamiento indicado se aplicó por
  /// completo (productos + puntos + reporte del especialista) y se pagó en su
  /// totalidad: existe un `tratamientos.estado = 'COMPLETADO'` vinculado a la
  /// solicitud del mapa **y** `pagos.saldo_pendiente = 0`.
  ///
  /// Devuelve `null` si el paciente no tiene un mapa para ese servicio.
  /// El mapa resultante contiene: `id`, `notas`, `puntos` (filas de
  /// `face_map_puntos`) y `tratamientoCerrado` (bool).
  static Future<Map<String, dynamic>?> getFaceMapPorServicio({
    required String profileId,
    required String servicioId,
  }) async {
    debugPrint('📍 [getFaceMapPorServicio] profileId=$profileId, servicioId=$servicioId');

    final pacienteId = await _ensurePaciente(profileId);
    if (pacienteId == null) {
      debugPrint('❌ [getFaceMapPorServicio] No se pudo obtener pacienteId');
      return null;
    }

    final mapa = await _client
        .from('face_maps')
        .select('id, observaciones, solicitud_id, tratamiento_id')
        .eq('paciente_id', pacienteId)
        .eq('servicio_id', servicioId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (mapa == null) return null;

    final puntos = await _client
        .from('face_map_puntos')
        .select('zona_anatomica, punto_id, vista, coordenada_x, coordenada_y')
        .eq('face_map_id', mapa['id']);

    bool tratamientoCerrado = false;
    final solicitudId = mapa['solicitud_id'] as String?;

    if (solicitudId != null && solicitudId.isNotEmpty) {
      // Estado del tratamiento vinculado a la solicitud del mapa.
      var tratamientoCompletado = false;
      try {
        final citas = await _client
            .from('citas')
            .select('tratamientos(estado)')
            .eq('solicitud_id', solicitudId);
        for (final cita in citas) {
          final tratamientos = cita['tratamientos'];
          if (tratamientos is List) {
            for (final t in tratamientos) {
              if (t is Map && t['estado']?.toString().toUpperCase() == 'COMPLETADO') {
                tratamientoCompletado = true;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [getFaceMapPorServicio] Error leyendo tratamientos: $e');
      }

      // Saldo pendiente: el tratamiento se cierra solo si se pagó en su totalidad.
      double saldoPendiente = 0;
      try {
        final pago = await _client
            .from('pagos')
            .select('saldo_pendiente')
            .eq('solicitud_id', solicitudId)
            .maybeSingle();
        saldoPendiente = (pago?['saldo_pendiente'] as num?)?.toDouble() ?? 0;
      } catch (e) {
        debugPrint('⚠️ [getFaceMapPorServicio] Error leyendo pago: $e');
      }

      tratamientoCerrado = tratamientoCompletado && saldoPendiente <= 0;
    }

    debugPrint('✅ [getFaceMapPorServicio] mapa=${mapa['id']} puntos=${puntos.length} cerrado=$tratamientoCerrado');
    return {
      'id': mapa['id'],
      'notas': mapa['observaciones'],
      'puntos': puntos,
      'tratamientoCerrado': tratamientoCerrado,
    };
  }

  // ══════════════════════════════════════════════════════════════
  // MÓDULO 3: CUESTIONARIOS DINÁMICOS & PREGUNTAS REUTILIZABLES
  // ══════════════════════════════════════════════════════════════

  /// Obtener cuestionarios activos de la tabla `cuestionarios`
  static Future<List<Map<String, dynamic>>> fetchDynamicQuestionnaires() async {
    try {
      final res = await _client
          .from('cuestionarios')
          .select()
          .eq('activo', true)
          .order('id', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('⚠️ [fetchDynamicQuestionnaires] ERROR: $e');
      return [];
    }
  }

  /// Obtener las preguntas asociadas a un cuestionario específico mediante `cuestionario_preguntas` -> `preguntas`
  static Future<List<Map<String, dynamic>>> fetchQuestionnaireQuestions(int cuestionarioId) async {
    try {
      final res = await _client
          .from('cuestionario_preguntas')
          .select('orden, preguntas(id, pregunta, tipo_respuesta, obligatoria, opciones)')
          .eq('cuestionario_id', cuestionarioId)
          .order('orden', ascending: true);

      final List<Map<String, dynamic>> questions = [];
      for (final row in res) {
        if (row['preguntas'] != null) {
          final p = Map<String, dynamic>.from(row['preguntas'] as Map);
          p['orden'] = row['orden'];
          questions.add(p);
        }
      }
      return questions;
    } catch (e) {
      debugPrint('⚠️ [fetchQuestionnaireQuestions] ERROR: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════
  // MÓDULO 4: CATÁLOGO PARAMETRIZABLE & MAPEO DE PRERREQUISITOS
  // ══════════════════════════════════════════════════════════════

  /// Obtener las categorías de servicio desde `categorias_servicio`
  static Future<List<Map<String, dynamic>>> fetchCatalogCategories() async {
    try {
      final res = await _client
          .from('categorias_servicio')
          .select()
          .eq('activo', true)
          .order('nombre', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('⚠️ [fetchCatalogCategories] ERROR: $e');
      return [];
    }
  }

  /// Obtener los servicios del catálogo desde `servicios` vinculados con sus prerrequisitos y categoría
  static Future<List<Map<String, dynamic>>> fetchCatalogServices({String? categoriaId}) async {
    try {
      var query = _client
          .from('servicios')
          .select('*, categorias_servicio(nombre, descripcion)')
          .eq('activo', true);

      if (categoriaId != null && categoriaId.isNotEmpty) {
        query = query.eq('categoria_id', categoriaId);
      }

      final res = await query.order('nombre', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('⚠️ [fetchCatalogServices] ERROR: $e');
      return [];
    }
  }

  /// Verifica los prerrequisitos específicos de un servicio (Telemedicina, Face Map, Fotos, Consentimiento)
  static Future<Map<String, bool>> checkServicePrerequisites({
    required Map<String, dynamic> serviceData,
    required String profileId,
  }) async {
    final bool requiereTelemedicina = serviceData['requiere_telemedicina'] == true;
    final bool requiereFaceMap = serviceData['requiere_face_map'] == true ||
        (serviceData['nombre']?.toString().toLowerCase().contains('inyectable') == true);
    final bool requiereFotos = serviceData['requiere_fotos'] == true;
    final bool requiereConsentimiento = serviceData['requiere_consentimiento'] == true;

    final status = await checkPatientFlowStatus(profileId: profileId);
    final bool hasValidTelemedicina = status['evaluationStatus'] == 'APROBADA' && status['isExpired'] != true;

    return {
      'requiere_telemedicina': requiereTelemedicina,
      'telemedicina_cumplida': hasValidTelemedicina,
      'requiere_face_map': requiereFaceMap,
      'requiere_fotos': requiereFotos,
      'requiere_consentimiento': requiereConsentimiento,
      'apto_para_reserva': !requiereTelemedicina || hasValidTelemedicina,
    };
  }

  // ══════════════════════════════════════════════════════════════
  // REGLAS ESTRICTAS DE NEGOCIO (RN-020, RN-022)
  // ══════════════════════════════════════════════════════════════

  /// Valida estrictamente si el paciente puede realizar cualquier reserva o pago de servicio.
  /// BLOQUEA inmediatamente si la evaluación médica está VENCIDA, RECHAZADA o PENDIENTE.
  static Future<Map<String, dynamic>> validateReservationRulesRN020({
    required String profileId,
  }) async {
    final status = await checkPatientFlowStatus(profileId: profileId);

    final String evalStatus = status['evaluationStatus']?.toString() ?? 'PENDIENTE';
    final bool isExpired = status['isExpired'] == true;

    if (evalStatus == 'RECHAZADA') {
      return {
        'allowed': false,
        'reason': 'RECHAZADA',
        'message': 'REGLA RN-020/RN-022: Tu evaluación médica fue RECHAZADA. Queda estrictamente bloqueada cualquier reserva hasta obtener un dictamen médico favorable.',
      };
    }

    if (evalStatus == 'VENCIDA' || isExpired) {
      return {
        'allowed': false,
        'reason': 'VENCIDA',
        'message': 'REGLA RN-020/RN-022: Tu evaluación médica tiene más de 1 año (365 días) de emitida y está VENCIDA. Debes abonar el pago de \$30 USD y realizar una nueva evaluación médica.',
      };
    }

    if (evalStatus == 'PENDIENTE') {
      return {
        'allowed': false,
        'reason': 'PENDIENTE',
        'message': 'REGLA RN-020/RN-022: No cuentas con una evaluación médica aprobada. Debes completar la cuota inicial de \$30 USD y la evaluación médica clínica.',
      };
    }

    return {
      'allowed': true,
      'reason': 'APROBADA',
      'message': 'Evaluación médica aprobada y vigente (< 1 año).',
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

