# AToken Prediction Market

AToken prediction market is a product-layer implementation for atoken.xyz built around Polymarket CLOB.

## Current scope

- Next.js App Router project skeleton
- Supabase schema migrations
- API route skeleton for markets, orders, positions, notifications, and admin sync jobs
- Service and repository layering for future Polymarket and Supabase integration

## Apply order

1. Install dependencies with `npm install`
2. Apply `supabase/migrations/202605050001_atoken_core_schema.sql`
3. Apply `supabase/migrations/202605050002_atoken_bootstrap_seed.sql`
4. Configure `.env.local` from `.env.example`
5. Run `npm run dev`

## Notes

- High-risk trading writes are intended to stay in server code.
- Public market reads can be safely exposed to the web client.
- This repository starts with stubbed repository methods so the real Supabase queries can be added incrementally.
