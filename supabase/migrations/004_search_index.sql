-- Enable pg_trgm extension for GIN text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- GIN index for efficient JSONB text search
CREATE INDEX IF NOT EXISTS idx_webhook_logs_payload_gin ON public.webhook_logs USING gin (payload gin_trgm_ops);
