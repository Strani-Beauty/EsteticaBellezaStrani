import 'package:flutter/material.dart';
import '../../../../app/config/app_theme.dart';
import '../../domain/entities/servicio_entity.dart';

/// Convierte un texto a slug para asset: minúsculas, sin acentos, sin
/// caracteres especiales y con los espacios como guion bajo.
String servicioSlug(String input) {
  const accents = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
    'ñ': 'n', 'Á': 'a', 'É': 'e', 'Í': 'i', 'Ó': 'o', 'Ú': 'u', 'Ü': 'u', 'Ñ': 'n',
  };
  final buffer = StringBuffer();
  for (final char in input.toLowerCase().trim().split('')) {
    buffer.write(accents[char] ?? (RegExp(r'[a-z0-9 ]').hasMatch(char) ? char : ''));
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), '_');
}

/// Ícono heurístico según el nombre/categoría del servicio (fallback visual).
IconData iconoServicio(ServicioEntity service) {
  final nombre = service.nombre.toLowerCase();
  final categoria = service.nombreCategoria?.toLowerCase() ?? '';

  if (nombre.contains('inyectable') || nombre.contains('toxina') || nombre.contains('jeringa') || categoria.contains('inyectable')) {
    return Icons.local_hospital;
  }
  if (nombre.contains('lás') || nombre.contains('lase') || nombre.contains('pulsada')) {
    return Icons.wb_incandescent;
  }
  if (nombre.contains('corporal') || nombre.contains('cuerpo') || nombre.contains('lipólisis') || nombre.contains('reductor') || nombre.contains('moldeamiento')) {
    return Icons.accessibility_new;
  }
  if (nombre.contains('mesoterapia') || nombre.contains('adelgazamiento') || nombre.contains('nutricion')) {
    return Icons.fitness_center;
  }
  if (nombre.contains('rejuvenecimiento') || nombre.contains('facial') || nombre.contains('piel') || nombre.contains('peeling') || nombre.contains('booster') || nombre.contains('skin')) {
    return Icons.face;
  }
  return Icons.spa;
}

/// Formatea el precio con prefijo "Desde $" y el sufijo según `TipoPrecio`.
String formatPrecioServicio(ServicioEntity service) {
  final suffix = switch (service.tipoPrecio) {
    TipoPrecio.precioFijo => '',
    TipoPrecio.porUnidad => '/unidad',
    TipoPrecio.porJeringa => '/jeringa',
    TipoPrecio.porSesion => '/sesión',
    TipoPrecio.porPlan => '/plan',
  };
  return 'Desde \$${service.precioBase}${suffix.isEmpty ? '' : ' '}$suffix';
}

const _kServiceAssetExtensions = ['.jpg', '.jfif', '.jpeg', '.png', '.webp'];

/// Gradiente + ícono como fallback visual de un servicio sin imagen.
class ServiceImageFallback extends StatelessWidget {
  final ServicioEntity service;
  final double iconSize;

  const ServiceImageFallback({super.key, required this.service, this.iconSize = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.cPastelPink, AppTheme.cPastelPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(iconoServicio(service), size: iconSize, color: AppTheme.cDeepAccent),
      ),
    );
  }
}

/// Hero de la imagen principal de un servicio: `imagenUrl` (network) si existe;
/// si no, intenta el asset local `assets/images/service_<slug>`; si no, fallback.
class ServiceImageHero extends StatelessWidget {
  final ServicioEntity service;
  final BoxFit fit;
  final double fallbackIconSize;

  const ServiceImageHero({
    super.key,
    required this.service,
    this.fit = BoxFit.cover,
    this.fallbackIconSize = 52,
  });

  @override
  Widget build(BuildContext context) {
    final imagenUrl = service.imagenUrl;
    if (imagenUrl != null && imagenUrl.trim().isNotEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.cPastelPurple,
        child: Image.network(
          imagenUrl,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) =>
              ServiceImageFallback(service: service, iconSize: fallbackIconSize),
        ),
      );
    }

    final slug = servicioSlug(service.nombre);
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.cPastelPurple,
      child: _ServiceHeroAsset(
        basePath: 'assets/images/service_$slug',
        fallback: ServiceImageFallback(service: service, iconSize: fallbackIconSize),
        fit: fit,
      ),
    );
  }
}

/// Intenta cargar `assets/images/service_<slug>` probando cada extensión
/// soportada. Si ninguna existe, muestra el fallback sin depender del AssetManifest.
class _ServiceHeroAsset extends StatefulWidget {
  final String basePath;
  final Widget fallback;
  final BoxFit fit;

  const _ServiceHeroAsset({required this.basePath, required this.fallback, required this.fit});

  @override
  State<_ServiceHeroAsset> createState() => _ServiceHeroAssetState();
}

class _ServiceHeroAssetState extends State<_ServiceHeroAsset> {
  int _extIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_extIndex >= _kServiceAssetExtensions.length) return widget.fallback;

    final path = widget.basePath + _kServiceAssetExtensions[_extIndex];
    return Image.asset(
      path,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        final next = _extIndex + 1;
        if (next >= _kServiceAssetExtensions.length) return widget.fallback;
        _extIndex = next;
        return build(context);
      },
    );
  }
}