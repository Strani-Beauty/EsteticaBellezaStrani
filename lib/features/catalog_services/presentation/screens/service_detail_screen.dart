import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/config/app_theme.dart';
import '../../domain/entities/servicio_entity.dart';
import '../widgets/service_image_hero.dart';

/// Vista a página completa del detalle de un servicio del catálogo.
///
/// Se muestra al tocar un servicio con sesión iniciada (paciente registrado),
/// antes del flujo de pago/reserva. Escritorio: imagen principal arriba-derecha,
/// descripción completa a la izquierda y galería de hasta 4 imágenes
/// relacionadas abajo-derecha. Celular: apilado vertical. Al pulsar
/// "Reservar este servicio" devuelve `'reservar'` para continuar con el flujo
/// de reserva (gate RN-020 → FaceMap → requisitos → resumen).
class ServiceDetailScreen extends StatelessWidget {
  final ServicioEntity service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Detalle del Servicio'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.cDeepAccent,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: isDesktop
                    ? _buildDesktop(context)
                    : _buildMobile(context),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Escritorio: dos columnas ──────────────────────────────────────────────
  Widget _buildDesktop(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildInfoColumna(context)),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: _buildImagenColumna(context)),
          ],
        ),
        const SizedBox(height: 28),
        _buildCta(context),
      ],
    );
  }

  // ── Celular: apilado vertical (título primero, luego imágenes) ────────────
  Widget _buildMobile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTituloBloque(),
        const SizedBox(height: 20),
        _buildImagenColumna(context),
        const SizedBox(height: 24),
        _buildDescripcionBloque(),
        const SizedBox(height: 28),
        _buildCta(context),
      ],
    );
  }

  Widget _buildImagenColumna(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ServiceImageHero(service: service, fallbackIconSize: 64),
          ),
        ),
        const SizedBox(height: 16),
        _buildGaleria(context),
      ],
    );
  }

  Widget _buildInfoColumna(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTituloBloque(),
        _buildDescripcionBloque(),
      ],
    );
  }

  // ── Encabezado: categoría, nombre, precio y duración ──────────────────────
  Widget _buildTituloBloque() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (service.nombreCategoria != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.cPastelPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              service.nombreCategoria!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.cDeepAccent,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          service.nombre,
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.cDarkText,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              formatPrecioServicio(service),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.cDeepAccent,
              ),
            ),
            if (service.duracionEstimada != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 16, color: AppTheme.cMutedText),
                  const SizedBox(width: 4),
                  Text(
                    '${service.duracionEstimada} min',
                    style: const TextStyle(fontSize: 14, color: AppTheme.cMutedText),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ── Descripción completa + badge de evaluación ────────────────────────────
  Widget _buildDescripcionBloque() {
    final descripcion = service.descripcion?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(color: Colors.grey),
        const SizedBox(height: 16),
        if (descripcion != null && descripcion.isNotEmpty) ...[
          Text(
            descripcion,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.cDarkText,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Text(
            'Este servicio no tiene una descripción disponible en este momento.',
            style: const TextStyle(fontSize: 13, color: AppTheme.cMutedText),
          ),
          const SizedBox(height: 16),
        ],
        if (service.requiereTelemedicina) _buildBadgeEvaluacion(),
      ],
    );
  }

  Widget _buildBadgeEvaluacion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cPastelPurple,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety_rounded, size: 20, color: AppTheme.cDeepAccent),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Requiere Evaluación Médica Interna antes de la reserva.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppTheme.cDarkText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaleria(BuildContext context) {
    const titulo = Text(
      'Galería de imágenes',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.cDarkText,
      ),
    );

    final slots = List.generate(4, (i) => _buildSlotGaleria(i));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        titulo,
        const SizedBox(height: 4),
        const Text(
          'Antes y después de este tipo de tratamiento',
          style: TextStyle(fontSize: 11.5, color: AppTheme.cMutedText),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            final columns = ancho >= 520 ? 4 : 2;
            final spacing = 10.0;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: 1,
              children: slots,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSlotGaleria(int index) {
    final url = index < service.imagenesAdicionales.length
        ? service.imagenesAdicionales[index]
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        color: AppTheme.cPastelPurple,
        child: (url != null && url.trim().isNotEmpty)
            ? Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    const _SlotVacio(),
              )
            : const _SlotVacio(),
      ),
    );
  }

  // ── Invitación a reservar + advertencia de pago ───────────────────────────
  Widget _buildCta(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cPastelPurple,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.cDeepAccent.withValues(alpha: 0.2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final apilado = constraints.maxWidth < 520;

          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatPrecioServicio(service),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.cDeepAccent,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Reserva tu cita y recibe el servicio en la comodidad de tu hogar.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.cDarkText, height: 1.4),
              ),
            ],
          );

          final boton = FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.cDeepAccent,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            onPressed: () => Navigator.pop(context, 'reservar'),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Reservar este servicio'),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (apilado) ...[
                info,
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: boton),
              ] else
                Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    boton,
                  ],
                ),
              if (service.requiereTelemedicina) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.cGoldAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.payment_rounded, size: 18, color: AppTheme.cGoldAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este servicio requiere Evaluación Médica Interna: deberás completar la cuota inicial de \$30 USD y la evaluación médica antes de reservar.',
                          style: TextStyle(fontSize: 12, color: AppTheme.cDarkText, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SlotVacio extends StatelessWidget {
  const _SlotVacio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.photo_library_rounded, size: 30, color: AppTheme.cDeepAccent),
    );
  }
}