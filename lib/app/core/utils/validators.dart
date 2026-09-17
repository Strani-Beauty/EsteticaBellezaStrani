/// Helpers de validación de entradas de datos reutilizables.
///
/// Se usan como `validator` de los `TextFormField` de la app. Los campos
/// opcionales pasan `requerido: false` (vacío = válido; si se rellena, se valida
/// el formato).
library;

final RegExp _emailRegex = RegExp(
  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
);

/// Acepta "+" opcional y entre 10 y 15 dígitos (E.164 flexible): admite tanto
/// números de Houston (p. ej. +1 713...) como de Venezuela (+58 412...).
final RegExp _telefonoRegex = RegExp(r'^\+?\d{10,15}$');

/// Valida un correo electrónico con formato estándar
/// (`local@dominio.tld`, dominio con al menos 2 letras).
String? validarCorreo(String? v, {bool requerido = true}) {
  final texto = (v ?? '').trim();
  if (texto.isEmpty) return requerido ? 'Ingresa tu correo' : null;
  return _emailRegex.hasMatch(texto) ? null : 'Correo no válido';
}

/// Valida un teléfono con formato E.164 flexible ("+" opcional, 10-15 dígitos).
String? validarTelefono(String? v, {bool requerido = true}) {
  final texto = (v ?? '').trim();
  if (texto.isEmpty) return requerido ? 'Ingresa tu teléfono' : null;
  return _telefonoRegex.hasMatch(texto)
      ? null
      : 'Teléfono no válido (10-15 dígitos, + opcional)';
}