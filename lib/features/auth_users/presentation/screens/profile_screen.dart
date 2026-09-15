import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/map_config.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/app/core/network/supabase_service.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/entities/paciente_entity.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/get_mi_paciente.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/domain/usecases/update_mi_paciente.dart';
import 'package:esteticaybellezastrani/features/patients_compliance/presentation/widgets/resizable_map_dialog.dart';
import '../cubits/auth_cubit.dart';
import '../widgets/avatar_selector.dart';
import '../widgets/avatar_view.dart';

/// Pantalla del perfil del usuario autenticado.
/// Permite consultar y actualizar la información del perfil. Para pacientes se
/// edita el set completo (avatar, nombre, teléfono, fecha de nacimiento, género
/// y dirección con mapa); para el resto de roles solo avatar/nombre/teléfono.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _generoOptions = ['Femenino', 'Masculino', 'Otro', 'Prefiero no decir'];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final MapController _mapController = MapController();

  bool _editing = false;
  bool _loaded = false;

  String? _avatarUrl;
  DateTime? _fechaNacimiento;
  String? _genero;
  LatLng _selectedLocation = kDefaultLocation;
  bool _ubicacionConfirmada = false;
  String? _addressError;
  bool _searchingLocation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final profile = context.read<AuthCubit>().currentProfile;
    if (profile == null) return;

    _nameCtrl.text = profile.fullName ?? '';
    _phoneCtrl.text = profile.phone ?? '';
    _avatarUrl = profile.avatarUrl;

    if (profile.isPatient) {
      _addressCtrl.text = profile.address ?? '';
      if (isValidMapCoordinate(profile.latitude, profile.longitude)) {
        _selectedLocation = LatLng(profile.latitude!, profile.longitude!);
        _ubicacionConfirmada = true;
      }

      PacienteEntity? paciente;
      final pacRes = await sl<GetMiPaciente>()();
      pacRes.fold((f) => null, (p) => paciente = p);
      if (!mounted) return;
      _fechaNacimiento = paciente?.fechaNacimiento;
      _genero = paciente?.genero;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.services),
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () => context.go(AppRoutes.changePassword),
            tooltip: 'Cambiar contraseña',
            icon: const Icon(Icons.lock_reset_rounded),
          ),
          IconButton(
            onPressed: () {
              if (_editing) {
                setState(() => _editing = false);
              } else {
                context.read<AuthCubit>().signOut();
              }
            },
            tooltip: _editing ? 'Cancelar edición' : 'Cerrar sesión',
            icon: Icon(
              _editing ? Icons.close_rounded : Icons.logout_rounded,
              color: _editing ? AppTheme.cMutedText : Colors.redAccent,
            ),
          ),
        ],
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            context.go(AppRoutes.login);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.cError),
            );
          } else if (state is AuthAuthenticated) {
            _loadProfile();
            if (_editing) {
              setState(() => _editing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Perfil actualizado.')),
              );
            }
          }
        },
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final profile =
                state is AuthAuthenticated ? state.profile : null;
            if (profile == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _editing
                        ? AvatarSelector(
                            avatarUrl: _avatarUrl,
                            onChanged: (value) =>
                                setState(() => _avatarUrl = value),
                          )
                        : AvatarView(
                            avatarUrl: profile.avatarUrl,
                            isPatient: profile.isPatient,
                            isAdmin: profile.isAdmin,
                            isSpecialist: profile.isSpecialist,
                            seed: profile.id,
                            diameter: 88,
                            showBorder: false,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      profile.rolNombre,
                      style: TextStyle(
                        color: AppTheme.cDeepAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!profile.activo)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          'Cuenta pendiente de activación',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _infoTile(Icons.email_outlined, 'Correo electrónico',
                      profile.email),
                  _infoTile(Icons.badge_outlined, 'Nombre completo',
                      _editing
                          ? null
                          : (profile.fullName?.isEmpty == true
                              ? 'Sin registrar'
                              : profile.fullName), nameField: _editing),
                  _infoTile(Icons.phone_outlined, 'Teléfono',
                      _editing
                          ? null
                          : (profile.phone?.isEmpty == true
                              ? 'Sin registrar'
                              : profile.phone), phoneField: _editing),
                  if (_editing && profile.isPatient) ...[
                    _infoTile(
                      Icons.cake_outlined,
                      'Fecha de nacimiento',
                      _fechaNacimiento == null
                          ? 'Sin registrar'
                          : _formatFecha(_fechaNacimiento!),
                      dateField: true,
                    ),
                    _infoTile(
                      Icons.wc_outlined,
                      'Género',
                      _genero ?? 'Sin registrar',
                      generoField: true,
                    ),
                    _infoTile(
                      Icons.home_outlined,
                      'Dirección',
                      _editing
                          ? null
                          : (profile.address?.isEmpty == true
                              ? 'Sin registrar'
                              : profile.address),
                      addressField: _editing,
                    ),
                    _mapTile(),
                  ],
                  if (!_editing) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Editar mi información'),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: state is AuthLoading ? null : _guardar,
                        child: state is AuthLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Guardar cambios'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _loadProfile();
                        setState(() => _editing = false);
                      },
                      child: const Text('Cancelar'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoTile(
    IconData icon,
    String label,
    String? value, {
    bool nameField = false,
    bool phoneField = false,
    bool dateField = false,
    bool generoField = false,
    bool addressField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.cDeepAccent, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppTheme.cMutedText)),
            ],
          ),
          const SizedBox(height: 6),
          if (nameField)
            TextFormField(
              controller: _nameCtrl,
              decoration: AppTheme.fieldDecoration(label: 'Nombre completo'),
            )
          else if (phoneField)
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: AppTheme.fieldDecoration(label: 'Teléfono'),
            )
          else if (dateField)
            InkWell(
              onTap: _selectFechaNacimiento,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: InputDecorator(
                decoration: AppTheme.fieldDecoration(label: 'Fecha de nacimiento'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fechaNacimiento == null
                          ? 'Seleccionar fecha'
                          : _formatFecha(_fechaNacimiento!),
                      style: TextStyle(
                        color: _fechaNacimiento == null
                            ? AppTheme.cMutedText
                            : AppTheme.cDeepAccent,
                      ),
                    ),
                    const Icon(Icons.calendar_today_rounded,
                        size: 18, color: AppTheme.cMutedText),
                  ],
                ),
              ),
            )
          else if (generoField)
            DropdownButtonFormField<String>(
              initialValue: _genero,
              items: [
                for (final g in _generoOptions)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              decoration: AppTheme.fieldDecoration(label: 'Género'),
              onChanged: (value) => setState(() => _genero = value),
            )
          else if (addressField)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _addressCtrl,
                  decoration: AppTheme.fieldDecoration(
                    label: 'Dirección de la cita',
                    suffix: _searchingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search_rounded),
                            tooltip: 'Buscar dirección',
                            onPressed: () => _searchLocation(),
                          ),
                  ),
                  onFieldSubmitted: _searchLocation,
                ),
                if (_addressError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _addressError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                value ?? '-',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mapTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.map_outlined, color: AppTheme.cDeepAccent, size: 20),
              SizedBox(width: 8),
              Text('Ubicación en Mapa',
                  style: TextStyle(color: AppTheme.cMutedText)),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _openMapModalDialog,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: InputDecorator(
              decoration: AppTheme.fieldDecoration(label: 'Ubicación en Mapa'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _ubicacionConfirmada
                        ? 'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)}, '
                            'Lng: ${_selectedLocation.longitude.toStringAsFixed(5)}'
                        : 'Confirmar posición del PIN',
                    style: TextStyle(
                      color: _ubicacionConfirmada
                          ? AppTheme.cDeepAccent
                          : AppTheme.cMutedText,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(Icons.map_rounded,
                      size: 18, color: AppTheme.cMutedText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFecha(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}';
  }

  Future<void> _selectFechaNacimiento() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? hoy.subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: hoy,
    );
    if (picked != null) setState(() => _fechaNacimiento = picked);
  }

  Future<void> _searchLocation([String? query]) async {
    final q = (query ?? _addressCtrl.text).trim();
    if (q.isEmpty) {
      setState(() => _addressError = 'Ingresa una dirección para buscar.');
      return;
    }
    setState(() {
      _searchingLocation = true;
      _addressError = null;
    });

    final coords = await SupabaseService.geocodeAddress(q);

    if (!mounted) return;

    if (coords != null) {
      setState(() {
        _selectedLocation = coords;
        _ubicacionConfirmada = true;
        _searchingLocation = false;
      });
      _openMapModalDialog();
    } else {
      setState(() {
        _searchingLocation = false;
        _addressError =
            'No se encontraron coordenadas exactas. Puedes ajustar el PIN en el mapa manualmente.';
      });
      _openMapModalDialog();
    }
  }

  Future<void> _openMapModalDialog() async {
    final result = await showDialog<LatLng>(
      context: context,
      builder: (_) => ResizableMapDialog(
        initialLocation: _selectedLocation,
        title: 'Mapa (Houston, TX)',
        mapController: _mapController,
        resolveAddress: (p) =>
            SupabaseService.reverseGeocodeAddress(p.latitude, p.longitude),
        onAddressResolved: (addr) => _addressCtrl.text = addr,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedLocation = result;
      _ubicacionConfirmada = true;
    });
  }

  Future<void> _guardar() async {
    final profile = context.read<AuthCubit>().currentProfile;
    if (profile == null) return;

    if (profile.isPatient) {
      final hoy = DateTime.now();
      final fechaMin = DateTime(1900);
      final fechaMax = hoy.subtract(const Duration(days: 365 * 10));
      if (_fechaNacimiento == null ||
          _fechaNacimiento!.isAfter(hoy) ||
          _fechaNacimiento!.isBefore(fechaMin) ||
          _fechaNacimiento!.isAfter(fechaMax)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona una fecha de nacimiento válida (edad mínima 10 años).'),
            backgroundColor: AppTheme.cError,
          ),
        );
        return;
      }
      if (_genero == null || _genero!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona tu género.'),
            backgroundColor: AppTheme.cError,
          ),
        );
        return;
      }
      if (!_ubicacionConfirmada) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirma tu ubicación en el mapa antes de guardar.'),
            backgroundColor: AppTheme.cError,
          ),
        );
        return;
      }

      await context.read<AuthCubit>().updateProfile(
            userId: profile.id,
            fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            address:
                _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
            latitude: _selectedLocation.latitude,
            longitude: _selectedLocation.longitude,
            avatarUrl: _avatarUrl,
          );

      // Datos clínicos del paciente.
      if (!mounted) return;
      final pacRes = await sl<UpdateMiPaciente>()(UpdateMiPacienteParams(
        fechaNacimiento: _fechaNacimiento,
        genero: _genero,
      ));
      pacRes.fold((f) => null, (p) => null);
    } else {
      await context.read<AuthCubit>().updateProfile(
            userId: profile.id,
            fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            avatarUrl: _avatarUrl,
          );
    }
  }
}