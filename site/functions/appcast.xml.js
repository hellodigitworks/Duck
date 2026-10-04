// The update feed, served exactly as before, with one addition: a running copy of Duck
// asking for it is counted. The counting happens after the answer has gone, so it can
// never slow an update down or stop one.
import { recordCheck, snapshotDownloads } from './_lib/stats.js';

export async function onRequestGet(context) {
  const { request, env, waitUntil } = context;
  const feed = await context.next();

  if (env.DB) {
    waitUntil(
      Promise.allSettled([
        recordCheck(env.DB, request),
        snapshotDownloads(env.DB, env.GITHUB_TOKEN),
      ])
    );
  }

  const response = new Response(feed.body, feed);
  response.headers.set('Cache-Control', 'public, max-age=0, must-revalidate');
  return response;
}
