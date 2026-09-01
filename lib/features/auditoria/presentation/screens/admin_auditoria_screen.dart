import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/features/auditoria/domain/entities/auditoria_entity.dart';
import 'package:esteticaybellezastrani/features/auditoria/domain/repositories/i_auditoria_repository.dart';
import 'package:esteticaybellezastrani/features/auditoria/presentation/cubits/admin_auditoria_cubit.dart';

/// Panel admin: registro de auditoría (quién, qué, cuándo, sobre qué).
class AdminAuditoriaScreen extends StatefulWidget {
  const AdminAuditoriaScreen({super.key});

  @override
  State<AdminAuditoriaScreen> createState() => _AdminAuditoriaScreenState();
}

class _AdminAuditoriaScreenState extends State<AdminAuditoriaScreen> {
  bool _loaded = false;
  String? _entidad;
  String? _accion;
  DateTime? _desde;
  DateTime? _hasta;

  static const _entidades = <(String, String)>[
    ('Cualquiera', ''),
    ('Perfiles', 'public.profiles'),
    ('Especialistas', 'public.especialistas'),
    ('Documentos', 'public.documentos_especialista'),
    ('Liquidaciones', 'public.liquidaciones_especialistas'),
    ('Pagos a especialistas', 'public.pagos_especialistas'),
    ('Roles', 'public.roles'),
    ('Permisos', 'public.permisos'),
    ('Asignación rol-permiso', 'public.rol_permisos'),
    ('Configuración del sistema', 'public.configuracion_sistema'),
    ('Citas', 'public.citas'),
    ('Solicitudes', 'public.solicitudes'),
    ('Transacciones', 'public.transacciones'),
    ('Pagos', 'public.pagos'),
    ('Tratamientos', 'public.tratamientos'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<AdminAuditoriaCubit>().load();
    }
  }

  void _aplicar() {
    context.read<AdminAuditoriaCubit>().load(AuditoriaFiltros(
          entidad: (_entidad ?? '').isEmpty ? null : _entidad,
          accion: (_accion ?? '').isEmpty ? null : _accion,
          desde: _desde,
          hasta: _hasta,
        ));
  }

  Future<void> _seleccionarRango() async {
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: hoy.add(const Duration(days: 1)),
      initialDateRange: _desde != null && _hasta != null
          ? DateTimeRange(start: _desde!, end: _hasta!)
          : null,
    );
    if (rango != null) {
      setState(() {
        _desde = rango.start;
        _hasta = rango.end;
      });
      _aplicar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<AdminAuditoriaCubit>().load(),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          const Divider(height: 1),
          Expanded(
            child: BlocConsumer<AdminAuditoriaCubit, AdminAuditoriaState>(
              listener: (context, state) {
                if (state is AdminAuditoriaError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppTheme.cError,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is AdminAuditoriaLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is AdminAuditoriaError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.cError)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () =>
                              context.read<AdminAuditoriaCubit>().load(),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is AdminAuditoriaLoaded) {
                  final registros = state.registros;
                  if (registros.isEmpty) {
                    return const Center(
                        child: Text('No hay registros de auditoría.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: registros.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _AuditoriaTile(registros[index]),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: _entidad ?? '',
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Entidad',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _entidades
                  .map((e) => DropdownMenuItem(
                        value: e.$2,
                        child: Text(e.$1,
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _entidad = v);
                _aplicar();
              },
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              initialValue: _accion ?? '',
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Acción',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todas')),
                DropdownMenuItem(value: 'INSERT', child: Text('Creación')),
                DropdownMenuItem(value: 'UPDATE', child: Text('Actualización')),
                DropdownMenuItem(value: 'DELETE', child: Text('Eliminación')),
              ],
              onChanged: (v) {
                setState(() => _accion = v);
                _aplicar();
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: _seleccionarRango,
            icon: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(
              _desde != null && _hasta != null
                  ? '${DateFormat('dd/MM/yyyy').format(_desde!)} - '
                      '${DateFormat('dd/MM/yyyy').format(_hasta!)}'
                  : 'Rango de fechas',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (_desde != null || _hasta != null)
            IconButton(
              onPressed: () {
                setState(() {
                  _desde = null;
                  _hasta = null;
                });
                _aplicar();
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Quitar rango',
            ),
        ],
      ),
    );
  }
}

class _AuditoriaTile extends StatelessWidget {
  final AuditoriaEntity registro;
  const _AuditoriaTile(this.registro);

  Color get _colorAccion => switch (registro.accion) {
        'INSERT' => AppTheme.cBrandGreen,
        'DELETE' => Colors.redAccent,
        _ => AppTheme.cDeepAccent,
      };

  @override
  Widget build(BuildContext context) {
    final fecha =
        DateFormat('dd/MM/yyyy HH:mm').format(registro.fecha.toLocal());
    final entidadCorta =
        registro.entidad.replaceFirst('public.', '');

    return Card(
      elevation: 0,
      color: AppTheme.cSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: _colorAccion.withValues(alpha: 0.15),
          child: Text(
            registro.accionLabel[0],
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _colorAccion,
                fontSize: 14),
          ),
        ),
        title: Text(
          '${registro.accionLabel} · $entidadCorta',
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: AppTheme.cDarkText),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${registro.usuarioNombre ?? 'Sistema'} · $fecha',
            style:
                const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
          ),
        ),
        children: [
          if (registro.entidadId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                'ID: ${registro.entidadId}',
                style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
              ),
            ),
          if (registro.detalle != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: SelectableText(
                _detalleResumen(registro.detalle!),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _detalleResumen(Map<String, dynamic> detalle) {
    final keys = detalle.keys.take(8).toList();
    return keys.map((k) {
      final s = detalle[k]?.toString() ?? 'null';
      final resumido = s.length > 60 ? '${s.substring(0, 57)}…' : s;
      return '$k=$resumido';
    }).join(' · ');
  }
}