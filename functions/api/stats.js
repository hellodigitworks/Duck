// The numbers behind Duck's local stats page (admin/stats.html in the repo, never
// deployed), as JSON. Answers only with the right key, which lives in the STATS_KEY
// secret here and in admin/key.local.js on Swayam's Mac.
import { readStats, snapshotDownloads } from '../_lib/stats.js';

// The page is opened from a file, so its origin is "null". The key is the lock, not the
// origin, so any origin may ask.
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization',
  'Access-Control-Max-Age': '86400',
};

function answer(body, status = 200) {
  return Response.json(body, {
    status,
    headers: { ...CORS, 'Cache-Control': 'private, no-store', 'X-Robots-Tag': 'noindex' },
  });
}

// Same length and every byte compared, so the time taken gives nothing away.
function sameKey(given, real) {
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(real);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export function onRequestOptions() {
  return new Response(null, { status: 204, headers: CORS });
}

export async function onRequestGet({ request, env }) {
  if (!env.STATS_KEY) return answer({ error: 'The site has no stats key set.' }, 503);
  const given = (request.headers.get('authorization') || '').replace(/^Bearer\s+/i, '');
  if (!sameKey(given, env.STATS_KEY)) return answer({ error: 'The key does not match the site.' }, 401);
  if (!env.DB) return answer({ error: 'No database is attached to the site.' }, 503);
  // Opening the page also saves today's download totals, in case no Mac has checked yet today.
  await snapshotDownloads(env.DB, env.GITHUB_TOKEN).catch(() => {});
  return answer(await readStats(env.DB));
}
