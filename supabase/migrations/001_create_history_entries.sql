-- Supabase migration: Create history_entries table for encrypted cloud sync
-- This table stores client-side encrypted typing history entries.
-- Only ciphertext is stored — plaintext never reaches the server.

CREATE TABLE IF NOT EXISTS history_entries (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  encrypted_text TEXT NOT NULL,
  encrypted_source_app TEXT NOT NULL,
  iv TEXT NOT NULL,
  captured_at BIGINT NOT NULL,
  device_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index for user-scoped queries ordered by capture time
CREATE INDEX IF NOT EXISTS idx_history_user_captured
  ON history_entries(user_id, captured_at DESC);

-- Enable Row Level Security
ALTER TABLE history_entries ENABLE ROW LEVEL SECURITY;

-- RLS policies: users can only access their own rows
CREATE POLICY "Users can read own entries"
  ON history_entries FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can insert own entries"
  ON history_entries FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete own entries"
  ON history_entries FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);
