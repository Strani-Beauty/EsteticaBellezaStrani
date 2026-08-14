# Configuración de email / SMTP (Supabase)

- **Fecha**: 2026-08-14
- **Proveedor elegido**: Gmail / Google Workspace.
- **Aplicación**: Estética y Belleza Strani (Supabase, proyecto ref `hhyjremkguvphmjuaazp`).
- **Objetivo**: que Supabase entregue los correos transaccionales (confirmación de correo, recuperación de contraseña) → desbloquea las pruebas AU-H-03 y AU-H-10.

## Configuración en Supabase (dashboard)

Authentication → Email → **Custom SMTP**:

| Campo | Valor |
|---|---|
| Host | `smtp.gmail.com` |
| Puerto | `465` (SSL) o `587` (STARTTLS) |
| Usuario | correo remitente completo (ej. `no-reply@tudominio.com` si es Workspace) |
| Contraseña | **App Password** (16 caracteres) — no la contraseña normal |
| From email / sender | el mismo correo remitente |

Además, mantener **Confirm email ON** en Authentication → Email → Confirm email.

## Cómo generar el App Password (Gmail / Workspace)

1. Google Account → Security → **2-Step Verification** (debe estar activo; sin 2FA no existe la opción).
2. Security → **App passwords**.
3. Crear una app (p. ej. "Supabase") → Google genera una clave de 16 caracteres.
4. Pegar esa clave en el campo de contraseña del Custom SMTP de Supabase.

## Precondiciones

- 2FA activo en la cuenta de Google (obligatorio para App Passwords).
- En Google Workspace, el administrador del dominio debe permitir el envío SMTP (si restringe el acceso a apps, autorizar el App Password).
- Para `@gmail.com` personal no hace falta dominio propio.

## Alternativa de prueba sin SMTP

Supabase → Authentication → **Logs / Emails**: ahí aparece el enlace de confirmación/recovery generado aunque no haya SMTP; se copia y se abre en el navegador para completar el flujo (útil para pruebas AU-H-03/AU-H-10 sin depender de un proveedor).

## Notas de seguridad

- El App Password **no se guarda en el repositorio** (nada de SMTP en `.env`/`.env.example`; se configura solo en el dashboard). Conservarlo en el gestor de contraseñas.
- Si se rota la contraseña de Google o se revoca el App Password, hay que actualizarlo en el dashboard de Supabase.
