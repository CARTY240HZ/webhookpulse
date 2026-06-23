# WebhookPulse

Professional webhook receiver dashboard. Built for Discord and generic webhooks.

## Stack

- React 18 + TypeScript + Vite
- Tailwind CSS
- Supabase (Auth + PostgreSQL + Realtime)
- Netlify Functions (serverless backend)
- Netlify (hosting)

## Design System

- Background: `#0C0C0E`
- Surface: `#161618`
- Accent: `#D4E83A` (lime)
- No emojis, no gradients, pure vector icons via Lucide React.

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Create a Supabase project and run the SQL from `supabase/schema.sql` in the SQL Editor.

3. Copy `.env.example` to `.env` and fill in your Supabase credentials:
   ```bash
   cp .env.example .env
   ```

4. Start the dev server:
   ```bash
   npm run dev
   ```

5. Build for production:
   ```bash
   npm run build
   ```

## Netlify Deploy

1. Connect your Git repository to Netlify.
2. Set build command to `npm run build` and publish directory to `dist`.
3. Add environment variables in Netlify dashboard:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_KEY`
4. Deploy.

## Netlify Functions

The backend consists of 5 serverless functions:

- `webhook-receive` — Public endpoint to receive webhooks.
- `webhook-list` — List user's webhooks.
- `webhook-logs` — Get logs for a specific webhook.
- `webhook-create` — Create a new webhook.
- `webhook-delete` — Delete a webhook.

## License

MIT
