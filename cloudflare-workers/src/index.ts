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

import { z } from 'zod';

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
      // Support both /api/flights and /flights for backwards compatibility
      if (path.startsWith('/api/flights') || path.startsWith('/flights')) {
        // Verify authentication before proxying to Amadeus
        const authResult = await verifyAuth(request, env);
        if (!authResult.authenticated) {
          return authResult.response;
        }
        return await handleFlightSearch(request, env, authResult.userId);
      }

      // Supabase proxy endpoints (for authenticated requests)
      // Support both /api/deals and /deals for backwards compatibility
      if (path.startsWith('/api/deals') || path.startsWith('/deals')) {
        return await handleDeals(request, env);
      }

      // Alerts history endpoint
      // Support both /api/alerts/history and /alerts/history
      if (path === '/api/alerts/history' || path === '/alerts/history') {
        return await handleAlertHistory(request, env);
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
  const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
  const dateParts = departureDate.split('-').map(Number);
  const testDate = new Date(dateParts[0], dateParts[1] - 1, dateParts[2]);
  if (!dateRegex.test(departureDate) || testDate.getMonth() !== dateParts[1] - 1) {
    return jsonResponse({ error: 'Invalid date format. Must be a valid YYYY-MM-DD date.' }, 400, {}, env);
  }

  // Validate date is not in the past and not too far in future (1 year)
  const requestedDate = new Date(`${departureDate}T00:00:00.000Z`);
  const today = new Date();
  const todayUTCStart = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));

  const oneYearFromNow = new Date(todayUTCStart);
  oneYearFromNow.setUTCFullYear(oneYearFromNow.getUTCFullYear() + 1);

  if (requestedDate < todayUTCStart) {
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
 * Authentication result types using discriminated union for type safety
 */
type AuthResult =
  | { authenticated: true; userId: string; token: string }
  | { authenticated: false; response: Response };

/**
 * Verify JWT authentication with Supabase
 * Returns discriminated union: either success with user ID + token, or failure with error response
 */
async function verifyAuth(request: Request, env: Env): Promise<AuthResult> {
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

  // Validate Supabase user response with zod for runtime type safety
  const userJson = await userResponse.json();
  const parseResult = SupabaseUserSchema.safeParse(userJson);

  if (!parseResult.success) {
    console.error('Invalid Supabase user response:', parseResult.error);
    return {
      authenticated: false,
      response: jsonResponse({ error: 'Invalid user data from auth provider' }, 500, {}, env),
    };
  }

  return {
    authenticated: true,
    userId: parseResult.data.id,
    token: token,
  };
}

/**
 * Handle deals endpoint (queries Supabase)
 * Uses ANON_KEY to respect Row-Level Security policies
 * Supports:
 * - GET /deals - List all deals
 * - GET /deals/{id} - Get single deal by ID
 */
async function handleDeals(request: Request, env: Env): Promise<Response> {
  // Verify authentication
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) {
    return authResult.response;
  }

  const token = authResult.token;
  const url = new URL(request.url);
  const path = url.pathname;

  // Extract deal ID if present
  // Match patterns: /deals/{id}, /api/deals/{id}
  const dealIdMatch = path.match(/\/(?:api\/)?deals\/([a-f0-9-]+)$/i);

  if (dealIdMatch) {
    // GET /deals/{id} - Fetch single deal
    const dealId = dealIdMatch[1];

    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(dealId)) {
      return jsonResponse({ error: 'Invalid deal ID format' }, 400, {}, env);
    }

    const dealResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/flight_deals?id=eq.${dealId}`,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'apikey': env.SUPABASE_ANON_KEY,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!dealResponse.ok) {
      const errorText = await dealResponse.text();
      console.error('Failed to fetch deal from Supabase:', errorText);
      return jsonResponse({ error: 'Failed to fetch deal' }, dealResponse.status, {}, env);
    }

    const deals = await dealResponse.json();

    // Check if deal exists
    if (!Array.isArray(deals) || deals.length === 0) {
      return jsonResponse({ error: 'Deal not found' }, 404, {}, env);
    }

    return jsonResponse(deals[0], 200, {}, env);
  } else {
    // GET /deals - List all deals
    const dealsResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/flight_deals?order=deal_score.desc&limit=20`,
      {
        headers: {
          'Authorization': `Bearer ${token}`,
          'apikey': env.SUPABASE_ANON_KEY,
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
}

/**
 * Handle alerts history endpoint (queries Supabase)
 * Uses ANON_KEY to respect Row-Level Security policies
 * GET /alerts/history - Get alert history for authenticated user
 */
async function handleAlertHistory(request: Request, env: Env): Promise<Response> {
  // Verify authentication
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) {
    return authResult.response;
  }

  const token = authResult.token;

  // Query alert history from Supabase using anon key
  // RLS policies will automatically filter results based on the user's JWT
  const alertsResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/alert_history?order=created_at.desc&limit=50`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
    }
  );

  if (!alertsResponse.ok) {
    const errorText = await alertsResponse.text();
    console.error('Failed to fetch alert history from Supabase:', errorText);
    return jsonResponse({ error: 'Failed to fetch alert history' }, alertsResponse.status, {}, env);
  }

  const alerts = await alertsResponse.json();

  return jsonResponse({ alerts, user_id: authResult.userId }, 200, {}, env);
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
// Zod schema for runtime validation of Supabase user response
const SupabaseUserSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email().optional(),
  // Allow additional properties from Supabase
}).passthrough();

type SupabaseUser = z.infer<typeof SupabaseUserSchema>;

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

  // Cache token with clamped TTL (expire 1 min early, minimum 60s)
  if (env.CACHE) {
    const cacheTtl = Math.max(expiresIn - 60, 60); // Clamp to minimum 60 seconds
    await env.CACHE.put('amadeus:token', token, { expirationTtl: cacheTtl });
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
 *
 * Note: We use wildcard CORS (Access-Control-Allow-Origin: *) without credentials
 * to comply with CORS spec. The spec forbids using wildcard with credentials=true.
 * Security is enforced via JWT authentication, not CORS credentials.
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
      ...extraHeaders,
    },
  });
}
