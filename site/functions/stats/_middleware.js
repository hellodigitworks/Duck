// The stats page only answers on duck.hellodigitworks.com, where Cloudflare Access asks
// for an email code before anything gets through. The project's other addresses
// (tuck.pages.dev and its preview links) have no such lock, so there it does not exist.
const OPEN_HOSTS = ['duck.hellodigitworks.com', 'localhost', '127.0.0.1'];

export async function onRequest(context) {
  const host = new URL(context.request.url).hostname;
  if (!OPEN_HOSTS.includes(host)) return new Response('Not found', { status: 404 });

  const response = await context.next();
  const locked = new Response(response.body, response);
  locked.headers.set('X-Robots-Tag', 'noindex, nofollow');
  locked.headers.set('Cache-Control', 'private, no-store');
  return locked;
}
