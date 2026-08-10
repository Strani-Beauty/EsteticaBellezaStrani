import { handleOptions, jsonResponse } from '../_shared/cors.ts';
import { getUserFromRequest } from '../_shared/auth.ts';

// Crea un PaymentIntent en Stripe desde el backend.
// La STRIPE_SECRET_KEY se inyecta como secret de Supabase (NUNCA en el cliente).
// Devuelve clientSecret + paymentIntentId para que el app presente el PaymentSheet.

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const user = await getUserFromRequest(req);
  if (!user) return jsonResponse({ error: 'No autorizado' }, 401);

  const secretKey = Deno.env.get('STRIPE_SECRET_KEY') ?? '';
  if (!secretKey) {
    return jsonResponse({ error: 'Stripe no configurado en el servidor' }, 503);
  }

  const body = await req.json();
  const amount = Number(body.amount);
  const currency = String(body.currency ?? 'usd').toLowerCase();
  const concepto = String(body.concepto ?? 'PAGO_SERVICIO');
  const solicitudId = body.solicitud_id ? String(body.solicitud_id) : undefined;
  const citaId = body.cita_id ? String(body.cita_id) : undefined;

  if (!Number.isFinite(amount) || amount < 0.5) {
    return jsonResponse({ error: 'Monto inválido para el pago (mínimo 0.50 USD)' }, 400);
  }

  const params = new URLSearchParams();
  params.set('amount', String(Math.round(amount * 100)));
  params.set('currency', currency);
  params.set('automatic_payment_methods[enabled]', 'true');
  params.set('metadata[concepto]', concepto);
  params.set('metadata[usuario_id]', user.id);
  if (solicitudId) params.set('metadata[solicitud_id]', solicitudId);
  if (citaId) params.set('metadata[cita_id]', citaId);

  const response = await fetch('https://api.stripe.com/v1/payment_intents', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${secretKey}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: params,
  });

  const data = await response.json();
  if (!response.ok) {
    return jsonResponse(
      {
        error: data?.error?.message ?? 'No se pudo crear el pago.',
        code: data?.error?.code ?? 'STRIPE_ERROR',
      },
      502,
    );
  }

  return jsonResponse({
    clientSecret: data.client_secret,
    paymentIntentId: data.id,
    amount: (data.amount ?? 0) / 100,
    currency: data.currency,
  });
});