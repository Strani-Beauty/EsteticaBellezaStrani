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
import '../../domain/entities/especialista_entity.dart';
import '../cubits/specialists_cubit.dart';
import '../widgets/especialidades_selector.dart';
import '../widgets/registrar_medico_regente_dialog.dart';

/// Perfil del especialista: permite consultar y actualizar la información que
/// le corresponde (datos personales de `profiles` + datos profesionales del
/// registro `especialistas`). El estado de verificación es de solo lectura.
class SpecialistProfileScreen extends StatefulWidget {
  const SpecialistProfileScreen({super.key});

  @override
  State<SpecialistProfileScreen> createState() => _SpecialistProfileScreenState();
}

class _SpecialistProfileScreenState extends State<SpecialistProfileScreen> {
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _hourlyRateCtrl = TextEditingController();
  final _licenciaCtrl = TextEditingController();

  bool _cargandoInicial = true;
  bool _guardando = false;
  bool _buscandoDireccion = false;
  bool _editingPersonal = false;
  bool _editingProfesional = false;

  LatLng _selectedLocation = kDefaultLocation;
  String? _direccionError;

  Set<int> _seleccionadas = {};
  String? _medicoRegenteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usuarioId = context.read<AuthCubit>().currentProfile?.id;
      if (usuarioId != null && usuarioId.isNotEmpty) {
        context.read<SpecialistsCubit>().loadDashboard(usuarioId: usuarioId);
      }
    });
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
    final especialista = state.especialista;
    if (especialista != null) {
      _medicoRegenteId = especialista.medicoRegenteId;
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
    final authCubit = context.read<AuthCubit>();
    final specialistsCubit = context.read<SpecialistsCubit>();
    final usuarioId = authCubit.currentProfile?.id;
    if (usuarioId == null) return;

    setState(() => _guardando = true);
    await specialistsCubit.guardarDatosPersonales(
      userId: usuarioId,
      fullName: _fullNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: _selectedLocation.latitude,
      longitude: _selectedLocation.longitude,
      hourlyRate: double.tryParse(_hourlyRateCtrl.text.trim()),
    );
    await authCubit.refreshProfile();
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _editingPersonal = false;
    });
  }

  Future<void> _guardarProfesional() async {
    final especialista = _especialista;
    if (especialista == null) return;

    setState(() => _guardando = true);
    final cubit = context.read<SpecialistsCubit>();

    await cubit.actualizarDatosProfesionales(
      especialistaId: especialista.id,
      numeroLicencia: _licenciaCtrl.text.trim().isEmpty
          ? null
          : _licenciaCtrl.text.trim(),
      medicoRegenteId: _medicoRegenteId,
    );

    await cubit.guardarEspecialidades(
      especialistaId: especialista.id,
      especialidadIds: _seleccionadas.toList(),
    );

    // Mantiene la ubicación base (`ubicaciones_especialista`) alineada con el
    // PIN seleccionado para el mapa y la búsqueda por proximidad.
    if (isValidMapCoordinate(_selectedLocation.latitude, _selectedLocation.longitude)) {
      await cubit.saveLocation(
        especialistaId: especialista.id,
        latitud: _selectedLocation.latitude,
        longitud: _selectedLocation.longitude,
      );
    }

    if (!mounted) return;
    setState(() {
      _guardando = false;
      _editingProfesional = false;
    });
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

  EspecialistaEntity? get _especialista {
    final state = context.read<SpecialistsCubit>().state;
    return state is SpecialistsLoaded ? state.especialista : null;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.read<AuthCubit>().currentProfile;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Perfil de Especialista')),
      body: BlocListener<SpecialistsCubit, SpecialistsState>(
        listener: (context, state) {
          if (state is SpecialistsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.cError),
            );
          }
        },
        child: BlocBuilder<SpecialistsCubit, SpecialistsState>(
          builder: (context, state) {
            if (state is SpecialistsLoaded && _cargandoInicial) {
              _syncDesdeEstado(state);
              _cargandoInicial = false;
            }
            if (state is! SpecialistsLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: () async {
                final usuarioId = profile?.id;
                if (usuarioId != null) {
                  await context.read<SpecialistsCubit>().loadDashboard(usuarioId: usuarioId);
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _EstadoVerificacionCard(
                    especialista: state.especialista,
                    onCorregir: () => context.go(
                      AppRoutes.specialistDocuments,
                      extra: state.especialista?.id ?? '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _seccionPersonal(state),
                  const SizedBox(height: 16),
                  _seccionProfesional(state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _seccionPersonal(SpecialistsLoaded state) {
    return _SectionCard(
      icon: Icons.person_outline_rounded,
      title: 'Datos personales',
      trailing: TextButton.icon(
        onPressed: _editingPersonal
            ? () => setState(() {
                  _syncDesdeEstado(state);
                  _editingPersonal = false;
                })
            : () => setState(() => _editingPersonal = true),
        icon: Icon(_editingPersonal ? Icons.close_rounded : Icons.edit_rounded),
        label: Text(_editingPersonal ? 'Cancelar' : 'Editar'),
      ),
      child: _editingPersonal
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field('Nombre completo', _fullNameCtrl, Icons.person_outline),
                const SizedBox(height: 12),
                _field('Teléfono', _phoneCtrl, Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field('Tarifa por hora (USD)', _hourlyRateCtrl, Icons.attach_money,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _buscarDireccion(),
                  decoration: AppTheme.fieldDecoration(
                    label: 'Dirección',
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
                ),
                const SizedBox(height: 12),
                PatientMapPicker(
                  selectedLocation: _selectedLocation,
                  onLocationChanged: (loc) => _selectedLocation = loc,
                  height: 170,
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
                        : const Icon(Icons.save_rounded),
                    label: const Text('Guardar datos personales'),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.person_outline, 'Nombre', _fullNameCtrl.text),
                _infoRow(Icons.phone_outlined, 'Teléfono', _phoneCtrl.text),
                _infoRow(Icons.attach_money, 'Tarifa/hora',
                    _hourlyRateCtrl.text.isEmpty ? '—' : '\$${_hourlyRateCtrl.text} USD'),
                _infoRow(Icons.location_on_outlined, 'Dirección', _addressCtrl.text),
              ],
            ),
    );
  }

  Widget _seccionProfesional(SpecialistsLoaded state) {
    final especialista = state.especialista;
    final medicosActivos =
        state.medicosRegentes.where((m) => m.activo).toList();
    final especialidades = state.especialidades;

    if (especialista == null) {
      return const _SectionCard(
        icon: Icons.badge_outlined,
        title: 'Datos profesionales',
        child: Text(
          'Aún no has creado tu registro de especialista. Completa tu onboarding para solicitarla.',
          style: TextStyle(color: AppTheme.cMutedText),
        ),
      );
    }

    final medicoActual = medicosActivos
        .where((m) => m.id == especialista.medicoRegenteId)
        .firstOrNull;
    final nombresEspecialidades = especialidades
        .where((e) => _seleccionadas.contains(e.id))
        .map((e) => e.nombre)
        .join(', ');

    return _SectionCard(
      icon: Icons.badge_outlined,
      title: 'Datos profesionales',
      trailing: TextButton.icon(
        onPressed: _editingProfesional
            ? () => setState(() {
                  _syncDesdeEstado(state);
                  _editingProfesional = false;
                })
            : () => setState(() => _editingProfesional = true),
        icon: Icon(_editingProfesional ? Icons.close_rounded : Icons.edit_rounded),
        label: Text(_editingProfesional ? 'Cancelar' : 'Editar'),
      ),
      child: _editingProfesional
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field('Número de licencia', _licenciaCtrl, Icons.badge_outlined),
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
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _registrarMedicoRegente,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Registrar nuevo médico regente'),
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
                        : const Icon(Icons.save_rounded),
                    label: const Text('Guardar datos profesionales'),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.badge_outlined, 'Licencia',
                    especialista.numeroLicencia ?? 'Sin registrar'),
                _infoRow(Icons.local_hospital_outlined, 'Médico regente',
                    medicoActual?.nombre ?? 'Sin asignar'),
                _infoRow(Icons.medical_services_outlined, 'Especialidades',
                    nombresEspecialidades.isEmpty ? 'Sin seleccionar' : nombresEspecialidades),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: AppTheme.fieldDecoration(
        label: label,
        prefix: Icon(icon, color: AppTheme.cDeepAccent),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.cDeepAccent),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppTheme.cMutedText, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.cDeepAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (trailing != null) ?trailing,
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}

class _EstadoVerificacionCard extends StatelessWidget {
  final EspecialistaEntity? especialista;
  final VoidCallback onCorregir;
  const _EstadoVerificacionCard({
    required this.especialista,
    required this.onCorregir,
  });

  @override
  Widget build(BuildContext context) {
    final s = especialista;
    final label = switch (s?.estadoVerificacion) {
      EstadoVerificacion.aprobado => 'Verificado',
      EstadoVerificacion.enRevision => 'En revisión',
      EstadoVerificacion.rechazado => 'Rechazado',
      EstadoVerificacion.bloqueado => 'Bloqueado',
      EstadoVerificacion.pendiente => 'Pendiente',
      null => 'Sin registro',
    };
    final color = switch (s?.estadoVerificacion) {
      EstadoVerificacion.aprobado => AppTheme.cBrandGreen,
      EstadoVerificacion.rechazado || EstadoVerificacion.bloqueado => Colors.redAccent,
      EstadoVerificacion.enRevision => Colors.orange,
      EstadoVerificacion.pendiente => AppTheme.cDeepAccent,
      null => AppTheme.cMutedText,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  s?.isApproved == true
                      ? Icons.verified_rounded
                      : Icons.hourglass_top_rounded,
                  color: color,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Estado de verificación: $label',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ],
            ),
            if (s != null && !s.isApproved && s.observacion != null) ...[
              const SizedBox(height: 10),
              Text('Motivo: ${s.observacion}',
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onCorregir,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Corregir y reenviar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
