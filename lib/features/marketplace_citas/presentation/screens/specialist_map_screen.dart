import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/map_config.dart';
import '../../domain/entities/solicitud_pendiente_entity.dart';
import '../cubits/marketplace_cubit.dart';

/// Mapa interactivo del especialista: muestra pacientes que buscan especialista
/// (flag verde) y especialistas aprobados (flag morado). La asignación es
/// "primer aviso gana" vía RPC.
class SpecialistMapScreen extends StatefulWidget {
  final String especialistaId;

  const SpecialistMapScreen({super.key, required this.especialistaId});

  @override
  State<SpecialistMapScreen> createState() => _SpecialistMapScreenState();
}

class _SpecialistMapScreenState extends State<SpecialistMapScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketplaceCubit>().load(widget.especialistaId);
    });
  }

  double? _distanciaKm(double? lat, double? lng, MarketplaceLoaded state) {
    if (lat == null || lng == null || state.miLatitud == null || state.miLongitud == null) {
      return null;
    }
    return const Distance().as(
      LengthUnit.Kilometer,
      LatLng(lat, lng),
      LatLng(state.miLatitud!, state.miLongitud!),
    );
  }

  List<SolicitudPendienteEntity> _ordenadasPorCercania(MarketplaceLoaded state) {
    final conUbicacion =
        state.solicitudes.where((s) => isValidMapCoordinate(s.latitud, s.longitud)).toList();
    conUbicacion.sort((a, b) {
      final da = _distanciaKm(a.latitud, a.longitud, state) ?? double.infinity;
      final db = _distanciaKm(b.latitud, b.longitud, state) ?? double.infinity;
      return da.compareTo(db);
    });
    return conUbicacion;
  }

  void _recenterMine(MarketplaceLoaded state) {
    if (state.miLatitud == null || state.miLongitud == null) return;
    _mapController.move(LatLng(state.miLatitud!, state.miLongitud!), kFocusMapZoom);
  }

  void _zoomIn() {
    final c = _mapController.camera;
    _mapController.move(c.center, c.zoom + 1);
  }

  void _zoomOut() {
    final c = _mapController.camera;
    _mapController.move(c.center, c.zoom - 1);
  }

  void _showPatientDetail(MarketplaceLoaded state, SolicitudPendienteEntity s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => _PatientDetailSheet(
        solicitud: s,
        distanciaKm: _distanciaKm(s.latitud, s.longitud, state),
        aceptando: state.aceptandoId == s.id,
        onAceptar: () {
          Navigator.of(ctx).pop();
          context.read<MarketplaceCubit>().aceptar(
                solicitudId: s.id,
                especialistaId: widget.especialistaId,
              );
        },
      ),
    );
  }

  void _showListaPacientes(MarketplaceLoaded state) {
    final ordenadas = _ordenadasPorCercania(state);
    if (ordenadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay pacientes con ubicación registrada.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        minChildSize: 0.35,
        builder: (context, scrollController) => _PatientListSheet(
          solicitudes: ordenadas,
          state: state,
          distanciaKm: (s) => _distanciaKm(s.latitud, s.longitud, state),
          especialistaId: widget.especialistaId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mapa de Pacientes'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocConsumer<MarketplaceCubit, MarketplaceState>(
        listener: (context, state) {
          if (state is MarketplaceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is MarketplaceLoaded && state.feedback != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.feedback!)),
            );
            context.read<MarketplaceCubit>().clearFeedback();
          }
        },
        builder: (context, state) {
          if (state is MarketplaceLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is MarketplaceError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
                  const SizedBox(height: 12),
                  const Text('No pudimos cargar el mapa.', style: TextStyle(color: AppTheme.cMutedText)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cDeepAccent),
                    onPressed: () => context.read<MarketplaceCubit>().load(widget.especialistaId),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is! MarketplaceLoaded) {
            return const SizedBox.shrink();
          }
          return _buildMap(state);
        },
      ),
    );
  }

  Widget _buildMap(MarketplaceLoaded state) {
    final center = state.miLatitud != null && state.miLongitud != null
        ? LatLng(state.miLatitud!, state.miLongitud!)
        : kDefaultCaguaLocation;

    final markers = <Marker>[
      ..._pacienteMarkers(state),
      ..._especialistaMarkers(state),
    ];

    return RefreshIndicator(
      onRefresh: () => context.read<MarketplaceCubit>().load(widget.especialistaId),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: kDefaultMapZoom,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: kOsmTileUrlTemplate,
                userAgentPackageName: kUserAgentPackageName,
              ),
              MarkerLayer(markers: markers),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap',
                    onTap: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (state.solicitudes.isEmpty)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
                    ],
                  ),
                  child: const Text(
                    'No hay pacientes buscando especialista en este momento.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.cDarkText, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

          _buildLegend(),

          Positioned(
            right: 10,
            bottom: 110,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'mapa_recenter_btn',
                  tooltip: 'Centrar en mi ubicación',
                  backgroundColor: AppTheme.cDeepAccent,
                  onPressed: () => _recenterMine(state),
                  child: const Icon(Icons.my_location_rounded, color: Colors.white),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'mapa_zoom_in_btn',
                  tooltip: 'Acercar',
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: AppTheme.cDeepAccent),
                ),
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'mapa_zoom_out_btn',
                  tooltip: 'Alejar',
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: AppTheme.cDeepAccent),
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _ConteoCard(
                        pacientes: state.solicitudes.length,
                        especialistas: state.especialistas.length,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.extended(
                      heroTag: 'mapa_lista_btn',
                      backgroundColor: AppTheme.cDeepAccent,
                      foregroundColor: Colors.white,
                      onPressed: () => _showListaPacientes(state),
                      icon: const Icon(Icons.format_list_numbered_rounded),
                      label: const Text('Por cercanía'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _pacienteMarkers(MarketplaceLoaded state) {
    return state.solicitudes
        .where((s) => isValidMapCoordinate(s.latitud, s.longitud))
        .map((s) => Marker(
              point: LatLng(s.latitud!, s.longitud!),
              width: 46,
              height: 46,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => _showPatientDetail(state, s),
                child: _MapPin(
                  color: AppTheme.cBrandGreen,
                  icon: Icons.person_pin_circle_rounded,
                  aceptando: state.aceptandoId == s.id,
                ),
              ),
            ))
        .toList();
  }

  List<Marker> _especialistaMarkers(MarketplaceLoaded state) {
    return state.especialistas
        .where((e) => isValidMapCoordinate(e.latitud, e.longitud))
        .map((e) => Marker(
              point: LatLng(e.latitud!, e.longitud!),
              width: 42,
              height: 42,
              alignment: Alignment.topCenter,
              child: Tooltip(
                message: e.nombre ?? 'Especialista',
                child: _MapPin(
                  color: AppTheme.cDeepAccent,
                  icon: Icons.medical_services_rounded,
                ),
              ),
            ))
        .toList();
  }

  Widget _buildLegend() {
    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendItem(color: AppTheme.cBrandGreen, label: 'Paciente'),
            SizedBox(width: 10),
            _LegendItem(color: AppTheme.cDeepAccent, label: 'Especialista'),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool aceptando;

  const _MapPin({
    required this.color,
    required this.icon,
    this.aceptando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: aceptando
            ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.cDarkText)),
      ],
    );
  }
}

class _ConteoCard extends StatelessWidget {
  final int pacientes;
  final int especialistas;

  const _ConteoCard({required this.pacientes, required this.especialistas});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)],
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_rounded, color: AppTheme.cBrandGreen, size: 18),
          const SizedBox(width: 4),
          Text('$pacientes', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 14),
          const Icon(Icons.medical_services_rounded, color: AppTheme.cDeepAccent, size: 18),
          const SizedBox(width: 4),
          Text('$especialistas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _PatientDetailSheet extends StatelessWidget {
  final SolicitudPendienteEntity solicitud;
  final double? distanciaKm;
  final bool aceptando;
  final VoidCallback onAceptar;

  const _PatientDetailSheet({
    required this.solicitud,
    required this.distanciaKm,
    required this.aceptando,
    required this.onAceptar,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_pin_circle_rounded, color: AppTheme.cBrandGreen, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    solicitud.pacienteNombre,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(icon: Icons.medical_services_outlined, label: 'Servicio', value: solicitud.servicioNombre),
            const SizedBox(height: 8),
            _DetailRow(icon: Icons.payments_outlined, label: 'Precio', value: '\$${solicitud.precio} USD'),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.near_me_outlined,
              label: 'Distancia',
              value: distanciaKm != null ? '${distanciaKm!.toStringAsFixed(1)} km' : 'No disponible',
            ),
            if (solicitud.direccion != null) ...[
              const SizedBox(height: 8),
              _DetailRow(icon: Icons.place_outlined, label: 'Dirección', value: solicitud.direccion!),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cBrandGreen),
                onPressed: aceptando ? null : onAceptar,
                icon: aceptando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.flash_on_rounded),
                label: Text(aceptando ? 'Asignando...' : 'Asignarme este paciente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.cMutedText),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.cDarkText)),
        ),
      ],
    );
  }
}

class _PatientListSheet extends StatelessWidget {
  final List<SolicitudPendienteEntity> solicitudes;
  final MarketplaceLoaded state;
  final double? Function(SolicitudPendienteEntity) distanciaKm;
  final String especialistaId;
  final ScrollController scrollController;

  const _PatientListSheet({
    required this.solicitudes,
    required this.state,
    required this.distanciaKm,
    required this.especialistaId,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: Text(
            'Pacientes por cercanía',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        ...solicitudes.map((s) {
          final dist = distanciaKm(s);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.person_pin_circle_rounded, color: AppTheme.cBrandGreen, size: 32),
              title: Text(s.pacienteNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                '${s.servicioNombre} · \$${s.precio} · ${dist != null ? "${dist.toStringAsFixed(1)} km" : "sin ubicación"}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: state.aceptandoId == s.id
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cBrandGreen),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.cBrandGreen),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.read<MarketplaceCubit>().aceptar(
                              solicitudId: s.id,
                              especialistaId: especialistaId,
                            );
                      },
                      child: const Text('Asignarme'),
                    ),
            ),
          );
        }),
      ],
    );
  }
}
