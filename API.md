# FARELENS BACKEND API ARCHITECTURE v1.0

**Company:** Astrion Studio
**App:** FareLens
**Backend Architect:** Claude (backend-architect agent)
**Based on:** PRD v2.0, DESIGN.md v1.0, ARCHITECTURE.md v1.0
**Date:** 2025-10-06

---

## EXECUTIVE SUMMARY

FareLens backend is a serverless, edge-first API architecture designed to deliver flight intelligence to iOS clients with sub-second latency at near-zero cost. The primary technical constraint — **Amadeus free tier (2,000 calls/month)** — drives every architectural decision.

**Mission:** Build a backend that scales from 0 to 100k users on less than $50/month until revenue justifies infrastructure investment.

**Key Decisions:**
- **Platform:** Cloudflare Workers (edge compute, global deployment, free tier: 100k req/day)
- **Database:** Supabase Postgres (free tier: 500MB DB, real-time pub/sub, auth)
- **Cache:** Cloudflare KV (included free: 1M reads + 1K writes/day, edge-distributed)
- **Rate Limiting & Sessions:** Cloudflare Durable Objects (included free, in-memory state management)
- **Strategy:** Aggressive caching (5-min TTL) + fallback APIs (Travelpayouts, SerpAPI)
- **Monetization:** Server-side subscription validation (StoreKit 2), strict tier enforcement

**Why Cloudflare KV (NOT Upstash Redis):**
- **Cost:** Free (1M reads/day) vs Upstash $5/mo minimum after 10K commands/day
- **Our traffic (3K MAU):** ~300 flight searches/day + 6K watchlist checks/day = 6.3K reads/day ✅
- **Performance:** ~10-50ms latency (edge-cached) vs Redis <1ms (acceptable tradeoff for $0 cost)
- **Scalability:** Won't hit $5/mo until 10K+ MAU (by then, revenue from Pro subscriptions covers it)
- **Rate limiting:** Use Durable Objects (free, in-memory) instead of Redis counters

**Architecture Principles:**
- **Cache-first:** Always serve cached data if valid (minimize API costs)
- **Edge-native:** Deploy globally (30ms p95 latency for all users)
- **Serverless:** Pay-per-request (no idle server costs)
- **Privacy-preserving:** Minimal PII, row-level security, encrypted at rest

---

## COMPETITIVE RESEARCH: BACKEND STACK ANALYSIS

### What Successful Travel Apps Use

**Hopper** (10M+ users):
- Backend: Microservices (Kubernetes, AWS)
- Database: PostgreSQL + Redis (their stack, confirmed in job postings)
- Caching: Aggressive (15-min TTL for flight prices)
- Scale: Handles 50M searches/day
- **Takeaway:** Postgres scales, caching is critical (we use Cloudflare KV for $0 cost, not Redis)

**Skyscanner** (100M+ users):
- Backend: Distributed microservices (from engineering blog)
- Database: Multi-datacenter Cassandra + Postgres
- Caching: Multi-layer (CDN, in-memory, application)
- API: Custom aggregation layer (parallel queries to 1,200+ providers)
- **Takeaway:** Start simple (single DB), add complexity when revenue justifies

**Google Flights** (Proprietary):
- Backend: Custom infrastructure (protobuf, bigtable)
- Performance: Sub-1s response time
- **Takeaway:** Can't compete on scale, but can beat on simplicity

### FareLens Strategy: Start Cheap, Scale When Revenue Allows

| Metric | Hopper (Scale) | Skyscanner (Scale) | FareLens (MVP → Growth) |
|--------|---------------|-------------------|------------------------|
| Users | 10M+ | 100M+ | 0 → 10k → 100k |
| Infra Cost | $100k+/month | $1M+/month | **$0 → $25 → $500/mo** |
| Architecture | Microservices | Distributed | **Serverless edge** |
| Database | Postgres + Redis | Cassandra + Postgres | **Postgres + KV** |
| API Response | <1.5s | <1.2s | **<1s (edge cache)** |

**Decision:** Hopper's stack (Postgres + caching) is proven. We use managed versions (Supabase + Cloudflare KV) to eliminate ops overhead at $0 cost.

---

## TECHNICAL CONSTRAINTS & MITIGATION

### Constraint 1: Amadeus Free Tier (2,000 calls/month = 67/day)

**Math:**
- 10k users × 5 searches/user/week = 7,142 searches/week = 1,020 searches/day
- 1,020 searches/day ÷ 67 available calls/day = **15x over quota**

**Mitigation Strategy:**

**Tier 1: Aggressive Caching (Reduces calls by 80%)**
```
Flight Search Results: 5-minute TTL (Cloudflare Workers KV)
  - Cache key: origin_destination_date_cabin_passengers
  - Hit rate target: 70% (10 users search LAX→NYC Dec 15, 9 use cache)
  - Result: 1,020 searches → 306 API calls (within budget!)

Watchlist Checks: 30-minute cache TTL (server-initiated background refresh)
  - **Refresh frequency:** 2x/day (9am, 6pm local time, server-initiated)
  - **Cache duration:** 30 minutes (extended to stay under quota, reuse data for multiple users checking same route)
  - Batch 10 routes per API call (Amadeus Flight Offers Search limit)
  - Result: 200 Pro watchlists × 2 checks/day ÷ 10 batch ÷ 2 (30min cache reuse) = 20 calls/day
  - Under budget ✅ Free users get 1x/day checks (9am only), Pro users get 2x/day priority
```

**Tier 2: Fallback APIs (When Amadeus quota exceeded)**
```
Priority Order:
1. Amadeus Self-Service (primary, best data quality)
2. Travelpayouts Search API (free, affiliate-only, decent coverage)
3. SerpAPI Google Flights (paid backup, $50/mo for 5k searches)
4. Core Data cache (stale data, show "Last updated X hours ago")
```

**Tier 3: User Rate Limiting**
```
Free Tier: 3 searches/minute, 20 searches/day
Pro Tier: 10 searches/minute, unlimited/day
Enforcement: Cloudflare Durable Objects rate limiter (token bucket algorithm)
```

**Tier 4: Smart Scheduling (Background Jobs)**
```
Watchlist Background Refresh:
  - Pro users: 2x/day (9am, 6pm local time) - server-initiated, instant push when price drops
  - Free users: 1x/day (9am local time) - results shown in in-app "Good Deals" feed with badge notification
  - Skip refresh if price unchanged in last 24h (detected by hash)
  - Result: 50% reduction in background API calls
```

**Expected API Usage (Post-Mitigation):**
- User searches: ~15 calls/day (50 searches/day × 30% cache miss rate, at 1K MAU)
- Watchlist checks: ~20 calls/day (200 Pro watchlists × 2 checks/day ÷ 10 batch ÷ 2 for 30min cache reuse)
- Deal feed refresh: ~20 calls/day (50 popular routes refreshed, batched efficiently)
- **Total: ~55 calls/day ≈ 1,650 calls/month ✅** (Under 2K quota with 350-call safety margin)
- **Safety margin:** Stays under 2,000/month free tier limit with headroom for growth

**Monitoring & Alerts:**
```typescript
// Track quota in Durable Objects (persistent counter)
const quotaCounterId = env.QUOTA_COUNTER.idFromName(`amadeus:quota:${month}`);
const quotaCounter = env.QUOTA_COUNTER.get(quotaCounterId);
await quotaCounter.increment(); // Atomic increment
const used = await quotaCounter.getValue();

if (used > 1800) { // 90% threshold
  await sendSlackAlert("⚠️ Amadeus quota at 90%! Throttling background jobs.");
  await env.CACHE.put("amadeus:throttle", "true");
}

if (used > 1900) { // 95% threshold - AUTO-FAILOVER
  await sendSlackAlert("🚨 Amadeus quota at 95%! AUTO-SWITCHING to Travelpayouts fallback.");
  await env.CACHE.put("amadeus:disabled", "true", { expirationTtl: 86400 }); // 24-hour cooldown
  // All subsequent requests automatically use Travelpayouts API
}
```

---

### Constraint 2: Free Tier Limits (Cloudflare, Supabase)

**Cloudflare Workers Free Tier:**
- Requests: 100,000/day
- CPU time: 10ms/request
- Storage (KV): 1GB
- **Expected usage:** 10k users × 10 req/day = 100k req/day (at limit!)
- **Mitigation:** Upgrade to Workers Paid ($5/mo) when MAU exceeds 5k

**Supabase Free Tier:**
- Database: 500MB storage
- Bandwidth: 2GB/month
- Real-time connections: 200 concurrent
- **Expected usage:** 10k users = ~50MB DB (deals, watchlists, users)
- **Mitigation:** Upgrade to Pro ($25/mo) when DB exceeds 400MB

**Cloudflare KV Free Tier (Included with Workers):**
- Reads: 1,000,000/day
- Writes: 1,000/day
- Storage: 1GB
- **Expected usage:** 6.3K reads/day (flight cache + watchlist checks), ~360 writes/day
- **Mitigation:** Included free with Workers Paid ($5/mo), no additional cost

**Cloudflare Durable Objects (Included with Workers Paid):**
- Requests: Unlimited on Paid plan
- Storage: Pay-per-GB (negligible for quota counters)
- **Expected usage:** Rate limiting + quota tracking (minimal storage)
- **Cost:** Effectively $0 (covered by Workers Paid $5/mo)

**Total Cost Trajectory:**
- MVP (0-1k users): $0/month
- Growth (1k-10k users): $30/month ($5 Cloudflare Workers Paid + $25 Supabase Pro)
- Scale (10k-100k users): $275/month ($25 Cloudflare + $50 Supabase + $200 Amadeus Production tier)

---

## SYSTEM ARCHITECTURE

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS CLIENT                               │
│  (SwiftUI, Core Data, NSCache, Keychain)                        │
└────────────────────┬────────────────────────────────────────────┘
                     │ HTTPS (TLS 1.3)
                     │ Authorization: Bearer <JWT>
                     ↓
┌─────────────────────────────────────────────────────────────────┐
│          CLOUDFLARE WORKERS (Edge API Gateway)                   │
│  - Global deployment (300+ cities)                               │
│  - Request routing (search, watchlist, deals, alerts)            │
│  - Rate limiting (Durable Objects)                               │
│  - Response caching (KV store, 5-min TTL)                        │
│  - Quota tracking (Durable Objects)                              │
│  - CORS, auth validation, request logging                        │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ↓
            ┌─────────────────┐
            │  SUPABASE       │
            │  (Postgres)     │
            │                 │
            │  - Users        │
            │  - Watchlists   │
            │  - Deals        │
            │  - Alerts       │
            │  - Price hist   │
            │  - Device tokens│
            │                 │
            │  + Auth (JWT)   │
            │  + Real-time    │
            │    (pub/sub)    │
            │  + RLS policies │
            └─────────────────┘
                                 │
                                 │ Background Jobs
                                 ↓
                        ┌─────────────────┐
                        │  CLOUDFLARE     │
                        │  CRON TRIGGERS  │
                        │                 │
                        │  - Deal refresh │
                        │    (every 15min)│
                        │  - Watchlist    │
                        │    checks (2x/d)│
                        │  - Alert match  │
                        │    (every 5min) │
                        └────────┬────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ↓                       ↓                       ↓
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  AMADEUS API    │   │ TRAVELPAYOUTS   │   │   APNs          │
│  (Flight Data)  │   │ (Fallback +     │   │  (Push Notifs)  │
│                 │   │  Affiliate)     │   │                 │
│  - Search       │   │  - Search API   │   │  - Alerts       │
│  - Offers       │   │  - Deep links   │   │  - Exceptions   │
│  - Prices       │   │  - Commission   │   │  - Silent push  │
└─────────────────┘   └─────────────────┘   └─────────────────┘
```

### Request Flow: User Searches Flight

```
1. iOS App → POST /v1/flights/search
   Headers: Authorization: Bearer <jwt>, X-Device-ID: <uuid>
   Body: { origin: "LAX", destination: "NYC", date: "2025-12-01", passengers: 1 }

2. Cloudflare Worker (Edge)
   → Check rate limit (Durable Objects): OK (2 of 3 searches/min used)
   → Validate JWT (Supabase public key): OK
   → Generate cache key: "search:LAX:NYC:2025-12-01:1:economy"
   → Check KV cache (5-min TTL): MISS

3. Worker → Amadeus API
   → Check quota (Durable Objects): OK (52 of 67 calls today used)
   → POST https://api.amadeus.com/v2/shopping/flight-offers
   → Response: 15 offers, 200ms latency

4. Worker → Transform & Cache
   → Map Amadeus DTO → FareLens format (remove cruft, add deal scores)
   → Store in KV cache (TTL: 300s)
   → Store in Supabase (background, async)
   → Increment quota counter (Durable Objects)

5. Worker → iOS Client
   Response: { deals: [...], cached_at: "2025-10-06T10:00:00Z" }
   Latency: 250ms (Amadeus 200ms + processing 50ms)

6. Next User (Same Search, <5 min later)
   → Worker checks KV cache: HIT
   → Return cached data immediately (no Amadeus call)
   → Latency: 20ms (edge cache only)
```

---

## API SPECIFICATION

### Base URLs

```
Production:  https://api.farelens.app
Development: https://dev-api.farelens.app
```

### Authentication

**JWT Token (Supabase Auth)**
```
Authorization: Bearer <access_token>
```

- Access token: 1-hour expiry
- Refresh token: 7-day expiry (HTTP-only cookie)
- iOS handles refresh automatically (URLSession interceptor)

**Device Identification**
```
X-Device-ID: <uuid>
```

- Used for push notifications (APNs token mapping)
- iOS generates on first launch, persists in Keychain

---

## API ENDPOINTS

### 1. Authentication & User Management

#### POST /v1/auth/signup

**Purpose:** Create new user account (email/password or Sign in with Apple)

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!", // Optional if using Apple Sign-In
  "apple_token": "eyJhbGc...", // Optional, from Sign in with Apple
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response (201 Created):**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "tier": "free",
    "created_at": "2025-10-06T10:00:00Z"
  },
  "session": {
    "access_token": "eyJhbGc...",
    "refresh_token": "eyJhbGc...",
    "expires_at": "2025-10-06T11:00:00Z"
  }
}
```

**Rate Limit:** 5 signups/hour per IP

---

#### POST /v1/auth/login

**Purpose:** Authenticate existing user

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response (200 OK):**
```json
{
  "session": {
    "access_token": "eyJhbGc...",
    "refresh_token": "eyJhbGc...",
    "expires_at": "2025-10-06T11:00:00Z"
  }
}
```

**Rate Limit:** 10 attempts/hour per email

---

#### POST /v1/auth/refresh

**Purpose:** Refresh expired access token

**Request:**
```json
{
  "refresh_token": "eyJhbGc..."
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGc...",
  "expires_at": "2025-10-06T12:00:00Z"
}
```

---

### 2. Flight Search & Deals

#### POST /v1/flights/search

**Purpose:** Search for flight offers (primary feature)

**Request:**
```json
{
  "origin": "LAX",
  "destination": "NYC",
  "departure_date": "2025-12-15",
  "return_date": "2025-12-22", // Optional, null = one-way
  "passengers": {
    "adults": 1,
    "children": 0,
    "infants": 0
  },
  "cabin": "economy", // economy | premium | business | first
  "nonstop_only": false,
  "max_price": 1000 // Optional, USD
}
```

**Response (200 OK):**
```json
{
  "search_id": "search_abc123",
  "results": [
    {
      "id": "deal_xyz789",
      "route": {
        "origin": {
          "iata": "LAX",
          "city": "Los Angeles",
          "airport": "Los Angeles International"
        },
        "destination": {
          "iata": "JFK",
          "city": "New York",
          "airport": "John F. Kennedy International"
        }
      },
      "outbound": {
        "departure": "2025-12-15T08:00:00-08:00",
        "arrival": "2025-12-15T16:30:00-05:00",
        "duration_minutes": 330,
        "stops": 0,
        "segments": [
          {
            "airline": {
              "iata": "UA",
              "name": "United Airlines"
            },
            "flight_number": "UA1545",
            "departure": "2025-12-15T08:00:00-08:00",
            "arrival": "2025-12-15T16:30:00-05:00",
            "aircraft": "Boeing 777-300ER"
          }
        ]
      },
      "inbound": {
        "departure": "2025-12-22T09:00:00-05:00",
        "arrival": "2025-12-22T12:30:00-08:00",
        "duration_minutes": 330,
        "stops": 0,
        "segments": [
          {
            "airline": {
              "iata": "UA",
              "name": "United Airlines"
            },
            "flight_number": "UA1546",
            "departure": "2025-12-22T09:00:00-05:00",
            "arrival": "2025-12-22T12:30:00-08:00",
            "aircraft": "Boeing 777-300ER"
          }
        ]
      },
      "pricing": {
        "total": 650.00,
        "currency": "USD",
        "base_fare": 550.00,
        "taxes": 100.00,
        "cabin": "economy",
        "fare_type": "main_cabin", // basic | main | premium | business | first
        "baggage": {
          "carry_on": "1 included",
          "checked": "1 bag included"
        }
      },
      "deal_score": {
        "value": 94,
        "label": "Exceptional", // Exceptional (90+) | Great (80-89) | Good (70-79) | Fair (60-69)
        "explanation": [
          "24% below 90-day average ($850)",
          "Lowest price in 6 months",
          "Nonstop flight (no layovers)"
        ]
      },
      "providers": [
        {
          "name": "United Airlines",
          "type": "airline_direct", // airline_direct | ota | affiliate
          "price": 650.00,
          "is_lowest": true,
          "booking_url": "https://united.com/book/..."
        },
        {
          "name": "Aviasales",
          "type": "affiliate",
          "price": 665.00,
          "is_lowest": false,
          "booking_url": "https://tp.media/r?campaign_id=X&marker=676763&sub_id=ios-fl-deal_xyz789-search-varA-free&u=https%3A%2F%2Faviasales.com%2F..."
        }
      ]
    }
  ],
  "meta": {
    "total_results": 15,
    "search_time_ms": 245,
    "cached": false,
    "cached_at": null,
    "provider": "amadeus" // amadeus | travelpayouts | cache
  }
}
```

**Cache Strategy:**
- TTL: 5 minutes (flight prices change slowly)
- Key: `search:{origin}:{destination}:{date}:{passengers}:{cabin}`
- Hit rate target: 70%

**Rate Limit:**
- Free tier: 3 searches/minute, 20 searches/day
- Pro tier: 10 searches/minute, unlimited/day

**Error Responses:**

**429 Rate Limit Exceeded:**
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Free tier: 3 searches/minute. Upgrade to Pro for unlimited.",
    "retry_after": 45,
    "upgrade_url": "farelens://subscription"
  }
}
```

**503 Service Unavailable (Amadeus quota exceeded):**
```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Live prices unavailable. Showing cached results.",
    "cached_results": true
  },
  "results": [...] // Stale data from cache
}
```

---

#### GET /v1/deals/feed

**Purpose:** Personalized deal feed (home screen)

**Query Parameters:**
```
?origin=LAX          // Optional, filter by origin
&max_price=1000      // Optional, USD
&cabin=economy       // Optional
&page=1              // Pagination
&per_page=20         // Default: 20, max: 50
```

**Response (200 OK):**
```json
{
  "deals": [
    {
      "id": "deal_abc123",
      "route": {
        "origin": { "iata": "LAX", "city": "Los Angeles" },
        "destination": { "iata": "NRT", "city": "Tokyo" }
      },
      "departure_date": "2025-12-01",
      "return_date": "2025-12-15",
      "price": 650.00,
      "currency": "USD",
      "airline": { "iata": "UA", "name": "United Airlines" },
      "cabin": "economy",
      "stops": 0,
      "deal_score": {
        "value": 94,
        "label": "Exceptional",
        "savings_percent": 35
      },
      "expires_at": "2025-10-06T16:00:00Z",
      "image_url": "https://images.farelens.app/destinations/tokyo.jpg"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 157,
    "total_pages": 8
  },
  "meta": {
    "cached": true,
    "cached_at": "2025-10-06T10:00:00Z"
  }
}
```

**Cache Strategy:**
- Global feed (no user-specific filters): 15-min TTL
- User-specific filters: 5-min TTL
- Background job refreshes feed every 15 min

**Rate Limit:** 20 requests/minute (generous, read-only)

---

#### GET /v1/deals/:dealId

**Purpose:** Detailed view of specific deal (price history, all providers)

**Response (200 OK):**
```json
{
  "deal": {
    "id": "deal_abc123",
    "route": {
      "origin": { "iata": "LAX", "city": "Los Angeles" },
      "destination": { "iata": "NRT", "city": "Tokyo" }
    },
    "departure_date": "2025-12-01",
    "return_date": "2025-12-15",
    "price": 650.00,
    "currency": "USD",
    "airline": { "iata": "UA", "name": "United Airlines" },
    "cabin": "economy",
    "stops": 0,
    "deal_score": {
      "value": 94,
      "label": "Exceptional",
      "explanation": [
        "24% below 90-day average ($850)",
        "Lowest price in 6 months",
        "Nonstop flight"
      ]
    },
    "price_history": [
      { "date": "2025-09-06", "price": 850.00 },
      { "date": "2025-09-13", "price": 820.00 },
      { "date": "2025-09-20", "price": 790.00 },
      { "date": "2025-09-27", "price": 750.00 },
      { "date": "2025-10-04", "price": 680.00 },
      { "date": "2025-10-06", "price": 650.00 }
    ],
    "average_price_30d": 785.00,
    "providers": [
      {
        "name": "United Airlines",
        "type": "airline_direct",
        "price": 650.00,
        "is_lowest": true,
        "baggage": { "carry_on": "1 included", "checked": "1 included" },
        "booking_url": "https://united.com/book/..."
      },
      {
        "name": "Aviasales",
        "type": "affiliate",
        "price": 665.00,
        "is_lowest": false,
        "baggage": { "carry_on": "1 included", "checked": "1 included" },
        "booking_url": "https://tp.media/r?campaign_id=X&marker=676763&sub_id=ios-fl-deal_abc123-detail-varA-free&u=..."
      },
      {
        "name": "Expedia",
        "type": "ota",
        "price": 685.00,
        "is_lowest": false,
        "baggage": { "carry_on": "1 included", "checked": "0 bags" },
        "booking_url": "https://expedia.com/flights/..."
      }
    ]
  }
}
```

**Cache Strategy:**
- TTL: 15 minutes (price history updates hourly)
- Key: `deal:{dealId}`

---

### 3. Watchlists

#### POST /v1/watchlists

**Purpose:** Create price watchlist (max 2 for Free, unlimited for Pro)

**Request:**
```json
{
  "origin": "LAX",
  "destination": "NYC",
  "departure_date": "2025-12-15", // Optional, null = flexible dates
  "return_date": "2025-12-22", // Optional
  "passengers": 1,
  "cabin": "economy",
  "max_price": 700.00, // Alert threshold
  "alert_settings": {
    "frequency": "immediate", // immediate | daily_digest | price_drop_only
    "quiet_hours": {
      "enabled": true,
      "start": "22:00", // 10pm local time
      "end": "07:00" // 7am local time
    }
  }
}
```

**Response (201 Created):**
```json
{
  "watchlist": {
    "id": "wl_xyz789",
    "route": {
      "origin": { "iata": "LAX", "city": "Los Angeles" },
      "destination": { "iata": "JFK", "city": "New York" }
    },
    "departure_date": "2025-12-15",
    "return_date": "2025-12-22",
    "current_price": 420.00,
    "max_price": 700.00,
    "alert_settings": { ... },
    "created_at": "2025-10-06T10:00:00Z",
    "last_checked_at": "2025-10-06T10:00:00Z"
  }
}
```

**Validation:**
- Free tier: Max 5 watchlists (enforce server-side)
- Pro tier: Unlimited watchlists

**Error (403 Forbidden - Free Tier Limit):**
```json
{
  "error": {
    "code": "WATCHLIST_LIMIT_EXCEEDED",
    "message": "Free tier: 5 watchlists max. You have 5 active watchlists.",
    "current_count": 5,
    "max_allowed": 5,
    "upgrade_url": "farelens://subscription"
  }
}
```

---

#### GET /v1/watchlists

**Purpose:** List user's active watchlists

**Response (200 OK):**
```json
{
  "watchlists": [
    {
      "id": "wl_xyz789",
      "route": {
        "origin": { "iata": "LAX", "city": "Los Angeles" },
        "destination": { "iata": "JFK", "city": "New York" }
      },
      "departure_date": "2025-12-15",
      "return_date": "2025-12-22",
      "current_price": 420.00,
      "previous_price": 470.00,
      "price_change": -50.00,
      "price_change_percent": -10.6,
      "max_price": 700.00,
      "is_active": true,
      "created_at": "2025-10-06T10:00:00Z",
      "last_checked_at": "2025-10-06T14:30:00Z"
    }
  ],
  "meta": {
    "total": 2,
    "max_allowed": 5, // Free tier
    "tier": "free"
  }
}
```

---

#### PUT /v1/watchlists/:id

**Purpose:** Update watchlist settings (dates, price threshold, alerts)

**Request:**
```json
{
  "max_price": 650.00,
  "alert_settings": {
    "frequency": "price_drop_only"
  }
}
```

**Response (200 OK):**
```json
{
  "watchlist": { ... } // Updated watchlist object
}
```

---

#### DELETE /v1/watchlists/:id

**Purpose:** Delete watchlist

**Response (204 No Content)**

---

#### POST /v1/watchlists/check

**Purpose:** Manual refresh (check prices now, don't wait for background job)

**Request:**
```json
{
  "watchlist_ids": ["wl_xyz789", "wl_abc123"]
}
```

**Response (200 OK):**
```json
{
  "results": [
    {
      "watchlist_id": "wl_xyz789",
      "current_price": 420.00,
      "previous_price": 470.00,
      "price_change": -50.00,
      "checked_at": "2025-10-06T15:00:00Z"
    }
  ]
}
```

**Rate Limit:**
- Free tier: 3 manual checks/hour
- Pro tier: 20 manual checks/hour

---

### 4. Alerts & Notifications

#### POST /v1/alerts/register

**Purpose:** Register device for push notifications (APNs)

**Request:**
```json
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "apns_token": "hex_token_from_ios",
  "platform": "ios",
  "app_version": "1.0.0",
  "os_version": "18.0"
}
```

**Response (201 Created):**
```json
{
  "registered": true,
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

#### POST /v1/alerts/preferences

**Purpose:** Update alert preferences (quiet hours, caps, snoozed routes)

**Request:**
```json
{
  "quiet_hours": {
    "enabled": true,
    "start": "22:00",
    "end": "07:00",
    "timezone": "America/Los_Angeles"
  },
  "alert_caps": {
    "max_per_day": 3, // Free: 3 immediate, Pro: 6 immediate (cap is only difference)
    "smart_queue_enabled": true // Formula: finalScore = dealScore × (1 + watchlistBoost) × (1 + airportWeight)
  },
  "preferred_airports": [
    { "iata": "LAX", "weight": 0.6 }, // Pro tier: Max 3 airports, weights must sum to 1.0
    { "iata": "JFK", "weight": 0.3 },
    { "iata": "ORD", "weight": 0.1 }
    // Free tier: Max 1 airport (weight: 1.0)
    // Validation: Free max 1, Pro max 3, weights sum to 1.0
  ],
  "watchlist_only_mode": false, // Pro tier only: Disable discovery alerts, only watchlist drops
  "snoozed_routes": [
    { "origin": "LAX", "destination": "SFO", "snoozed_until": "2025-11-06" }
  ]
}
```

**Response (200 OK):**
```json
{
  "preferences": { ... } // Updated preferences
}
```

---

#### GET /v1/alerts/history

**Purpose:** Past alerts sent (last 30 days)

**Response (200 OK):**
```json
{
  "alerts": [
    {
      "id": "alert_xyz",
      "deal_id": "deal_abc123",
      "watchlist_id": "wl_xyz789",
      "route": {
        "origin": { "iata": "LAX", "city": "Los Angeles" },
        "destination": { "iata": "JFK", "city": "New York" }
      },
      "price": 420.00,
      "deal_score": 94,
      "sent_at": "2025-10-06T09:30:00Z",
      "opened_at": "2025-10-06T09:45:00Z", // null if not opened
      "clicked_through": true // User tapped "Book Now"
    }
  ],
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 45
  }
}
```

---

### 5. Deal Intelligence (DealScore)

#### POST /v1/deals/score

**Purpose:** Server-side baseline scoring (client adds on-device personalization)

**Request:**
```json
{
  "origin": "LAX",
  "destination": "NYC",
  "price": 420.00,
  "departure_date": "2025-12-15",
  "airline": "UA",
  "cabin": "economy",
  "stops": 0
}
```

**Response (200 OK):**
```json
{
  "deal_score": {
    "baseline_score": 87, // Server-computed (0-100)
    "label": "Great", // Exceptional (90+) | Great (80-89) | Good (70-79)
    "factors": [
      {
        "name": "price_vs_average",
        "weight": 0.4,
        "value": 0.85,
        "explanation": "24% below 90-day average ($550)"
      },
      {
        "name": "historical_low",
        "weight": 0.3,
        "value": 0.9,
        "explanation": "Lowest price in 6 months"
      },
      {
        "name": "route_popularity",
        "weight": 0.15,
        "value": 0.8,
        "explanation": "High demand route (top 10%)"
      },
      {
        "name": "time_to_departure",
        "weight": 0.15,
        "value": 0.7,
        "explanation": "69 days out (moderate urgency)"
      }
    ],
    "comparable_prices": {
      "avg_30d": 550.00,
      "avg_90d": 580.00,
      "lowest_6mo": 420.00,
      "highest_6mo": 850.00
    }
  }
}
```

**Algorithm (Server-Side Baseline):**
```typescript
function calculateDealScore(deal: Deal, history: PriceHistory): number {
  const factors = {
    priceVsAverage: {
      weight: 0.4,
      value: calculatePriceScore(deal.price, history.avg90d)
    },
    historicalLow: {
      weight: 0.3,
      value: calculateHistoricalScore(deal.price, history.lowest6mo)
    },
    routePopularity: {
      weight: 0.15,
      value: calculatePopularityScore(deal.route)
    },
    timeToDeparture: {
      weight: 0.15,
      value: calculateUrgencyScore(deal.departureDate)
    }
  };

  const baselineScore = Object.values(factors).reduce(
    (sum, f) => sum + f.weight * f.value,
    0
  ) * 100;

  return Math.round(baselineScore); // 0-100
}

function calculatePriceScore(currentPrice: number, avgPrice: number): number {
  const delta = (avgPrice - currentPrice) / avgPrice;
  // 20% below avg = 0.8, 30% below = 0.9, 40% below = 1.0
  return Math.min(1.0, Math.max(0, delta * 2.5 + 0.5));
}
```

**iOS App:** Adds on-device personalization layer (user route preferences, airline loyalty) to baseline score.

---

#### GET /v1/deals/:dealId/history

**Purpose:** 30-day price trend data for chart

**Response (200 OK):**
```json
{
  "deal_id": "deal_abc123",
  "route": {
    "origin": "LAX",
    "destination": "NYC"
  },
  "price_history": [
    { "date": "2025-09-06", "price": 550.00 },
    { "date": "2025-09-13", "price": 530.00 },
    { "date": "2025-09-20", "price": 510.00 },
    { "date": "2025-09-27", "price": 480.00 },
    { "date": "2025-10-04", "price": 450.00 },
    { "date": "2025-10-06", "price": 420.00 }
  ],
  "statistics": {
    "avg_30d": 490.00,
    "avg_90d": 550.00,
    "lowest_30d": 420.00,
    "highest_30d": 580.00
  }
}
```

**Cache Strategy:**
- TTL: 1 hour (price history updates slowly)
- Background job: Fetch daily price snapshot at midnight UTC

---

### 6. Affiliate Deep Links

#### POST /v1/affiliate/click

**Purpose:** Log affiliate click (attribution tracking)

**Request:**
```json
{
  "deal_id": "deal_abc123",
  "provider": "aviasales",
  "placement": "detail_screen", // detail_screen | glasssheet | widget
  "user_tier": "free",
  "ab_variant": "variantA"
}
```

**Response (200 OK):**
```json
{
  "click_id": "click_xyz",
  "deep_link": "https://tp.media/r?campaign_id=100&marker=676763&sub_id=ios-fl-deal_abc123-detail-varA-free&u=https%3A%2F%2Faviasales.com%2F...",
  "logged_at": "2025-10-06T10:00:00Z"
}
```

**Purpose:**
- Track every affiliate click (dealId, userId, placement, timestamp)
- Match with Travelpayouts commission webhooks (30-day attribution)
- A/B test placements (detail screen vs GlassSheet)

**Sub-ID Schema:**
```
ios-fl-{dealId}-{placement}-{abVariant}-{tier}

Example: ios-fl-deal_abc123-detail-varA-free
  - dealId: deal_abc123 (which deal)
  - placement: detail (detail_screen) | sheet (glasssheet) | widget
  - abVariant: varA | varB (A/B testing)
  - tier: free | pro
```

---

### 7. Analytics Events (Complete Schema)

#### Event: affiliate_click

**Purpose:** Track every affiliate CTA click for attribution and revenue reconciliation

**Payload:**
```json
{
  "event": "affiliate_click",
  "user_id": "usr_abc123",
  "deal_id": "deal_xyz789",
  "provider": "aviasales",
  "sub_id": "ios-fl-deal_xyz789-detail-varA-free",
  "placement": "detail_screen",
  "price": 420.00,
  "route": "LAX-NYC",
  "timestamp": "2025-10-06T10:00:00Z",
  "session_id": "sess_123",
  "ab_variant": "varA"
}
```

**Sent to:** Backend + Firebase Analytics

---

#### Event: affiliate_confirmed

**Purpose:** Reconcile affiliate revenue (from Travelpayouts webhook) with logged clicks

**Payload:**
```json
{
  "event": "affiliate_confirmed",
  "user_id": "usr_abc123",
  "deal_id": "deal_xyz789",
  "provider": "aviasales",
  "sub_id": "ios-fl-deal_xyz789-detail-varA-free",
  "commission": 8.50,
  "booking_value": 420.00,
  "confirmed_at": "2025-11-05T15:30:00Z", // 30 days after click
  "click_timestamp": "2025-10-06T10:00:00Z"
}
```

**Source:** Travelpayouts webhook → Backend logs event

**Use Case:** Revenue attribution per placement, A/B test winner analysis

---

#### Event: deal_view

**Payload:**
```json
{
  "event": "deal_view",
  "user_id": "usr_abc123",
  "deal_id": "deal_xyz789",
  "deal_score": 94,
  "price": 420.00,
  "savings_percent": 35,
  "source": "feed" | "watchlist" | "notification",
  "timestamp": "2025-10-06T10:00:00Z"
}
```

**Use Case:** Funnel analysis (view → click → book)

---

#### Event: watchlist_create

**Payload:**
```json
{
  "event": "watchlist_create",
  "user_id": "usr_abc123",
  "route": "LAX-NYC",
  "departure_date": "2025-12-15",
  "price_threshold": 450.00,
  "user_tier": "free",
  "watchlist_count": 1,
  "timestamp": "2025-10-06T10:00:00Z"
}
```

**Use Case:** Activation metric (70% create ≥1 watchlist in week 1)

---

#### Event: alert_sent

**Payload:**
```json
{
  "event": "alert_sent",
  "user_id": "usr_abc123",
  "deal_id": "deal_xyz789",
  "watchlist_id": "wl_abc",
  "alert_type": "price_drop" | "exceptional_deal",
  "delivery_method": "push" | "email",
  "sent_at": "2025-10-06T10:00:00Z"
}
```

**Use Case:** Alert delivery SLO tracking (≥99% delivered <60s)

---

#### Event: alert_opened

**Payload:**
```json
{
  "event": "alert_opened",
  "user_id": "usr_abc123",
  "deal_id": "deal_xyz789",
  "alert_id": "alert_abc",
  "opened_at": "2025-10-06T10:05:00Z",
  "time_to_open_seconds": 300
}
```

**Use Case:** Alert open rate metric (target: ≥60%)

---

#### Event: subscription_converted

**Payload:**
```json
{
  "event": "subscription_converted",
  "user_id": "usr_abc123",
  "product_id": "com.farelens.pro.monthly",
  "price": 4.99,
  "trial_days": 0,
  "converted_at": "2025-10-06T10:00:00Z",
  "days_since_signup": 14
}
```

**Use Case:** Pro conversion metric (target: ≥8% within 30 days)

---

#### Event: search_performed

**Payload:**
```json
{
  "event": "search_performed",
  "user_id": "usr_abc123",
  "route": "LAX-NYC",
  "departure_date": "2025-12-15",
  "return_date": "2025-12-22",
  "cabin": "economy",
  "passengers": 1,
  "results_count": 15,
  "response_time_ms": 850,
  "timestamp": "2025-10-06T10:00:00Z"
}
```

**Use Case:** Search latency SLO (p95 <1.2s)

---

### Event Schema Completeness

**All events include:**
- `user_id` (for user-level analytics)
- `timestamp` (ISO 8601 UTC)
- `session_id` (for session replay)
- `platform`: "ios" (for cross-platform comparison in future)
- `app_version`: "1.0.0" (for feature flag rollout analysis)

**Backend Handling:**
```typescript
export async function logEvent(event: AnalyticsEvent): Promise<void> {
  // 1. Log to Supabase (analytics table - primary storage)
  await db.query('INSERT INTO analytics_events (event, payload, created_at) VALUES ($1, $2, NOW())', [
    event.event,
    JSON.stringify(event)
  ]);

  // 2. Track in Durable Objects (real-time counters for dashboards)
  const counterId = env.ANALYTICS_COUNTER.idFromName(`events:${event.event}:today`);
  const counter = env.ANALYTICS_COUNTER.get(counterId);
  await counter.increment();

  // 3. Send to external analytics (if needed)
  if (['affiliate_click', 'subscription_converted'].includes(event.event)) {
    await sendToExternalAnalytics(event);
  }
}
```

---

#### GET /v1/affiliate/providers

**Purpose:** Get all available providers for route (sorted by price)

**Query Parameters:**
```
?origin=LAX
&destination=NYC
&date=2025-12-15
```

**Response (200 OK):**
```json
{
  "providers": [
    {
      "name": "United Airlines",
      "type": "airline_direct",
      "price": 650.00,
      "is_lowest": true,
      "is_affiliate": false,
      "booking_url": "https://united.com/book/..."
    },
    {
      "name": "Aviasales",
      "type": "affiliate",
      "price": 665.00,
      "is_lowest": false,
      "is_affiliate": true,
      "commission_estimate": "1.2%",
      "booking_url": "https://tp.media/r?..."
    },
    {
      "name": "Expedia",
      "type": "ota",
      "price": 685.00,
      "is_lowest": false,
      "is_affiliate": false,
      "booking_url": "https://expedia.com/flights/..."
    }
  ],
  "meta": {
    "total_providers": 3,
    "lowest_price": 650.00,
    "affiliate_available": true
  }
}
```

**Ranking Logic:**
1. Lowest price first (always)
2. If affiliate within 7% of lowest → show as 2nd option
3. Sort remaining by: Airline direct > Top OTA > Others

**Transparency Rule:** Never hide lowest fare, even if non-affiliate.

---

### 7. Subscription (StoreKit 2 Server Validation)

#### POST /v1/subscription/validate

**Purpose:** Validate App Store receipt (server-side, prevent fraud)

**Request:**
```json
{
  "receipt_data": "base64_encoded_receipt",
  "product_id": "com.farelens.pro.monthly", // or .annual
  "transaction_id": "2000000123456789"
}
```

**Response (200 OK):**
```json
{
  "valid": true,
  "tier": "pro",
  "product_id": "com.farelens.pro.monthly",
  "expires_at": "2025-11-06T10:00:00Z",
  "is_trial": false,
  "auto_renew": true
}
```

**Server Validation Flow:**
1. iOS sends receipt to backend (not directly to Apple)
2. Backend validates with Apple's verifyReceipt API (StoreKit 2)
3. Backend updates `users.tier` in Supabase
4. iOS gets confirmation, unlocks Pro features

**Fraud Prevention:**
- Validate receipt server-side (iOS can be jailbroken)
- Check transaction_id uniqueness (prevent replay attacks)
- Verify bundle_id matches FareLens

---

#### GET /v1/subscription/status

**Purpose:** Get current user's subscription tier

**Response (200 OK):**
```json
{
  "tier": "pro",
  "product_id": "com.farelens.pro.annual",
  "purchased_at": "2025-10-06T10:00:00Z",
  "expires_at": "2026-10-06T10:00:00Z",
  "is_trial": false,
  "auto_renew": true,
  "features": {
    "max_watchlists": null, // null = unlimited
    "max_alerts_per_day": 6,
    "ad_free": true,
    "priority_support": true
  }
}
```

**Cache Strategy:**
- TTL: 1 hour (subscriptions don't change frequently)
- Invalidate on POST /subscription/validate

---

## DATABASE SCHEMA (Supabase Postgres)

### Table: users

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  encrypted_password VARCHAR(255), -- NULL if Sign in with Apple
  apple_user_id VARCHAR(255) UNIQUE, -- From Sign in with Apple
  tier VARCHAR(20) DEFAULT 'free' CHECK (tier IN ('free', 'pro')),
  subscription_product_id VARCHAR(100), -- com.farelens.pro.monthly
  subscription_expires_at TIMESTAMPTZ,
  subscription_auto_renew BOOLEAN DEFAULT false,
  home_airport VARCHAR(3), -- User's preferred origin
  preferred_cabin VARCHAR(20) DEFAULT 'economy',
  timezone VARCHAR(50) DEFAULT 'America/Los_Angeles', -- User's timezone for quiet hours + alert resets
  notification_preferences JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_tier ON users(tier);
CREATE INDEX idx_users_apple_id ON users(apple_user_id);
```

### Table: watchlists

```sql
CREATE TABLE watchlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  origin VARCHAR(3) NOT NULL,
  destination VARCHAR(3) NOT NULL,
  departure_date DATE, -- NULL = flexible dates
  return_date DATE,
  passengers INT DEFAULT 1,
  cabin VARCHAR(20) DEFAULT 'economy',
  max_price DECIMAL(10,2), -- Alert threshold
  current_price DECIMAL(10,2),
  previous_price DECIMAL(10,2),
  last_checked_at TIMESTAMPTZ,
  alert_settings JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_watchlists_user_id ON watchlists(user_id) WHERE is_active = true;
CREATE INDEX idx_watchlists_route ON watchlists(origin, destination) WHERE is_active = true;
CREATE INDEX idx_watchlists_last_checked ON watchlists(last_checked_at) WHERE is_active = true;

-- Row-Level Security (RLS)
ALTER TABLE watchlists ENABLE ROW LEVEL SECURITY;

CREATE POLICY watchlists_select_policy ON watchlists
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY watchlists_insert_policy ON watchlists
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY watchlists_update_policy ON watchlists
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY watchlists_delete_policy ON watchlists
  FOR DELETE USING (auth.uid() = user_id);
```

### Table: deals

```sql
CREATE TABLE deals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  origin VARCHAR(3) NOT NULL,
  destination VARCHAR(3) NOT NULL,
  departure_date DATE NOT NULL,
  return_date DATE,
  price DECIMAL(10,2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'USD',
  airline_iata VARCHAR(2) NOT NULL,
  cabin VARCHAR(20) NOT NULL,
  stops INT DEFAULT 0,
  duration_minutes INT,
  deal_score INT, -- 0-100
  deal_score_label VARCHAR(20), -- Exceptional, Great, Good
  deal_score_explanation JSONB,
  provider VARCHAR(50) NOT NULL, -- amadeus, travelpayouts, cache
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'
);

-- Indexes
CREATE INDEX idx_deals_route ON deals(origin, destination, departure_date) WHERE is_active = true;
CREATE INDEX idx_deals_price ON deals(price) WHERE is_active = true;
CREATE INDEX idx_deals_score ON deals(deal_score DESC) WHERE is_active = true;
CREATE INDEX idx_deals_created ON deals(created_at DESC) WHERE is_active = true;

-- Composite index for feed queries
CREATE INDEX idx_deals_feed ON deals(deal_score DESC, created_at DESC)
  WHERE is_active = true AND expires_at > NOW();

-- No RLS (deals are public, read-only for users)
```

### Table: price_history

```sql
CREATE TABLE price_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id UUID REFERENCES deals(id) ON DELETE CASCADE,
  origin VARCHAR(3) NOT NULL,
  destination VARCHAR(3) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_price_history_deal ON price_history(deal_id, recorded_at DESC);
CREATE INDEX idx_price_history_route ON price_history(origin, destination, recorded_at DESC);

-- Partition by month (for performance at scale)
-- CREATE TABLE price_history_2025_10 PARTITION OF price_history
--   FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
```

### Table: alerts

```sql
CREATE TABLE alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  watchlist_id UUID REFERENCES watchlists(id) ON DELETE CASCADE,
  deal_id UUID REFERENCES deals(id) ON DELETE SET NULL,
  route_origin VARCHAR(3),
  route_destination VARCHAR(3),
  price DECIMAL(10,2),
  deal_score INT,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  opened_at TIMESTAMPTZ, -- NULL until user opens notification
  clicked_through BOOLEAN DEFAULT false,
  provider VARCHAR(50) -- Which provider user clicked (if any)
);

-- Indexes
CREATE INDEX idx_alerts_user ON alerts(user_id, sent_at DESC);
CREATE INDEX idx_alerts_watchlist ON alerts(watchlist_id, sent_at DESC);

-- RLS
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY alerts_select_policy ON alerts
  FOR SELECT USING (auth.uid() = user_id);
```

### Table: affiliate_clicks

```sql
CREATE TABLE affiliate_clicks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  deal_id UUID REFERENCES deals(id) ON DELETE SET NULL,
  provider VARCHAR(50) NOT NULL, -- aviasales, wayaway
  placement VARCHAR(50) NOT NULL, -- detail_screen, glasssheet, widget
  ab_variant VARCHAR(20),
  user_tier VARCHAR(20),
  clicked_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_affiliate_clicks_user ON affiliate_clicks(user_id, clicked_at DESC);
CREATE INDEX idx_affiliate_clicks_deal ON affiliate_clicks(deal_id, clicked_at DESC);
CREATE INDEX idx_affiliate_clicks_provider ON affiliate_clicks(provider, clicked_at DESC);

-- Analytics query: CTR by placement
-- SELECT placement, COUNT(*) as clicks, COUNT(DISTINCT user_id) as unique_users
-- FROM affiliate_clicks WHERE clicked_at > NOW() - INTERVAL '30 days'
-- GROUP BY placement;
```

### Table: device_tokens

```sql
CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  device_id UUID NOT NULL,
  apns_token VARCHAR(255) NOT NULL,
  platform VARCHAR(20) DEFAULT 'ios',
  app_version VARCHAR(20),
  os_version VARCHAR(20),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, device_id)
);

-- Indexes
CREATE INDEX idx_device_tokens_user ON device_tokens(user_id) WHERE is_active = true;
CREATE INDEX idx_device_tokens_device ON device_tokens(device_id) WHERE is_active = true;
```

---

## AMADEUS API INTEGRATION STRATEGY

### Quota Management (Critical)

**Free Tier: 2,000 calls/month = 67 calls/day**

**Tracking:**
```typescript
// Cloudflare Worker + Durable Objects (persistent counter)
const AMADEUS_QUOTA_KEY = `amadeus:quota:${currentMonth}`;

// Get Durable Object stub for quota tracking
function getQuotaCounter(env: Env): DurableObjectStub {
  const id = env.QUOTA_COUNTER.idFromName(AMADEUS_QUOTA_KEY);
  return env.QUOTA_COUNTER.get(id);
}

async function checkQuota(env: Env): Promise<boolean> {
  const counter = getQuotaCounter(env);
  const used = await counter.getValue() || 0;
  return used < 1800; // 90% threshold (1,800 of 2,000)
}

async function incrementQuota(env: Env): Promise<void> {
  const counter = getQuotaCounter(env);
  await counter.increment();
}

async function getQuotaStatus(env: Env): Promise<QuotaStatus> {
  const counter = getQuotaCounter(env);
  const used = await counter.getValue() || 0;
  const remaining = 2000 - used;
  const percentUsed = (used / 2000) * 100;

  return { used, remaining, percentUsed };
}
```

**Alerts:**
```typescript
if (percentUsed > 90) {
  await sendSlackAlert("⚠️ Amadeus quota at 90%! Throttling background jobs.");
  // Disable non-critical background jobs
  await env.CACHE.put("amadeus:throttle", "true", { expirationTtl: 86400 }); // 24 hour TTL
}
```

**Paid Tier Migration Plan:**
- **When:** ~40 Pro subscribers ($200/mo revenue covers Amadeus cost)
- **Cost:** $200/mo for 10,000 calls (Production tier)
- **Process:** Update Amadeus API key in Cloudflare secrets, increase quota threshold
- **Validation:** No downtime (graceful cutover)

---

### Edge Cache Policy (Normative - CRITICAL FOR QUOTA MANAGEMENT)

**Fetch Policy (User-Initiated Search):**

```typescript
// POST /v1/flights/search
export async function handleFlightSearch(request: Request, env: Env): Promise<Response> {
  const params = await request.json();

  // 1. Generate cache key (route + cabin + date bucket)
  const cacheKey = generateCacheKey({
    origin: params.origin,
    destination: params.destination,
    cabin: params.cabin,
    dateBucket: roundToNearestHour(params.departureDate) // 1-hour bucket
  });

  // 2. Check Cloudflare KV edge cache first
  const cached = await env.CACHE.get(cacheKey);
  if (cached) {
    const age = Date.now() - JSON.parse(cached).timestamp;
    if (age < 300_000) { // 5-min TTL (respecting Amadeus T&Cs)
      return new Response(cached, {
        headers: {
          'Content-Type': 'application/json',
          'X-Cache': 'HIT',
          'Cache-Control': 'public, max-age=300',
          'CDN-Cache-Control': 'public, max-age=300'
        }
      });
    }
  }

  // 3. Check quota before calling Amadeus
  if (!(await checkQuota())) {
    // Quota exceeded → fallback to Travelpayouts
    return await searchTravelpayouts(params);
  }

  // 4. Call Amadeus API
  const offers = await searchAmadeus(params);
  await incrementQuota();

  // 5. Store in edge cache (60-300s TTL based on route popularity)
  const ttl = calculateDynamicTTL(params); // Popular routes = longer TTL
  await env.CACHE.put(cacheKey, JSON.stringify({
    offers,
    timestamp: Date.now(),
    provider: 'amadeus'
  }), { expirationTtl: ttl });

  return new Response(JSON.stringify(offers), {
    headers: {
      'Content-Type': 'application/json',
      'X-Cache': 'MISS',
      'Cache-Control': `public, max-age=${ttl}`,
      'CDN-Cache-Control': `public, max-age=${ttl}`
    }
  });
}

// Dynamic TTL based on route popularity
function calculateDynamicTTL(params: SearchParams): number {
  const popularRoutes = ['LAX-NYC', 'SFO-NYC', 'LAX-LHR', 'NYC-CDG'];
  const route = `${params.origin}-${params.destination}`;

  return popularRoutes.includes(route) ? 300 : 60; // 5min vs 1min
}
```

**Watchlist Polling (Server-Side Batched):**

```typescript
// Cron job: Runs 2x/day (9am, 6pm local time)
export async function checkWatchlists(env: Env): Promise<void> {
  const watchlists = await db.query('SELECT * FROM watchlists WHERE active = true');

  // Batch watchlists by route+date window to maximize cache hits
  const batches = groupByRouteAndMonth(watchlists);

  for (const batch of batches) {
    const cacheKey = `watchlist:${batch.route}:${batch.month}`;

    // Check if we already fetched this route/month recently
    const cached = await env.CACHE.get(cacheKey);
    if (cached && (Date.now() - cached.timestamp < 900_000)) { // 15-min TTL
      // Use cached prices for all watchlists in this batch
      await updateWatchlistsFromCache(batch.watchlists, cached.prices);
      continue;
    }

    // Cache miss → fetch from Amadeus
    if (await checkQuota()) {
      const prices = await fetchPricesForBatch(batch);
      await incrementQuota();

      // Cache for 15 minutes (allows multiple watchlists to share same data)
      await env.CACHE.put(cacheKey, JSON.stringify({
        prices,
        timestamp: Date.now()
      }), { expirationTtl: 900 });

      await updateWatchlistsFromFresh(batch.watchlists, prices);
    } else {
      // Quota exceeded → skip non-urgent checks, alert team
      await sendSlackAlert(`⚠️ Watchlist check skipped (quota exceeded)`);
    }
  }
}
```

**Burn-Rate Governor (Auto-Throttling):**

```typescript
// Automatically lower cache TTL if quota burn rate too high
export async function adjustCacheTTL(env: Env): Promise<void> {
  const status = await getQuotaStatus();

  if (status.percentUsed > 80) {
    // Increase cache TTL (longer freshness window)
    await env.CACHE.put('cache:ttl:multiplier', '2'); // 2x TTL (10min vs 5min)
    await sendSlackAlert(`🔥 Quota at 80%, doubling cache TTL`);
  } else if (status.percentUsed > 90) {
    // Aggressive caching
    await env.CACHE.put('cache:ttl:multiplier', '3'); // 3x TTL (15min)
    await sendSlackAlert(`🚨 Quota at 90%, tripling cache TTL + disabling background jobs`);
  } else {
    // Normal cache TTL
    await env.CACHE.put('cache:ttl:multiplier', '1');
  }
}
```

**Cache Hit Rate Target:** ≥70% (measured daily)

**Monitoring:**
```typescript
// Track cache hit rate with Durable Objects
const cacheStatsId = env.CACHE_STATS.idFromName('cache:stats:today');
const cacheStats = env.CACHE_STATS.get(cacheStatsId);
const { hits, misses } = await cacheStats.getStats();
const hitRate = hits / (hits + misses);

if (hitRate < 0.6) {
  await sendSlackAlert(`📉 Cache hit rate low: ${hitRate.toFixed(2)} (target: 0.70)`);
}
```

---

### Alternative Free/Affordable Flight APIs

**Comparison Table:**

| API | Pricing | Quota | Coverage | Booking | Quality | Recommendation |
|-----|---------|-------|----------|---------|---------|----------------|
| **Amadeus Self-Service** | Free: 2k/mo<br>Paid: $200/mo (10k) | Strict | 400+ airlines<br>Global | No (data only) | Excellent | **Primary** |
| **Travelpayouts Search API** | Free (affiliate-only) | Unlimited* | 100+ airlines<br>Good coverage | Via affiliate link | Good | **Fallback #1** |
| **SerpAPI Google Flights** | $50/mo for 5k searches | 5k/mo | All Google Flights data | No (scraping) | Excellent | **Fallback #2** |
| **Skyscanner API** | Commission-based | Unlimited* | 1,200+ partners | Via redirect | Excellent | **Requires approval** |
| **Kiwi.com Tequila** | Invitation-only | N/A | 750+ carriers | Yes (API booking) | Excellent | **Phase 2** |
| **Duffel API** | $99/mo + $5/order | Unlimited searches | 20+ airlines (NDC) | Yes (direct API) | Excellent | **Phase 3** |

*Unlimited searches, but affiliate revenue required to maintain access

---

### Fallback Strategy

**Priority Order (When Amadeus Quota Exceeded):**

**1. Travelpayouts Search API (Free, Affiliate-Only)**
```typescript
// Pros:
// - Unlimited searches (no quota)
// - Decent coverage (100+ airlines)
// - Affiliate deep links built-in
// - Free (just need to be approved partner)

// Cons:
// - Less comprehensive than Amadeus
// - Affiliate-only (no airline direct prices)
// - Response time slower (~500ms vs Amadeus 200ms)

// Use Case: Fallback when Amadeus quota exceeded
async function searchTravelpayouts(params: SearchParams): Promise<FlightOffers> {
  const response = await fetch('https://api.travelpayouts.com/v1/flight_search', {
    method: 'POST',
    headers: {
      'X-Access-Token': env.TRAVELPAYOUTS_TOKEN,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      origin: params.origin,
      destination: params.destination,
      departure_at: params.departureDate,
      return_at: params.returnDate,
      adults: params.passengers
    })
  });

  const data = await response.json();
  return mapTravelpayoutsToFareLens(data);
}
```

**2. SerpAPI Google Flights ($50/mo for 5k searches)**
```typescript
// Pros:
// - Scrapes Google Flights (most comprehensive)
// - Structured JSON output
// - Price insights (typical price, price history)
// - Reliable uptime

// Cons:
// - Costs $50/mo (not free)
// - 5k searches/month limit
// - Scraping (legal gray area, use carefully)
// - Slower (1-2s response time)

// Use Case: Pro users only, when Amadeus + Travelpayouts both fail
async function searchSerpAPI(params: SearchParams): Promise<FlightOffers> {
  const response = await fetch('https://serpapi.com/search', {
    method: 'GET',
    headers: {
      'X-API-KEY': env.SERPAPI_KEY
    },
    params: {
      engine: 'google_flights',
      departure_id: params.origin,
      arrival_id: params.destination,
      outbound_date: params.departureDate,
      return_date: params.returnDate
    }
  });

  const data = await response.json();
  return mapSerpAPIToFareLens(data);
}
```

**3. Core Data Cache (Stale Data)**
```typescript
// Pros:
// - Always available (offline-capable)
// - No API costs
// - Fast (local iOS storage)

// Cons:
// - Data may be hours/days old
// - No new deals discovered

// Use Case: Last resort, show banner "Live prices unavailable, showing cached results from X hours ago"
```

**Decision Tree:**
```typescript
async function searchFlights(params: SearchParams): Promise<FlightOffers> {
  // Try Amadeus (primary)
  if (await checkAmadeusQuota()) {
    try {
      return await searchAmadeus(params);
    } catch (error) {
      logError('Amadeus failed', error);
    }
  }

  // Fallback 1: Travelpayouts (free, affiliate-only)
  try {
    return await searchTravelpayouts(params);
  } catch (error) {
    logError('Travelpayouts failed', error);
  }

  // Fallback 2: SerpAPI (paid, Pro users only)
  if (user.tier === 'pro') {
    try {
      return await searchSerpAPI(params);
    } catch (error) {
      logError('SerpAPI failed', error);
    }
  }

  // Fallback 3: Return cached data (if available)
  const cached = await getCachedFlights(params);
  if (cached) {
    return {
      ...cached,
      meta: {
        cached: true,
        cachedAt: cached.timestamp,
        warning: 'Live prices unavailable. Showing cached results.'
      }
    };
  }

  // No data available
  throw new Error('All flight APIs unavailable. Please try again later.');
}
```

---

## BACKGROUND JOB ARCHITECTURE

### Cloudflare Cron Triggers

**Job 1: Deal Refresh (Every 15 Minutes)**
```typescript
// cron: */15 * * * * (every 15 minutes)
export default {
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    await refreshDealsFeed(env);
  }
};

async function refreshDealsFeed(env: Env): Promise<void> {
  // Fetch top 50 routes (by user search frequency)
  const topRoutes = await db.query(`
    SELECT origin, destination, COUNT(*) as search_count
    FROM watchlists
    WHERE is_active = true
    GROUP BY origin, destination
    ORDER BY search_count DESC
    LIMIT 50
  `);

  // Fetch deals for each route (batch 10 routes per Amadeus call)
  for (const batch of chunk(topRoutes, 10)) {
    if (!(await checkAmadeusQuota())) break; // Stop if quota exceeded

    const offers = await searchAmadeusBatch(batch);
    await storeDealsInDB(offers);
    await incrementQuota();
  }

  // Invalidate feed cache (note: KV doesn't support wildcard deletes)
  // Store feed cache keys explicitly for invalidation
  const feedCacheKeys = await env.CACHE.get('cache:index:deals:feed');
  if (feedCacheKeys) {
    const keys = JSON.parse(feedCacheKeys);
    await Promise.all(keys.map(key => env.CACHE.delete(key)));
  }

  console.log(`Deal refresh complete. ${topRoutes.length} routes updated.`);
}
```

---

**Job 2: Watchlist Price Checks (2x/day per user, 9am + 6pm local time)**
```typescript
// cron: 0 */6 * * * (every 6 hours, stagger by timezone)
async function checkWatchlistPrices(env: Env): Promise<void> {
  const now = new Date();
  const hour = now.getHours(); // 0-23

  // Get users whose local time is 9am or 6pm (±1 hour window)
  const targetHours = [9, 18]; // 9am, 6pm
  const timezoneOffsets = targetHours.map(h => (h - hour) % 24);

  const watchlists = await db.query(`
    SELECT w.*, u.timezone_offset
    FROM watchlists w
    JOIN users u ON w.user_id = u.id
    WHERE w.is_active = true
      AND u.timezone_offset IN (${timezoneOffsets.join(',')})
      AND w.last_checked_at < NOW() - INTERVAL '5 hours' -- Min 5h between checks
    ORDER BY u.tier DESC -- Pro users first
    LIMIT 1000 -- Max 1000 watchlists per job run
  `);

  // Batch 100 watchlists per Amadeus API call
  for (const batch of chunk(watchlists, 100)) {
    if (!(await checkAmadeusQuota())) {
      // Quota exceeded: Only check Pro users
      const proBatch = batch.filter(w => w.user_tier === 'pro');
      if (proBatch.length === 0) break;
      batch = proBatch;
    }

    const results = await checkPricesBatch(batch);

    // Update watchlists + send alerts if price dropped
    for (const result of results) {
      await updateWatchlistPrice(result);

      if (result.priceDropped && result.belowThreshold) {
        await sendPriceAlert(result);
      }
    }

    await incrementQuota();
  }

  console.log(`Watchlist check complete. ${watchlists.length} checked.`);
}
```

---

**Job 3: Alert Matching (Every 5 Minutes)**
```typescript
// cron: */5 * * * * (every 5 minutes)
async function matchAlerts(env: Env): Promise<void> {
  // Get new deals from last 5 minutes
  const newDeals = await db.query(`
    SELECT * FROM deals
    WHERE created_at > NOW() - INTERVAL '5 minutes'
      AND is_active = true
  `);

  // Get matching watchlists (route + price threshold)
  for (const deal of newDeals) {
    const matchingWatchlists = await db.query(`
      SELECT w.*, u.tier, u.notification_preferences
      FROM watchlists w
      JOIN users u ON w.user_id = u.id
      WHERE w.origin = $1
        AND w.destination = $2
        AND w.max_price >= $3
        AND w.is_active = true
    `, [deal.origin, deal.destination, deal.price]);

    for (const watchlist of matchingWatchlists) {
      // Check alert caps (Free: 3/day, Pro: 6/day)
      const alertCountToday = await getAlertCount(watchlist.user_id, 'today');
      const maxAlerts = watchlist.tier === 'pro' ? 6 : 3;

      if (alertCountToday >= maxAlerts) {
        // Cap exceeded: Skip unless exceptional deal (score ≥90)
        if (deal.deal_score < 90) continue;
      }

      // Check quiet hours (10pm-7am local time)
      if (isQuietHours(watchlist.user_id)) {
        // Skip unless exceptional deal + override enabled
        if (deal.deal_score < 90 || !watchlist.allow_exceptional_override) {
          continue;
        }
      }

      // Check dedupe (no same deal within 6 hours)
      const recentAlert = await getRecentAlert(watchlist.user_id, deal.id, '6 hours');
      if (recentAlert) continue;

      // Send alert!
      await sendPushNotification({
        userId: watchlist.user_id,
        dealId: deal.id,
        watchlistId: watchlist.id,
        title: `${deal.destination} deal dropped to $${deal.price}`,
        body: `Save ${deal.savingsPercent}% vs average. Deal Score: ${deal.deal_score}/100`,
        data: { dealId: deal.id, watchlistId: watchlist.id }
      });

      // Log alert
      await db.insert('alerts', {
        user_id: watchlist.user_id,
        watchlist_id: watchlist.id,
        deal_id: deal.id,
        price: deal.price,
        deal_score: deal.deal_score
      });
    }
  }

  console.log(`Alert matching complete. ${newDeals.length} new deals processed.`);
}
```

---

**Job 4: Deal Expiration (Hourly)**
```typescript
// cron: 0 * * * * (every hour)
async function expireDeals(env: Env): Promise<void> {
  // Mark deals as inactive if expires_at < NOW()
  await db.query(`
    UPDATE deals
    SET is_active = false
    WHERE expires_at < NOW()
      AND is_active = true
  `);

  // Archive deals older than 90 days (move to cold storage)
  await db.query(`
    INSERT INTO deals_archive
    SELECT * FROM deals
    WHERE created_at < NOW() - INTERVAL '90 days'
  `);

  await db.query(`
    DELETE FROM deals
    WHERE created_at < NOW() - INTERVAL '90 days'
  `);

  // Vacuum table (reclaim space)
  await db.query(`VACUUM ANALYZE deals`);

  console.log('Deal expiration complete.');
}
```

---

## REAL-TIME FEATURES

### Supabase Realtime (PostgreSQL LISTEN/NOTIFY)

**Enable Realtime on Deals Table:**
```sql
-- Supabase dashboard: Enable realtime replication
ALTER PUBLICATION supabase_realtime ADD TABLE deals;
```

**iOS Client Subscribes:**
```swift
// iOS App
let subscription = supabase
  .from("deals")
  .on(.insert, callback: { payload in
    // New deal inserted, refresh feed
    print("New deal: \(payload)")
    await viewModel.loadDeals()
  })
  .subscribe()
```

**Benefits:**
- No polling (saves battery, reduces API calls)
- Instant updates (deals appear within seconds)
- Simple implementation (Supabase handles WebSocket)

**Fallback (If Realtime Unavailable):**
- iOS polls GET /deals/feed every 5 minutes
- Works offline with cached data (Core Data)

---

## SECURITY & PRIVACY

### Authentication (JWT Tokens)

**Supabase Auth:**
```typescript
// Sign in with Apple (iOS)
const { data, error } = await supabase.auth.signInWithIdToken({
  provider: 'apple',
  token: appleIdentityToken
});

// JWT payload:
{
  "sub": "user_uuid",
  "email": "user@example.com",
  "role": "authenticated",
  "exp": 1696608000, // 1 hour from now
  "iat": 1696604400
}
```

**Token Validation (Cloudflare Worker):**
```typescript
async function validateJWT(token: string, env: Env): Promise<User | null> {
  try {
    const payload = await jose.jwtVerify(
      token,
      await importSPKI(env.SUPABASE_JWT_PUBLIC_KEY),
      { issuer: env.SUPABASE_URL }
    );

    return {
      id: payload.sub,
      email: payload.email,
      tier: payload.user_metadata?.tier || 'free'
    };
  } catch (error) {
    console.error('JWT validation failed:', error);
    return null;
  }
}
```

---

### Row-Level Security (RLS)

**Supabase RLS Policies:**
```sql
-- Watchlists: Users can only access their own
ALTER TABLE watchlists ENABLE ROW LEVEL SECURITY;

CREATE POLICY watchlists_select_policy ON watchlists
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY watchlists_insert_policy ON watchlists
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Deals: Public (read-only)
CREATE POLICY deals_select_policy ON deals
  FOR SELECT USING (is_active = true);

-- Alerts: Users can only see their own
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY alerts_select_policy ON alerts
  FOR SELECT USING (auth.uid() = user_id);
```

---

### Data Protection

**Encryption:**
- **At Rest:** Supabase encrypts all database data (AES-256)
- **In Transit:** TLS 1.3 (all API calls, iOS ↔ backend)

**PII Handling:**
- Email: Stored in `users` table, encrypted at rest
- Device tokens (APNs): Stored in `device_tokens` table, never logged
- Search history: NOT stored (privacy-preserving)
- Click tracking: Anonymized (userId, dealId, no search queries)

**GDPR Compliance:**
- **Right to Access:** GET /v1/user/data (export all user data as JSON)
- **Right to Delete:** DELETE /v1/user/account (cascade delete all user data)
- **Right to Portability:** JSON export of watchlists, alerts, preferences

---

### Rate Limiting (Durable Objects Token Bucket)

**Algorithm:**
```typescript
async function checkRateLimit(
  userId: string,
  action: string,
  limit: number,
  windowSeconds: number
): Promise<boolean> {
  const rateLimiterId = env.RATE_LIMITER.idFromName(`${userId}:${action}`);
  const rateLimiter = env.RATE_LIMITER.get(rateLimiterId);

  const response = await rateLimiter.fetch('https://internal/check', {
    method: 'POST',
    body: JSON.stringify({ limit, windowSeconds })
  });

  const { allowed, current } = await response.json();
  return allowed;
}

// Usage
const canSearch = await checkRateLimit(
  user.id,
  'search',
  user.tier === 'pro' ? 10 : 3, // Limit
  60 // Window: 1 minute
);

if (!canSearch) {
  return new Response(JSON.stringify({
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Free tier: 3 searches/minute. Upgrade to Pro for 10/minute.'
    }
  }), { status: 429 });
}
```

**Rate Limits by Tier:**

| Action | Free Tier | Pro Tier |
|--------|-----------|----------|
| Search | 3/min, 20/day | 10/min, unlimited |
| Watchlist create | 5 max | Unlimited |
| Watchlist check | 3/hour | 20/hour |
| Alerts | 3/day (immediate) | 6/day (immediate) |
| API requests (total) | 100/min | 500/min |

---

## ANALYTICS & MONITORING

### Metrics to Track

**API Performance:**
- Request latency (p50, p95, p99)
- Error rate (4xx, 5xx)
- Cache hit rate (target: 70%+)
- Amadeus API calls (track quota)

**Business Metrics:**
- Affiliate CTR (target: ≥15%)
- Pro conversion rate (target: ≥8% within 30 days)
- Alert open rate (target: ≥60%)
- Watchlist creation rate (target: 70% of users)

**Infrastructure:**
- Cloudflare Workers: Requests/day, CPU time, KV operations/day
- Cloudflare Durable Objects: Active objects, storage used
- Supabase: Database size, active connections, slow queries

---

### Logging (Structured JSON)

**Cloudflare Worker:**
```typescript
interface LogEntry {
  timestamp: string;
  level: 'debug' | 'info' | 'warn' | 'error';
  service: string;
  action: string;
  user_id?: string;
  duration_ms?: number;
  error?: string;
  metadata?: Record<string, any>;
}

function log(entry: Omit<LogEntry, 'timestamp'>): void {
  console.log(JSON.stringify({
    ...entry,
    timestamp: new Date().toISOString()
  }));
}

// Usage
log({
  level: 'info',
  service: 'api',
  action: 'search_flights',
  user_id: user.id,
  duration_ms: 245,
  metadata: { origin: 'LAX', destination: 'NYC' }
});
```

**Privacy:** Never log PII (emails, passwords, device tokens) or full search queries.

---

### Alerts (Slack Webhooks)

**Critical Alerts:**
```typescript
async function sendSlackAlert(message: string, env: Env): Promise<void> {
  await fetch(env.SLACK_WEBHOOK_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text: message,
      username: 'FareLens Backend',
      icon_emoji: ':airplane:'
    })
  });
}

// Trigger conditions:
// - Amadeus quota >90%
// - Error rate >5%
// - API latency p95 >2s
// - Database CPU >80%
// - Failed background job
```

---

## COST PROJECTIONS & FREE TIER OPTIMIZATION

### Free Tier Protection Strategy

**Autosleep & Cold-Start Mitigation:**

```typescript
// Cloudflare Worker: Keep-alive pings for free-tier backends
export async function keepAliveWarmup(env: Env): Promise<void> {
  // Ping Supabase every 10 minutes (prevents connection pool timeout)
  await fetch(env.SUPABASE_URL + '/rest/v1/users?limit=1', {
    headers: { 'apikey': env.SUPABASE_ANON_KEY }
  });

  // Ping self (Cloudflare Worker) to keep worker warm
  await fetch('https://api.farelens.app/v1/health');
}

// Cron trigger: Every 10 minutes
addEventListener('scheduled', (event) => {
  event.waitUntil(keepAliveWarmup(env));
});
```

**Rate Limiting (Protect Free Tiers):**

```typescript
// Per-IP rate limiting (prevents abuse)
const RATE_LIMITS = {
  search: { requests: 10, window: 60_000 }, // 10 searches/min per IP
  watchlist: { requests: 5, window: 60_000 }, // 5 creates/min per IP
  global: { requests: 100, window: 60_000 }  // 100 total/min per IP
};

export async function rateLimitCheck(
  ip: string,
  endpoint: string,
  env: Env
): Promise<boolean> {
  // Use Durable Objects for rate limiting
  const rateLimiterId = env.RATE_LIMITER.idFromName(`ratelimit:${ip}:${endpoint}`);
  const rateLimiter = env.RATE_LIMITER.get(rateLimiterId);

  const allowed = await rateLimiter.checkLimit({
    limit: RATE_LIMITS[endpoint]?.requests || RATE_LIMITS.global.requests,
    window: RATE_LIMITS[endpoint]?.window || RATE_LIMITS.global.window
  });

  return allowed;
}
```

**Cold Start Warm-Up (First Request):**

```typescript
// On first request after cold start, warm up critical paths
let isWarmedUp = false;

export async function warmUpOnFirstRequest(env: Env): Promise<void> {
  if (isWarmedUp) return;

  // Warm up database connection pool
  await env.DB.prepare('SELECT 1').first();

  // Warm up KV cache (read a test key)
  await env.CACHE.get('warmup:ping');

  // Pre-load hot cache keys (popular routes)
  await env.CACHE.get('deals:popular');

  isWarmedUp = true;
}
```

---

## COST PROJECTIONS

### MVP (0-1k Users) — $0/Month

**Cloudflare Workers:**
- Free tier: 100k requests/day
- Expected usage: 1k users × 10 req/day = 10k req/day
- Cost: **$0**

**Supabase:**
- Free tier: 500MB DB, 2GB bandwidth/month
- Expected usage: ~10MB DB (1k users, 2k deals)
- Cost: **$0**

**Cloudflare KV + Durable Objects:**
- Included free with Workers
- Expected usage: ~6.3K reads/day, ~360 writes/day
- Cost: **$0**

**Amadeus:**
- Free tier: 2k calls/month
- Expected usage: ~1.5k calls/month (with 70% cache hit rate)
- Cost: **$0**

**Total MVP Cost: $0/month**

---

### Growth (1k-10k Users) — $30/Month

**Cloudflare Workers Paid:**
- Paid plan: $5/month (10M requests/month included)
- Includes: KV, Durable Objects, Cron Triggers
- Expected usage: 10k users × 10 req/day = 100k req/day = 3M req/month
- Cost: **$5/month**

**Supabase:**
- Pro plan: $25/month (8GB DB, 50GB bandwidth)
- Expected usage: ~50MB DB (10k users, 20k deals), ~5GB bandwidth
- Cost: **$25/month**

**Amadeus:**
- Free tier: 2k calls/month (still sufficient with aggressive caching)
- Cost: **$0**

**Total Growth Cost: $30/month**

---

### Scale (10k-100k Users) — $275/Month

**Cloudflare Workers:**
- Paid plan: $5/month base + usage overage
- Expected usage: 100k users × 10 req/day = 1M req/day = 30M req/month
- Cost: **$25/month** ($5 base + $20 overage)
- **Includes:** KV, Durable Objects (no additional cost)

**Supabase:**
- Team plan: $500/month (50GB DB, 250GB bandwidth)
- Expected usage: ~500MB DB (100k users, 100k deals), ~50GB bandwidth
- **Alternative:** Migrate to self-hosted Postgres (Fly.io, $50/month)
- Cost: **$50/month** (self-hosted)

**Amadeus:**
- Production tier: $200/month (10k calls/month)
- Expected usage: ~8k calls/month (with caching)
- Cost: **$200/month**

**APNs:** Free (Apple's push notification service)

**Total Scale Cost: $275/month** (Cloudflare $25 + Supabase $50 + Amadeus $200)

---

### When to Upgrade (Revenue Thresholds)

**Cloudflare Workers ($5/mo):**
- Upgrade when: MAU exceeds 5k (50k req/day)
- Revenue needed: $0 (affordable from day 1 if needed)

**Supabase Pro ($25/mo):**
- Upgrade when: DB exceeds 400MB (~8k MAU) OR bandwidth exceeds 1.5GB
- Revenue needed: ~5 Pro subscribers ($25/month)

**Amadeus Production ($200/mo):**
- Upgrade when: Free tier quota consistently exceeded (>1.8k calls/month)
- Revenue needed: ~40 Pro subscribers ($200/month)
- **Decision Point:** 10k MAU, 8% Pro conversion = 800 Pro subs = $4k/month revenue → Amadeus cost is justified

---

## API RESPONSE EXAMPLES (FULL JSON)

### Flight Search Response

```json
{
  "search_id": "search_abc123",
  "results": [
    {
      "id": "deal_xyz789",
      "route": {
        "origin": {
          "iata": "LAX",
          "city": "Los Angeles",
          "airport": "Los Angeles International",
          "country": "USA"
        },
        "destination": {
          "iata": "NRT",
          "city": "Tokyo",
          "airport": "Narita International",
          "country": "Japan"
        }
      },
      "outbound": {
        "departure": "2025-12-15T11:00:00-08:00",
        "arrival": "2025-12-16T15:30:00+09:00",
        "duration_minutes": 630,
        "stops": 0,
        "segments": [
          {
            "airline": {
              "iata": "UA",
              "name": "United Airlines",
              "logo_url": "https://images.farelens.app/airlines/UA.png"
            },
            "flight_number": "UA9954",
            "aircraft": "Boeing 787-9 Dreamliner",
            "departure": {
              "airport": "LAX",
              "terminal": "7",
              "time": "2025-12-15T11:00:00-08:00"
            },
            "arrival": {
              "airport": "NRT",
              "terminal": "1",
              "time": "2025-12-16T15:30:00+09:00"
            }
          }
        ]
      },
      "inbound": {
        "departure": "2025-12-22T16:00:00+09:00",
        "arrival": "2025-12-22T09:30:00-08:00",
        "duration_minutes": 570,
        "stops": 0,
        "segments": [
          {
            "airline": {
              "iata": "UA",
              "name": "United Airlines",
              "logo_url": "https://images.farelens.app/airlines/UA.png"
            },
            "flight_number": "UA9955",
            "aircraft": "Boeing 787-9 Dreamliner",
            "departure": {
              "airport": "NRT",
              "terminal": "1",
              "time": "2025-12-22T16:00:00+09:00"
            },
            "arrival": {
              "airport": "LAX",
              "terminal": "7",
              "time": "2025-12-22T09:30:00-08:00"
            }
          }
        ]
      },
      "pricing": {
        "total": 650.00,
        "currency": "USD",
        "base_fare": 550.00,
        "taxes": 100.00,
        "cabin": "economy",
        "fare_type": "main_cabin",
        "fare_rules": {
          "refundable": false,
          "changeable": true,
          "change_fee": 200.00
        },
        "baggage": {
          "carry_on": {
            "included": true,
            "quantity": 1,
            "weight_kg": 10
          },
          "checked": {
            "included": true,
            "quantity": 1,
            "weight_kg": 23
          }
        }
      },
      "deal_score": {
        "value": 94,
        "label": "Exceptional",
        "savings_percent": 35,
        "explanation": [
          "24% below 90-day average ($850)",
          "Lowest price in 6 months",
          "Nonstop flight (no layovers)",
          "Premium airline (United)"
        ]
      },
      "providers": [
        {
          "name": "United Airlines",
          "type": "airline_direct",
          "price": 650.00,
          "is_lowest": true,
          "is_affiliate": false,
          "booking_url": "https://www.united.com/en/us/fsr/choose-flights?f=LAX&t=NRT&d=2025-12-15&r=2025-12-22&px=1&cmp=0"
        },
        {
          "name": "Aviasales",
          "type": "affiliate",
          "price": 665.00,
          "is_lowest": false,
          "is_affiliate": true,
          "commission_estimate": "1.2%",
          "booking_url": "https://tp.media/r?campaign_id=100&marker=676763&sub_id=ios-fl-deal_xyz789-search-varA-free&u=https%3A%2F%2Faviasales.com%2Fsearch%2FLAXNRT1512NRTLAX2212"
        },
        {
          "name": "Expedia",
          "type": "ota",
          "price": 685.00,
          "is_lowest": false,
          "is_affiliate": false,
          "booking_url": "https://www.expedia.com/Flights-Search?trip=roundtrip&leg1=from:LAX,to:NRT,departure:12/15/2025&leg2=from:NRT,to:LAX,departure:12/22/2025&passengers=adults:1"
        }
      ],
      "image_url": "https://images.farelens.app/destinations/tokyo.jpg",
      "expires_at": "2025-10-06T18:00:00Z"
    }
  ],
  "meta": {
    "total_results": 15,
    "search_time_ms": 245,
    "cached": false,
    "cached_at": null,
    "provider": "amadeus"
  }
}
```

---

## DEPLOYMENT STRATEGY

### Cloudflare Workers Deployment

**Development:**
```bash
# Install Wrangler CLI
npm install -g wrangler

# Login to Cloudflare
wrangler login

# Deploy to dev environment
wrangler deploy --env dev
```

**Production:**
```bash
# Deploy to production (requires manual approval)
wrangler deploy --env production
```

**Secrets Management:**
```bash
# Set secrets (API keys, JWT keys)
wrangler secret put AMADEUS_API_KEY
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_JWT_PUBLIC_KEY
wrangler secret put TRAVELPAYOUTS_TOKEN
wrangler secret put SERPAPI_KEY
```

---

### Supabase Database Migrations

**Migration Files:**
```sql
-- migrations/001_initial_schema.sql
CREATE TABLE users (...);
CREATE TABLE watchlists (...);
CREATE TABLE deals (...);
-- etc.

-- migrations/002_add_price_history.sql
CREATE TABLE price_history (...);
```

**Run Migrations:**
```bash
# Supabase CLI
supabase db push

# Or via Supabase Dashboard (SQL Editor)
```

---

## TECHNICAL RISKS & MITIGATION

### Risk 1: Amadeus Quota Exceeded (HIGH likelihood, HIGH impact)

**Mitigation:**
- Aggressive caching (5-min TTL, 70% hit rate target)
- Fallback to Travelpayouts (free, unlimited)
- User rate limiting (Free: 3/min, Pro: 10/min)
- Quota monitoring (Slack alerts at 90%)
- Paid tier migration plan (at 40 Pro subs = $200/mo revenue)

---

### Risk 2: Cloudflare Workers Free Tier Exceeded (MEDIUM likelihood, MEDIUM impact)

**Mitigation:**
- Upgrade to Paid plan ($5/mo) when MAU exceeds 5k
- Monitor request count daily (Cloudflare dashboard)
- Set billing alerts (auto-upgrade if approaching limit)

---

### Risk 3: Supabase Real-time Connection Limit (200 concurrent) (LOW likelihood, MEDIUM impact)

**Mitigation:**
- Real-time is optional (iOS polls every 5 min as fallback)
- Connection pooling (share connections across users)
- Upgrade to Pro plan ($25/mo) when needed (500 concurrent)

---

### Risk 4: Affiliate Conversion Tracking Failure (MEDIUM likelihood, HIGH impact)

**Mitigation:**
- Server-side click logging (every affiliate click logged in DB)
- Webhook validation (Travelpayouts sends commission webhooks)
- Monthly reconciliation (cross-check dashboard vs logs)
- User surveys ("Did you complete booking?")

---

### Risk 5: APNs Push Notification Delivery Failure (MEDIUM likelihood, MEDIUM impact)

**Mitigation:**
- Retry logic (exponential backoff: 1s, 5s, 30s)
- Fallback to email digest (2x/day for Free tier)
- Silent push for exceptional deals (bypass quiet hours)
- Monitor delivery rate (target: ≥95%)

---

## SUMMARY

**1. Tech Stack Decisions:**
- **Platform:** Cloudflare Workers (serverless edge, global deployment)
- **Database:** Supabase Postgres (free tier → Pro $25/mo, real-time pub/sub, auth)
- **Cache & State:** Cloudflare KV (caching, 5-min TTL) + Durable Objects (rate limiting, quota tracking)
- **Primary API:** Amadeus Self-Service (2k calls/month free → $200/mo paid)
- **Fallback APIs:** Travelpayouts (free, affiliate-only), SerpAPI ($50/mo, Pro only)

**2. Key API Endpoints:**
- Authentication: 3 endpoints (signup, login, refresh)
- Flight Search: 3 endpoints (search, feed, detail)
- Watchlists: 5 endpoints (CRUD + manual check)
- Alerts: 3 endpoints (register, preferences, history)
- Deal Intelligence: 2 endpoints (score, history)
- Affiliate: 2 endpoints (click, providers)
- Subscription: 2 endpoints (validate, status)
- **Total: 20 endpoints**

**3. Amadeus Quota Mitigation:**
- **Tier 1:** Aggressive caching (5-min TTL, 70% hit rate) → Reduces calls by 80%
- **Tier 2:** Fallback APIs (Travelpayouts free, SerpAPI $50/mo)
- **Tier 3:** User rate limiting (Free: 3/min, Pro: 10/min)
- **Tier 4:** Smart scheduling (Pro users priority, skip unchanged prices)
- **Expected:** 426 calls/day (under 2,000/month budget)

**4. Alternative Flight API Recommendations:**

| API | Cost | Use Case | Recommendation |
|-----|------|----------|----------------|
| **Travelpayouts** | Free (affiliate) | Fallback when Amadeus quota exceeded | **Primary fallback** |
| **SerpAPI** | $50/mo (5k searches) | Pro users only, high-quality Google Flights data | **Secondary fallback** |
| **Skyscanner** | Affiliate (commission) | Requires approval, excellent coverage | **Requires approval** |
| **Kiwi.com Tequila** | Invitation-only | Direct booking API, Phase 2 | **Phase 2** |
| **Duffel** | $99/mo + $5/order | Direct booking, NDC airlines | **Phase 3** |

**5. Cost Projections:**

| Stage | Users | Monthly Cost | Revenue Needed |
|-------|-------|-------------|----------------|
| **MVP** | 0-1k | **$0** | $0 (all free tiers) |
| **Growth** | 1k-10k | **$30** | ~6 Pro subs ($30/mo) |
| **Scale** | 10k-100k | **$275** | ~55 Pro subs ($275/mo) |

**When to upgrade:**
- Cloudflare Workers Paid ($5/mo): At 5k MAU (includes KV + Durable Objects)
- Supabase Pro ($25/mo): At 8k MAU or 400MB DB
- Amadeus Production ($200/mo): At 40 Pro subs ($200/mo revenue)

**6. Technical Risks:**

**Critical Risk:** Amadeus quota exceeded
- **Mitigation:** Aggressive caching (80% reduction) + Travelpayouts fallback (free, unlimited)
- **Monitoring:** Slack alert at 90% quota, throttle background jobs at 95%
- **Paid migration:** At 40 Pro subs ($200/mo revenue = Amadeus cost covered)

**Secondary Risk:** Cloudflare Workers free tier exceeded
- **Mitigation:** Upgrade to Paid plan ($5/mo) at 5k MAU (affordable, low risk)

**Concern:** Affiliate conversion tracking opacity (30-day cookies)
- **Mitigation:** Server-side click logging + webhook reconciliation + monthly audits

---

## NEXT STEPS

**Backend architect ready to implement:**
1. Cloudflare Workers API (20 endpoints defined)
2. Supabase Postgres schema (7 tables, RLS policies)
3. Amadeus integration + fallback strategy
4. Background jobs (Cron triggers)
5. Real-time pub/sub (Supabase)

**Waiting for:**
- iOS architect: Confirm API contracts match iOS data models
- Product manager: Approve alternative API strategy (Travelpayouts fallback)
- Legal: Review affiliate disclosure, privacy policy

**Ready to debate:**
- iOS architect: API response formats (too much data? need more fields?)
- Product manager: Free tier limits (too restrictive? 3 searches/min OK?)
- Platform engineer: Deployment strategy (Cloudflare Workers best choice?)

**Will NOT ask user for:**
- Technical implementation details (I'm the expert)
- Database schema choices (Postgres + Redis decided)
- Caching strategy (5-min TTL locked in)

**Let's build a backend that costs $0 until revenue justifies infrastructure investment.**

---

**End of API Architecture Document**
