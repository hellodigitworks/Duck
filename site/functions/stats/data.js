// The numbers behind the stats page, as JSON.
import { readStats, snapshotDownloads } from '../_lib/stats.js';

export async function onRequestGet({ env }) {
  if (!env.DB) return Response.json({ error: 'No database is attached to this site.' }, { status: 500 });
  // Opening the page also saves today's download totals, in case no Mac has checked yet today.
  await snapshotDownloads(env.DB, env.GITHUB_TOKEN).catch(() => {});
  return Response.json(await readStats(env.DB));
}
