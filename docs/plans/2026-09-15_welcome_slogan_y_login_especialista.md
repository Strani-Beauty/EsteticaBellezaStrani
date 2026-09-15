# Plan: Slogan nuevo, reorden de CTA en bienvenida y login directo de especialista

Fecha: 2026-09-15
Estado: aprobado por usuario (sin commit — habrá más cambios luego)

## Objetivo
Cambios solicitados por el usuario final en la vista de bienvenida y flujo de acceso:

1. Cambiar el slogan de la vista de bienvenida por:
   "Nuestro spa, hasta la comodidad de tu hogar. Vive la experiencia de un spa de estética avanzada sin moverte de casa. Botox, fillers y más, aplicados por expertos certificados."
2. En la misma vista, eliminar el botón "Agendar cita / Soy paciente" y dejar el texto "Donde la ciencia encuentra tu belleza" alineado en solo dos líneas.
3. Al hacer clic en el botón "Especialista", ir directamente a la vista de login de especialistas.

## Decisiones confirmadas con el usuario
- El slogan reemplaza los dos párrafos descriptivos actuales ("Tratamientos personalizados..." e "Tu piel no necesita..."). El titular "Donde la ciencia encuentra tu belleza" se conserva (solo re-alineado a 2 líneas).
- Los botones restantes ("Especialistas" y "Explorar Servicios") mantienen el estilo secundario actual.

## Cambios

### `lib/features/auth_users/presentation/screens/welcome_screen.dart`
- [x] Reemplazar los dos `Text` descriptivos (líneas ~144-157) por un único `Text` con el nuevo slogan (GoogleFonts.inter, fontSize 14, cMutedText, height 1.6).
- [x] Titular (RichText ~126-142): pasar de 3 líneas a 2 con el split "Donde la ciencia" / "encuentra tu belleza", conservando la itálica en "encuentra". Split seguro de ancho: línea 2 de 20 caracteres cabe en paneles anchos (42px) y estrechos (34px).
- [x] Eliminar el botón primario "Agendar Cita / Soy Paciente" y su espaciado (SizedBox height 36 + _ActionButton + SizedBox height 14), dejando solo el `Row` con Especialistas / Explorar Servicios.
- [x] `_openSpecialist`: navegar a `context.go('${AppRoutes.login}?login=especialista')`. Quitar la lógica de perfil (ahora el route guard redirige por rol a autenticados). Eliminar imports sin uso: `../cubits/auth_cubit.dart` y `package:flutter_bloc/flutter_bloc.dart`.

### `lib/features/auth_users/presentation/screens/login_screen.dart`
- [x] Añadir parámetro `loginEspecialista` (bool, default false).
- [x] En `initState`: si `loginEspecialista` → `_selectedType = _UserType.specialist; _mode = _AuthMode.signIn`. Mutuamente excluyente con `registroPaciente` (if/else if).

### `lib/app/config/app_routes.dart`
- [x] En el builder de `/login`, pasar `loginEspecialista: state.uri.queryParameters['login'] == 'especialista'`.

## Verificación
- [x] `flutter analyze` limpio (No issues found).
- [x] `flutter test` (366 tests pasan).
- [ ] Manual en `flutter run -d chrome`: slogan nuevo visible, titular en 2 líneas, sin botón "Agendar Cita", botón "Especialistas" abre el formulario "Ingresar como Especialista".

## Notas
- Sin commit (usuario lo aprobó sin commitear; hay más cambios pendientes).