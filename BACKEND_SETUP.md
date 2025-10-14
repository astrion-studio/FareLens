# Backend Implementation Guide

Complete guide for implementing the FareLens backend using Cloudflare Workers, Supabase, and Amadeus API.

## Architecture Overview

```
┌─────────────────┐
│   iOS App       │
│   (SwiftUI)     │
└────────┬────────┘
         │ HTTPS
         ↓
┌─────────────────────────────────┐
│  Cloudflare Workers (Edge API)  │
│  • POST /api/auth/signup        │
│  • POST /api/auth/signin        │
│  • GET  /api/deals              │
│  • POST /api/watchlists         │
│  • POST /api/alerts/register    │
└───────┬─────────┬───────────────┘
        │         │
        ↓         ↓
   ┌────────┐  ┌──────────────┐
   │Supabase│  │ Amadeus API  │
   │(Postgres│  │ (Flight Data)│
   │ + Auth) │  └──────────────┘
   └────────┘
        │
        ↓
   ┌──────────────┐
   │ Apple APNs   │
   │ (Push Notif.)│
   └──────────────┘
```

## Tech Stack

- **API Layer:** Cloudflare Workers (serverless edge functions)
- **Database:** Supabase (PostgreSQL)
- **Authentication:** Supabase Auth
- **Flight Data:** Amadeus Self-Service API
- **Caching:** Cloudflare KV
- **Queue Processing:** Cloudflare Durable Objects
- **Push Notifications:** Apple Push Notification service (APNs)

## Part 1: Supabase Setup

### 1.1 Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Note:
   - Project URL: `https://[project-id].supabase.co`
   - API Key (anon): `eyJ...`
   - API Key (service_role): `eyJ...` (keep secret!)
   - Database password

### 1.2 Database Schema

Run this SQL in Supabase SQL Editor:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Supabase auth.users)
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    subscription_tier TEXT NOT NULL DEFAULT 'free',
    subscription_expires_at TIMESTAMPTZ,
    trial_ends_at TIMESTAMPTZ,
    timezone TEXT NOT NULL DEFAULT 'America/Los_Angeles',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Alert preferences
CREATE TABLE public.alert_preferences (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL DEFAULT true,
    quiet_hours_enabled BOOLEAN NOT NULL DEFAULT true,
    quiet_hours_start INTEGER NOT NULL DEFAULT 22,
    quiet_hours_end INTEGER NOT NULL DEFAULT 7,
    watchlist_only_mode BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Preferred airports
CREATE TABLE public.preferred_airports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    iata TEXT NOT NULL,
    weight NUMERIC(3,2) NOT NULL CHECK (weight >= 0 AND weight <= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, iata)
);

-- Watchlists
CREATE TABLE public.watchlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    origin TEXT NOT NULL,
    destination TEXT,
    is_flexible_destination BOOLEAN NOT NULL DEFAULT false,
    departure_date_start DATE,
    departure_date_end DATE,
    max_price NUMERIC(10,2),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Flight deals
CREATE TABLE public.flight_deals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    airline TEXT NOT NULL,
    departure_date DATE NOT NULL,
    return_date DATE NOT NULL,
    total_price NUMERIC(10,2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    stops INTEGER NOT NULL DEFAULT 0,
    return_stops INTEGER,
    deal_score INTEGER NOT NULL CHECK (deal_score >= 0 AND deal_score <= 100),
    discount_percent INTEGER NOT NULL,
    booking_url TEXT,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Alert history
CREATE TABLE public.alert_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    deal_id UUID NOT NULL REFERENCES public.flight_deals(id) ON DELETE CASCADE,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    was_clicked BOOLEAN NOT NULL DEFAULT false,
    clicked_at TIMESTAMPTZ
);

-- APNs device tokens
CREATE TABLE public.device_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Daily alert counters
CREATE TABLE public.daily_alert_counters (
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, date)
);

-- Indexes for performance
CREATE INDEX idx_users_subscription ON public.users(subscription_tier, subscription_expires_at);
CREATE INDEX idx_watchlists_user ON public.watchlists(user_id) WHERE is_active = true;
CREATE INDEX idx_flight_deals_route ON public.flight_deals(origin, destination, departure_date);
CREATE INDEX idx_flight_deals_score ON public.flight_deals(deal_score DESC);
CREATE INDEX idx_alert_history_user_date ON public.alert_history(user_id, sent_at DESC);
CREATE INDEX idx_daily_counters ON public.daily_alert_counters(user_id, date);

-- Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alert_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preferred_airports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alert_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies (users can only see their own data)
CREATE POLICY "Users can view own profile" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can manage own alert prefs" ON public.alert_preferences FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own airports" ON public.preferred_airports FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own watchlists" ON public.watchlists FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Users can view own alert history" ON public.alert_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own device tokens" ON public.device_tokens FOR ALL USING (auth.uid() = user_id);

-- Public deals (anyone can read)
ALTER TABLE public.flight_deals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view deals" ON public.flight_deals FOR SELECT TO authenticated USING (true);

-- Functions
CREATE OR REPLACE FUNCTION increment_daily_alert_counter(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    current_count INTEGER;
BEGIN
    INSERT INTO public.daily_alert_counters (user_id, date, count)
    VALUES (p_user_id, CURRENT_DATE, 1)
    ON CONFLICT (user_id, date)
    DO UPDATE SET count = daily_alert_counters.count + 1
    RETURNING count INTO current_count;

    RETURN current_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION get_daily_alert_count(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
    current_count INTEGER;
BEGIN
    SELECT count INTO current_count
    FROM public.daily_alert_counters
    WHERE user_id = p_user_id AND date = CURRENT_DATE;

    RETURN COALESCE(current_count, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 1.3 Configure Supabase Auth

1. Authentication → Settings
2. Enable providers:
   - ✅ Email (with email confirmation)
3. Configure email templates:
   - Confirmation: "Welcome to FareLens! Confirm your email..."
   - Password Reset: "Reset your FareLens password..."

## Part 2: Amadeus API Setup

### 2.1 Create Amadeus Account

1. Go to [developers.amadeus.com](https://developers.amadeus.com)
2. Create account
3. Create new app: "FareLens"
4. Note:
   - API Key: `[your-api-key]`
   - API Secret: `[your-api-secret]`

### 2.2 Test API Access

```bash
# Get access token
curl -X POST \
  https://test.api.amadeus.com/v1/security/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=[API_KEY]&client_secret=[API_SECRET]"

# Response:
# {"access_token": "...", "expires_in": 1799}

# Test flight offers search
curl -X GET \
  "https://test.api.amadeus.com/v2/shopping/flight-offers?originLocationCode=LAX&destinationLocationCode=NYC&departureDate=2025-11-01&adults=1" \
  -H "Authorization: Bearer [ACCESS_TOKEN]"
```

### 2.3 Amadeus Free Tier Limits

- **2,000 API calls/month** (production)
- **40 calls/second**
- Test environment unlimited
- Good for MVP testing

## Part 3: Cloudflare Workers Setup

### 3.1 Install Wrangler CLI

```bash
npm install -g wrangler

# Login to Cloudflare
wrangler login
```

### 3.2 Create Worker Project

```bash
mkdir farelens-api
cd farelens-api
npm init -y
npm install --save-dev wrangler
npm install itty-router @supabase/supabase-js node-fetch
```

### 3.3 Configure wrangler.toml

```toml
name = "farelens-api"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[env.production]
workers_dev = false
routes = ["api.farelens.com/*"]

# KV Namespaces (for caching)
kv_namespaces = [
  { binding = "DEALS_CACHE", id = "[kv-namespace-id]" }
]

# Secrets (set with: wrangler secret put SUPABASE_KEY)
[vars]
SUPABASE_URL = "https://[project-id].supabase.co"
AMADEUS_API_URL = "https://api.amadeus.com"

# These go in secrets (not in code):
# SUPABASE_SERVICE_KEY
# AMADEUS_API_KEY
# AMADEUS_API_SECRET
# APNS_KEY_ID
# APNS_TEAM_ID
# APNS_AUTH_KEY
```

### 3.4 Set Secrets

```bash
wrangler secret put SUPABASE_SERVICE_KEY
# Paste your Supabase service_role key

wrangler secret put AMADEUS_API_KEY
# Paste Amadeus API key

wrangler secret put AMADEUS_API_SECRET
# Paste Amadeus API secret

wrangler secret put APNS_KEY_ID
# Paste APNs Key ID

wrangler secret put APNS_TEAM_ID
# Paste APNs Team ID

wrangler secret put APNS_AUTH_KEY
# Paste APNs .p8 file contents
```

## Part 4: Worker Implementation

### 4.1 Project Structure

```
farelens-api/
├── src/
│   ├── index.ts           # Main router
│   ├── routes/
│   │   ├── auth.ts        # Auth endpoints
│   │   ├── deals.ts       # Deal endpoints
│   │   ├── watchlists.ts  # Watchlist endpoints
│   │   └── alerts.ts      # Alert endpoints
│   ├── services/
│   │   ├── supabase.ts    # Supabase client
│   │   ├── amadeus.ts     # Amadeus client
│   │   ├── apns.ts        # APNs client
│   │   └── queue.ts       # Smart queue logic
│   └── types/
│       └── index.ts       # TypeScript types
├── wrangler.toml
└── package.json
```

### 4.2 Example: Main Router (src/index.ts)

```typescript
import { Router } from 'itty-router';
import { authRoutes } from './routes/auth';
import { dealsRoutes } from './routes/deals';
import { watchlistsRoutes } from './routes/watchlists';
import { alertsRoutes } from './routes/alerts';

const router = Router();

// Health check
router.get('/health', () => new Response('OK'));

// Mount route modules
authRoutes(router);
dealsRoutes(router);
watchlistsRoutes(router);
alertsRoutes(router);

// 404 handler
router.all('*', () => new Response('Not Found', { status: 404 }));

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return router.handle(request, env).catch((err) => {
      console.error(err);
      return new Response('Internal Server Error', { status: 500 });
    });
  },
};
```

### 4.3 Example: Deals Route (src/routes/deals.ts)

```typescript
import { Router } from 'itty-router';
import { createSupabaseClient } from '../services/supabase';
import { searchFlights } from '../services/amadeus';

export function dealsRoutes(router: Router) {
  // GET /api/deals - Fetch current deals
  router.get('/api/deals', async (request, env) => {
    const supabase = createSupabaseClient(env);

    // Check cache first
    const cached = await env.DEALS_CACHE.get('deals:latest');
    if (cached) {
      return new Response(cached, {
        headers: { 'Content-Type': 'application/json' }
      });
    }

    // Fetch from database
    const { data: deals, error } = await supabase
      .from('flight_deals')
      .select('*')
      .gte('deal_score', 70)
      .gte('expires_at', new Date().toISOString())
      .order('deal_score', { ascending: false })
      .limit(50);

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const response = JSON.stringify(deals);

    // Cache for 5 minutes
    await env.DEALS_CACHE.put('deals:latest', response, { expirationTtl: 300 });

    return new Response(response, {
      headers: { 'Content-Type': 'application/json' }
    });
  });
}
```

### 4.4 Example: Amadeus Service (src/services/amadeus.ts)

```typescript
interface AmadeusToken {
  access_token: string;
  expires_in: number;
  expires_at: number;
}

let cachedToken: AmadeusToken | null = null;

async function getAccessToken(env: Env): Promise<string> {
  // Return cached token if valid
  if (cachedToken && cachedToken.expires_at > Date.now()) {
    return cachedToken.access_token;
  }

  // Fetch new token
  const response = await fetch('https://api.amadeus.com/v1/security/oauth2/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: env.AMADEUS_API_KEY,
      client_secret: env.AMADEUS_API_SECRET
    })
  });

  const data = await response.json();

  cachedToken = {
    access_token: data.access_token,
    expires_in: data.expires_in,
    expires_at: Date.now() + (data.expires_in * 1000) - 60000 // 1 min buffer
  };

  return cachedToken.access_token;
}

export async function searchFlights(
  origin: string,
  destination: string,
  departureDate: string,
  returnDate: string,
  env: Env
) {
  const token = await getAccessToken(env);

  const url = new URL('https://api.amadeus.com/v2/shopping/flight-offers');
  url.searchParams.set('originLocationCode', origin);
  url.searchParams.set('destinationLocationCode', destination);
  url.searchParams.set('departureDate', departureDate);
  url.searchParams.set('returnDate', returnDate);
  url.searchParams.set('adults', '1');
  url.searchParams.set('currencyCode', 'USD');
  url.searchParams.set('max', '50');

  const response = await fetch(url.toString(), {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });

  return response.json();
}
```

## Part 5: Background Job - Deal Scanner

Use Cloudflare Durable Objects for scheduled deal scanning:

```typescript
export class DealScanner {
  async fetch(request: Request) {
    // Scan for deals every 5 minutes
    await this.scanDeals();
    return new Response('OK');
  }

  async scanDeals() {
    // 1. Get all active watchlists
    // 2. Search Amadeus for each route
    // 3. Calculate deal scores
    // 4. Save deals to database
    // 5. Trigger smart queue for alerts
  }
}
```

## Part 6: Deploy

```bash
# Development
wrangler dev

# Production
wrangler deploy
```

## Part 7: iOS Integration

Update `APIClient.swift` with production URL:

```swift
let baseURL = "https://api.farelens.com"
```

## Costs Estimate (MVP)

- **Supabase:** Free (up to 500MB database, 2GB bandwidth)
- **Cloudflare Workers:** Free (100K requests/day)
- **Cloudflare KV:** Free (1GB storage, 100K reads/day)
- **Amadeus API:** Free (2K calls/month)
- **APNs:** Free (unlimited push notifications)

**Total: $0/month for MVP** 🎉

## Next Steps

1. Implement all API endpoints
2. Set up deal scanning cron job
3. Implement smart queue logic
4. Set up APNs push notification delivery
5. Test end-to-end with iOS app
6. Monitor and optimize performance
