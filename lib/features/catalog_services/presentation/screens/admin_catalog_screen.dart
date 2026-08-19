import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/core/di/injection.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/categoria_servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/domain/entities/servicio_entity.dart';
import 'package:esteticaybellezastrani/features/catalog_services/presentation/cubits/admin_catalog_cubit.dart';

/// Mantenimiento del catálogo de servicios (solo admin):
/// categorías y servicios con sus especialidades y cuestionarios.
class AdminCatalogScreen extends StatelessWidget {
  const AdminCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminCatalogCubit>.value(
      value: sl<AdminCatalogCubit>(),
      child: const _AdminCatalogView(),
    );
  }
}

class _AdminCatalogView extends StatefulWidget {
  const _AdminCatalogView();

  @override
  State<_AdminCatalogView> createState() => _AdminCatalogViewState();
}

class _AdminCatalogViewState extends State<_AdminCatalogView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    sl<AdminCatalogCubit>().load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _mostrarFeedback(String? feedback) {
    if (feedback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(feedback), duration: const Duration(seconds: 3)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.cDeepAccent),
          tooltip: 'Volver al panel admin',
          onPressed: () => context.go(AppRoutes.adminDashboard),
        ),
        title: const Text('Catálogo de Servicios'),
        centerTitle: true,
      ),
      body: BlocConsumer<AdminCatalogCubit, AdminCatalogState>(
        listener: (context, state) {
          if (state is AdminCatalogError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
          if (state is AdminCatalogLoaded) {
            _mostrarFeedback(state.feedback);
          }
        },
        builder: (context, state) {
          if (state is AdminCatalogLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.cDeepAccent),
            );
          }
          if (state is AdminCatalogError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.cError, size: 44),
                  const SizedBox(height: 12),
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cDeepAccent,
                    ),
                    onPressed: () => context.read<AdminCatalogCubit>().load(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is! AdminCatalogLoaded) {
            return const SizedBox.shrink();
          }
          return _buildContenido(context, state);
        },
      ),
      floatingActionButton: Builder(
        builder: (fabContext) {
          final esCategorias = _tabController.index == 0;
          return FloatingActionButton(
            backgroundColor: AppTheme.cDeepAccent,
            tooltip: esCategorias ? 'Nueva categoría' : 'Nuevo servicio',
            onPressed: () {
              if (esCategorias) {
                _editarCategoriaDialog(context, null);
              } else {
                context.push(AppRoutes.adminCatalogServicio, extra: null);
              }
            },
            child: const Icon(Icons.add_rounded, color: Colors.white),
          );
        },
      ),
    );
  }

  Widget _buildContenido(BuildContext context, AdminCatalogLoaded state) {
    final cubit = context.read<AdminCatalogCubit>();

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.cDeepAccent,
          unselectedLabelColor: AppTheme.cMutedText,
          indicatorColor: AppTheme.cDeepAccent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Categorías'),
            Tab(text: 'Servicios'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _CategoriasTab(
                categorias: state.categorias,
                onEditar: (c) => _editarCategoriaDialog(context, c),
                onActivar: (c) => cubit.guardarCategoria(
                      id: c.id,
                      nombre: c.nombre,
                      descripcion: c.descripcion,
                      activo: !c.activo,
                    ),
              ),
              _ServiciosTab(
                servicios: state.servicios,
                onAbrir: (s) => context.push(
                  AppRoutes.adminCatalogServicio,
                  extra: s,
                ),
                onActivar: (s) => cubit.guardarServicio(
                      id: s.id,
                      categoriaId: s.categoriaId,
                      nombre: s.nombre,
                      descripcion: s.descripcion,
                      precioBase: s.precioBase,
                      tipoPrecio: s.tipoPrecio,
                      duracionEstimada: s.duracionEstimada,
                      requiereTelemedicina: s.requiereTelemedicina,
                      requiereFaceMap: s.requiereFaceMap,
                      requiereFotos: s.requiereFotos,
                      requiereConsentimiento: s.requiereConsentimiento,
                      activo: !s.activo,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editarCategoriaDialog(
    BuildContext context,
    CategoriaServicioEntity? categoria,
  ) {
    final cubit = context.read<AdminCatalogCubit>();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final nombreCtrl = TextEditingController(text: categoria?.nombre ?? '');
        final descCtrl =
            TextEditingController(text: categoria?.descripcion ?? '');
        var activo = categoria?.activo ?? true;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            void guardar() {
              final nombre = nombreCtrl.text.trim();
              if (nombre.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('El nombre es obligatorio')),
                );
                return;
              }
              cubit.guardarCategoria(
                id: categoria?.id ?? 0,
                nombre: nombre,
                descripcion: descCtrl.text.trim().isEmpty
                    ? null
                    : descCtrl.text.trim(),
                activo: activo,
              );
              Navigator.of(dialogContext).pop();
            }

            return AlertDialog(
              title: Text(categoria == null
                  ? 'Nueva categoría'
                  : 'Editar categoría'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activa'),
                    value: activo,
                    onChanged: (v) => setState(() => activo = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.cDeepAccent,
                  ),
                  onPressed: guardar,
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CategoriasTab extends StatelessWidget {
  final List<CategoriaServicioEntity> categorias;
  final ValueChanged<CategoriaServicioEntity> onEditar;
  final ValueChanged<CategoriaServicioEntity> onActivar;

  const _CategoriasTab({
    required this.categorias,
    required this.onEditar,
    required this.onActivar,
  });

  @override
  Widget build(BuildContext context) {
    if (categorias.isEmpty) {
      return const Center(child: Text('Aún no hay categorías.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final c in categorias) ...[
          _CategoriaTile(
            categoria: c,
            onEditar: () => onEditar(c),
            onActivar: () => onActivar(c),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CategoriaTile extends StatelessWidget {
  final CategoriaServicioEntity categoria;
  final VoidCallback onEditar;
  final VoidCallback onActivar;

  const _CategoriaTile({
    required this.categoria,
    required this.onEditar,
    required this.onActivar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.cWhite,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.cPastelPurple,
          child: const Icon(Icons.category_rounded, color: AppTheme.cDeepAccent),
        ),
        title: Text(
          categoria.nombre,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.cDarkText,
          ),
        ),
        subtitle: Text(
          categoria.descripcion ?? 'Sin descripción',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.cMutedText, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: categoria.activo,
              activeTrackColor: AppTheme.cBrandGreen,
              onChanged: (_) => onActivar(),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppTheme.cDeepAccent),
              onPressed: onEditar,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiciosTab extends StatelessWidget {
  final List<ServicioEntity> servicios;
  final ValueChanged<ServicioEntity> onAbrir;
  final ValueChanged<ServicioEntity> onActivar;

  const _ServiciosTab({
    required this.servicios,
    required this.onAbrir,
    required this.onActivar,
  });

  String _formatPrice(ServicioEntity service) {
    final suffix = switch (service.tipoPrecio) {
      TipoPrecio.precioFijo => '',
      TipoPrecio.porUnidad => '/unidad',
      TipoPrecio.porJeringa => '/jeringa',
      TipoPrecio.porSesion => '/sesión',
      TipoPrecio.porPlan => '/plan',
    };
    return '\$${service.precioBase}${suffix.isEmpty ? '' : ' '}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    if (servicios.isEmpty) {
      return const Center(child: Text('Aún no hay servicios.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final s in servicios) ...[
          _ServicioTile(
            servicio: s,
            precio: _formatPrice(s),
            onTap: () => onAbrir(s),
            onActivar: () => onActivar(s),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ServicioTile extends StatelessWidget {
  final ServicioEntity servicio;
  final String precio;
  final VoidCallback onTap;
  final VoidCallback onActivar;

  const _ServicioTile({
    required this.servicio,
    required this.precio,
    required this.onTap,
    required this.onActivar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.cWhite,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: Colors.black12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.cPastelPink,
          child: const Icon(Icons.spa_rounded, color: AppTheme.cDeepAccent),
        ),
        title: Text(
          servicio.nombre,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.cDarkText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              servicio.nombreCategoria ?? 'Sin categoría',
              style: const TextStyle(color: AppTheme.cMutedText, fontSize: 12),
            ),
            Text(
              precio,
              style: const TextStyle(
                color: AppTheme.cBrandGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (servicio.duracionEstimada != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${servicio.duracionEstimada} min',
                  style: const TextStyle(
                    color: AppTheme.cMutedText,
                    fontSize: 12,
                  ),
                ),
              ),
            Switch(
              value: servicio.activo,
              activeTrackColor: AppTheme.cBrandGreen,
              onChanged: (_) => onActivar(),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}