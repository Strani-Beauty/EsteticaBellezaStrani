---
name: stripe-pagos-strani
description: Guía de integración de pagos Stripe en Flutter Web con Edge Functions de Supabase para Estética y Belleza Strani. Usar cuando se trabaje en Stripe, pagos, checkout, Checkout Session, PaymentIntent, PaymentSheet, webhook, suscripciones/membresía, o en los módulos payments_stripe y las edge functions create-payment-intent / stripe-webhook / verify-payment.
---

# Guía de Integración Stripe — Flutter Web + Supabase Edge Functions

**Versión:** 1.0 (agosto 2026)
**Alcance:** Pasos completos + consideraciones para integrar pagos Stripe en una app Flutter Web con backend de Supabase Edge Functions (Deno).
**Uso con OpenCode:** este archivo es un skill de OpenCode (`.opencode/skills/stripe-pagos-strani/SKILL.md`); se carga automáticamente al trabajar en el proyecto y aplica esta guía.

---

## Contexto del proyecto (Estética y Belleza Strani)

Datos reales del proyecto para sustituir los placeholders genéricos:

- **Proyecto Supabase**: `hhyjremkguvphmjuaazp` (linked, `supabase/.temp/linked-project.json`).
- **Dominio de hosting**: Firebase Hosting (proyecto `esteticaybellezastrani`) → `https://esteticaybellezastrani.web.app`.
- **Tabla de suscripciones**: `subscriptions` (aún NO existe en la BD). Hoy el equivalente funcional son `transacciones` / `pagos` / `configuracion_sistema`.

**Estado actual (temporal) y arquitectura objetivo:**

- El repo usa hoy una estructura temporal de **Payment Intents + PaymentSheet**: edge functions `create-payment-intent` (mínimo 0.50 USD, metadata `concepto`/`usuario_id`/`solicitud_id`/`cita_id`, secret por env `STRIPE_SECRET_KEY`) y `stripe-webhook` (verificación manual HMAC-SHA256 de `stripe-signature` con `STRIPE_WEBHOOK_SECRET`; atiende `payment_intent.succeeded` y `payment_intent.payment_failed` delegando en los RPCs `confirmar_pago_saldo`, `confirmar_deposito_solicitud` y `registrar_pago_fallido`). Compartidos `_shared/cors.ts` y `_shared/auth.ts`.
- Esta guía describe la **arquitectura objetivo (Checkout Sessions + `subscriptions`)** que reemplazará a la actual **antes de la entrega de la App**, cuando se tenga la API real de Stripe del usuario final. No crear `subscriptions`/`app_settings` antes de esa migración.
- Claves de Stripe NUNCA en código, commits o chats: hoy son secrets de Supabase (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`); la guía los gestiona vía tabla de configuración (`app_settings`) — migrar al final.

---

## 1. Arquitectura

- **3 Edge Functions (Deno)** en Supabase:
  - `create-checkout` — autentica al usuario (JWT), lee configuración, valida monto mínimo, crea la Checkout Session y devuelve `{ url }`.
  - `stripe-webhook` — verifica la firma (`whsec_`), maneja `checkout.session.completed` y hace UPSERT en la tabla de suscripciones.
  - `verify-payment` — refuerzo: el frontend lo llama al volver con `session_id`; marca `paid` si Stripe confirma.
- **Tabla de suscripciones** (`subscriptions`): `profile_id` **UNIQUE**, `paid`, `paid_at`, `stripe_customer_id`, `amount`, `currency`. UPSERT con `onConflict: 'profile_id'` (idempotente contra eventos duplicados).
- **Tabla de configuración** (`app_settings`): `subscription_price`, `currency`, `stripe_publishable_key`, `stripe_secret_key`, `stripe_webhook_secret`, mensajes de membresía/bloqueo.
- **Montos en centavos**: `amount_total / 100` al guardar.
- **Botón "Marcar como pagado (testeo)"** (opcional): NO escribe `amount` → permite distinguir en la BD un pago manual de uno automático (si hay `amount`, vino del webhook/verify).

## 2. Requisitos

- Cuenta Stripe (modo prueba para desarrollar; live solo con cuenta verificada).
- Proyecto Supabase (Edge Functions).
- Hosting web HTTPS público (Firebase Hosting, Vercel, etc.) — los webhooks deben ser HTTPS. En este proyecto: Firebase Hosting en `https://esteticaybellezastrani.web.app`.
- Supabase CLI + token de acceso (`SUPABASE_ACCESS_TOKEN`) para desplegar funciones.

## 3. Paso a paso

### Paso 1 — Base de datos

```sql
create table if not exists public.subscriptions (
  id bigint generated always as identity primary key,
  profile_id uuid not null unique,
  paid boolean not null default false,
  paid_at timestamptz,
  stripe_customer_id text,
  amount numeric,
  currency text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.subscriptions enable row level security;

create policy "users see own subscription" on public.subscriptions
  for select using (auth.uid() = profile_id);
create policy "users update own subscription" on public.subscriptions
  for update using (auth.uid() = profile_id);

-- Tabla de configuración (una fila por clave)
create table if not exists public.app_settings (
  key text primary key,
  value text not null default ''
);
```

### Paso 2 — Edge Functions (código completo)

#### create-checkout/index.ts

```ts
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders() });
  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json({ error: 'No autorizado' }, 401);

    const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
    if (authError || !user) return json({ error: 'No autorizado' }, 401);

    const { data: settings } = await supabase.from('app_settings').select('key, value');
    const val = (k: string) => settings?.find((s) => s.key === k)?.value ?? '';
    const secretKey = val('stripe_secret_key');
    const price = parseFloat(val('subscription_price') || '10');
    const currency = (val('currency') || 'USD').toLowerCase();

    if (!secretKey) return json({ error: 'Stripe no configurado: falta la secret key' }, 500);

    const unitAmount = Math.round(price * 100);
    const minAmount = currency === 'usd' ? 50 : 1000; // USD >= $0.50, MXN >= $10
    const minPrice = currency === 'usd' ? '0.50' : '10';
    if (unitAmount < minAmount) {
      return json({ error: `El monto mínimo para ${currency.toUpperCase()} es ${minPrice} ${currency.toUpperCase()}` }, 400);
    }

    const stripe = new Stripe(secretKey);
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency: currency,
          product_data: { name: 'Membresía' },
          unit_amount: unitAmount,
        },
        quantity: 1,
      }],
      client_reference_id: user.id,
      metadata: { profile_id: user.id },
      // IMPORTANTE: con hash routing (#/), la ruta DEBE llevar #/
      success_url: 'https://esteticaybellezastrani.web.app/#/payment-success?session_id={CHECKOUT_SESSION_ID}',
      cancel_url: 'https://esteticaybellezastrani.web.app/#/payment-cancel',
    });

    return json({ url: session.url });
  } catch (e) {
    return json({ error: e.message ?? 'Error al crear el pago' }, 500);
  }
});

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}
function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } });
}
```

#### stripe-webhook/index.ts

```ts
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders() });
  try {
    const signature = req.headers.get('stripe-signature');
    if (!signature) return json({ error: 'Firma faltante' }, 400);

    const body = await req.text(); // NUNCA manipular el raw body antes de verificar

    const { data: settings } = await supabase.from('app_settings').select('key, value');
    const val = (k: string) => settings?.find((s) => s.key === k)?.value ?? '';
    const secretKey = val('stripe_secret_key');
    const webhookSecret = val('stripe_webhook_secret');

    if (!secretKey || !webhookSecret) return json({ error: 'Stripe no configurado' }, 500);

    const stripe = new Stripe(secretKey);

    // IMPORTANTE: en Deno usar constructEventAsync (constructEvent falla con SubtleCryptoProvider)
    let event: Stripe.Event;
    try {
      event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret);
    } catch (err) {
      return json({ error: `Firma inválida: ${err.message}` }, 400);
    }

    if (event.type === 'checkout.session.completed') {
      const session = event.data.object as Stripe.Checkout.Session;
      const profileId = session.metadata?.profile_id ?? session.client_reference_id;

      if (profileId) {
        const { error } = await supabase
          .from('subscriptions')
          .upsert({
            profile_id: profileId,
            paid: true,
            paid_at: new Date().toISOString(),
            stripe_customer_id: typeof session.customer === 'string' ? session.customer : undefined,
            amount: (session.amount_total ?? 0) / 100,
            currency: (session.currency ?? 'usd').toUpperCase(),
            updated_at: new Date().toISOString(),
          }, { onConflict: 'profile_id' });

        if (error) return json({ error: `Error al marcar pago: ${error.message}` }, 500);
      }
    }

    return json({ received: true });
  } catch (e) {
    return json({ error: e.message ?? 'Error en webhook' }, 500);
  }
});

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, stripe-signature',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}
function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } });
}
```

#### verify-payment/index.ts

```ts
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders() });
  try {
    const url = new URL(req.url);
    const sessionId = url.searchParams.get('session_id');
    if (!sessionId) return json({ error: 'session_id requerido' }, 400);

    const { data: settings } = await supabase.from('app_settings').select('key, value');
    const val = (k: string) => settings?.find((s) => s.key === k)?.value ?? '';
    const secretKey = val('stripe_secret_key');
    if (!secretKey) return json({ error: 'Stripe no configurado' }, 500);

    const stripe = new Stripe(secretKey);
    const session = await stripe.checkout.sessions.retrieve(sessionId);

    const profileId = session.metadata?.profile_id ?? session.client_reference_id;
    const paid = session.payment_status === 'paid';

    if (paid && profileId) {
      const { error } = await supabase
        .from('subscriptions')
        .upsert({
          profile_id: profileId,
          paid: true,
          paid_at: new Date().toISOString(),
          stripe_customer_id: typeof session.customer === 'string' ? session.customer : undefined,
          amount: (session.amount_total ?? 0) / 100,
          currency: (session.currency ?? 'usd').toUpperCase(),
          updated_at: new Date().toISOString(),
        }, { onConflict: 'profile_id' });

      if (error) return json({ error: `Error al marcar pago: ${error.message}` }, 500);
    }

    return json({ paid, status: session.payment_status });
  } catch (e) {
    return json({ error: e.message ?? 'Error al verificar pago' }, 500);
  }
});

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  };
}
function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders(), 'Content-Type': 'application/json' } });
}
```

### Paso 3 — Deploy (Supabase CLI)

```bash
# OJO: el webhook DEBE desplegarse con --no-verify-jwt (Stripe no envía JWT)
$env:SUPABASE_ACCESS_TOKEN = "<TU_TOKEN>"
npx supabase functions deploy create-checkout --project-ref hhyjremkguvphmjuaazp
npx supabase functions deploy stripe-webhook --project-ref hhyjremkguvphmjuaazp --no-verify-jwt
npx supabase functions deploy verify-payment --project-ref hhyjremkguvphmjuaazp
```

Verificar en el dashboard que `stripe-webhook` tenga `verify_jwt: false`.

### Paso 4 — Configuración en Stripe

1. **Developers/Workbench → Webhooks → "Crear destino de evento"** → "Tu cuenta".
2. Seleccionar **SOLO `checkout.session.completed`** (NO dejar eventos por defecto tipo `account.*` / `capability.*` — generan "dos estilos de carga" y destinos extra que responden 200 sin marcar nada).
3. Tipo de destino: **"Punto de conexión de webhook"** (NO EventBridge/Azure).
4. URL: `https://hhyjremkguvphmjuaazp.supabase.co/functions/v1/stripe-webhook` (HTTPS pública obligatoria).
5. **"Signing secret" → Reveal** → copiar `whsec_...`.
6. Guardar ese `whsec_` en la tabla de configuración (panel admin o SQL directo).

### Paso 5 — App Flutter (frontend)

- Ruta `/payment-success` debe recibir `sessionId` desde el router: `state.uri.queryParameters['session_id']` (go_router ya parsea el query del hash).
- La pantalla de retorno llama a `verify-payment` con `session_id` + `Authorization: Bearer <token>` y, si `paid == true`, invalida el provider de suscripción.
- Botón "Pagar": `functions.invoke('create-checkout')` → navegar a `data['url']`.
- IMPORTANTE: la URL de retorno generada por Stripe incluye `#/` (hash routing). No usar `window.location.search` para leer el session_id (está vacío con hash) — leer del hash o del estado de go_router.

### Paso 6 — Prueba (modo prueba)

1. Tarjeta: `4242 4242 4242 4242`, fecha futura, CVC 123.
2. Flujo: login → Perfil → "Pagar" → checkout → 4242 → Pagar → redirige a `/#/payment-success?session_id=...` → "¡Pago exitoso!".
3. Verificación en 3 vías:
   - **BD**: `paid = true` + `amount` presente (automático).
   - **Stripe → Transacciones**: cargo visible (ej. 11.90 MXN − 4.33 MXN comisión).
   - **Stripe → Webhooks → Entregas de eventos**: intento con **200**.

### Paso 7 — Go-live (producción)

1. Cuenta Stripe del cliente **VERIFICADA** (identificación, negocio, cuenta bancaria).
2. Claves LIVE (`sk_live_` / `pk_live_`) en la tabla de configuración.
3. **Crear NUEVO endpoint webhook en modo activo** (misma URL, solo `checkout.session.completed`, nuevo `whsec_`).
4. Precio + moneda reales (la moneda la dicta el país de la cuenta: México=MXN, USA=USD).
5. Pago real de prueba.

## 4. ⚠️ Los 10 errores que cuestan horas (síntoma → causa → fix)

| # | Síntoma | Causa | Fix |
|---|---------|-------|-----|
| 1 | Webhook **401** en Entregas | Función con `verify_jwt: true` | Deploy con **`--no-verify-jwt`** |
| 2 | `SubtleCryptoProvider cannot be used in a synchronous context` | `constructEvent()` no funciona en Deno | Usar **`await constructEventAsync(...)`** |
| 3 | Al pagar redirige a `/profile` en vez de la pantalla de éxito | `success_url` sin `#/` (hash routing) | `https://esteticaybellezastrani.web.app/#/payment-success?session_id={CHECKOUT_SESSION_ID}` |
| 4 | "No se encontró la sesión de pago" | La pantalla leía `window.location.search` (vacío con hash) | Leer del **hash** o `GoRouterState.uri.queryParameters['session_id']` |
| 5 | Webhook responde 200 pero no marca nada | Endpoint con eventos por defecto (`account.*`) | Endpoint con **SOLO `checkout.session.completed`** |
| 6 | "Firma inválida" | `whsec_` del panel no coincide con el del endpoint actual | Al recrear endpoint → actualizar secret (formato `whsec_` + 32 chars) |
| 7 | Stripe rechaza el pago | Monto menor al mínimo | USD ≥ **$0.50**, MXN ≥ **$10**; validar en función y panel |
| 8 | No llegan eventos nuevos | Endpoint eliminado / config rota | Recrear (hasta 16 endpoints; URL HTTPS pública) |
| 9 | `stripe_customer_id` null | `customer_creation: if_required` | Normal; opcional forzar Customer |
| 10 | Cuenta real no cobra / país no soportado | Venezuela NO soportado por Stripe | Cuenta en país soportado (México/MXN, USA/USD) |

## 5. Comportamientos de Stripe (no redescubrir)

- Reintentos automáticos: **3 en modo prueba** (varias horas). Manual "Reenviar": hasta **15 días** (dashboard) / 30 días (CLI `stripe events resend`).
- Responder **2xx rápido** antes de lógica pesada (evitar timeouts).
- **No manipular el raw body** antes de verificar la firma (rompe la verificación).
- Tolerancia de firma: **5 minutos** por defecto (nunca 0).
- Rotación de secreto: hasta **2 secretos activos** (24h de gracia).
- **TLS 1.2+** obligatorio; redirecciones 3xx = fallo; IPs fijas de Stripe (permitirlas opcionalmente).
- Verificar firma SIEMPRE (evita spoofing). Eventos duplicados: el UPSERT con `onConflict` los absorbe.
- Control de versiones de API: el evento lleva la versión del momento en que se creó.

## 6. Seguridad y operación

- Claves solo en la BD de configuración — **NUNCA** en código, commits o chats.
- Si una key se expone → **Roll key** (regenerar) y actualizar configuración.
- Rotar el secreto del webhook periódicamente.
- Deploy/commits/push solo con autorización explícita del dueño del proyecto.

---

*Documento generado a partir de la experiencia real de integración (agosto 2026). Si encuentras un error nuevo, agrégalo a la sección 4.*