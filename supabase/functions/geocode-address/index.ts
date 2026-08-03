import { handleOptions, jsonResponse } from '../_shared/cors.ts';
import { getUserFromRequest } from '../_shared/auth.ts';

async function geocodeWithNominatim(address: string) {
  const url = new URL('https://nominatim.openstreetmap.org/search');
  url.searchParams.set('q', address);
  url.searchParams.set('format', 'json');
  url.searchParams.set('limit', '1');
  url.searchParams.set('countrycodes', 've'); // ajusta a tu país

  const response = await fetch(url.toString(), {
    headers: {
      'User-Agent': Deno.env.get('NOMINATIM_USER_AGENT') ?? 'MiApp/1.0',
    },
  });
  if (!response.ok) return { found: false, status: `HTTP_${response.status}` };

  const results = await response.json();
  if (!Array.isArray(results) || results.length === 0) {
    return { found: false, status: 'NO_RESULTS' };
  }
  const first = results[0];
  return {
    found: true,
    latitude: parseFloat(first.lat),
    longitude: parseFloat(first.lon),
    provider: 'nominatim',
  };
}

Deno.serve(async (req) => {
  const options = handleOptions(req);
  if (options) return options;

  if (req.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);
  await getUserFromRequest(req); // valida JWT del usuario

  const body = await req.json();
  const address = body.address?.trim();
  if (!address) return jsonResponse({ error: 'address is required' }, 400);

  const result = await geocodeWithNominatim(address);
  return jsonResponse(result);
});