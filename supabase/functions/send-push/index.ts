import { handleOptions, jsonResponse } from '../_shared/cors.ts';
import { getUserFromRequest } from '../_shared/auth.ts';

// Envía notificaciones push (FCM) a los tokens de `dispositivos_usuario`.
//
// Se invoca desde la BD (pg_net → `notificar_solicitud_asignada_push`) con el
// anon key, o manualmente para pruebas. Requiere el secret `FCM_LEGACY_SERVER_KEY`
// (legacy HTTP API de FCM, proyectada a Firebase Cloud Messaging).
//
// Cuerpo esperado:
//   { "tokens": string[], "titulo": string, "mensaje": string, "data": object? }
//
// Si la app se autentica (JWT), ignora `tokens` y resuelve los tokens de
// `dispositivos_usuario` para el usuario autenticado. Si llega sin JWT, usa
// `tokens` tal cual (caso del hook pg_net).

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const serverKey = Deno.env.get('FCM_LEGACY_SERVER_KEY') ?? '';
  if (!serverKey) {
    return jsonResponse({ error: 'FCM_LEGACY_SERVER_KEY no configurado' }, 503);
  }

  const user = await getUserFromRequest(req);

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Payload inválido' }, 400);
  }

  let tokens: string[] = body.tokens ?? [];
  if (user?.id && Array.isArray(tokens) && tokens.length === 0) {
    // Auto-resuelve los tokens del usuario autenticado.
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const serviceRole = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    if (!supabaseUrl || !serviceRole) {
      return jsonResponse({ error: 'Servidor mal configurado' }, 503);
    }
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
    const supabase = createClient(supabaseUrl, serviceRole);
    const { data } = await supabase
      .from('dispositivos_usuario')
      .select('token_fcm')
      .eq('usuario_id', user.id)
      .eq('activo', true)
      .not('token_fcm', 'is', null);
    tokens = (data ?? []).map((d: any) => String(d.token_fcm)).filter(Boolean);
  }

  if (!Array.isArray(tokens) || tokens.length === 0) {
    return jsonResponse({ received: 'no_tokens' });
  }

  const notification = {
    title: String(body.titulo ?? 'Estética y Belleza Strani'),
    body: String(body.mensaje ?? ''),
  };
  const data = (body.data && typeof body.data === 'object')
    ? body.data
    : {};

  const fcmPayload = {
    registration_ids: tokens,
    notification,
    data,
    priority: 'high',
  };

  const response = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      Authorization: `key=${serverKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(fcmPayload),
  });

  const fcmData = await response.json().catch(() => null);
  if (!response.ok) {
    return jsonResponse(
      { error: fcmData?.error ?? 'FCM rechazó el envío', details: fcmData },
      502,
    );
  }

  return jsonResponse({ sent: tokens.length, results: fcmData?.results ?? [] });
});
