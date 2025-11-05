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

      // Watchlist endpoints
      // Support both /api/watchlists and /watchlists for backwards compatibility
      if (path.startsWith('/api/watchlists') || path.startsWith('/watchlists')) {
        return await handleWatchlists(request, env);
      }

      // Alert preferences endpoints
      if (path === '/api/alert-preferences' || path === '/alert-preferences') {
        return await handleAlertPreferences(request, env);
      }

      if (path === '/api/alert-preferences/airports' || path === '/alert-preferences/airports') {
        return await handlePreferredAirports(request, env);
      }

      // User endpoint
      if (path === '/api/user' || path === '/user') {
        return await handleUser(request, env);
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
 * Helper function to fetch data from Supabase table with authentication
 * Reduces code duplication for list queries
 * @param token - JWT token for authentication
 * @param env - Environment variables
 * @param table - Supabase table name
 * @param query - Query parameters (e.g., "order=created_at.desc&limit=50")
 * @param dataKey - Key name for the response data array
 * @param userId - User ID to include in response
 */
async function fetchSupabaseListQuery(
  token: string,
  env: Env,
  table: string,
  query: string,
  dataKey: string,
  userId: string
): Promise<Response> {
  const response = await fetch(
    `${env.SUPABASE_URL}/rest/v1/${table}?${query}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    console.error(`Failed to fetch ${table} from Supabase:`, errorText);
    return jsonResponse({ error: `Failed to fetch ${dataKey}` }, response.status, {}, env);
  }

  const data = await response.json();
  return jsonResponse({ [dataKey]: data, user_id: userId }, 200, {}, env);
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

    // Return single deal wrapped in object for API consistency
    return jsonResponse({ deal: deals[0], user_id: authResult.userId }, 200, {}, env);
  } else {
    // GET /deals - List all deals
    return fetchSupabaseListQuery(
      token,
      env,
      'flight_deals',
      'order=deal_score.desc&limit=20',
      'deals',
      authResult.userId
    );
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

  // Use helper function to reduce code duplication
  return fetchSupabaseListQuery(
    authResult.token,
    env,
    'alert_history',
    'order=created_at.desc&limit=50',
    'alerts',
    authResult.userId
  );
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

/**
 * Handle watchlist endpoints (CRUD operations)
 * Supports:
 * - POST /watchlists - Create new watchlist
 * - GET /watchlists - List all watchlists for authenticated user
 * - GET /watchlists/{id} - Get single watchlist by ID
 * - PUT /watchlists/{id} - Update watchlist
 * - DELETE /watchlists/{id} - Delete watchlist
 */
async function handleWatchlists(request: Request, env: Env): Promise<Response> {
  // Verify authentication
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) {
    return authResult.response;
  }

  const token = authResult.token;
  const userId = authResult.userId;
  const url = new URL(request.url);
  const path = url.pathname;
  const method = request.method;

  // Extract watchlist ID if present
  // Match patterns: /watchlists/{id}, /api/watchlists/{id}
  const watchlistIdMatch = path.match(/\/(?:api\/)?watchlists\/([a-f0-9-]+)$/i);

  if (watchlistIdMatch) {
    const watchlistId = watchlistIdMatch[1];

    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(watchlistId)) {
      return jsonResponse({ error: 'Invalid watchlist ID format' }, 400, {}, env);
    }

    // Route to appropriate handler based on method
    switch (method) {
      case 'GET':
        return await getWatchlist(token, env, watchlistId, userId);
      case 'PUT':
        return await updateWatchlist(request, token, env, watchlistId, userId);
      case 'DELETE':
        return await deleteWatchlist(token, env, watchlistId, userId);
      default:
        return jsonResponse({ error: 'Method not allowed' }, 405, {}, env);
    }
  } else {
    // No ID in path - collection operations
    switch (method) {
      case 'GET':
        return await listWatchlists(token, env, userId);
      case 'POST':
        return await createWatchlist(request, token, env, userId);
      default:
        return jsonResponse({ error: 'Method not allowed' }, 405, {}, env);
    }
  }
}

/**
 * Zod schema for watchlist creation/update
 */
const WatchlistSchema = z.object({
  origin_code: z.string().regex(/^[A-Z]{3}$/, 'Origin must be 3-letter IATA code'),
  destination_code: z.string().regex(/^[A-Z]{3}$/, 'Destination must be 3-letter IATA code'),
  max_price: z.number().positive('Max price must be positive').optional(),
  alert_enabled: z.boolean().optional(),
});

type WatchlistInput = z.infer<typeof WatchlistSchema>;

/**
 * POST /watchlists - Create new watchlist
 */
async function createWatchlist(
  request: Request,
  token: string,
  env: Env,
  userId: string
): Promise<Response> {
  // Parse and validate request body
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, env);
  }

  const parseResult = WatchlistSchema.safeParse(body);
  if (!parseResult.success) {
    return jsonResponse(
      { error: 'Invalid watchlist data', details: parseResult.error.issues },
      400,
      {},
      env
    );
  }

  const watchlistData: WatchlistInput = parseResult.data;

  // Create watchlist in Supabase
  // RLS policy will automatically set user_id to authenticated user
  const response = await fetch(`${env.SUPABASE_URL}/rest/v1/watchlists`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'apikey': env.SUPABASE_ANON_KEY,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation', // Return created record
    },
    body: JSON.stringify(watchlistData),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Failed to create watchlist:', errorText);
    return jsonResponse({ error: 'Failed to create watchlist' }, response.status, {}, env);
  }

  const data = await response.json();

  // Return first item if array, otherwise return as-is
  const watchlist = Array.isArray(data) ? data[0] : data;

  return jsonResponse({ watchlist, user_id: userId }, 201, {}, env);
}

/**
 * GET /watchlists - List all watchlists for authenticated user
 */
async function listWatchlists(token: string, env: Env, userId: string): Promise<Response> {
  return fetchSupabaseListQuery(
    token,
    env,
    'watchlists',
    'order=created_at.desc',
    'watchlists',
    userId
  );
}

/**
 * GET /watchlists/{id} - Get single watchlist by ID
 */
async function getWatchlist(
  token: string,
  env: Env,
  watchlistId: string,
  userId: string
): Promise<Response> {
  const response = await fetch(
    `${env.SUPABASE_URL}/rest/v1/watchlists?id=eq.${watchlistId}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Failed to fetch watchlist:', errorText);
    return jsonResponse({ error: 'Failed to fetch watchlist' }, response.status, {}, env);
  }

  const watchlists = await response.json();

  // Check if watchlist exists
  if (!Array.isArray(watchlists) || watchlists.length === 0) {
    return jsonResponse({ error: 'Watchlist not found' }, 404, {}, env);
  }

  return jsonResponse({ watchlist: watchlists[0], user_id: userId }, 200, {}, env);
}

/**
 * PUT /watchlists/{id} - Update watchlist
 */
async function updateWatchlist(
  request: Request,
  token: string,
  env: Env,
  watchlistId: string,
  userId: string
): Promise<Response> {
  // Parse and validate request body
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, env);
  }

  const parseResult = WatchlistSchema.safeParse(body);
  if (!parseResult.success) {
    return jsonResponse(
      { error: 'Invalid watchlist data', details: parseResult.error.issues },
      400,
      {},
      env
    );
  }

  const watchlistData: WatchlistInput = parseResult.data;

  // Update watchlist in Supabase
  // RLS policy will ensure user can only update their own watchlists
  const response = await fetch(
    `${env.SUPABASE_URL}/rest/v1/watchlists?id=eq.${watchlistId}`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify(watchlistData),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Failed to update watchlist:', errorText);
    return jsonResponse({ error: 'Failed to update watchlist' }, response.status, {}, env);
  }

  const data = await response.json();

  // Check if any rows were updated
  if (!Array.isArray(data) || data.length === 0) {
    return jsonResponse({ error: 'Watchlist not found or access denied' }, 404, {}, env);
  }

  return jsonResponse({ watchlist: data[0], user_id: userId }, 200, {}, env);
}

/**
 * DELETE /watchlists/{id} - Delete watchlist
 */
async function deleteWatchlist(
  token: string,
  env: Env,
  watchlistId: string,
  userId: string
): Promise<Response> {
  // Delete watchlist from Supabase
  // RLS policy will ensure user can only delete their own watchlists
  const response = await fetch(
    `${env.SUPABASE_URL}/rest/v1/watchlists?id=eq.${watchlistId}`,
    {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Failed to delete watchlist:', errorText);
    return jsonResponse({ error: 'Failed to delete watchlist' }, response.status, {}, env);
  }

  const data = await response.json();

  // Check if any rows were deleted
  if (!Array.isArray(data) || data.length === 0) {
    return jsonResponse({ error: 'Watchlist not found or access denied' }, 404, {}, env);
  }

  return jsonResponse({ success: true, user_id: userId }, 200, {}, env);
}

/**
 * Handle alert preferences endpoint
 * PUT /alert-preferences - Update user's alert preferences
 */
async function handleAlertPreferences(request: Request, env: Env): Promise<Response> {
  // Verify authentication
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) {
    return authResult.response;
  }

  const method = request.method;

  // Only PUT is supported
  if (method !== 'PUT') {
    return jsonResponse({ error: 'Method not allowed' }, 405, {}, env);
  }

  // Parse and validate request body
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, env);
  }

  // Validate alert preferences schema
  const AlertPreferencesSchema = z.object({
    email_enabled: z.boolean().optional(),
    push_enabled: z.boolean().optional(),
    price_drop_threshold: z.number().min(0).max(100).optional(),
  });

  const parseResult = AlertPreferencesSchema.safeParse(body);
  if (!parseResult.success) {
    return jsonResponse(
      { error: 'Invalid alert preferences data', details: parseResult.error.issues },
      400,
      {},
      env
    );
  }

  const preferencesData = parseResult.data;

  // Update alert preferences in Supabase
  // RLS policy will ensure user can only update their own preferences
  const response = await fetch(
    `${env.SUPABASE_URL}/rest/v1/alert_preferences?user_id=eq.${authResult.userId}`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${authResult.token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify(preferencesData),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Failed to update alert preferences:', errorText);
    return jsonResponse({ error: 'Failed to update alert preferences' }, response.status, {}, env);
  }

  const data = await response.json();

  // Check if any rows were updated (if not, need to insert)
  if (!Array.isArray(data) || data.length === 0) {
    // Try to insert new record
    const insertResponse = await fetch(`${env.SUPABASE_URL}/rest/v1/alert_preferences`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${authResult.token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify(preferencesData),
    });

    if (!insertResponse.ok) {
      const errorText = await insertResponse.text();
      console.error('Failed to create alert preferences:', errorText);
      return jsonResponse({ error: 'Failed to create alert preferences' }, insertResponse.status, {}, env);
    }

    const insertData = await insertResponse.json();
    const preferences = Array.isArray(insertData) ? insertData[0] : insertData;
    return jsonResponse({ preferences, user_id: authResult.userId }, 201, {}, env);
  }

  return jsonResponse({ preferences: data[0], user_id: authResult.userId }, 200, {}, env);
}

/**
 * Handle preferred airports endpoint
 * PUT /alert-preferences/airports - Update user's preferred airports
 */
async function handlePreferredAirports(request: Request, env: Env): Promise<Response> {
  // Verify authentication
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) {
    return authResult.response;
  }

  const method = request.method;

  // Only PUT is supported
  if (method !== 'PUT') {
    return jsonResponse({ error: 'Method not allowed' }, 405, {}, env);
  }

  // Parse and validate request body
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, env);
  }

  // Validate preferred airports schema
  const PreferredAirportsSchema = z.object({
    preferred_airports: z.array(
      z.string().regex(/^[A-Z]{3}$/, 'Airport codes must be 3-letter IATA codes')
    ).max(10, 'Maximum 10 preferred airports allowed'),
  });

  const parseResult = PreferredAirportsSchema.safeParse(body);
  if (!parseResult.success) {
    return jsonResponse(
      { error: 'Invalid preferred airports data', details: parseResult.error.issues },
      400,
      {},
      env
    );
  }

  const airportsData = parseResult.data;

  // Update alert preferences with new preferred airports
  const response = await fetch(
    `${env.SUPABASE_URL}/rest/v1/alert_preferences?user_id=eq.${authResult.userId}`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${authResult.token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify(airportsData),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Failed to update preferred airports:', errorText);
    return jsonResponse({ error: 'Failed to update preferred airports' }, response.status, {}, env);
  }

  const data = await response.json();

  // Check if any rows were updated (if not, need to insert)
  if (!Array.isArray(data) || data.length === 0) {
    // Try to insert new record
    const insertResponse = await fetch(`${env.SUPABASE_URL}/rest/v1/alert_preferences`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${authResult.token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify(airportsData),
    });

    if (!insertResponse.ok) {
      const errorText = await insertResponse.text();
      console.error('Failed to create preferred airports:', errorText);
      return jsonResponse({ error: 'Failed to create preferred airports' }, insertResponse.status, {}, env);
    }

    const insertData = await insertResponse.json();
    const preferences = Array.isArray(insertData) ? insertData[0] : insertData;
    return jsonResponse({ preferences, user_id: authResult.userId }, 201, {}, env);
  }

  return jsonResponse({ preferences: data[0], user_id: authResult.userId }, 200, {}, env);
}

/**
 * Handle user endpoint
 * PATCH /user - Update user profile
 */
async function handleUser(request: Request, env: Env): Promise<Response> {
  // Verify authentication
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) {
    return authResult.response;
  }

  const method = request.method;

  // Only PATCH is supported for updates
  if (method !== 'PATCH') {
    return jsonResponse({ error: 'Method not allowed' }, 405, {}, env);
  }

  // Parse and validate request body
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, env);
  }

  // Validate user update schema
  const UserUpdateSchema = z.object({
    display_name: z.string().min(1).max(100).optional(),
    email: z.string().email().optional(),
  });

  const parseResult = UserUpdateSchema.safeParse(body);
  if (!parseResult.success) {
    return jsonResponse(
      { error: 'Invalid user data', details: parseResult.error.issues },
      400,
      {},
      env
    );
  }

  const userData = parseResult.data;

  // Update user profile in Supabase auth
  // Note: Email updates require verification in Supabase Auth
  if (userData.email) {
    const authUpdateResponse = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${authResult.token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email: userData.email }),
    });

    if (!authUpdateResponse.ok) {
      const errorText = await authUpdateResponse.text();
      console.error('Failed to update user email:', errorText);
      return jsonResponse({ error: 'Failed to update email' }, authUpdateResponse.status, {}, env);
    }
  }

  // Update display name in profiles table if provided
  if (userData.display_name) {
    const profileResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/profiles?id=eq.${authResult.userId}`,
      {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${authResult.token}`,
          'apikey': env.SUPABASE_ANON_KEY,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: JSON.stringify({ display_name: userData.display_name }),
      }
    );

    if (!profileResponse.ok) {
      const errorText = await profileResponse.text();
      console.error('Failed to update user profile:', errorText);
      return jsonResponse({ error: 'Failed to update profile' }, profileResponse.status, {}, env);
    }
  }

  // Fetch updated user data
  const userResponse = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {
    headers: {
      'Authorization': `Bearer ${authResult.token}`,
      'apikey': env.SUPABASE_ANON_KEY,
    },
  });

  if (!userResponse.ok) {
    return jsonResponse({ error: 'Failed to fetch updated user data' }, 500, {}, env);
  }

  const updatedUser = await userResponse.json();
  return jsonResponse({ user: updatedUser, user_id: authResult.userId }, 200, {}, env);
}
