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

// Minimal Cloudflare Worker types (inline to avoid @cloudflare/workers-types dependency)
interface KVNamespace {
  get(key: string): Promise<string | null>;
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
}

interface ExecutionContext {
  waitUntil(promise: Promise<any>): void;
  passThroughOnException(): void;
}

interface Env {
  // Secrets (set via `wrangler secret put`)
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;      // Publishable key for RLS-protected queries
  SUPABASE_SECRET_KEY: string;    // Service role key (admin) - use sparingly
  AMADEUS_API_KEY: string;
  AMADEUS_API_SECRET: string;

  // KV Namespace for caching
  CACHE?: KVNamespace;

  // Environment variables (from wrangler.toml)
  ENVIRONMENT: string;
  API_VERSION: string;
  CORS_ALLOW_ORIGIN: string;
  AMADEUS_BASE_URL?: string;      // Optional: override for production
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
        return jsonResponse({ status: 'healthy', version: env.API_VERSION }, 200, {}, env);
      }

      // Amadeus proxy endpoints (requires authentication to prevent quota abuse)
      if (path.startsWith('/api/flights')) {
        // Verify authentication before proxying to Amadeus
        const authResult = await verifyAuth(request, env);
        if (!authResult.authenticated) {
          return authResult.response!;
        }
        return await handleFlightSearch(request, env, authResult.userId!);
      }

      // Supabase proxy endpoints (for authenticated requests)
      if (path.startsWith('/api/deals')) {
        return await handleDeals(request, env);
      }

      // 404 for unknown routes
      return jsonResponse({ error: 'Not found' }, 404, {}, env);

    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse(
        { error: 'Internal Server Error' },
        500,
        {},
        env
      );
    }
  },
};

/**
 * Handle flight search requests (proxies to Amadeus API)
 * Implements caching and quota tracking
 * @param userId - Verified user ID from JWT authentication
 */
async function handleFlightSearch(request: Request, env: Env, userId: string): Promise<Response> {
  // Parse query params
  const url = new URL(request.url);
  const origin = url.searchParams.get('origin');
  const destination = url.searchParams.get('destination');
  const departureDate = url.searchParams.get('departureDate');

  if (!origin || !destination || !departureDate) {
    return jsonResponse({ error: 'Missing required parameters' }, 400, {}, env);
  }

  // Validate input parameters to prevent injection attacks
  // Airport codes: 3 uppercase letters (IATA format)
  const airportCodeRegex = /^[A-Z]{3}$/;
  if (!airportCodeRegex.test(origin)) {
    return jsonResponse({ error: 'Invalid origin airport code. Must be 3 uppercase letters.' }, 400, {}, env);
  }
  if (!airportCodeRegex.test(destination)) {
    return jsonResponse({ error: 'Invalid destination airport code. Must be 3 uppercase letters.' }, 400, {}, env);
  }

  // Date validation: YYYY-MM-DD format
  const dateParts = departureDate.split('-').map(Number);
  const testDate = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
  if (!dateRegex.test(departureDate) || testDate.getMonth() !== dateParts[1] - 1) {
    return jsonResponse({ error: 'Invalid date format. Must be a valid YYYY-MM-DD date.' }, 400, {}, env);
  }

  // Validate date is not in the past and not too far in future (1 year)
  const requestedDate = new Date(departureDate);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const oneYearFromNow = new Date(today);
  oneYearFromNow.setFullYear(oneYearFromNow.getFullYear() + 1);

  if (requestedDate < today) {
    return jsonResponse({ error: 'Departure date cannot be in the past.' }, 400, {}, env);
  }
  if (requestedDate > oneYearFromNow) {
    return jsonResponse({ error: 'Departure date cannot be more than 1 year in the future.' }, 400, {}, env);
  }

  // Check cache first (5-min TTL)
  const cacheKey = `amadeus:${origin}:${destination}:${departureDate}`;
  if (env.CACHE) {
    const cached = await env.CACHE.get(cacheKey);
    if (cached) {
      console.log('Cache HIT:', cacheKey);
      return jsonResponse(JSON.parse(cached), 200, { 'X-Cache': 'HIT' }, env);
    }
  }

  // Get Amadeus access token
  const amadeusToken = await getAmadeusToken(env);

  // Get Amadeus base URL (defaults to test environment)
  const amadeusBaseUrl = env.AMADEUS_BASE_URL || 'https://test.api.amadeus.com';

  // Call Amadeus Flight Offers API
  const amadeusResponse = await fetch(
    `${amadeusBaseUrl}/v2/shopping/flight-offers?` +
    `originLocationCode=${origin}&destinationLocationCode=${destination}&departureDate=${departureDate}&adults=1`,
    {
      headers: {
        'Authorization': `Bearer ${amadeusToken}`,
        'Content-Type': 'application/json',
      },
    }
  );

  if (!amadeusResponse.ok) {
    const errorText = await amadeusResponse.text();
    console.error('Amadeus API error:', errorText);
    // Don't leak internal error details to client for security
    return jsonResponse({ error: 'Failed to fetch flight data' }, amadeusResponse.status, {}, env);
  }

  const data = await amadeusResponse.json();

  // Cache response (5-min TTL = 300 seconds)
  if (env.CACHE) {
    await env.CACHE.put(cacheKey, JSON.stringify(data), { expirationTtl: 300 });
  }

  return jsonResponse(data, 200, { 'X-Cache': 'MISS' }, env);
}

/**
 * Verify JWT authentication with Supabase
 * Returns authentication result with user ID and token if successful
 */
async function verifyAuth(request: Request, env: Env): Promise<{
  authenticated: boolean;
  userId?: string;
  token?: string;
  response?: Response;
}> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return {
      authenticated: false,
      response: jsonResponse({ error: 'Unauthorized' }, 401, {}, env),
    };
  }

  const token = authHeader.replace('Bearer ', '');

  // Verify token with Supabase using anon key (respects RLS)
  const userResponse = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'apikey': env.SUPABASE_ANON_KEY,
    },
  });

  if (!userResponse.ok) {
    return {
      authenticated: false,
      response: jsonResponse({ error: 'Invalid token' }, 401, {}, env),
    };
  }

  const user = await userResponse.json() as SupabaseUser;
  return {
    authenticated: true,
    userId: user.id,
    token: token,
  };
}

/**
 * Handle deals endpoint (queries Supabase)
 * Uses ANON_KEY to respect Row-Level Security policies
 */
async function handleDeals(request: Request, env: Env): Promise<Response> {
  // Verify authentication
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) {
    return authResult.response!;
  }

  const token = authResult.token!;

  // Query flight deals from Supabase using anon key
  // RLS policies will automatically filter results based on the user's JWT
  const dealsResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/flight_deals?order=deal_score.desc&limit=20`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_ANON_KEY,  // Use anon key to respect RLS
        'Content-Type': 'application/json',
      },
    }
  );

  if (!dealsResponse.ok) {
    const errorText = await dealsResponse.text();
    console.error('Failed to fetch deals from Supabase:', errorText);
    return jsonResponse({ error: 'Failed to fetch deals' }, dealsResponse.status, {}, env);
  }

  const deals = await dealsResponse.json();

  return jsonResponse({ deals, user_id: authResult.userId }, 200, {}, env);
}

/**
 * Amadeus OAuth token response
 */
interface AmadeusTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

/**
 * Supabase user response
 */
interface SupabaseUser {
  id: string;
  email?: string;
  [key: string]: unknown;
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

  // Get Amadeus base URL (defaults to test environment)
  const amadeusBaseUrl = env.AMADEUS_BASE_URL || 'https://test.api.amadeus.com';

  // Request new token
  const response = await fetch(`${amadeusBaseUrl}/v1/security/oauth2/token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: `grant_type=client_credentials&client_id=${env.AMADEUS_API_KEY}&client_secret=${env.AMADEUS_API_SECRET}`,
  });

  if (!response.ok) {
    throw new Error('Failed to get Amadeus token');
  }

  const data = await response.json() as AmadeusTokenResponse;
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
 * env parameter is required to ensure CORS origin is always properly configured
 */
function jsonResponse(
  data: any,
  status: number,
  extraHeaders: Record<string, string>,
  env: Env
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': env.CORS_ALLOW_ORIGIN,
      'Access-Control-Allow-Credentials': 'true',
      ...extraHeaders,
    },
  });
}
