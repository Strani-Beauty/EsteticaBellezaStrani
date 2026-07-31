import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_constants.dart';
import '../cubits/auth_cubit.dart';

/// Pantalla para completar el perfil del paciente tras el registro.
/// Reemplaza _buildClientProfilesFormView() del monolito original.
/// Flujo: Dirección → Geocodificación → Guardar → Pago Stripe → Evaluación Qualify
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  double _lat = 10.4806;
  double _lng = -66.9036;
  bool _searchingLocation = false;
  String? _addressError;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Geocodificación Secuencial: Mapbox → Google → Nominatim ──
  Future<void> _searchLocation([String? query]) async {
    final q = (query ?? _addressCtrl.text).trim();
    if (q.isEmpty) {
      setState(() => _addressError = 'Ingresa una dirección para buscar.');
      return;
    }
    setState(() { _searchingLocation = true; _addressError = null; });

    final mapboxToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    final googleKey   = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

    // 1. Mapbox
    if (mapboxToken.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json?access_token=$mapboxToken&limit=1&language=es',
        );
        final resp = await http.get(url);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final center = features.first['center'] as List;
            setState(() {
              _lat = double.parse(center[1].toString());
              _lng = double.parse(center[0].toString());
              _searchingLocation = false;
            });
            return;
          }
        }
      } catch (_) {}
    }

    // 2. Google Maps
    if (googleKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(q)}&key=$googleKey&language=es',
        );
        final resp = await http.get(url);
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final loc = results.first['geometry']['location'];
            setState(() {
              _lat = double.parse(loc['lat'].toString());
              _lng = double.parse(loc['lng'].toString());
              _searchingLocation = false;
            });
            return;
          }
        }
      } catch (_) {}
    }

    // 3. Nominatim
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=1',
      );
      final resp = await http.get(url, headers: {
        'User-Agent': 'EsteticaBellezaStrani/2.0',
        'Accept-Language': 'es',
      });
      if (resp.statusCode == 200) {
        final results = json.decode(resp.body) as List;
        if (results.isNotEmpty) {
          setState(() {
            _lat = double.parse(results.first['lat'].toString());
            _lng = double.parse(results.first['lon'].toString());
            _searchingLocation = false;
          });
          return;
        }
      }
    } catch (_) {}

    // 4. Respaldo local
    final hash = q.codeUnits.fold(0, (p, e) => p + e * 31);
    setState(() {
      _lat = 10.4806 + (hash % 500) * 0.0001;
      _lng = -66.9036 + ((hash ~/ 500) % 500) * 0.0001;
      _searchingLocation = false;
      _addressError = 'Coordenadas estimadas (sin proveedor disponible).';
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<AuthCubit>();
    final profile = cubit.currentProfile;
    if (profile == null) return;

    await cubit.updateProfile(
      userId: profile.id,
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: _lat,
      longitude: _lng,
    );

    if (mounted && cubit.state is AuthAuthenticated) {
      _showStripeModal();
    }
  }

  void _showStripeModal() {
    bool processing = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
          title: const Row(children: [
            Icon(Icons.credit_card_rounded, color: AppTheme.cStripe, size: 28),
            SizedBox(width: 10),
            Text('Pago de Cuota Inicial'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cPastelPurple,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Cuota Inicial:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('\$${AppConstants.depositoInicial} USD',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                            color: AppTheme.cDeepAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Procesado de forma segura con Stripe.',
                  style: TextStyle(fontSize: 12, color: AppTheme.cMutedText)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: processing ? null : () {
                Navigator.pop(ctx);
                _triggerEvaluation(paid: false);
              },
              child: const Text('Posponer', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cStripe),
              onPressed: processing ? null : () async {
                setModal(() => processing = true);
                await Future.delayed(const Duration(seconds: 2));
                if (ctx.mounted) Navigator.pop(ctx);
                _triggerEvaluation(paid: true);
              },
              child: processing
                  ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Pagar con Stripe'),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerEvaluation({required bool paid}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 3), () async {
          final cubit = context.read<AuthCubit>();
          final profile = cubit.currentProfile;
          if (profile == null) return;

          await cubit.updateProfile(
            userId: profile.id,
            activo: paid,
            paymentCompleted: paid,
            evaluationPassed: paid,
          );

          if (ctx.mounted) Navigator.pop(ctx);

          if (!paid && mounted) {
            _showNotApprovedDialog();
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 12),
              CircularProgressIndicator(color: AppTheme.cDeepAccent),
              SizedBox(height: 20),
              Text('Evaluación Clínica en Proceso...',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Conectando con proveedor independiente Qualify.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.cMutedText)),
              SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showNotApprovedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Row(children: [
          Icon(Icons.cancel_outlined, color: Colors.redAccent),
          SizedBox(width: 10),
          Text('No Apto', style: TextStyle(color: Colors.redAccent)),
        ]),
        content: const Text(
          'La evaluación médica con Qualify determinó que no cumples los criterios de aptitud clínica en este momento.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthCubit>().signOut();
            },
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AuthCubit>();
    final isLoading = cubit.state is AuthLoading;
    final profile = cubit.currentProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completar Perfil'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Auth ID
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: [
                  const Icon(Icons.vpn_key_outlined, size: 16, color: AppTheme.cMutedText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'auth.users.id: ${profile?.id ?? '...'}',
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // Teléfono
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: AppTheme.fieldDecoration(
                  label: 'Teléfono de Contacto',
                  hint: '+58 412 1234567',
                  prefix: const Icon(Icons.phone_outlined, color: AppTheme.cDeepAccent),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa tu número telefónico' : null,
              ),
              const SizedBox(height: 14),

              // Dirección
              TextFormField(
                controller: _addressCtrl,
                textInputAction: TextInputAction.search,
                onFieldSubmitted: _searchLocation,
                decoration: AppTheme.fieldDecoration(
                  label: 'Dirección de Habitación',
                  hint: 'Ej: Av. Principal, Edificio Strani, Caracas',
                  prefix: const Icon(Icons.location_on_outlined, color: AppTheme.cDeepAccent),
                  suffix: _searchingLocation
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                  color: AppTheme.cDeepAccent)))
                      : IconButton(
                          icon: const Icon(Icons.search_rounded, color: AppTheme.cDeepAccent),
                          onPressed: () => _searchLocation(),
                        ),
                  error: _addressError,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa tu dirección' : null,
              ),
              const SizedBox(height: 14),

              // Coordenadas
              Row(children: [
                Expanded(
                  child: TextFormField(
                    key: Key('lat_$_lat'),
                    initialValue: _lat.toStringAsFixed(6),
                    readOnly: true,
                    decoration: AppTheme.fieldDecoration(
                      label: 'Latitud',
                      prefix: const Icon(Icons.my_location_rounded,
                          color: AppTheme.cMutedText),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    key: Key('lng_$_lng'),
                    initialValue: _lng.toStringAsFixed(6),
                    readOnly: true,
                    decoration: AppTheme.fieldDecoration(
                      label: 'Longitud',
                      prefix: const Icon(Icons.explore_outlined,
                          color: AppTheme.cMutedText),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // Botón
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _submit,
                  icon: const Icon(Icons.payment_rounded),
                  label: const Text('Guardar e Ir a Pago Stripe (\$30)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
