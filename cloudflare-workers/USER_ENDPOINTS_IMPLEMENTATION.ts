/**
 * FareLens Worker - User Endpoints Implementation
 *
 * This file contains the complete implementation for GET /user and PATCH /user endpoints
 * with transformation between iOS nested format and Supabase flat schema.
 *
 * Copy these functions into src/index.ts to replace the existing handleUser() function.
 */

import { z } from 'zod';

// ============================================================================
// TYPES & SCHEMAS
// ============================================================================

/**
 * Zod schema for alert preferences update (iOS format)
 */
const AlertPreferencesUpdateSchema = z.object({
  enabled: z.boolean().optional(),
  quiet_hours_enabled: z.boolean().optional(),
  quiet_hours_start: z.number().int().min(0).max(23).optional(),
  quiet_hours_end: z.number().int().min(0).max(23).optional(),
  watchlist_only_mode: z.boolean().optional(),
}).strict(); // Reject unknown fields

/**
 * Zod schema for preferred airport input (iOS format)
 */
const PreferredAirportInputSchema = z.object({
  id: z.string().uuid().optional(), // Client can send existing ID
  iata: z.string().regex(/^[A-Z]{3}$/, 'IATA code must be 3 uppercase letters'),
  weight: z.number().min(0).max(1.0, 'Weight must be 0.0-1.0'),
});

/**
 * Zod schema for PATCH /user request body (iOS format)
 */
const UserUpdateRequestSchema = z.object({
  timezone: z.string()
    .regex(/^[A-Z][a-zA-Z_]+\/[A-Z][a-zA-Z_]+$/, 'Invalid IANA timezone format')
    .optional(),
  alert_preferences: AlertPreferencesUpdateSchema.optional(),
  preferred_airports: z.array(PreferredAirportInputSchema)
    .max(3, 'Maximum 3 preferred airports allowed')
    .optional(),
}).strict();

type UserUpdateRequest = z.infer<typeof UserUpdateRequestSchema>;
type AlertPreferencesUpdate = z.infer<typeof AlertPreferencesUpdateSchema>;
type PreferredAirportInput = z.infer<typeof PreferredAirportInputSchema>;

/**
 * Zod schema for Supabase users table row (flat format)
 */
const SupabaseUserRowSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  created_at: z.string(), // ISO8601 datetime string
  timezone: z.string(),
  subscription_tier: z.enum(['free', 'pro']),
  alert_enabled: z.boolean(),
  quiet_hours_enabled: z.boolean(),
  quiet_hours_start: z.number().int().min(0).max(23),
  quiet_hours_end: z.number().int().min(0).max(23),
  watchlist_only_mode: z.boolean(),
  preferred_airports: z.string(), // JSONB comes as string from PostgREST
});

type SupabaseUserRow = z.infer<typeof SupabaseUserRowSchema>;

/**
 * API response format (nested, iOS-friendly)
 */
interface APIUser {
  id: string;
  email: string;
  created_at: string;
  timezone: string;
  subscription_tier: 'free' | 'pro';
  alert_preferences: {
    enabled: boolean;
    quiet_hours_enabled: boolean;
    quiet_hours_start: number;
    quiet_hours_end: number;
    watchlist_only_mode: boolean;
  };
  preferred_airports: Array<{
    id: string;
    iata: string;
    weight: number;
  }>;
}

// ============================================================================
// TRANSFORMATION FUNCTIONS
// ============================================================================

/**
 * Transform Supabase flat row to iOS nested API format
 * @param supabaseRow - Flat row from Supabase users table
 * @returns Nested user object for iOS
 */
function transformSupabaseUserToAPI(supabaseRow: SupabaseUserRow): APIUser {
  // Parse preferred_airports JSONB (stored as JSON string by PostgREST)
  let preferredAirports: Array<{ id: string; iata: string; weight: number }> = [];
  try {
    const parsed = JSON.parse(supabaseRow.preferred_airports || '[]');
    if (Array.isArray(parsed)) {
      preferredAirports = parsed;
    }
  } catch (e) {
    console.error('Failed to parse preferred_airports JSONB:', e);
    preferredAirports = [];
  }

  return {
    id: supabaseRow.id,
    email: supabaseRow.email,
    created_at: supabaseRow.created_at,
    timezone: supabaseRow.timezone,
    subscription_tier: supabaseRow.subscription_tier,
    alert_preferences: {
      enabled: supabaseRow.alert_enabled,
      quiet_hours_enabled: supabaseRow.quiet_hours_enabled,
      quiet_hours_start: supabaseRow.quiet_hours_start,
      quiet_hours_end: supabaseRow.quiet_hours_end,
      watchlist_only_mode: supabaseRow.watchlist_only_mode,
    },
    preferred_airports: preferredAirports,
  };
}

/**
 * Transform iOS nested update request to Supabase flat columns
 * @param updateRequest - Nested update request from iOS
 * @returns Flat update object for Supabase
 */
function transformAPIUserToSupabase(
  updateRequest: UserUpdateRequest
): Record<string, any> {
  const supabaseUpdate: Record<string, any> = {};

  // Direct field mapping
  if (updateRequest.timezone !== undefined) {
    supabaseUpdate.timezone = updateRequest.timezone;
  }

  // Flatten alert_preferences nested object to flat columns
  if (updateRequest.alert_preferences) {
    const prefs = updateRequest.alert_preferences;
    if (prefs.enabled !== undefined) {
      supabaseUpdate.alert_enabled = prefs.enabled;
    }
    if (prefs.quiet_hours_enabled !== undefined) {
      supabaseUpdate.quiet_hours_enabled = prefs.quiet_hours_enabled;
    }
    if (prefs.quiet_hours_start !== undefined) {
      supabaseUpdate.quiet_hours_start = prefs.quiet_hours_start;
    }
    if (prefs.quiet_hours_end !== undefined) {
      supabaseUpdate.quiet_hours_end = prefs.quiet_hours_end;
    }
    if (prefs.watchlist_only_mode !== undefined) {
      supabaseUpdate.watchlist_only_mode = prefs.watchlist_only_mode;
    }
  }

  // Transform preferred_airports array to JSONB string
  if (updateRequest.preferred_airports !== undefined) {
    // Generate UUIDs for airports without IDs
    const airportsWithIds = updateRequest.preferred_airports.map(airport => ({
      id: airport.id || crypto.randomUUID(),
      iata: airport.iata,
      weight: airport.weight,
    }));

    supabaseUpdate.preferred_airports = JSON.stringify(airportsWithIds);
  }

  return supabaseUpdate;
}

// ============================================================================
// VALIDATION FUNCTIONS
// ============================================================================

/**
 * Validate tier-based limits (Free vs Pro)
 * @returns { valid: true } or { valid: false, error: string }
 */
function validateTierLimits(
  updateRequest: UserUpdateRequest,
  currentTier: 'free' | 'pro'
): { valid: boolean; error?: string; upgrade_required?: boolean } {
  // Check preferred airports limit
  if (updateRequest.preferred_airports !== undefined) {
    const MAX_AIRPORTS = { free: 1, pro: 3 };
    if (updateRequest.preferred_airports.length > MAX_AIRPORTS[currentTier]) {
      return {
        valid: false,
        error: `${currentTier} tier allows maximum ${MAX_AIRPORTS[currentTier]} preferred airport(s)`,
        upgrade_required: currentTier === 'free',
      };
    }
  }

  // Check watchlist-only mode (Pro only feature)
  if (updateRequest.alert_preferences?.watchlist_only_mode === true) {
    if (currentTier === 'free') {
      return {
        valid: false,
        error: 'Watchlist-only mode is a Pro feature. Upgrade to enable.',
        upgrade_required: true,
      };
    }
  }

  return { valid: true };
}

/**
 * Validate airport weights sum to 1.0
 * @returns { valid: true } or { valid: false, error: string }
 */
function validateAirportWeights(
  airports: PreferredAirportInput[]
): { valid: boolean; error?: string } {
  if (airports.length === 0) {
    return { valid: true }; // Empty array is valid (user clearing airports)
  }

  // Calculate total weight
  const totalWeight = airports.reduce((sum, airport) => sum + airport.weight, 0);

  // Allow small floating point error tolerance (0.001 = 0.1%)
  if (Math.abs(totalWeight - 1.0) > 0.001) {
    return {
      valid: false,
      error: `Airport weights must sum to 1.0 (current: ${totalWeight.toFixed(3)})`,
    };
  }

  return { valid: true };
}

/**
 * Check for duplicate IATA codes in airports array
 * @returns { valid: true } or { valid: false, error: string }
 */
function validateNoDuplicateAirports(
  airports: PreferredAirportInput[]
): { valid: boolean; error?: string } {
  const iataSet = new Set(airports.map(a => a.iata));
  if (iataSet.size !== airports.length) {
    return {
      valid: false,
      error: 'Duplicate airport codes detected',
    };
  }
  return { valid: true };
}

// ============================================================================
// ENDPOINT HANDLERS
// ============================================================================

/**
 * Handle GET /user - Fetch current user profile
 *
 * Response format (iOS-friendly nested structure):
 * {
 *   "user": {
 *     "id": "uuid",
 *     "email": "user@example.com",
 *     "timezone": "America/Los_Angeles",
 *     "subscription_tier": "pro",
 *     "alert_preferences": { ... },
 *     "preferred_airports": [ ... ]
 *   }
 * }
 */
async function handleGetUser(
  token: string,
  userId: string,
  env: Env
): Promise<Response> {
  // Fetch user from Supabase
  const response = await fetch(
    `${env.SUPABASE_URL}/rest/v1/users?id=eq.${userId}`,
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
    console.error('Failed to fetch user from Supabase:', errorText);
    return jsonResponse({ error: 'Failed to fetch user data' }, response.status, {}, env);
  }

  const users = await response.json();

  // Check if user exists
  if (!Array.isArray(users) || users.length === 0) {
    return jsonResponse({ error: 'User not found' }, 404, {}, env);
  }

  const supabaseRow = users[0];

  // Validate Supabase row schema
  const parseResult = SupabaseUserRowSchema.safeParse(supabaseRow);
  if (!parseResult.success) {
    console.error('Invalid Supabase user row:', parseResult.error);
    return jsonResponse({ error: 'Invalid user data from database' }, 500, {}, env);
  }

  // Transform flat Supabase row to nested iOS format
  const apiUser = transformSupabaseUserToAPI(parseResult.data);

  return jsonResponse({ user: apiUser }, 200, {}, env);
}

/**
 * Handle PATCH /user - Update user profile
 *
 * Request body (partial update, iOS nested format):
 * {
 *   "timezone": "America/New_York",
 *   "alert_preferences": { "quiet_hours_enabled": false },
 *   "preferred_airports": [{ "iata": "JFK", "weight": 1.0 }]
 * }
 *
 * Validates:
 * - Tier limits (Free=1 airport, Pro=3 airports)
 * - Weight sum = 1.0
 * - No duplicate IATA codes
 * - Pro-only features (watchlist_only_mode)
 *
 * Transforms:
 * - iOS nested format → Supabase flat columns
 * - Generates UUIDs for new airports
 *
 * Returns:
 * - Updated user in iOS nested format
 */
async function handlePatchUser(
  request: Request,
  token: string,
  userId: string,
  env: Env
): Promise<Response> {
  // Parse request body
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, env);
  }

  // Validate request schema
  const parseResult = UserUpdateRequestSchema.safeParse(body);
  if (!parseResult.success) {
    return jsonResponse(
      {
        error: 'Invalid user update data',
        details: parseResult.error.issues,
      },
      400,
      {},
      env
    );
  }

  const updateRequest = parseResult.data;

  // Fetch current user to check tier and current state
  const currentUserResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/users?id=eq.${userId}`,
    {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
      },
    }
  );

  if (!currentUserResponse.ok) {
    return jsonResponse({ error: 'Failed to fetch current user' }, 500, {}, env);
  }

  const currentUsers = await currentUserResponse.json();
  if (!Array.isArray(currentUsers) || currentUsers.length === 0) {
    return jsonResponse({ error: 'User not found' }, 404, {}, env);
  }

  const currentUser = currentUsers[0];
  const currentTier = currentUser.subscription_tier as 'free' | 'pro';

  // Validate tier-based limits
  const tierValidation = validateTierLimits(updateRequest, currentTier);
  if (!tierValidation.valid) {
    return jsonResponse(
      {
        error: tierValidation.error,
        upgrade_required: tierValidation.upgrade_required,
      },
      403,
      {},
      env
    );
  }

  // Validate airport weights if updating preferred_airports
  if (updateRequest.preferred_airports) {
    const weightsValidation = validateAirportWeights(updateRequest.preferred_airports);
    if (!weightsValidation.valid) {
      return jsonResponse({ error: weightsValidation.error }, 400, {}, env);
    }

    const duplicatesValidation = validateNoDuplicateAirports(updateRequest.preferred_airports);
    if (!duplicatesValidation.valid) {
      return jsonResponse({ error: duplicatesValidation.error }, 400, {}, env);
    }
  }

  // Transform nested iOS format to flat Supabase columns
  const supabaseUpdate = transformAPIUserToSupabase(updateRequest);

  // Update user in Supabase
  const updateResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/users?id=eq.${userId}`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation', // Return updated row
      },
      body: JSON.stringify(supabaseUpdate),
    }
  );

  if (!updateResponse.ok) {
    const errorText = await updateResponse.text();
    console.error('Failed to update user:', errorText);
    return jsonResponse({ error: 'Failed to update user data' }, updateResponse.status, {}, env);
  }

  const updatedUsers = await updateResponse.json();

  // Check if any rows were updated
  if (!Array.isArray(updatedUsers) || updatedUsers.length === 0) {
    return jsonResponse({ error: 'User not found or access denied' }, 404, {}, env);
  }

  const updatedRow = updatedUsers[0];

  // Validate updated row schema
  const updatedParseResult = SupabaseUserRowSchema.safeParse(updatedRow);
  if (!updatedParseResult.success) {
    console.error('Invalid updated user row:', updatedParseResult.error);
    return jsonResponse({ error: 'Invalid user data from database' }, 500, {}, env);
  }

  // Transform flat Supabase row to nested iOS format
  const apiUser = transformSupabaseUserToAPI(updatedParseResult.data);

  return jsonResponse({ user: apiUser }, 200, {}, env);
}

/**
 * Main handler for /user endpoint
 * Routes to GET or PATCH based on HTTP method
 */
async function handleUser(request: Request, env: Env): Promise<Response> {
  // Verify authentication
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) {
    return authResult.response;
  }

  const method = request.method;

  switch (method) {
    case 'GET':
      return handleGetUser(authResult.token, authResult.userId, env);

    case 'PATCH':
      return handlePatchUser(request, authResult.token, authResult.userId, env);

    default:
      return jsonResponse(
        { error: `Method ${method} not allowed on /user` },
        405,
        {},
        env
      );
  }
}

// ============================================================================
// BACKWARDS COMPATIBILITY (DEPRECATED ENDPOINTS)
// ============================================================================

/**
 * Handle deprecated GET /alert-preferences
 * Redirects to GET /user and extracts alert_preferences
 */
async function handleGetAlertPreferences(request: Request, env: Env): Promise<Response> {
  const userResponse = await handleUser(
    new Request(request.url, { ...request, method: 'GET' }),
    env
  );

  if (!userResponse.ok) {
    return userResponse; // Pass through error
  }

  const userData = await userResponse.json();
  return jsonResponse(
    {
      alert_preferences: userData.user.alert_preferences,
      user_id: userData.user.id,
    },
    200,
    { 'X-Deprecated': 'Use GET /user instead' },
    env
  );
}

/**
 * Handle deprecated PUT /alert-preferences
 * Transforms to PATCH /user
 */
async function handlePutAlertPreferences(request: Request, env: Env): Promise<Response> {
  // Parse old format
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, env);
  }

  // Transform to new format
  const newBody = {
    alert_preferences: body,
  };

  // Create new request with transformed body
  const newRequest = new Request(request.url, {
    method: 'PATCH',
    headers: request.headers,
    body: JSON.stringify(newBody),
  });

  const userResponse = await handleUser(newRequest, env);

  if (!userResponse.ok) {
    return userResponse; // Pass through error
  }

  const userData = await userResponse.json();
  return jsonResponse(
    {
      alert_preferences: userData.user.alert_preferences,
      user_id: userData.user.id,
    },
    200,
    { 'X-Deprecated': 'Use PATCH /user instead' },
    env
  );
}

/**
 * Handle deprecated PUT /alert-preferences/airports
 * Transforms to PATCH /user
 */
async function handlePutPreferredAirports(request: Request, env: Env): Promise<Response> {
  // Parse old format (expects: { "preferred_airports": [...] })
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body' }, 400, {}, env);
  }

  // Body already has "preferred_airports" key, can use directly
  const newRequest = new Request(request.url, {
    method: 'PATCH',
    headers: request.headers,
    body: JSON.stringify(body),
  });

  const userResponse = await handleUser(newRequest, env);

  if (!userResponse.ok) {
    return userResponse; // Pass through error
  }

  const userData = await userResponse.json();
  return jsonResponse(
    {
      preferred_airports: userData.user.preferred_airports,
      user_id: userData.user.id,
    },
    200,
    { 'X-Deprecated': 'Use PATCH /user instead' },
    env
  );
}

// ============================================================================
// EXPORT
// ============================================================================

// Export handlers for use in main worker
export {
  handleUser,
  handleGetUser,
  handlePatchUser,
  handleGetAlertPreferences,
  handlePutAlertPreferences,
  handlePutPreferredAirports,
  transformSupabaseUserToAPI,
  transformAPIUserToSupabase,
  validateTierLimits,
  validateAirportWeights,
  validateNoDuplicateAirports,
};
