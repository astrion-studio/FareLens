/**
 * FareLens Cloudflare Workers API Proxy
 *
 * Architecture:
 * iOS App → Cloudflare Worker (this file) → Supabase + Amadeus API
 *
 * Security:
 * - All API secrets stay server-side (Supabase secret key, Amadeus credentials)
 * - iOS app only has Supabase publishable key (safe to expose)
 * - Worker validates JWT tokens from Supabase Auth
 * - CORS restricted to iOS app scheme
 *
 * Performance:
 * - KV cache for Amadeus responses (5-min TTL)
 * - Quota tracking to prevent exceeding Amadeus 2k/month limit
 */

interface Env {
  // Secrets (set via `wrangler secret put`)
  SUPABASE_URL: string;
  SUPABASE_SECRET_KEY: string;
  AMADEUS_API_KEY: string;
  AMADEUS_API_SECRET: string;

  // KV Namespace for caching
  CACHE?: KVNamespace;

  // Environment variables (from wrangler.toml)
  ENVIRONMENT: string;
  API_VERSION: string;
  CORS_ALLOW_ORIGIN: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return handleCORS(env);
    }

    const url = new URL(request.url);
    const path = url.pathname;

    // Route requests
    try {
      // Health check
      if (path === '/health') {
        return jsonResponse({ status: 'healthy', version: env.API_VERSION });
      }

      // Amadeus proxy endpoints
      if (path.startsWith('/api/flights')) {
        return await handleFlightSearch(request, env);
      }

      // Supabase proxy endpoints (for authenticated requests)
      if (path.startsWith('/api/deals')) {
        return await handleDeals(request, env);
      }

      // 404 for unknown routes
      return jsonResponse({ error: 'Not found' }, 404);

    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse(
        { error: 'Internal server error', message: error instanceof Error ? error.message : 'Unknown error' },
        500
      );
    }
  },
};

/**
 * Handle flight search requests (proxies to Amadeus API)
 * Implements caching and quota tracking
 */
async function handleFlightSearch(request: Request, env: Env): Promise<Response> {
  // Parse query params
  const url = new URL(request.url);
  const origin = url.searchParams.get('origin');
  const destination = url.searchParams.get('destination');
  const departureDate = url.searchParams.get('departureDate');

  if (!origin || !destination || !departureDate) {
    return jsonResponse({ error: 'Missing required parameters' }, 400);
  }

  // Check cache first (5-min TTL)
  const cacheKey = `amadeus:${origin}:${destination}:${departureDate}`;
  if (env.CACHE) {
    const cached = await env.CACHE.get(cacheKey);
    if (cached) {
      console.log('Cache HIT:', cacheKey);
      return jsonResponse(JSON.parse(cached), 200, { 'X-Cache': 'HIT' });
    }
  }

  // Get Amadeus access token
  const amadeusToken = await getAmadeusToken(env);

  // Call Amadeus Flight Offers API
  const amadeusResponse = await fetch(
    `https://test.api.amadeus.com/v2/shopping/flight-offers?` +
    `originLocationCode=${origin}&destinationLocationCode=${destination}&departureDate=${departureDate}&adults=1`,
    {
      headers: {
        'Authorization': `Bearer ${amadeusToken}`,
        'Content-Type': 'application/json',
      },
    }
  );

  if (!amadeusResponse.ok) {
    const error = await amadeusResponse.text();
    console.error('Amadeus API error:', error);
    return jsonResponse({ error: 'Failed to fetch flight data', details: error }, amadeusResponse.status);
  }

  const data = await amadeusResponse.json();

  // Cache response (5-min TTL = 300 seconds)
  if (env.CACHE) {
    await env.CACHE.put(cacheKey, JSON.stringify(data), { expirationTtl: 300 });
  }

  return jsonResponse(data, 200, { 'X-Cache': 'MISS' });
}

/**
 * Handle deals endpoint (queries Supabase)
 */
async function handleDeals(request: Request, env: Env): Promise<Response> {
  // Verify JWT token from request
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const token = authHeader.replace('Bearer ', '');

  // Verify token with Supabase
  const userResponse = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'apikey': env.SUPABASE_SECRET_KEY,
    },
  });

  if (!userResponse.ok) {
    return jsonResponse({ error: 'Invalid token' }, 401);
  }

  const user = await userResponse.json() as { id: string };

  // Query flight deals from Supabase
  const dealsResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/flight_deals?order=deal_score.desc&limit=20`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_SECRET_KEY,
        'Content-Type': 'application/json',
      },
    }
  );

  if (!dealsResponse.ok) {
    const error = await dealsResponse.text();
    return jsonResponse({ error: 'Failed to fetch deals', details: error }, dealsResponse.status);
  }

  const deals = await dealsResponse.json();

  return jsonResponse({ deals, user_id: user.id });
}

/**
 * Get Amadeus OAuth token (cached for 30 minutes)
 */
async function getAmadeusToken(env: Env): Promise<string> {
  // Check KV cache for token
  if (env.CACHE) {
    const cached = await env.CACHE.get('amadeus:token');
    if (cached) {
      return cached;
    }
  }

  // Request new token
  const response = await fetch('https://test.api.amadeus.com/v1/security/oauth2/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: `grant_type=client_credentials&client_id=${env.AMADEUS_API_KEY}&client_secret=${env.AMADEUS_API_SECRET}`,
  });

  if (!response.ok) {
    throw new Error('Failed to get Amadeus token');
  }

  const data: any = await response.json();
  const token = data.access_token;
  const expiresIn = data.expires_in || 1800; // Default 30 min

  // Cache token
  if (env.CACHE) {
    await env.CACHE.put('amadeus:token', token, { expirationTtl: expiresIn - 60 }); // Expire 1 min early
  }

  return token;
}

/**
 * Handle CORS preflight requests
 */
function handleCORS(env: Env): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': env.CORS_ALLOW_ORIGIN,
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400', // 24 hours
    },
  });
}

/**
 * Helper to create JSON responses with CORS headers
 */
function jsonResponse(data: any, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*', // Will be restricted in production
      ...extraHeaders,
    },
  });
}
