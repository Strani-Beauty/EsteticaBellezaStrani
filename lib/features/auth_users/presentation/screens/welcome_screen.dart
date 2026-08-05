import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:esteticaybellezastrani/app/config/app_theme.dart';
import 'package:esteticaybellezastrani/app/config/app_routes.dart';
import '../cubits/auth_cubit.dart';

/// Pantalla de bienvenida — punto de entrada público de la app.
/// Presenta la marca Strani y dirige al usuario según su rol.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Acceso profesional: solo entra si el usuario autenticado es especialista.
  /// Si no hay sesión (o el rol no es especialista) se envía al login.
  void _openSpecialist(BuildContext context) {
    final auth = context.read<AuthCubit>();
    final profile = auth.currentProfile;
    if (profile != null && profile.isSpecialist) {
      context.go(AppRoutes.specialistHome);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F5),
      body: isWide
          ? _buildWideLayout(context, size)
          : _buildNarrowLayout(context, size),
    );
  }

  Widget _buildWideLayout(BuildContext context, Size size) {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildLeftPanel(context, wide: true)),
        Expanded(flex: 4, child: _buildHeroPanel(size)),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, Size size) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: size.height * 0.38,
            width: double.infinity,
            child: _buildHeroPanel(size),
          ),
          _buildLeftPanel(context, wide: false),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context, {required bool wide}) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          color: const Color(0xFFFDF8F5),
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 52 : 28,
            vertical: wide ? 0 : 32,
          ),
          child: wide
              ? Center(child: _buildContent(context, wide: true))
              : _buildContent(context, wide: false),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool wide}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TagLabel(label: 'MEDICINA ESTÉTICA · BELLEZA · BIENESTAR'),
        const SizedBox(height: 20),
        const _BrandLogo(),
        const SizedBox(height: 24),
        RichText(
          text: TextSpan(
            style: GoogleFonts.playfairDisplay(
              fontSize: wide ? 42 : 34,
              color: AppTheme.cDarkText,
              height: 1.15,
            ),
            children: const [
              TextSpan(text: 'Donde la ciencia\n'),
              TextSpan(
                text: 'encuentra ',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              TextSpan(text: 'tu\nbelleza'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Tratamientos personalizados con tecnología avanzada,\nevaluación médica telemática y especialistas certificados.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.cMutedText, height: 1.6),
        ),
        const SizedBox(height: 10),
        Text(
          'Tu piel no necesita más productos.\nNecesita un plan médico bien indicado.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: AppTheme.cDeepAccent,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 36),
        // Botón principal
        _ActionButton(
          icon: Icons.calendar_today_rounded,
          label: 'Agendar Cita',
          subtitle: 'Soy Paciente',
          isPrimary: true,
          onTap: () => context.go(AppRoutes.login),
        ),
        const SizedBox(height: 14),
        // Botones secundarios
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.medical_services_rounded,
                label: 'Especialistas',
                subtitle: 'Acceso profesional',
                isPrimary: false,
                onTap: () => _openSpecialist(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.spa_rounded,
                label: 'Explorar Servicios',
                subtitle: 'Ver catálogo',
                isPrimary: false,
                onTap: () => context.go(AppRoutes.services),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _TrustBadge(icon: Icons.verified_user_rounded, text: 'Evaluación Qualify'),
            _TrustBadge(icon: Icons.lock_rounded,          text: 'Pago Seguro'),
            _TrustBadge(icon: Icons.star_rounded,          text: 'Especialistas Certificados'),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHeroPanel(Size size) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7D6E0), Color(0xFFE8D5C4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Image.asset(
          'assets/images/Imagen_Ini.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const _HeroFallback(),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFDF8F5).withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.spa_rounded, color: AppTheme.cDeepAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'ESTÉTICA & BELLEZA STRANI',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.cDeepAccent,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────

class _TagLabel extends StatelessWidget {
  final String label;
  const _TagLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.8,
          color: AppTheme.cDeepAccent,
        ),
      );
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.spa_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Strani',
              style: GoogleFonts.playfairDisplay(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.cDeepAccent,
                height: 1.0,
              ),
            ),
            Text(
              'ESTÉTICA & BELLEZA',
              style: GoogleFonts.inter(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.8,
                color: AppTheme.cMutedText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovered ? -2.0 : 0.0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: widget.isPrimary ? AppTheme.primaryGradient : null,
            color:    widget.isPrimary ? null : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: widget.isPrimary
                ? null
                : Border.all(
                    color: _hovered ? AppTheme.cDeepAccent : Colors.grey.shade200,
                  ),
            boxShadow: _hovered
                ? (widget.isPrimary ? AppTheme.elevatedShadow : AppTheme.cardShadow)
                : AppTheme.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: widget.isPrimary ? Colors.white : AppTheme.cDeepAccent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: widget.isPrimary ? Colors.white : AppTheme.cDarkText,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: widget.isPrimary
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppTheme.cMutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: widget.isPrimary
                    ? Colors.white.withValues(alpha: 0.75)
                    : AppTheme.cMutedText,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TrustBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.cDeepAccent),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.cMutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7D6E0), Color(0xFFE2D5F0), Color(0xFFBEE1E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_rounded, size: 90,
                color: AppTheme.cDeepAccent.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              'STRANI',
              style: GoogleFonts.playfairDisplay(
                fontSize: 36,
                color: AppTheme.cDeepAccent.withValues(alpha: 0.45),
                letterSpacing: 10,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ESTÉTICA & BELLEZA',
              style: GoogleFonts.inter(
                fontSize: 11,
                letterSpacing: 4,
                color: AppTheme.cDeepAccent.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
