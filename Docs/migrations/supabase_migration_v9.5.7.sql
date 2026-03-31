-- Supabase Migration v9.5.6
-- Part of LeoBook Chapter 1 Hardening
--
-- This script adds the columns required for the new "Rich Intelligence Rationale"
-- format in the predictions table.

-- Add rationale columns to public.predictions
ALTER TABLE public.predictions ADD COLUMN IF NOT EXISTS form_home TEXT;
ALTER TABLE public.predictions ADD COLUMN IF NOT EXISTS form_away TEXT;
ALTER TABLE public.predictions ADD COLUMN IF NOT EXISTS h2h_summary TEXT;

-- (Optional) Comment on columns for documentation
COMMENT ON COLUMN public.predictions.form_home IS 'Rich rationale for home team form analysis';
COMMENT ON COLUMN public.predictions.form_away IS 'Rich rationale for away team form analysis';
COMMENT ON COLUMN public.predictions.h2h_summary IS 'Rich rationale for Head-to-Head analysis';

-- Ensure Realtime is enabled for the new columns (Supabase specific)
-- Check if the publication 'supabase_realtime' exists and add the table if not already added.
-- Note: In most Supabase setups, you handle this via the UI, but it can be done here.
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.predictions;
