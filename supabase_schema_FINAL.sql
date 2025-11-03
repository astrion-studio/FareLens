-- FareLens Supabase Database Schema - FINAL VERSION
-- Validated: All IMMUTABLE issues resolved
-- Run this in Supabase SQL Editor after project creation

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    subscription_tier TEXT NOT NULL DEFAULT 'free' CHECK (subscription_tier IN ('free', 'pro')),
    timezone TEXT NOT NULL DEFAULT 'America/Los_Angeles',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    trial_ends_at TIMESTAMP WITH TIME ZONE,
    subscription_started_at TIMESTAMP WITH TIME ZONE,
    subscription_cancelled_at TIMESTAMP WITH TIME ZONE,
    alert_enabled BOOLEAN NOT NULL DEFAULT true,
    quiet_hours_enabled BOOLEAN NOT NULL DEFAULT true,
    quiet_hours_start INTEGER NOT NULL DEFAULT 22 CHECK (quiet_hours_start >= 0 AND quiet_hours_start < 24),
    quiet_hours_end INTEGER NOT NULL DEFAULT 7 CHECK (quiet_hours_end >= 0 AND quiet_hours_end < 24),
    watchlist_only_mode BOOLEAN NOT NULL DEFAULT false,
    preferred_airports JSONB NOT NULL DEFAULT '[]'::jsonb,
    CONSTRAINT users_preferred_airports_valid CHECK (jsonb_typeof(preferred_airports) = 'array')
);

CREATE TABLE public.watchlists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    date_range_start TIMESTAMP WITH TIME ZONE,
    date_range_end TIMESTAMP WITH TIME ZONE,
    max_price NUMERIC(10, 2),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT watchlists_dates_valid CHECK (date_range_start IS NULL OR date_range_end IS NULL OR date_range_start <= date_range_end),
    CONSTRAINT watchlists_price_positive CHECK (max_price IS NULL OR max_price > 0)
);

CREATE TABLE public.flight_deals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    origin TEXT NOT NULL,
    destination TEXT NOT NULL,
    departure_date TIMESTAMP WITH TIME ZONE NOT NULL,
    return_date TIMESTAMP WITH TIME ZONE NOT NULL,
    total_price NUMERIC(10, 2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    deal_score INTEGER NOT NULL CHECK (deal_score >= 0 AND deal_score <= 100),
    discount_percent INTEGER NOT NULL CHECK (discount_percent >= 0 AND discount_percent <= 100),
    normal_price NUMERIC(10, 2) NOT NULL,
    airline TEXT NOT NULL,
    stops INTEGER NOT NULL DEFAULT 0 CHECK (stops >= 0),
    return_stops INTEGER CHECK (return_stops IS NULL OR return_stops >= 0),
    deep_link TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT flight_deals_dates_valid CHECK (departure_date <= return_date),
    CONSTRAINT flight_deals_prices_valid CHECK (total_price > 0 AND normal_price > 0)
);

CREATE TABLE public.alert_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    deal_id UUID NOT NULL REFERENCES public.flight_deals(id) ON DELETE CASCADE,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    opened_at TIMESTAMP WITH TIME ZONE,
    clicked_through BOOLEAN,
    expires_at TIMESTAMP WITH TIME ZONE,
    placement TEXT,
    queue_score NUMERIC(10, 2)
);

CREATE TABLE public.device_registrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL,
    apns_token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT device_registrations_unique_device UNIQUE (user_id, device_id)
);

CREATE TABLE public.saved_deals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    deal_id UUID NOT NULL REFERENCES public.flight_deals(id) ON DELETE CASCADE,
    saved_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    notes TEXT,
    CONSTRAINT saved_deals_unique_user_deal UNIQUE (user_id, deal_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_users_subscription_tier ON public.users(subscription_tier);
CREATE INDEX idx_users_email ON public.users(email);

CREATE INDEX idx_watchlists_user_id ON public.watchlists(user_id);
CREATE INDEX idx_watchlists_active ON public.watchlists(user_id, is_active) WHERE is_active = true;
CREATE INDEX idx_watchlists_origin_destination ON public.watchlists(origin, destination);

CREATE INDEX idx_flight_deals_route ON public.flight_deals(origin, destination);
CREATE INDEX idx_flight_deals_departure_date ON public.flight_deals(departure_date);
CREATE INDEX idx_flight_deals_deal_score ON public.flight_deals(deal_score DESC);
CREATE INDEX idx_flight_deals_expires_at ON public.flight_deals(expires_at);
CREATE INDEX idx_flight_deals_created_at ON public.flight_deals(created_at DESC);

CREATE INDEX idx_alert_history_user_id ON public.alert_history(user_id);
CREATE INDEX idx_alert_history_deal_id ON public.alert_history(deal_id);
CREATE INDEX idx_alert_history_sent_at ON public.alert_history(sent_at DESC);
CREATE INDEX idx_alert_history_user_sent_at ON public.alert_history(user_id, sent_at DESC);
-- Note: Deduplication will be handled in application code via queries using WHERE clause
-- No functional index needed - the above indexes are sufficient for performance

CREATE INDEX idx_device_registrations_user_id ON public.device_registrations(user_id);
CREATE INDEX idx_device_registrations_last_active ON public.device_registrations(last_active_at);

CREATE INDEX idx_saved_deals_user_id ON public.saved_deals(user_id);
CREATE INDEX idx_saved_deals_saved_at ON public.saved_deals(user_id, saved_at DESC);

-- ============================================================================
-- ROW-LEVEL SECURITY
-- ============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.watchlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flight_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alert_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saved_deals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own data" ON public.users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own data" ON public.users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view their own watchlists" ON public.watchlists FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create their own watchlists" ON public.watchlists FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own watchlists" ON public.watchlists FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own watchlists" ON public.watchlists FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view flight deals" ON public.flight_deals FOR SELECT TO authenticated USING (true);
CREATE POLICY "Service role can insert deals" ON public.flight_deals FOR INSERT TO service_role WITH CHECK (true);
CREATE POLICY "Service role can update deals" ON public.flight_deals FOR UPDATE TO service_role USING (true);

CREATE POLICY "Users can view their own alert history" ON public.alert_history FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Service role can insert alert history" ON public.alert_history FOR INSERT TO service_role WITH CHECK (true);
CREATE POLICY "Users can update their own alert interactions" ON public.alert_history FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own devices" ON public.device_registrations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can register their own devices" ON public.device_registrations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own devices" ON public.device_registrations FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own devices" ON public.device_registrations FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own saved deals" ON public.saved_deals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can save deals" ON public.saved_deals FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own saved deals" ON public.saved_deals FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own saved deals" ON public.saved_deals FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.users (id, email) VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_watchlists_updated_at BEFORE UPDATE ON public.watchlists FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_device_registrations_updated_at BEFORE UPDATE ON public.device_registrations FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.enforce_watchlist_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    active_watchlist_count INTEGER;
    user_tier TEXT;
BEGIN
    SELECT subscription_tier INTO user_tier FROM public.users WHERE id = NEW.user_id;

    -- Count existing active watchlists, excluding the current row if it's an UPDATE
    IF TG_OP = 'UPDATE' THEN
        SELECT COUNT(*) INTO active_watchlist_count
        FROM public.watchlists
        WHERE user_id = NEW.user_id
        AND is_active = true
        AND id != NEW.id;
    ELSE
        SELECT COUNT(*) INTO active_watchlist_count
        FROM public.watchlists
        WHERE user_id = NEW.user_id
        AND is_active = true;
    END IF;

    -- Only enforce limit if the new/updated watchlist is active
    IF NEW.is_active = true AND user_tier = 'free' AND active_watchlist_count >= 5 THEN
        RAISE EXCEPTION 'Free tier allows maximum 5 active watchlists. Upgrade to Pro for unlimited.'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER check_watchlist_limit BEFORE INSERT OR UPDATE ON public.watchlists FOR EACH ROW EXECUTE FUNCTION public.enforce_watchlist_limit();

CREATE OR REPLACE FUNCTION public.cleanup_expired_deals()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.flight_deals WHERE expires_at < NOW() - INTERVAL '7 days';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

-- ============================================================================
-- GRANTS
-- ============================================================================
-- IMPORTANT: These GRANTs are SAFE because Row Level Security (RLS) is enabled
-- on all tables (see lines 139-144) with 20 policies (lines 146-170).
--
-- GRANTs give permission to ATTEMPT operations, but RLS policies determine
-- what data can be accessed. With RLS enabled:
-- - Users can only see/modify their own data (enforced by auth.uid() = user_id)
-- - Extracting the anon key does NOT bypass RLS policies
-- - RLS policies are evaluated on the server side for every query
--
-- This is the recommended Supabase security model. Without these GRANTs,
-- authenticated users couldn't perform any operations, even on their own data.

GRANT SELECT, UPDATE ON public.users TO authenticated;
GRANT ALL ON public.watchlists TO authenticated;
GRANT SELECT ON public.flight_deals TO authenticated;
GRANT ALL ON public.alert_history TO authenticated;
GRANT ALL ON public.device_registrations TO authenticated;
GRANT ALL ON public.saved_deals TO authenticated;

GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
