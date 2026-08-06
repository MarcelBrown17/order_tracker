# Biscuit Order Tracker

Simple order tracker for a home biscuit business. Vue 3 + Vite + Pinia + Supabase.

Profit formula (every order, including bulk):

```
profit_total = (unit_sell_price - unit_cost) * quantity
profit_per_partner = profit_total / 3
```

Partners: **Marcel (admin)**, Delton, Richard.

## Roles

| Role | Who | Can do |
|---|---|---|
| **Admin** | Marcel | Full access: orders, products, all partner splits, mark paid |
| **Partner** | Delton, Richard | Own dashboard + **My earnings** only (their splits / owed / paid) |

Access is enforced in the database (RLS), not only in the UI.

## Setup

### 1. Run the database migrations

1. Open your Supabase project
2. Go to **SQL Editor**
3. Run `supabase/migrations/0001_init.sql`
4. Run `supabase/migrations/0002_roles_rls.sql`

### 2. Create auth users

In Supabase → **Authentication** → **Users**, create an email/password account for each person (Marcel, Delton, Richard).

### 3. Link auth accounts to partners

Marcel is linked by email in `0002_roles_rls.sql` (set there when you run migrations).

For Delton and Richard (after creating their Auth users):

```sql
update public.users set email = 'delton@example.com' where name = 'Delton';
update public.users set email = 'richard@example.com' where name = 'Richard';
```

On first sign-in the app links `auth_user_id` automatically.

### 4. Environment variables

Copy `.env.example` to `.env` and fill in your Supabase project values (Project Settings → API):

```
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Never commit `.env`. On Netlify, set the same variables under Site settings → Environment variables.

### 5. Install and run

```bash
npm install
npm run dev
```

## App pages

| Route | Who | Purpose |
|---|---|---|
| `/login` | All | Email + password auth |
| `/` | All | Admin: business totals. Partner: own owed / paid / lifetime |
| `/orders` | Admin | Order list |
| `/orders/new` | All | Create order (customer, product, sell price). Cost from product; admin-only cost/bulk |
| `/orders/:id` | Admin | Detail, status, mark splits paid |
| `/products` | Admin | Product CRUD |
| `/earnings` | Partner | Full list of own splits |

## Notes

- Creating an order inserts one `orders` row; a trigger creates three `order_splits` rows automatically.
- Editing cost/sell/qty updates split amounts via an update trigger (keeps existing `paid_out` flags).
- Money is always shown as South African format via `<Money />` (e.g. `R1 234.56`).
- Accent colour: `#c2410c`.
# order_tracker
