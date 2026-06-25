CREATE TABLE IF NOT EXISTS public.health_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id uuid NOT NULL REFERENCES public.webhooks(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('online', 'degraded', 'offline')),
  response_time_ms integer NOT NULL DEFAULT 0,
  checked_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_health_checks_webhook_id ON public.health_checks(webhook_id);
CREATE INDEX IF NOT EXISTS idx_health_checks_checked_at ON public.health_checks(checked_at DESC);
