# FareLens Quick Start Guide

**Goal:** Get the app running on your iPhone and set up the backend in the simplest way possible.

**Time Required:**
- iPhone setup: 30 minutes
- Backend setup: 2-3 hours (Supabase approach)

---

## PART 1: Get App Running on Your iPhone (30 Minutes)

### Prerequisites
- Mac with Xcode 16+ installed
- iPhone running iOS 26
- USB cable
- Apple ID (free account works)

### Step 1: Open the Project (5 minutes)

```bash
# Navigate to project
cd /Users/Parvez/Projects/FareLens

# The Xcode project needs to be recreated (it's currently broken)
# We'll do this manually in Xcode
```

**In Xcode:**
1. Open Xcode
2. File → New → Project
3. Choose "iOS" → "App"
4. Click "Next"

**Configure Project:**
- Product Name: `FareLens`
- Team: Select your Apple ID
- Organization Identifier: `com.astrionstudio.farelens` (or your own)
- Interface: **SwiftUI**
- Language: **Swift**
- Storage: **None** (we handle persistence manually)
- Include Tests: **YES**

5. Click "Next"
6. Save location: `/Users/Parvez/Projects/FareLens/ios-app/`
7. **UNCHECK** "Create Git repository" (we already have one)
8. Click "Create"

### Step 2: Add All Swift Files to Project (10 minutes)

**In Xcode Project Navigator:**

1. **Delete** the default files:
   - Right-click `ContentView.swift` (the default one) → Delete → Move to Trash
   - Right-click `FareLensApp.swift` (the default one) → Delete → Move to Trash

2. **Add existing files:**
   - Right-click `FareLens` (blue folder icon)
   - Choose "Add Files to FareLens..."
   - Navigate to `/Users/Parvez/Projects/FareLens/ios-app/FareLens/`
   - Select ALL folders: `App`, `Features`, `Core`, `Data`, `DesignSystem`, `Resources`
   - Check **"Create groups"** (NOT "Create folder references")
   - Check **"Copy items if needed"** is UNCHECKED (files already in right location)
   - Target: Check **FareLens** (app target)
   - Click "Add"

3. **Add test files:**
   - Right-click `FareLensTests` (test target)
   - Choose "Add Files to FareLens..."
   - Navigate to `/Users/Parvez/Projects/FareLens/ios-app/FareLensTests/`
   - Select all `.swift` test files
   - Target: Check **FareLensTests** ONLY (not the app target)
   - Click "Add"

### Step 3: Configure Project Settings (5 minutes)

**Select FareLens target → General tab:**

1. **Deployment Target:** iOS 26.0
2. **iPhone Orientation:** Portrait only (uncheck Landscape)
3. **Display Name:** FareLens

**Signing & Capabilities tab:**

1. Check **"Automatically manage signing"**
2. Select your **Team** (your Apple ID)
3. Xcode will create a provisioning profile automatically

**Add Capabilities (click "+ Capability"):**
4. Add "Push Notifications"
5. Add "Background Modes":
   - Check "Remote notifications"
   - Check "Background fetch"

### Step 4: Fix Build Errors (If Any) (5 minutes)

**Try building:**
- Press Cmd+B (Build)
- If you see errors, common fixes:

**Error: "Cannot find type 'FareLensApp' in scope"**
- Fix: Make sure `App/FareLensApp.swift` is added to the target

**Error: "Module 'X' not found"**
- Fix: All files should be added to the project

**Error: "Duplicate symbol"**
- Fix: Make sure test files are ONLY in FareLensTests target, not app target

### Step 5: Run on Your iPhone (5 minutes)

1. **Connect iPhone via USB**
2. **Trust your Mac:**
   - On iPhone, a popup appears: "Trust This Computer?"
   - Tap "Trust"
   - Enter iPhone passcode

3. **Select your iPhone:**
   - In Xcode toolbar, click the device dropdown (next to "FareLens")
   - Select your iPhone from the list (not "Any iOS Device")

4. **Run the app:**
   - Click the Play button ▶️ (or press Cmd+R)
   - First time: Build will take 1-2 minutes
   - Xcode will install app on your phone

5. **Trust the developer certificate (first time only):**
   - On iPhone: Settings → General → VPN & Device Management
   - Tap your Apple ID email
   - Tap "Trust [Your Name]"
   - Tap "Trust" again to confirm

6. **Open the app:**
   - App icon will appear on home screen
   - Tap to launch

### Step 6: What to Expect

**What Works:**
- ✅ App launches (no crashes)
- ✅ Onboarding screens (Welcome, Benefits, Auth)
- ✅ Tab navigation (Deals, Watchlists, Alerts, Settings)
- ✅ UI components (buttons, cards, typography)
- ✅ Design system (colors, spacing, animations)

**What Doesn't Work Yet (Expected):**
- ❌ Sign In / Sign Up (backend not connected)
- ❌ Deals list (no real data - backend needed)
- ❌ Watchlists (backend needed)
- ❌ Alerts history (backend needed)
- ❌ Push notifications (APNs certificates needed)

**This is normal!** The iOS app is complete but needs the backend. Let's set that up next.

---

## PART 2: Backend Setup - Supabase Approach (2-3 Hours)

**Why Supabase instead of the FastAPI backend you see in the /backend folder?**

The FastAPI backend has 32 critical issues including:
- No authentication (anyone can access any data)
- Security vulnerabilities (CORS wide open, SQL injection risk)
- No database migrations (tables don't exist)
- 5 weeks to fix vs 1-2 weeks with Supabase

**Supabase gives you:**
- ✅ Authentication: Built-in, zero code
- ✅ Authorization: Row-Level Security policies
- ✅ Database: Postgres with migrations
- ✅ Realtime: Live updates (WebSockets)
- ✅ Edge Functions: Serverless API endpoints
- ✅ Free tier: $0 until 50,000 users

**Let's get started:**

### Step 1: Create Supabase Project (15 minutes)

1. **Go to:** https://supabase.com
2. **Click** "Start your project"
3. **Sign up** with GitHub (recommended) or email
4. **Create organization:**
   - Name: "Astrion Studio" (or your name)
   - Plan: Free ($0/month)
5. **Create project:**
   - Name: `farelens`
   - Database Password: **Generate strong password** (save it!)
   - Region: Choose closest to you (e.g., `us-west-1`)
   - Pricing Plan: Free
6. **Wait** 2-3 minutes for project to initialize

**Save these values (you'll need them):**
- Project URL: `https://[your-project-ref].supabase.co`
- `anon` public key: (Found in Settings → API)
- `service_role` secret key: (Found in Settings → API)

### Step 2: Create Database Schema (30 minutes)

**In Supabase Dashboard:**

1. Go to "SQL Editor" (left sidebar)
2. Click "New query"
3. Paste this complete schema:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (managed by Supabase Auth, we extend it)
CREATE TABLE public.users (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  subscription_tier TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'pro')),
  trial_ends_at TIMESTAMPTZ,
  timezone TEXT NOT NULL DEFAULT 'America/Los_Angeles',
  preferred_currency TEXT NOT NULL DEFAULT 'USD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Watchlists table
CREATE TABLE public.watchlists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  origin TEXT, -- IATA code or NULL for "any"
  destination TEXT, -- IATA code or NULL for "any"
  max_price_cents INTEGER,
  departure_start_date DATE,
  departure_end_date DATE,
  return_start_date DATE,
  return_end_date DATE,
  min_score INTEGER DEFAULT 70,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Preferred airports table
CREATE TABLE public.preferred_airports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  iata TEXT NOT NULL, -- 3-letter IATA code
  weight NUMERIC(3,2) NOT NULL DEFAULT 1.0 CHECK (weight >= 0.0 AND weight <= 1.0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, iata)
);

-- Alert preferences table
CREATE TABLE public.alert_preferences (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  quiet_hours_start TIME, -- e.g., '22:00'
  quiet_hours_end TIME,   -- e.g., '07:00'
  watchlist_only BOOLEAN NOT NULL DEFAULT FALSE, -- Only alert on watchlist matches
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Alert history table
CREATE TABLE public.alert_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  deal_id UUID NOT NULL, -- Reference to deal (deals are ephemeral, not stored)
  origin TEXT NOT NULL,
  destination TEXT NOT NULL,
  departure_date DATE NOT NULL,
  return_date DATE,
  price_cents INTEGER NOT NULL,
  deal_score INTEGER NOT NULL,
  clicked_through BOOLEAN NOT NULL DEFAULT FALSE,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Saved deals table
CREATE TABLE public.saved_deals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  deal_id UUID NOT NULL,
  origin TEXT NOT NULL,
  destination TEXT NOT NULL,
  departure_date DATE NOT NULL,
  return_date DATE,
  price_cents INTEGER NOT NULL,
  deal_score INTEGER NOT NULL,
  saved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, deal_id)
);

-- Indexes for performance
CREATE INDEX idx_watchlists_user_id ON public.watchlists(user_id);
CREATE INDEX idx_watchlists_active ON public.watchlists(user_id, is_active);
CREATE INDEX idx_alert_history_user_id ON public.alert_history(user_id);
CREATE INDEX idx_alert_history_sent_at ON public.alert_history(sent_at);
CREATE INDEX idx_saved_deals_user_id ON public.saved_deals(user_id);
CREATE INDEX idx_preferred_airports_user_id ON public.preferred_airports(user_id);

-- Enable Row-Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preferred_airports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alert_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alert_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_deals ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access their own data

-- Users policies
CREATE POLICY "Users can view own profile" ON public.users
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- Watchlists policies
CREATE POLICY "Users can view own watchlists" ON public.watchlists
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own watchlists" ON public.watchlists
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own watchlists" ON public.watchlists
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own watchlists" ON public.watchlists
  FOR DELETE USING (auth.uid() = user_id);

-- Preferred airports policies
CREATE POLICY "Users can view own preferred airports" ON public.preferred_airports
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own preferred airports" ON public.preferred_airports
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own preferred airports" ON public.preferred_airports
  FOR DELETE USING (auth.uid() = user_id);

-- Alert preferences policies
CREATE POLICY "Users can view own alert preferences" ON public.alert_preferences
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own alert preferences" ON public.alert_preferences
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own alert preferences" ON public.alert_preferences
  FOR UPDATE USING (auth.uid() = user_id);

-- Alert history policies
CREATE POLICY "Users can view own alert history" ON public.alert_history
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own alert history" ON public.alert_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own alert history" ON public.alert_history
  FOR UPDATE USING (auth.uid() = user_id);

-- Saved deals policies
CREATE POLICY "Users can view own saved deals" ON public.saved_deals
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own saved deals" ON public.saved_deals
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own saved deals" ON public.saved_deals
  FOR DELETE USING (auth.uid() = user_id);

-- Function to automatically create user profile after auth signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, subscription_tier, trial_ends_at, timezone)
  VALUES (
    NEW.id,
    NEW.email,
    'free',
    NOW() + INTERVAL '14 days',
    'America/Los_Angeles'
  );

  -- Create default alert preferences
  INSERT INTO public.alert_preferences (user_id, enabled, quiet_hours_start, quiet_hours_end)
  VALUES (NEW.id, true, '22:00', '07:00');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to run handle_new_user on auth.users insert
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

4. **Click "Run" (or press Cmd+Enter)**
5. **Verify:** You should see "Success. No rows returned" (this is correct)

**Check tables were created:**
- Go to "Table Editor" (left sidebar)
- You should see: `users`, `watchlists`, `preferred_airports`, `alert_preferences`, `alert_history`, `saved_deals`

### Step 3: Enable Authentication (10 minutes)

**In Supabase Dashboard:**

1. Go to "Authentication" → "Providers" (left sidebar)
2. **Email provider:**
   - Toggle "Enable Email provider" ON
   - Check "Confirm email" ON (for production safety)
   - Check "Secure email change" ON
   - Save
3. **Apple provider** (recommended for iOS apps):
   - Toggle "Enable Sign in with Apple" ON
   - You'll need Apple developer account for this
   - For now, leave it OFF (we'll add later)

### Step 4: Configure iOS App to Use Supabase (45 minutes)

**Install Supabase Swift SDK:**

1. In Xcode, select your project (`FareLens` blue icon at top)
2. Select `FareLens` target
3. Go to "Package Dependencies" tab
4. Click "+" button
5. Enter URL: `https://github.com/supabase/supabase-swift`
6. Version: "Up to Next Major" → 2.0.0
7. Click "Add Package"
8. Check "Supabase" (all modules)
9. Click "Add Package"

**Create Supabase configuration file:**

In Xcode, create new file:
1. Right-click `App` folder → New File → Swift File
2. Name: `SupabaseClient.swift`
3. Target: FareLens

**Paste this code:**

```swift
import Foundation
import Supabase

// MARK: - Supabase Configuration
enum SupabaseConfig {
    static let url = URL(string: "https://YOUR_PROJECT_REF.supabase.co")!
    static let anonKey = "YOUR_ANON_KEY_HERE"
}

// MARK: - Supabase Client Singleton
final class SupabaseClient {
    static let shared = SupabaseClient()

    let client: Supabase.Client

    private init() {
        self.client = Supabase.Client(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
}
```

**Replace placeholders:**
- `YOUR_PROJECT_REF`: From your Supabase project URL
- `YOUR_ANON_KEY_HERE`: From Settings → API → `anon` public key

**Update APIClient to use Supabase:**

Open `/ios-app/FareLens/Data/Networking/APIClient.swift`

Replace the entire file with:

```swift
import Foundation
import Supabase

actor APIClient {
    static let shared = APIClient()

    private let client = SupabaseClient.shared.client

    private init() {}

    // Auth methods
    func signUp(email: String, password: String) async throws -> Session {
        let response = try await client.auth.signUp(
            email: email,
            password: password
        )
        guard let session = response.session else {
            throw APIError.unauthorized
        }
        return session
    }

    func signIn(email: String, password: String) async throws -> Session {
        return try await client.auth.signIn(
            email: email,
            password: password
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func getCurrentSession() async throws -> Session? {
        return try await client.auth.session
    }

    // Deals (using Supabase Edge Functions - we'll create these next)
    func fetchDeals(origin: String?, limit: Int) async throws -> [FlightDeal] {
        // TODO: Implement with Supabase Edge Function
        return []
    }

    // Watchlists (direct Supabase queries)
    func fetchWatchlists() async throws -> [Watchlist] {
        return try await client
            .from("watchlists")
            .select()
            .eq("is_active", value: true)
            .execute()
            .value
    }

    func createWatchlist(_ watchlist: Watchlist) async throws -> Watchlist {
        return try await client
            .from("watchlists")
            .insert(watchlist)
            .select()
            .single()
            .execute()
            .value
    }

    func updateWatchlist(_ watchlist: Watchlist) async throws -> Watchlist {
        return try await client
            .from("watchlists")
            .update(watchlist)
            .eq("id", value: watchlist.id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteWatchlist(id: UUID) async throws {
        try await client
            .from("watchlists")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

enum APIError: Error {
    case unauthorized
    case notFound
    case serverError
    case invalidResponse
}
```

### Step 5: Test Authentication (15 minutes)

**Build and run the app:**

1. Press Cmd+R to run on your iPhone
2. Go through onboarding to the Auth screen
3. **Sign Up:**
   - Email: `your-test-email@example.com`
   - Password: `Test123!` (minimum 6 characters)
   - Tap "Sign Up"
4. **Check Supabase:**
   - Go to Supabase Dashboard → Authentication → Users
   - You should see your new user!
5. **Try signing in:**
   - Sign out from the app (Settings → Sign Out)
   - Sign back in with same email/password
   - Should work!

**If authentication works:** ✅ Backend is functional!

**If you get errors:**
- Check Supabase URL and anon key are correct
- Check internet connection
- Check Supabase project is not paused (free tier pauses after 1 week of inactivity)

### Step 6: What's Next?

**You now have:**
- ✅ iOS app running on iPhone
- ✅ Supabase backend with database
- ✅ Authentication working

**What you still need:**
- ❌ Deals endpoint (Amadeus API integration)
- ❌ Background refresh job (fetch deals every 5 minutes)
- ❌ Push notifications (APNs certificates)
- ❌ Subscription handling (StoreKit 2 validation)

**These will be implemented in PHASE 2 of the MASTER_PLAN** (Weeks 2-4).

For now, you can:
- Test UI flows (navigation, settings)
- Create watchlists (they save to Supabase!)
- Test authentication (sign up, sign in, sign out)

---

## Troubleshooting

### Common Xcode Errors

**Error: "Command PhaseScriptExecution failed"**
- Fix: Clean build folder (Shift+Cmd+K), then rebuild

**Error: "No signing certificate found"**
- Fix: Xcode → Settings → Accounts → Add your Apple ID → Download Manual Profiles

**Error: "Failed to create provisioning profile"**
- Fix: Change Bundle ID to something unique (e.g., `com.yourname.farelens`)

**Error: "Untrusted Developer"**
- Fix: iPhone → Settings → General → VPN & Device Management → Trust your account

### Common Supabase Errors

**Error: "Invalid API key"**
- Fix: Verify you copied the `anon` public key (NOT the service_role secret key)

**Error: "Row Level Security policy violation"**
- Fix: Make sure you're authenticated (logged in) before accessing data

**Error: "relation 'public.users' does not exist"**
- Fix: Re-run the SQL schema from Step 2

**Error: "duplicate key value violates unique constraint"**
- Fix: User already exists with that email, try signing in instead of signing up

---

## Next Steps

Read [MASTER_PLAN.md](MASTER_PLAN.md) for the complete 8-12 week timeline to production.

**Week 1 focus:**
- ✅ iOS app on phone (you just did this!)
- ✅ Backend authentication working (you just did this!)
- Next: Fix CI, consolidate documentation

**Week 2-4 focus:**
- Implement deals endpoint (Amadeus API)
- Complete iOS-backend integration
- Fix all remaining TODOs in iOS app

**Good luck! 🚀**
