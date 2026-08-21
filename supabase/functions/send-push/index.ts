import { handleOptions, jsonResponse } from '../_shared/cors.ts';
import { getUserFromRequest } from '../_shared/auth.ts';

// Envía notificaciones push (FCM) a los tokens de `dispositivos_usuario`.
//
// Usa la API **FCM HTTP v1** (`/v1/projects/<project>/messages:send`). La API
// legacy (`/fcm/send`) fue descontinuada por Google (devuelve HTTP 404).
// Requiere el secret `FCM_SERVICE_ACCOUNT` = JSON del service account de
// Firebase (Console → Project settings → Service accounts → Generate new
// private key). El access token OAuth se obtiene firmando un JWT RS256 con la
// clave privada y se cachea hasta ~1h.
//
// Cuerpo esperado:
//   { "tokens": string[], "titulo": string, "mensaje": string, "data": object? }
//
// Si la app se autentica (JWT), ignora `tokens` y resuelve los tokens de
// `dispositivos_usuario` para el usuario autenticado. Si llega sin JWT, usa
// `tokens` tal cual (caso del hook pg_net).

interface TokenCache {
  email: string;
  expiresAt: number;
  token: string;
}
let cachedToken: TokenCache | null = null;

function base64UrlEncode(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function signRsa256(data: Uint8Array, privateKeyPem: string): Promise<Uint8Array> {
  const pem = privateKeyPem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  return new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, data));
}

function encodePart(value: unknown): string {
  return base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
}

async function getAccessToken(sa: Record<string, any>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.email === sa.client_email && cachedToken.expiresAt > now + 60) {
    return cachedToken.token;
  }

  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${encodePart(header)}.${encodePart(claims)}`;
  const sig = await signRsa256(new TextEncoder().encode(signingInput), sa.private_key);
  const jwt = `${signingInput}.${base64UrlEncode(sig)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${encodeURIComponent(jwt)}`,
  });
  const data = await res.json().catch(() => null);
  if (!res.ok || !data?.access_token) {
    throw new Error(data?.error_description || data?.error || 'No se pudo obtener token OAuth');
  }

  cachedToken = { email: sa.client_email, expiresAt: now + 3600, token: data.access_token };
  return data.access_token;
}

async function sendToToken(
  projectId: string,
  token: string,
  notification: Record<string, any>,
  data: Record<string, any>,
): Promise<Record<string, any>> {
  const sa = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}');
  const accessToken = await getAccessToken(sa);

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token,
          notification,
          data,
          android: { priority: 'high' },
          apns: { headers: { 'apns-priority': '10' } },
        },
      }),
    },
  );

  const raw = await res.text();
  let body: any = null;
  try {
    body = raw ? JSON.parse(raw) : null;
  } catch {
    body = null;
  }
  if (!res.ok) {
    return {
      token,
      ok: false,
      error: body?.error?.message ?? `HTTP ${res.status}`,
      raw: raw.slice(0, 200),
    };
  }
  return { token, ok: true, name: body?.name ?? null };
}

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const saRaw = Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '';
  if (!saRaw) {
    return jsonResponse(
      { error: 'FCM_SERVICE_ACCOUNT no configurado (service account JSON de Firebase)' },
      503,
    );
  }

  let sa: Record<string, any>;
  try {
    sa = JSON.parse(saRaw);
  } catch {
    return jsonResponse({ error: 'FCM_SERVICE_ACCOUNT inválido (no es JSON válido)' }, 503);
  }
  const projectId = sa.project_id;

  const user = await getUserFromRequest(req);

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Payload inválido' }, 400);
  }

  let tokens: string[] = body.tokens ?? [];
  if (user?.id && Array.isArray(tokens) && tokens.length === 0) {
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
  const data = (body.data && typeof body.data === 'object') ? body.data : {};

  try {
    const results = [];
    for (const token of tokens) {
      results.push(await sendToToken(projectId, token, notification, data));
    }
    const sent = results.filter((r) => r.ok).length;
    return jsonResponse({ sent, total: tokens.length, results });
  } catch (e: any) {
    return jsonResponse({ error: e?.message ?? 'FCM rechazó el envío' }, 502);
  }
});
