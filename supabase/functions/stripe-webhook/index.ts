import { handleOptions, jsonResponse } from '../_shared/cors.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Webhook de Stripe: confirma el pago de forma idempotente en la BD.
// Se invoca con `verify_jwt = false` (Stripe no autentica con JWT); la
// autenticidad se valida aquí con la firma `Stripe-Signature`.
//
// Eventos atendidos:
//   - payment_intent.succeeded con metadata.concepto == 'SALDO' (saldo final de
//     una cita): marca el pago como PAGADO y registra la transacción SALDO.
//   - Otros conceptos (DEPÓSITO / PAGO_TOTAL / PAGO_SERVICIO): el app ya crea
//     la cadena solicitudes → pagos → transacciones al confirmar el PaymentSheet,
//     así que el webhook solo acusa recibo (idempotencia por metadata).

function hmacSha256Hex(key: ArrayBuffer, data: ArrayBuffer): Promise<string> {
  return crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']).then(
    (k) => crypto.subtle.sign('HMAC', k, data),
  ).then((sig) => {
    const bytes = new Uint8Array(sig);
    let hex = '';
    for (const b of bytes) hex += b.toString(16).padStart(2, '0');
    return hex;
  });
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function verifyStripeSignature(payload: string, header: string | null, secret: string): Promise<boolean> {
  if (!header || !secret) return Promise.resolve(false);
  const entries = new Map<string, string>();
  for (const part of header.split(',')) {
    const eq = part.indexOf('=');
    if (eq > 0) entries.set(part.slice(0, eq), part.slice(eq + 1));
  }
  const timestamp = entries.get('t');
  const signature = entries.get('v1');
  if (!timestamp || !signature) return Promise.resolve(false);

  const signedPayload = `${timestamp}.${payload}`;
  return crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  ).then((key) => crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signedPayload))).then((sig) => {
    const bytes = new Uint8Array(sig);
    let hex = '';
    for (const b of bytes) hex += b.toString(16).padStart(2, '0');
    return constantTimeEqual(hex, signature);
  });
}

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const signingSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
  if (!signingSecret) {
    return jsonResponse({ error: 'STRIPE_WEBHOOK_SECRET no configurado' }, 503);
  }

  const payload = await req.text();
  const ok = await verifyStripeSignature(payload, req.headers.get('stripe-signature'), signingSecret);
  if (!ok) return jsonResponse({ error: 'Firma de webhook inválida' }, 400);

  let event;
  try {
    event = JSON.parse(payload);
  } catch {
    return jsonResponse({ error: 'Payload inválido' }, 400);
  }

  if (event.type !== 'payment_intent.succeeded') {
    return jsonResponse({ received: event.type });
  }

  const pi = event.data?.object ?? {};
  const metadata: Record<string, string> = pi.metadata ?? {};
  const concepto = String(metadata.concepto ?? '');
  const solicitudId = metadata.solicitud_id;
  const citaId = metadata.cita_id;

  // El app ya registra la cadena de depósitos/pagos totales al confirmar;
  // aquí confirmamos únicamente el SALDO final para que sea idempotente.
  if (concepto === 'SALDO' && solicitudId && citaId) {
    const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const url = Deno.env.get('SUPABASE_URL') ?? '';
    if (!serviceRole || !url) return jsonResponse({ error: 'Servidor mal configurado' }, 503);

    const supabase = createClient(url, serviceRole);

    const yaRegistrada = await supabase
      .from('transacciones')
      .select('id')
      .eq('cita_id', citaId)
      .eq('tipo_transaccion', 'SALDO')
      .maybeSingle();
    if (yaRegistrada.data) return jsonResponse({ received: 'already_processed' });

    const sol = await supabase
      .from('solicitudes')
      .select('paciente_id')
      .eq('id', solicitudId)
      .maybeSingle();
    const pacienteId = sol.data?.paciente_id as string | undefined;

    const monto = (pi.amount ?? 0) / 100;

    const { error: pagoError } = await supabase
      .from('pagos')
      .update({ estado: 'PAGADO', saldo_pendiente: 0, updated_at: new Date().toISOString() })
      .eq('solicitud_id', solicitudId);
    if (pagoError) return jsonResponse({ error: pagoError.message }, 500);

    const { error: txError } = await supabase
      .from('transacciones')
      .insert({
        solicitud_id: solicitudId,
        cita_id: citaId,
        paciente_id: pacienteId,
        tipo_transaccion: 'SALDO',
        monto,
        moneda: 'USD',
        estado: 'APROBADO',
        stripe_payment_id: pi.id,
        stripe_payment_intent: pi.id,
        fecha_transaccion: new Date().toISOString(),
      });
    if (txError) return jsonResponse({ error: txError.message }, 500);
  }

  return jsonResponse({ received: event.type });
});