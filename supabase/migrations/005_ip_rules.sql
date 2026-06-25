CREATE TABLE IF NOT EXISTS public.ip_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id uuid NOT NULL REFERENCES public.webhooks(id) ON DELETE CASCADE,
  ip text NOT NULL,
  action text NOT NULL CHECK (action IN ('allow', 'block')),
  description text,
  created_at timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ip_rules_webhook_id ON public.ip_rules(webhook_id);
CREATE INDEX IF NOT EXISTS idx_ip_rules_ip ON public.ip_rules(ip);
