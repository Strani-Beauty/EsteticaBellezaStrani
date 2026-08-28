import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/config/app_theme.dart';
import '../../../../app/config/app_routes.dart';
import '../../../../app/config/map_config.dart';
import '../../../../app/core/network/supabase_service.dart';
import '../../../auth_users/presentation/cubits/auth_cubit.dart';
import '../../../patients_compliance/presentation/widgets/patient_map_picker.dart';
import '../../domain/entities/especialidad_entity.dart';
import '../../domain/entities/medico_regente_entity.dart';
import '../cubits/specialists_cubit.dart';
import '../widgets/especialidades_selector.dart';
import '../widgets/registrar_medico_regente_dialog.dart';

/// Onboarding multi-paso del especialista:
///   Paso 1 — Datos personales (profiles)
///   Paso 2 — Datos profesionales: licencia + médico regente + especialidades
/// Después de guardar el paso 2 se deriva a la subida de documentos
/// ([SpecialistDocumentsScreen]), que ya gestiona su propio flujo.
class SpecialistOnboardingScreen extends StatefulWidget {
  /// ID del especialista ya existente (se omiten datos personales) o vacío
  /// si el especialista aún no ha creado su registro.
  final String especialistaId;
  const SpecialistOnboardingScreen({super.key, this.especialistaId = ''});

  @override
  State<SpecialistOnboardingScreen> createState() =>
      _SpecialistOnboardingScreenState();
}

class _SpecialistOnboardingScreenState extends State<SpecialistOnboardingScreen> {
  final _personalKey = GlobalKey<FormState>();
  final _profesionalKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _hourlyRateCtrl = TextEditingController();
  final _licenciaCtrl = TextEditingController();

  late int _currentStep;
  late bool _cargandoInicial;
  bool _buscandoDireccion = false;
  bool _guardando = false;

  LatLng _selectedLocation = kDefaultLocation;
  String? _direccionError;

  /// IDs de especialidades seleccionadas localmente.
  Set<int> _seleccionadas = {};

  String? _medicoRegenteId;

  bool get _esNuevo => widget.especialistaId.isEmpty;

  @override
  void initState() {
    super.initState();
    _currentStep = _esNuevo ? 0 : 1;
    _cargandoInicial = true;
    _medicoRegenteId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuarioId = context.read<AuthCubit>().currentProfile?.id;
      if (usuarioId != null && usuarioId.isNotEmpty) {
        context.read<SpecialistsCubit>().loadDashboard(usuarioId: usuarioId);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.read<AuthCubit>().currentProfile;
    if (profile != null) {
      if (_fullNameCtrl.text.isEmpty) _fullNameCtrl.text = profile.fullName ?? '';
      if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = profile.phone ?? '';
      if (_addressCtrl.text.isEmpty) _addressCtrl.text = profile.address ?? '';
      if (_hourlyRateCtrl.text.isEmpty && profile.hourlyRate != null) {
        _hourlyRateCtrl.text = profile.hourlyRate!.toStringAsFixed(2);
      }
      if (isValidMapCoordinate(profile.latitude, profile.longitude)) {
        _selectedLocation = LatLng(profile.latitude!, profile.longitude!);
      }
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _licenciaCtrl.dispose();
    super.dispose();
  }

  void _syncDesdeEstado(SpecialistsLoaded state) {
    final especialista = state.especialista;
    if (especialista != null) {
      // Solo aplica el médico regente si el usuario aún no eligió uno en esta
      // sesión; si lo sobrescribe siempre, cada rebuild del Stepper borra la
      // selección (especialistas ya existentes con medico_regente_id NULL).
      _medicoRegenteId ??= especialista.medicoRegenteId;
      if (_licenciaCtrl.text.isEmpty) {
        _licenciaCtrl.text = especialista.numeroLicencia ?? '';
      }
    }
    if (_seleccionadas.isEmpty) {
      _seleccionadas = state.especialidadIds.toSet();
    }
  }

  Future<void> _buscarDireccion() async {
    final q = _addressCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _direccionError = 'Ingresa una dirección para buscar.');
      return;
    }
    setState(() {
      _buscandoDireccion = true;
      _direccionError = null;
    });
    final coords = await SupabaseService.geocodeAddress(q);
    if (!mounted) return;
    setState(() {
      _buscandoDireccion = false;
      if (coords != null) {
        _selectedLocation = coords;
      } else {
        _direccionError =
            'No se encontraron coordenadas. Ajusta el PIN en el mapa.';
      }
    });
  }

  Future<void> _guardarPersonal() async {
    if (!(_personalKey.currentState?.validate() ?? false)) return;
    final usuarioId = context.read<AuthCubit>().currentProfile?.id;
    if (usuarioId == null) return;

    setState(() => _guardando = true);
    await context.read<SpecialistsCubit>().guardarDatosPersonales(
          userId: usuarioId,
          fullName: _fullNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          latitude: _selectedLocation.latitude,
          longitude: _selectedLocation.longitude,
          hourlyRate: double.tryParse(_hourlyRateCtrl.text.trim()),
        );
    if (!mounted) return;
    setState(() => _guardando = false);
    await context.read<AuthCubit>().refreshProfile();
    if (mounted) setState(() => _currentStep = 1);
  }

  Future<void> _guardarProfesional() async {
    if (!(_profesionalKey.currentState?.validate() ?? false)) return;
    if (_seleccionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos una especialidad para continuar.'),
        ),
      );
      return;
    }
    final usuarioId = context.read<AuthCubit>().currentProfile?.id;
    if (usuarioId == null) return;

    final cubit = context.read<SpecialistsCubit>();
    setState(() => _guardando = true);

    String? especialistaId = widget.especialistaId;
    if (_esNuevo) {
      await cubit.createSpecialist(
        usuarioId: usuarioId,
        numeroLicencia: _licenciaCtrl.text.trim().isEmpty
            ? null
            : _licenciaCtrl.text.trim(),
        medicoRegenteId: _medicoRegenteId,
      );
    } else {
      await cubit.actualizarDatosProfesionales(
        especialistaId: especialistaId,
        numeroLicencia: _licenciaCtrl.text.trim().isEmpty
            ? null
            : _licenciaCtrl.text.trim(),
        medicoRegenteId: _medicoRegenteId,
      );
    }

    especialistaId = cubit.especialista?.id ?? especialistaId;
    if (especialistaId.isNotEmpty && _seleccionadas.isNotEmpty) {
      await cubit.guardarEspecialidades(
        especialistaId: especialistaId,
        especialidadIds: _seleccionadas.toList(),
      );
    }

    // Registra la ubicación base en `ubicaciones_especialista` (geography
    // PostGIS) para el mapa y futuras búsquedas por proximidad.
    if (especialistaId.isNotEmpty &&
        isValidMapCoordinate(_selectedLocation.latitude, _selectedLocation.longitude)) {
      await cubit.saveLocation(
        especialistaId: especialistaId,
        latitud: _selectedLocation.latitude,
        longitud: _selectedLocation.longitude,
      );
    }

    if (!mounted) return;
    setState(() => _guardando = false);
    if (especialistaId.isNotEmpty) {
      context.push(AppRoutes.specialistDocuments, extra: especialistaId);
    }
  }

  Future<void> _registrarMedicoRegente() async {
    final datos = await showDialog<Map<String, String?>>(
      context: context,
      builder: (_) => const RegistrarMedicoRegenteDialog(),
    );
    if (datos == null || !mounted) return;
    final cubit = context.read<SpecialistsCubit>();
    await cubit.createMedicoRegente(
      nombre: datos['nombre'] ?? '',
      numeroLicencia: datos['numeroLicencia'],
      telefono: datos['telefono'],
      correo: datos['correo'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Médico regente registrado. Queda pendiente de validación por un administrador.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completa tu perfil de especialista'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Volver al panel',
          onPressed: () => context.go(AppRoutes.specialistHome),
        ),
      ),
      body: BlocListener<SpecialistsCubit, SpecialistsState>(
        listener: (context, state) {
          if (state is SpecialistsLoaded && _cargandoInicial) {
            _syncDesdeEstado(state);
            setState(() => _cargandoInicial = false);
          }
          if (state is SpecialistsError) {
            // Si la carga inicial falla, salir del spinner para que el
            // especialista pueda completar el formulario igualmente.
            if (_cargandoInicial) setState(() => _cargandoInicial = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.cError),
            );
          }
        },
        child: BlocBuilder<SpecialistsCubit, SpecialistsState>(
          builder: (context, state) {
            if (state is SpecialistsLoaded) {
              _syncDesdeEstado(state);
            }
            if (_cargandoInicial) {
              return const Center(child: CircularProgressIndicator());
            }
            return Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepTapped: (index) =>
                  setState(() => _currentStep = index),
              onStepContinue: _currentStep == 0
                  ? _guardarPersonal
                  : _guardarProfesional,
              onStepCancel: _currentStep > 0
                  ? () => setState(() => _currentStep -= 1)
                  : null,
              steps: [
                _stepPersonal(),
                _stepProfesional(),
              ],
            );
          },
        ),
      ),
    );
  }

  Step _stepPersonal() {
    return Step(
      title: const Text('Datos personales'),
      subtitle: const Text('Información de contacto y tarifa'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.editing,
      content: Form(
        key: _personalKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _fullNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: AppTheme.fieldDecoration(
                label: 'Nombre completo *',
                prefix: const Icon(Icons.person_outline, color: AppTheme.cDeepAccent),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa tu nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: AppTheme.fieldDecoration(
                label: 'Teléfono *',
                hint: '+58 412 1234567',
                prefix: const Icon(Icons.phone_outlined, color: AppTheme.cDeepAccent),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa tu teléfono' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hourlyRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: AppTheme.fieldDecoration(
                label: 'Tarifa por hora (USD)',
                prefix: const Icon(Icons.attach_money, color: AppTheme.cDeepAccent),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              textInputAction: TextInputAction.search,
              onFieldSubmitted: (_) => _buscarDireccion(),
              decoration: AppTheme.fieldDecoration(
                label: 'Dirección *',
                hint: 'Ej: Main St, Houston, TX',
                prefix: const Icon(Icons.location_on_outlined, color: AppTheme.cDeepAccent),
                suffix: _buscandoDireccion
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search_rounded, color: AppTheme.cDeepAccent),
                        onPressed: _buscarDireccion,
                      ),
                error: _direccionError,
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa tu dirección' : null,
            ),
            const SizedBox(height: 12),
            PatientMapPicker(
              selectedLocation: _selectedLocation,
              onLocationChanged: (loc) => _selectedLocation = loc,
              height: 190,
            ),
            const SizedBox(height: 8),
            Text(
              'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)} · '
              'Lng: ${_selectedLocation.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: AppTheme.cMutedText, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardarPersonal,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Step _stepProfesional() {
    final state = context.read<SpecialistsCubit>().state;
    final medicosActivos = state is SpecialistsLoaded
        ? state.medicosRegentes.where((m) => m.activo).toList()
        : <MedicoRegenteEntity>[];
    final especialidades = state is SpecialistsLoaded
        ? state.especialidades
        : <EspecialidadEntity>[];

    return Step(
      title: const Text('Datos profesionales'),
      subtitle: const Text('Licencia, médico regente y especialidades'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.editing,
      content: Form(
        key: _profesionalKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _licenciaCtrl,
              decoration: AppTheme.fieldDecoration(
                label: 'Número de licencia',
                prefix: const Icon(Icons.badge_outlined, color: AppTheme.cDeepAccent),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Médico Regente',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _medicoRegenteId,
              isExpanded: true,
              decoration: AppTheme.fieldDecoration(
                label: 'Selecciona tu médico regente',
                prefix: const Icon(Icons.local_hospital_rounded, color: AppTheme.cDeepAccent),
              ),
              items: [
                for (final medico in medicosActivos)
                  DropdownMenuItem(
                    value: medico.id,
                    child: Text(
                      '${medico.nombre}'
                      '${medico.numeroLicencia == null ? '' : ' (${medico.numeroLicencia})'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _medicoRegenteId = value),
              validator: (v) =>
                  v == null ? 'Debes seleccionar un médico regente' : null,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _registrarMedicoRegente,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrar nuevo médico regente'),
            ),
            if (medicosActivos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'No hay médicos regentes validados. Registra el tuyo y espera la validación del administrador.',
                  style: TextStyle(color: AppTheme.cMutedText, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            const Text('Especialidades que ofreces',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            EspecialidadesSelector(
              especialidades: especialidades,
              seleccionadas: _seleccionadas,
              onChanged: (ids) => setState(() => _seleccionadas = ids),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardarProfesional,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continuar a documentos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
