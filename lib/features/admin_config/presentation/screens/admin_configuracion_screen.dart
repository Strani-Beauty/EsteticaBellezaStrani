import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import '../../domain/entities/config_sistema_entity.dart';
import '../cubits/admin_configuracion_cubit.dart';

/// Configuración del sistema — listar y editar claves (`configuracion_sistema`).
class AdminConfiguracionScreen extends StatefulWidget {
  const AdminConfiguracionScreen({super.key});

  @override
  State<AdminConfiguracionScreen> createState() =>
      _AdminConfiguracionScreenState();
}

class _AdminConfiguracionScreenState extends State<AdminConfiguracionScreen> {
  bool _cargado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cargado) {
      _cargado = true;
      context.read<AdminConfiguracionCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Configuración del Sistema'),
        backgroundColor: AppTheme.cDeepAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocConsumer<AdminConfiguracionCubit, AdminConfiguracionState>(
        listener: (context, state) {
          if (state is AdminConfiguracionSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            context.read<AdminConfiguracionCubit>().clearSaved();
          } else if (state is AdminConfiguracionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminConfiguracionLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is AdminConfiguracionError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<AdminConfiguracionCubit>().load(),
            );
          }
          if (state is! AdminConfiguracionLoaded) {
            return const SizedBox.shrink();
          }
          final items = state.items
              .where((i) => !_clavesSecretas.contains(i.clave))
              .toList();
          return RefreshIndicator(
            onRefresh: () async {
              context.read<AdminConfiguracionCubit>().load();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) => _ConfigTile(
                item: items[i],
                onEdit: () => _editar(items[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editar(ConfigSistemaEntity item) async {
    final formKey = GlobalKey<FormState>();
    final esMoneda = item.clave == _claveMoneda;
    final esEntero = item.tipoDato.toUpperCase() == 'INTEGER';

    String? nuevo;
    if (esEntero) {
      nuevo = await _editarEntero(context, item, formKey);
    } else if (esMoneda) {
      nuevo = await _editarMoneda(context, item);
    } else if (item.tipoDato.toUpperCase() == 'BOOLEAN') {
      nuevo = await _editarBooleano(context, item);
    } else {
      nuevo = await _editarTexto(context, item, formKey);
    }

    if (nuevo == null || !mounted) return;
    await context
        .read<AdminConfiguracionCubit>()
        .update(item.clave, nuevo.trim());
  }

  Future<String?> _editarEntero(
    BuildContext context,
    ConfigSistemaEntity item,
    GlobalKey<FormState> formKey,
  ) async {
    final ctrl = TextEditingController(text: item.valor);
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(_etiquetaConfig(item.clave)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.descripcion != null) ...[
                  Text(item.descripcion!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.cMutedText)),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        final actual = int.tryParse(ctrl.text) ?? 0;
                        setState(() => ctrl.text =
                            '${actual <= 0 ? 0 : actual - 1}');
                      },
                      icon: const Icon(Icons.remove_rounded),
                      tooltip: 'Disminuir',
                    ),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: ctrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Valor (${item.tipoDato})',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => _validarValor(item.tipoDato, v),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final actual = int.tryParse(ctrl.text) ?? 0;
                        setState(() => ctrl.text = '${actual + 1}');
                      },
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Aumentar',
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx, ctrl.text);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _editarBooleano(
    BuildContext context,
    ConfigSistemaEntity item,
  ) async {
    String? seleccion = item.valor.toLowerCase() == 'true' ? 'true' : 'false';
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(_etiquetaConfig(item.clave)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.descripcion != null) ...[
                Text(item.descripcion!,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.cMutedText)),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: seleccion,
                decoration: InputDecoration(
                  labelText: 'Valor (${item.tipoDato})',
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'true', child: Text('true')),
                  DropdownMenuItem(value: 'false', child: Text('false')),
                ],
                onChanged: (v) => setState(() => seleccion = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, seleccion),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _editarMoneda(
    BuildContext context,
    ConfigSistemaEntity item,
  ) async {
    String? seleccion = _monedas.contains(item.valor) ? item.valor : _monedas.first;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(_etiquetaConfig(item.clave)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.descripcion != null) ...[
                Text(item.descripcion!,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.cMutedText)),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: seleccion,
                decoration: const InputDecoration(
                  labelText: 'Moneda',
                  border: OutlineInputBorder(),
                ),
                items: _monedas
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => seleccion = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, seleccion),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _editarTexto(
    BuildContext context,
    ConfigSistemaEntity item,
    GlobalKey<FormState> formKey,
  ) async {
    final ctrl = TextEditingController(text: item.valor);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_etiquetaConfig(item.clave)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.descripcion != null) ...[
                Text(item.descripcion!,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.cMutedText)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: item.tipoDato.toUpperCase() == 'NUMERIC'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Valor (${item.tipoDato})',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => _validarValor(item.tipoDato, v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(ctx, ctrl.text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  String? _validarValor(String tipoDato, String? v) {
    final valor = (v ?? '').trim();
    switch (tipoDato.toUpperCase()) {
      case 'INTEGER':
        final entero = int.tryParse(valor);
        if (entero == null) return 'Debe ser un número entero';
        if (entero < 0) return 'Debe ser mayor o igual a 0';
        return null;
      case 'NUMERIC':
        if (double.tryParse(valor) == null) return 'Debe ser un número';
        return null;
      case 'BOOLEAN':
        if (valor.toLowerCase() != 'true' && valor.toLowerCase() != 'false') {
          return 'Debe ser true o false';
        }
        return null;
      default:
        if (valor.isEmpty) return 'Ingresa un valor';
        return null;
    }
  }
}

/// Claves de infraestructura que no deben editarse desde la UI.
const Set<String> _clavesSecretas = {'anon_key', 'edge_function_base_url'};

/// Clave de configuración de moneda (se edita con dropdown de monedas).
const String _claveMoneda = 'moneda_principal';

/// Principales monedas del mundo (ISO 4217).
const List<String> _monedas = [
  'USD', 'EUR', 'MXN', 'COP', 'VES', 'ARS', 'BRL', 'PEN', 'CLP', 'CAD',
  'GBP', 'CRC', 'GTQ', 'PYG', 'UYU', 'BOB',
];

/// Etiqueta legible para cada clave de configuración del sistema.
String _etiquetaConfig(String clave) {
  const etiquetas = <String, String>{
    'adelanto_porcentaje': 'Porcentaje de adelanto del servicio',
    'comision_plataforma': 'Comisión de la plataforma',
    'comision_porcentaje': 'Porcentaje de comisión de la plataforma',
    'deposito_reserva': 'Depósito de reserva',
    'dias_validez_qualify': 'Días de validez del dictamen médico',
    'enforce_pago_real': 'Exigir confirmación real del pago',
    'enforce_rn020': 'Bloquear servicios sin evaluación médica vigente',
    'inicio_semana_liquidacion': 'Día de inicio de la semana de liquidación',
    'moneda_principal': 'Moneda principal del sistema',
    'porcentaje_comision': 'Porcentaje retenido por la plataforma',
    'push_notifications': 'Notificaciones push',
    'radio_busqueda_inicial': 'Radio inicial de búsqueda',
    'radio_busqueda_km': 'Radio máximo de búsqueda (km)',
    'recordatorio_horas_previas': 'Horas previas para el recordatorio de cita',
    'simular_llegada': 'Simular la llegada del especialista',
    'solicitud_expiracion_horas': 'Horas de vigencia de la solicitud publicada',
    'tiempo_expiracion_sol': 'Tiempo de expiración de la solicitud',
    'tiempo_expiracion_solicitud':
        'Tiempo de expiración de la solicitud sin aceptar',
  };
  return etiquetas[clave] ?? clave;
}

class _ConfigTile extends StatelessWidget {
  final ConfigSistemaEntity item;
  final VoidCallback onEdit;

  const _ConfigTile({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.tune_rounded, color: AppTheme.cDeepAccent),
        title: Text(_etiquetaConfig(item.clave),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.valor} · ${item.tipoDato}${item.descripcion != null ? ' — ${item.descripcion}' : ''}',
              style: const TextStyle(fontSize: 12, color: AppTheme.cMutedText),
            ),
            if (item.clave != _etiquetaConfig(item.clave))
              Text(
                item.clave,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.cMutedText),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: onEdit,
          tooltip: 'Editar',
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.cMutedText)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.cDeepAccent),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}