-- Migration 001: Security hardening
-- Apply this via Supabase SQL Editor or psql

-- 1. Add secret_hash column (nullable, for migration period)
ALTER TABLE webhooks
ADD COLUMN IF NOT EXISTS secret_hash text;

-- 2. Create index for rate limiting (ip_address + created_at)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_webhook_logs_ip
ON webhook_logs (ip_address, created_at DESC);

-- 3. One-time: hash existing secrets into secret_hash
-- NOTE: This requires the WEBHOOK_SECRET_SALT env var to match the backend.
-- Run this ONLY after the backend is deployed with the HMAC functions.
-- Uncomment below after verifying salt matches:

-- UPDATE webhooks
-- SET secret_hash = encode(hmac(secret::bytea, 'webhookpulse-default-salt-change-me'::bytea, 'sha256'), 'hex')
-- WHERE secret IS NOT NULL AND secret_hash IS NULL;

-- 4. After verifying all secrets are hashed, drop the plaintext column:
-- ALTER TABLE webhooks DROP COLUMN IF EXISTS secret;
