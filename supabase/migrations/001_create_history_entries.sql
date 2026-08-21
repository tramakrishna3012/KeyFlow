-- Create history_entries table for encrypted snippet sync
CREATE TABLE IF NOT EXISTS public.history_entries (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    encrypted_text TEXT NOT NULL,
    encrypted_source_app TEXT NOT NULL,
    iv TEXT NOT NULL,
    captured_at BIGINT NOT NULL,
    device_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Indices for efficient query filtering
CREATE INDEX IF NOT EXISTS idx_history_entries_user_id ON public.history_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_history_entries_captured_at ON public.history_entries(user_id, captured_at DESC);

-- Enable Row-Level Security
ALTER TABLE public.history_entries ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Restrict access strictly to the owning authenticated user
CREATE POLICY "Users can view own history entries"
    ON public.history_entries
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own history entries"
    ON public.history_entries
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own history entries"
    ON public.history_entries
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own history entries"
    ON public.history_entries
    FOR DELETE
    USING (auth.uid() = user_id);
