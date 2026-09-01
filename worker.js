/**
 * Cloudflare Worker for KeyFlow Web Dashboard & Cloud Sync
 */
export default {
  async fetch(request, env) {
    // Attempt to serve asset via Cloudflare Workers Static Assets binding
    if (env.ASSETS) {
      try {
        const assetResponse = await env.ASSETS.fetch(request);
        if (assetResponse && assetResponse.status < 400) {
          return assetResponse;
        }
      } catch (_) {}

      // Fallback to index.html for Single Page Application (SPA) routes
      try {
        const fallbackUrl = new URL('/index.html', request.url);
        return await env.ASSETS.fetch(new Request(fallbackUrl, request));
      } catch (_) {}
    }

    return new Response('KeyFlow Web Platform', {
      status: 200,
      headers: { 'Content-Type': 'text/html; charset=UTF-8' }
    });
  }
};
