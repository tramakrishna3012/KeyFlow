-- ============================================================================
-- KeyFlow Migration 003: Session-Aggregated Recovery & Multi-Device Clipboard
-- Schema version: 3.0
-- ============================================================================

-- Enable pgcrypto / uuid extensions if not already present
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. Table: typing_sessions
-- Stores aggregated paragraph-level typing sessions per app, window & device
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.typing_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    app_name TEXT NOT NULL,
    window_title TEXT,
    content TEXT NOT NULL,
    character_count INTEGER NOT NULL DEFAULT 0,
    word_count INTEGER NOT NULL DEFAULT 0,
    started_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_favorite BOOLEAN NOT NULL DEFAULT false,
    draft_history JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 2. Table: clipboard_entries
-- Stores synchronized multi-device copied snippets, URLs, and code blocks
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clipboard_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL,
    source_app TEXT,
    content TEXT NOT NULL,
    content_type TEXT NOT NULL CHECK (content_type IN ('text', 'url', 'code')),
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 3. Performance Indexes
-- ----------------------------------------------------------------------------
-- Typing Sessions Indexes
CREATE INDEX IF NOT EXISTS idx_typing_sessions_user_id 
    ON public.typing_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_typing_sessions_user_updated 
    ON public.typing_sessions(user_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_typing_sessions_app_name 
    ON public.typing_sessions(user_id, app_name);

CREATE INDEX IF NOT EXISTS idx_typing_sessions_device_name 
    ON public.typing_sessions(user_id, device_name);

CREATE INDEX IF NOT EXISTS idx_typing_sessions_is_favorite 
    ON public.typing_sessions(user_id, is_favorite) 
    WHERE is_favorite = true;

-- Full-text search index for typing sessions content
CREATE INDEX IF NOT EXISTS idx_typing_sessions_content_search 
    ON public.typing_sessions USING gin(to_tsvector('english', content));

-- Clipboard Entries Indexes
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_user_id 
    ON public.clipboard_entries(user_id);

CREATE INDEX IF NOT EXISTS idx_clipboard_entries_user_created 
    ON public.clipboard_entries(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clipboard_entries_pinned 
    ON public.clipboard_entries(user_id, is_pinned DESC, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clipboard_entries_content_type 
    ON public.clipboard_entries(user_id, content_type);

-- ----------------------------------------------------------------------------
-- 4. Row Level Security (RLS) Policies
-- ----------------------------------------------------------------------------
ALTER TABLE public.typing_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clipboard_entries ENABLE ROW LEVEL SECURITY;

-- Typing Sessions RLS Policies
CREATE POLICY "Users can view own typing sessions"
    ON public.typing_sessions
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own typing sessions"
    ON public.typing_sessions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own typing sessions"
    ON public.typing_sessions
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own typing sessions"
    ON public.typing_sessions
    FOR DELETE
    USING (auth.uid() = user_id);

-- Clipboard Entries RLS Policies
CREATE POLICY "Users can view own clipboard entries"
    ON public.clipboard_entries
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own clipboard entries"
    ON public.clipboard_entries
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own clipboard entries"
    ON public.clipboard_entries
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own clipboard entries"
    ON public.clipboard_entries
    FOR DELETE
    USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- 5. Helper Functions & Triggers
-- ----------------------------------------------------------------------------
-- Automatically update character_count and word_count on insert/update
CREATE OR REPLACE FUNCTION public.calculate_typing_session_metrics()
RETURNS TRIGGER AS $$
BEGIN
    NEW.character_count := char_length(NEW.content);
    -- Calculate word count based on regex splitting on whitespace
    IF NEW.content ~ '^\s*$' THEN
        NEW.word_count := 0;
    ELSE
        NEW.word_count := array_length(regexp_split_to_array(trim(NEW.content), '\s+'), 1);
    END IF;
    NEW.updated_at := timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_typing_sessions_metrics ON public.typing_sessions;
CREATE TRIGGER trg_typing_sessions_metrics
    BEFORE INSERT OR UPDATE ON public.typing_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.calculate_typing_session_metrics();
