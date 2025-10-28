# Supabase + Cloudflare Workers Setup Guide

## Architecture Overview

```
iOS App (Swift)
    ↓ (Supabase Auth SDK)
Supabase Auth (JWT tokens)
    ↓
Cloudflare Workers (API proxy)
    ↓
Supabase Database (PostgreSQL + RLS)
    ↓
Amadeus API (flight data)
```

## Phase 1: Supabase Setup (YOU DO THIS)

### Step 1: Create Supabase Project (5 minutes)

1. Go to [https://supabase.com](https://supabase.com)
2. Sign up / Log in
3. Click "New Project"
4. Fill in:
   - **Name:** `farelens-production`
   - **Database Password:** Generate strong password (save in 1Password)
   - **Region:** Choose closest to your users (e.g., US West)
   - **Pricing Plan:** Free tier (sufficient for 50K users)
5. Wait 2 minutes for project to provision

### Step 2: Get API Keys (2 minutes)

Once project is ready:

1. Go to **Project Settings** → **API**
2. Scroll to **Publishable key** and **Secret keys** sections
3. Copy these values (I need them):
   ```
   Project URL: https://xxxxx.supabase.co
   Publishable key: sb_publishable_xxxxx (this is safe to use in the iOS app)
   Secret key: sb_secret_xxxxx (this is for Cloudflare Workers only, never in iOS app)
   ```

4. **SEND ME THESE 3 VALUES**

**Note:** Supabase now uses `sb_publishable_` and `sb_secret_` prefixes (new format). These are the same as the old `anon` and `service_role` keys, just with clearer naming. The code works identically with both formats.

### Step 3: Enable Email Auth (3 minutes)

1. Go to **Authentication** → **Providers**
2. Enable **Email**:
   - ✅ Enable email provider
   - ✅ Confirm email: **ENABLED** (required for production security)
   - ✅ Secure email change: **ENABLED** (required for production security)
3. Click **Save**

**Note:** Email confirmation is enabled for production readiness. This is the correct approach and will NOT slow down testing significantly.

### Step 4: Create Database Schema (10 minutes)

1. Go to **SQL Editor**
2. Click **New Query**
3. Copy the entire contents of `/supabase_schema_FINAL.sql` (in the project root)
4. Paste into the SQL Editor
5. Click **Run** (bottom right)
6. Wait ~30 seconds for schema creation
7. Verify success: You should see "Success. No rows returned" message
8. **SEND ME CONFIRMATION** that the schema ran successfully

**What this creates:**

- 6 tables: users, watchlists, flight_deals, alert_history, device_registrations, saved_deals
- Row-Level Security (RLS) policies for all tables
- Indexes for performance
- Triggers for auto-creating user profiles and enforcing watchlist limits
- Functions for cleanup and business logic

---

## Phase 2: iOS App Integration (I DO THIS)

### What I'll Do Once You Send Keys:

1. **Install Supabase SDK**
   ```swift
   // Package.swift
   dependencies: [
       .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
   ]
   ```

2. **Configure Supabase Client**
   ```swift
   // Config.swift
   let supabase = SupabaseClient(
       supabaseURL: URL(string: "YOUR_PROJECT_URL")!,
       supabaseKey: "YOUR_ANON_KEY"
   )
   ```

3. **Update AuthService to use Supabase**
   ```swift
   // Real signup
   let response = try await supabase.auth.signUp(
       email: email,
       password: password
   )

   // Real signin
   let response = try await supabase.auth.signIn(
       email: email,
       password: password
   )
   ```

4. **Update APIClient to send JWT tokens**
   ```swift
   let token = try await supabase.auth.session.accessToken
   request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
   ```

---

## Phase 3: Cloudflare Workers Setup (YOU + ME)

### Step 1: Create Cloudflare Account (YOU - 5 minutes)

1. Go to [https://dash.cloudflare.com](https://dash.cloudflare.com)
2. Sign up / Log in
3. No credit card required for free tier

### Step 2: Install Wrangler CLI (YOU - 2 minutes)

```bash
npm install -g wrangler
wrangler login
```

### Step 3: Configure Your Environment (YOU - 5 minutes)

The `cloudflare-workers/wrangler.toml` file contains some hardcoded values that are specific to the original developer's Cloudflare account. You need to update these for your environment:

1. **Get your Cloudflare Account ID:**
   - Go to https://dash.cloudflare.com
   - Select "Workers & Pages" from the left sidebar
   - Your Account ID is displayed on the right side of the overview page
   - Copy this value

2. **Create KV Namespace for caching:**
   ```bash
   cd cloudflare-workers
   wrangler kv:namespace create CACHE
   ```
   - This will output an ID like: `{ binding = "CACHE", id = "your-kv-id-here" }`
   - Copy the ID value

3. **Update `wrangler.toml`:**
   - Replace `account_id` with your Cloudflare Account ID from step 1
   - Replace the KV namespace `id` with your KV ID from step 2

**Important:** These values are environment-specific and different for each developer. If you're deploying to multiple environments (dev, staging, production), you can create a `.dev.vars` file (already in `.gitignore`) to override values locally without modifying the committed `wrangler.toml`.

### Step 4: Create Worker Project (I DO THIS)

I'll create the Cloudflare Worker code that:
- Proxies requests to Supabase
- Validates JWT tokens
- Calls Amadeus API
- Implements rate limiting

---

## What I Need From You (Action Items)

### ✅ NOW - To Unblock Development:

1. **Supabase Project URL** (from Step 2 above)
2. **Supabase anon key** (public, safe to commit)
3. **Supabase service_role key** (secret, for server-side)

### ✅ LATER - For Production:

4. **Amadeus API credentials**
   - Client ID
   - Client Secret
   - Sign up at: https://developers.amadeus.com

5. **Cloudflare account** (free tier)
   - Just need you to create account
   - I'll write the Worker code

6. **Custom domain** (optional for MVP)
   - e.g., api.farelens.app
   - Can use Cloudflare's free *.workers.dev domain initially

---

## Migration Path (How We'll Transition)

### Current State:
```
iOS App → FastAPI (localhost:8000) → Mock data
```

### After Supabase Setup:
```
iOS App → Supabase → Real PostgreSQL database
         ↓
    Supabase Auth (real JWT tokens)
```

### After Cloudflare Setup:
```
iOS App → Cloudflare Workers → Supabase + Amadeus
```

---

## Benefits of This Architecture

### vs Current FastAPI:
- ✅ **No server to maintain** (Cloudflare Workers = serverless)
- ✅ **Auth built-in** (Supabase Auth = production-ready)
- ✅ **Row-Level Security** (database enforces permissions)
- ✅ **Free tier** ($0 until 50K users)
- ✅ **Global edge** (Cloudflare CDN = fast worldwide)
- ✅ **Automatic scaling** (handles traffic spikes)

### vs Continuing with FastAPI:
- ❌ FastAPI requires: Docker, hosting, SSL certs, monitoring
- ❌ Manual JWT implementation (security risk)
- ❌ Manual rate limiting
- ❌ Manual database security
- ❌ Server costs ($20-50/month minimum)

---

## Timeline

| Phase | Duration | Blocker |
|-------|----------|---------|
| **You: Supabase setup** | 20 minutes | Need your action |
| **Me: iOS integration** | 1 hour | Need your keys |
| **Test auth on phone** | 15 minutes | - |
| **You: Cloudflare account** | 5 minutes | When ready for production |
| **Me: Worker code** | 2 hours | After Cloudflare account |
| **Deploy to production** | 30 minutes | - |

**Total: ~4 hours** (vs 5 weeks fixing FastAPI)

---

## Next Steps

### 🚀 START HERE:

1. Create Supabase project (5 min)
2. Send me the 3 values from Step 2
3. I'll integrate and test (1 hour)
4. You test on phone! (15 min)

**Once I have those 3 values, you can test on your phone within 2 hours.**

Ready to proceed?
