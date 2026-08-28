-- The twelve tables of `handoff §7`. The schema IS the contract: there is no
-- documented REST API, PostgREST exposes whatever is here, and the app reads
-- it directly.
--
-- ── The five decisions this file is built on (docs/pendencias §B) ─────────
-- B1  A weight-sold product still gets a `product` row; its packaging columns
--     are null. Every purchase points at one kind of target, always.
-- B2  The unique index on the registration uses NULLS NOT DISTINCT, so two
--     "acém moído with no brand" collide. The screen offers "Sem marca"; the
--     database stores nothing, and no phantom brand pollutes the reports.
-- B3  The unique indexes IGNORE `active`: deactivating "Limpeza" prevents a
--     second "Limpeza" from being created. The app finds the deactivated row
--     and offers to REACTIVATE it, which is what keeps a catalog's history in
--     one place.
-- B4  `selling_mode` lives on the registration, not on the type — so
--     "mussarela em pacote" and "mussarela do balcão" share one type, and the
--     per-type totals stay whole.
-- B5  Money and quantity are INTEGERS in the smallest unit: cents, grams,
--     millilitres. Not `numeric`: PostgREST returns numeric as a bare JSON
--     number and `json.decode` turns it into a Dart double before any line of
--     ours sees it — R15 happening at the boundary with a perfectly correct
--     schema. `bigint` arrives as an int and nothing rounds anywhere.
--
-- ── What is NOT in this file, by decision ─────────────────────────────────
-- No `now()` or `current_date` deciding a period, no numeric threshold and no
-- unit conversion (decisions 7 and 13): "today" is born on the phone's clock,
-- in Dart, and travels as a parameter. `created_at DEFAULT now()` is an audit
-- stamp, not a rule, and is allowed.
--
-- No DELETE on the six catalogs (decision 19): renaming has to hold for the
-- whole history, so every one of them carries `active` and the purchase
-- points at a key, never at a copied name.

-- ─────────────────────────────────────────────────────────────────────────
-- Catalogs
-- ─────────────────────────────────────────────────────────────────────────

create table public.category (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  -- Generated, so nothing can write a normalized name that disagrees with the
  -- name. Once this column exists, normalize_name is frozen in practice —
  -- read the header of the previous migration before touching it.
  name_normalized text generated always as (public.normalize_name(name)) stored,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Total, not partial: B3. `where active` here would let a second "Limpeza" be
-- born while the first sleeps.
create unique index category_name_key on public.category (name_normalized);

create table public.product_type (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_normalized text generated always as (public.normalize_name(name)) stored,
  category_id uuid not null references public.category (id),
  -- The LEVEL THAT SUMS carries the base unit: everything below it is
  -- converted into this before being added up.
  base_unit text not null check (base_unit in ('kilogram', 'liter', 'unit')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Unique across the whole table, not per category: the type is the level the
-- reports add up, and two "Leite" types would split that sum in half with
-- nothing on screen explaining why.
create unique index product_type_name_key
  on public.product_type (name_normalized);

create index product_type_category_idx on public.product_type (category_id);

create table public.brand (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_normalized text generated always as (public.normalize_name(name)) stored,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index brand_name_key on public.brand (name_normalized);

-- The identity of a registration is type + brand + description. This is the
-- row that must not repeat.
create table public.product_registration (
  id uuid primary key default gen_random_uuid(),
  product_type_id uuid not null references public.product_type (id),
  -- Null is "Sem marca" (B2), which is a real answer and not missing data.
  brand_id uuid references public.brand (id),
  -- NEVER null, always '': an empty description is a VALUE — it is what tells
  -- "Coca-Cola" apart from "Coca-Cola zero".
  description text not null default '',
  description_normalized text
    generated always as (public.normalize_name(description)) stored,
  -- B4. It decides what the purchase screen asks for, and it holds in any
  -- base unit: bulk olive oil is measured in litres and still sold by weight.
  selling_mode text not null check (selling_mode in ('by_weight', 'by_piece')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- NULLS NOT DISTINCT is the whole point (B2): without it Postgres considers
-- two null brands different and lets a duplicate through in silence.
create unique index product_registration_identity_key
  on public.product_registration (
    product_type_id, brand_id, description_normalized
  )
  nulls not distinct;

-- The leaf: registration + packaging. This is what a purchase points at —
-- always, including when it is sold by weight and has no packaging (B1).
create table public.product (
  id uuid primary key default gen_random_uuid(),
  product_registration_id uuid not null
    references public.product_registration (id),
  -- The three packaging columns are null for a weight-sold product.
  piece_count integer check (piece_count is null or piece_count > 0),
  -- INTEGER in the smallest unit of the base (grams, millilitres, units) —
  -- B5. `piece_size_unit` is what the person TYPED, kept only so the screen
  -- can show "0,35 L" back to whoever typed "0,35 L" instead of "350 ml".
  piece_size bigint check (piece_size is null or piece_size > 0),
  piece_size_unit text check (
    piece_size_unit is null
    or piece_size_unit in ('gram', 'kilogram', 'milliliter', 'liter', 'unit')
  ),
  -- piece_count × piece_size, in the same smallest unit. CALCULATED by Dart
  -- before the write, never typed and never computed here: conversion is not
  -- the database's job (decision 7).
  --
  -- One column and not two. `handoff` sketched a numeric total_content beside
  -- a bigint one; under B5 the fractional twin would be the exact door R15
  -- walks through, so it is gone.
  total_content bigint check (total_content is null or total_content > 0),
  -- Its own `active` (decision 23): this is what "deactivate the packaging"
  -- reaches, without touching the registration above it.
  active boolean not null default true,
  created_at timestamptz not null default now(),
  -- Packaging is all-or-nothing: a leaf either describes one (by piece) or
  -- describes none (by weight). Half of it filled in is a bug upstream.
  constraint product_packaging_all_or_nothing check (
    (piece_count is null and piece_size is null
      and piece_size_unit is null and total_content is null)
    or (piece_count is not null and piece_size is not null
      and piece_size_unit is not null and total_content is not null)
  )
);

-- "1 × 0,35 L" and "1 × 350 ml" are the SAME packaging, and this is where
-- that is enforced: both store 350. NULLS NOT DISTINCT so a registration
-- cannot grow two weight-sold leaves either.
create unique index product_packaging_key
  on public.product (product_registration_id, total_content)
  nulls not distinct;

create table public.store (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_normalized text generated always as (public.normalize_name(name)) stored,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index store_name_key on public.store (name_normalized);

-- ─────────────────────────────────────────────────────────────────────────
-- The list
-- ─────────────────────────────────────────────────────────────────────────

create table public.shopping_list_item (
  id uuid primary key default gen_random_uuid(),
  -- The list is written at the TYPE level: brand and packaging are
  -- preferences, and they do not command the write-off.
  product_type_id uuid not null references public.product_type (id),
  preferred_brand_id uuid references public.brand (id),
  preferred_product_id uuid references public.product (id),
  -- In the smallest unit of the type's base unit (B5).
  --
  -- NULL is an ANSWER, not missing data: "acabou o sabão em pó" has no
  -- quantity to state, and an item with no quantity leaves the list on the
  -- FIRST purchase of that type (wireframe #1a and screen 1). Whoever wants
  -- to ask for "6 litros" opens the item dialog afterwards.
  quantity bigint check (quantity is null or quantity > 0),
  -- Decision 25, and the reason a late purchase does not clear an item added
  -- afterwards. `date`, no time zone: it is a calendar day, not an instant.
  entered_on date not null,
  picked boolean not null default false,
  not_found boolean not null default false,
  created_at timestamptz not null default now()
);

create index shopping_list_item_type_idx
  on public.shopping_list_item (product_type_id);

-- ─────────────────────────────────────────────────────────────────────────
-- Purchases
-- ─────────────────────────────────────────────────────────────────────────

create table public.purchase (
  -- Generated ON THE PHONE and sent with the insert: it is what makes a retry
  -- after a timeout idempotent instead of a second purchase.
  id uuid primary key,
  -- `date`, not timestamptz: the day printed on the receipt (decision 13).
  purchase_date date not null,
  store_id uuid not null references public.store (id),
  -- The Hive label, copied at the moment of the purchase. Text on purpose:
  -- it is NOT an account, there is nothing to reference.
  registered_by text not null,
  created_at timestamptz not null default now()
);

create index purchase_date_idx on public.purchase (purchase_date);

create table public.purchase_item (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null
    references public.purchase (id) on delete cascade,
  product_id uuid not null references public.product (id),
  -- What was TYPED: a package count when sold by piece, a weight in the
  -- smallest unit when sold by weight.
  quantity bigint not null check (quantity > 0),
  -- The same amount converted into the type's base unit, in its smallest
  -- unit. Both are persisted (decision 7) because the conversion happens in
  -- Dart, before the write, and a report must never redo it.
  quantity_in_base_unit bigint not null check (quantity_in_base_unit > 0),
  -- CENTS (B5). What was paid in total, not the unit price: the receipt has
  -- the total, and the unit price is a division the reports do.
  total_paid bigint not null check (total_paid >= 0)
);

create index purchase_item_purchase_idx on public.purchase_item (purchase_id);
create index purchase_item_product_idx on public.purchase_item (product_id);

-- The trail of decision 20. It is born with H7 and not with H9: what a
-- purchase cleared off the list cannot be reconstructed afterwards, so if it
-- is not written at the same moment, it is lost.
create table public.list_write_off (
  id uuid primary key default gen_random_uuid(),
  purchase_item_id uuid not null
    references public.purchase_item (id) on delete cascade,
  shopping_list_item_id uuid not null
    references public.shopping_list_item (id),
  quantity_written_off bigint not null check (quantity_written_off > 0),
  -- Whether this write-off is what cleared a "não encontrei" — so deleting
  -- the purchase can put the mark back.
  cleared_not_found boolean not null default false,
  created_at timestamptz not null default now()
);

create index list_write_off_item_idx
  on public.list_write_off (shopping_list_item_id);

-- ─────────────────────────────────────────────────────────────────────────
-- Spending cap (decision 14) — the tables are born here, H13 fills them
-- ─────────────────────────────────────────────────────────────────────────

create table public.spending_cap (
  id uuid primary key default gen_random_uuid(),
  -- CENTS (B5).
  amount bigint not null check (amount >= 0),
  -- Always day 1: the cap is monthly, and a mid-month start would make "the
  -- month's total" ambiguous. This is structure, not a business threshold.
  effective_from date not null check (extract(day from effective_from) = 1),
  created_at timestamptz not null default now()
);

-- One row per CHANGE, and at most one per month: saving a cap for a month
-- that already has one replaces it.
create unique index spending_cap_month_key
  on public.spending_cap (effective_from);

create table public.spending_cap_alert (
  id uuid primary key default gen_random_uuid(),
  -- Day 1 of the month the alerts belong to.
  month date not null check (extract(day from month) = 1),
  -- Null means "not warned yet". The 80% and 100% thresholds themselves live
  -- in Dart, in the domain — never here (decision 7).
  warned_80_at timestamptz,
  warned_100_at timestamptz
);

create unique index spending_cap_alert_month_key
  on public.spending_cap_alert (month);

-- ─────────────────────────────────────────────────────────────────────────
-- Realtime
-- ─────────────────────────────────────────────────────────────────────────

-- Only the list: it is the one thing both phones touch at the same time, in
-- the aisle. And the screen NEVER moves under a finger — what arrives from
-- the other phone shows up as a banner, and the tap is what redraws.
alter publication supabase_realtime add table public.shopping_list_item;

-- ─────────────────────────────────────────────────────────────────────────
-- The one write that cannot be two calls
-- ─────────────────────────────────────────────────────────────────────────

-- A registration with four packagings is FIVE rows in TWO tables, and
-- PostgREST cannot write that in one transaction. Two separate calls mean the
-- second one failing leaves an orphan registration with no leaf — and the
-- duplicate guard then blocks the user's own retry. It is the worst possible
-- outcome of H2, and this function is the fix.
--
-- It DECIDES NOTHING. Every value arrives already converted by Dart; this
-- only inserts, so "no conversion in SQL" (decision 7) still holds.
--
-- `packagings` is a JSON array. Each element is either {} (weight-sold: one
-- leaf with null packaging) or
-- {"piece_count": 6, "piece_size": 350, "piece_size_unit": "milliliter",
--  "total_content": 2100}.
create function public.create_product_registration(
  p_product_type_id uuid,
  p_brand_id uuid,
  p_description text,
  p_selling_mode text,
  p_packagings jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_registration public.product_registration;
  v_products jsonb;
begin
  insert into public.product_registration (
    product_type_id, brand_id, description, selling_mode
  )
  values (
    p_product_type_id, p_brand_id, coalesce(p_description, ''), p_selling_mode
  )
  returning * into v_registration;

  with inserted as (
    insert into public.product (
      product_registration_id,
      piece_count,
      piece_size,
      piece_size_unit,
      total_content
    )
    select
      v_registration.id,
      (packaging ->> 'piece_count')::integer,
      (packaging ->> 'piece_size')::bigint,
      packaging ->> 'piece_size_unit',
      (packaging ->> 'total_content')::bigint
    from jsonb_array_elements(p_packagings) as packaging
    returning *
  )
  select coalesce(jsonb_agg(to_jsonb(inserted)), '[]'::jsonb)
  into v_products
  from inserted;

  return jsonb_build_object(
    'registration', to_jsonb(v_registration),
    'products', v_products
  );
end;
$$;

comment on function public.create_product_registration is
  'Inserts a registration and its packagings in ONE transaction. Decides '
  'nothing: every value arrives converted from Dart. Called by '
  'CatalogRepositoryRemote.saveRegistrationWithProducts.';
