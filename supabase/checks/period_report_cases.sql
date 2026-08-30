-- Not a migration: the cases of `report_period`, run by hand against a
-- throwaway Postgres 17 (`uv run tool/local_dev/setup.py --reset`) because the
-- Supabase projects do not exist yet (pendency A1).
--
-- Everything happens inside ONE transaction that is rolled back at the end, so
-- the file can be run again over a seeded database without dirtying it.
--
-- Each block prints a line whose expected value is written next to it. A line
-- that comes back different is the failure — there is no assertion framework
-- here, and adding one would mean a second implementation of the schema.

begin;

-- ── Fixtures ────────────────────────────────────────────────────────────
-- Its own catalog, so the file does not depend on what the seed happens to
-- hold. Ids are hex-only on purpose: `uuid` refuses anything else.
insert into public.category (id, name) values
  ('00000000-0000-4000-8000-00000000ca01', 'Check Carnes'),
  ('00000000-0000-4000-8000-00000000ca02', 'Check Limpeza');

insert into public.product_type (id, name, category_id, base_unit) values
  (
    '00000000-0000-4000-8000-00000000bb01', 'Check Acém',
    '00000000-0000-4000-8000-00000000ca01', 'kilogram'
  ),
  (
    '00000000-0000-4000-8000-00000000bb02', 'Check Sabão',
    '00000000-0000-4000-8000-00000000ca01', 'kilogram'
  ),
  -- Deactivated, for case 7: a tidied-up catalog must not rewrite the past.
  (
    '00000000-0000-4000-8000-00000000bb03', 'Check Frango',
    '00000000-0000-4000-8000-00000000ca02', 'kilogram'
  );
update public.product_type set active = false
where id = '00000000-0000-4000-8000-00000000bb03';

insert into public.brand (id, name) values
  ('00000000-0000-4000-8000-00000000bd01', 'Check Omo'),
  ('00000000-0000-4000-8000-00000000bd02', 'Check Tixan');
update public.brand set active = false
where id = '00000000-0000-4000-8000-00000000bd02';

insert into public.product_registration
  (id, product_type_id, brand_id, description, selling_mode, active)
values
  -- No brand at all: the ground beef of case 6.
  (
    '00000000-0000-4000-8000-00000000dd01',
    '00000000-0000-4000-8000-00000000bb01', null, '', 'by_weight', true
  ),
  (
    '00000000-0000-4000-8000-00000000dd02',
    '00000000-0000-4000-8000-00000000bb02',
    '00000000-0000-4000-8000-00000000bd01', '', 'by_piece', true
  ),
  -- Deactivated registration under a deactivated brand — case 7.
  (
    '00000000-0000-4000-8000-00000000dd03',
    '00000000-0000-4000-8000-00000000bb02',
    '00000000-0000-4000-8000-00000000bd02', '', 'by_piece', false
  ),
  (
    '00000000-0000-4000-8000-00000000dd04',
    '00000000-0000-4000-8000-00000000bb03', null, '', 'by_weight', true
  );

insert into public.product
  (id, product_registration_id, piece_count, piece_size, piece_size_unit,
   total_content)
values
  ('00000000-0000-4000-8000-00000000ee01',
   '00000000-0000-4000-8000-00000000dd01', null, null, null, null),
  ('00000000-0000-4000-8000-00000000ee02',
   '00000000-0000-4000-8000-00000000dd02', 1, 4300, 'gram', 4300),
  ('00000000-0000-4000-8000-00000000ee03',
   '00000000-0000-4000-8000-00000000dd03', 1, 2500, 'gram', 2500),
  ('00000000-0000-4000-8000-00000000ee04',
   '00000000-0000-4000-8000-00000000dd04', null, null, null, null);

insert into public.store (id, name)
values ('00000000-0000-4000-8000-00000000ff01', 'Check Mercado Relatório');

-- Six purchases: two inside, two exactly ON the boundaries, two one day
-- outside each end.
insert into public.purchase (id, purchase_date, store_id, registered_by) values
  ('00000000-0000-4000-8000-00000000aa01', date '2026-08-10',
   '00000000-0000-4000-8000-00000000ff01', 'Check'),
  ('00000000-0000-4000-8000-00000000aa02', date '2026-08-18',
   '00000000-0000-4000-8000-00000000ff01', 'Check'),
  ('00000000-0000-4000-8000-00000000aa03', date '2026-08-01',
   '00000000-0000-4000-8000-00000000ff01', 'Check'),
  ('00000000-0000-4000-8000-00000000aa04', date '2026-08-31',
   '00000000-0000-4000-8000-00000000ff01', 'Check'),
  ('00000000-0000-4000-8000-00000000aa05', date '2026-07-31',
   '00000000-0000-4000-8000-00000000ff01', 'Check'),
  ('00000000-0000-4000-8000-00000000aa06', date '2026-09-01',
   '00000000-0000-4000-8000-00000000ff01', 'Check');

insert into public.purchase_item
  (id, purchase_id, product_id, quantity, quantity_in_base_unit, total_paid)
values
  -- 5 kg of beef at R$ 30 the kilo.
  ('00000000-0000-4000-8000-0000000011a1',
   '00000000-0000-4000-8000-00000000aa01',
   '00000000-0000-4000-8000-00000000ee01', 5000, 5000, 15000),
  -- 1 kg at R$ 42 — the average of averages would answer R$ 36.
  ('00000000-0000-4000-8000-0000000011a2',
   '00000000-0000-4000-8000-00000000aa02',
   '00000000-0000-4000-8000-00000000ee01', 1000, 1000, 4200),
  -- Omo 4,3 kg for R$ 86,00.
  ('00000000-0000-4000-8000-0000000011a3',
   '00000000-0000-4000-8000-00000000aa01',
   '00000000-0000-4000-8000-00000000ee02', 1, 4300, 8600),
  -- Tixan 2,5 kg for R$ 50,00 — deactivated everything, and it still counts.
  ('00000000-0000-4000-8000-0000000011a4',
   '00000000-0000-4000-8000-00000000aa02',
   '00000000-0000-4000-8000-00000000ee03', 1, 2500, 5000),
  -- On `p_from` and on `p_to`: both ends are closed.
  ('00000000-0000-4000-8000-0000000011a5',
   '00000000-0000-4000-8000-00000000aa03',
   '00000000-0000-4000-8000-00000000ee04', 1000, 1000, 1100),
  ('00000000-0000-4000-8000-0000000011a6',
   '00000000-0000-4000-8000-00000000aa04',
   '00000000-0000-4000-8000-00000000ee04', 1000, 1000, 2200),
  -- One day before `p_from` and one day after `p_to`: neither enters.
  ('00000000-0000-4000-8000-0000000011a7',
   '00000000-0000-4000-8000-00000000aa05',
   '00000000-0000-4000-8000-00000000ee04', 1000, 1000, 9900),
  ('00000000-0000-4000-8000-0000000011a8',
   '00000000-0000-4000-8000-00000000aa06',
   '00000000-0000-4000-8000-00000000ee04', 1000, 1000, 8800);

-- The report under test, computed once and read by every case below.
create temporary table check_report on commit drop as
select public.report_period(date '2026-08-01', date '2026-08-31') as r;

-- ── 1. The beef: 6 kg for R$ 192,00 ─────────────────────────────────────
-- The written acceptance criterion of requirement 4. 6000 and 19200 — the
-- average price is R$ 32,00/kg, which Dart divides, not the database.
select 'case 1 — beef sums quantity and money' as case,
       (t->>'quantity_in_base_unit')::bigint = 6000
         and (t->>'total_paid')::bigint = 19200 as expected_true
from check_report, jsonb_array_elements(r->'types') t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb01';

-- ── 2. The washing powder: one type, two brands ─────────────────────────
select 'case 2a — powder type sums both brands' as case,
       (t->>'quantity_in_base_unit')::bigint = 6800
         and (t->>'total_paid')::bigint = 13600 as expected_true
from check_report, jsonb_array_elements(r->'types') t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb02';

select 'case 2b — the powder breaks into exactly two brand rows' as case,
       count(*) = 2 as expected_true
from check_report, jsonb_array_elements(r->'brands') b
where b->>'product_type_id' = '00000000-0000-4000-8000-00000000bb02'
  and b->>'brand_id' is not null;

select 'case 2c — Omo 4300/8600 and Tixan 2500/5000' as case,
       bool_and(
         case b->>'brand_id'
           when '00000000-0000-4000-8000-00000000bd01'
             then (b->>'quantity_in_base_unit')::bigint = 4300
               and (b->>'total_paid')::bigint = 8600
           else (b->>'quantity_in_base_unit')::bigint = 2500
               and (b->>'total_paid')::bigint = 5000
         end
       ) as expected_true
from check_report, jsonb_array_elements(r->'brands') b
where b->>'product_type_id' = '00000000-0000-4000-8000-00000000bb02'
  and b->>'brand_id' is not null;

-- ── 3. A category with two types comes back as ONE line ─────────────────
-- "Check Carnes" holds the beef (19200) and the powder (13600).
select 'case 3 — the category is one line, summing its types' as case,
       count(*) = 1 and max((c->>'total_paid')::bigint) = 32800 as expected_true
from check_report, jsonb_array_elements(r->'categories') c
where c->>'category_id' = '00000000-0000-4000-8000-00000000ca01';

-- ── 4. Both ends of the interval are CLOSED ─────────────────────────────
-- 1100 on `p_from` plus 2200 on `p_to` — and nothing else in that category.
select 'case 4 — the day of p_from and the day of p_to both enter' as case,
       (c->>'total_paid')::bigint = 3300 as expected_true
from check_report, jsonb_array_elements(r->'categories') c
where c->>'category_id' = '00000000-0000-4000-8000-00000000ca02';

-- ── 5. One day outside each end stays outside ───────────────────────────
-- Same assertion read the other way: 9900 and 8800 are NOT in the 3300 above.
-- Scoped to THIS file's two categories: the database it runs against is a
-- seeded one, and a total over every category would be counting the seed.
select 'case 5 — the day before and the day after stay out' as case,
       sum((c->>'total_paid')::bigint) = 36100 as expected_true
from check_report, jsonb_array_elements(r->'categories') c
where c->>'category_id' in (
  '00000000-0000-4000-8000-00000000ca01',
  '00000000-0000-4000-8000-00000000ca02'
);

-- ── 6. The product with no brand ────────────────────────────────────────
-- It is in `types` (its money counts) AND in `brands` with a null id — what
-- the domain does with that group is rule C2, decided in Dart.
select 'case 6a — the unbranded type is in types' as case,
       count(*) = 1 as expected_true
from check_report, jsonb_array_elements(r->'types') t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb01';

select 'case 6b — and it comes back with a NULL brand row' as case,
       count(*) = 1
         and max((b->>'total_paid')::bigint) = 19200 as expected_true
from check_report, jsonb_array_elements(r->'brands') b
where b->>'product_type_id' = '00000000-0000-4000-8000-00000000bb01'
  and b->>'brand_id' is null;

-- ── 7. A deactivated catalog keeps appearing (requirement 16) ───────────
-- Three deactivations, all of which still report: the Tixan line hangs from a
-- deactivated BRAND under a deactivated REGISTRATION, and "Check Frango" is a
-- deactivated TYPE. A `where active` in the query would rewrite the past every
-- time someone tidied up the catalog.
select 'case 7a — the deactivated brand still reports' as case,
       (b->>'total_paid')::bigint = 5000 as expected_true
from check_report, jsonb_array_elements(r->'brands') b
where b->>'brand_id' = '00000000-0000-4000-8000-00000000bd02';

select 'case 7b — the deactivated type still reports' as case,
       (t->>'total_paid')::bigint = 3300 as expected_true
from check_report, jsonb_array_elements(r->'types') t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb03';

-- ── 8. A period with no purchase at all ─────────────────────────────────
-- `jsonb_agg` of zero rows returns NULL, not `[]`. The empty period is a
-- STATE to draw, and without the coalesce it would arrive as three nulls and
-- blow up in `fromJson`.
select 'case 8a — the three keys come back as arrays, never null' as case,
       jsonb_typeof(r->'categories') = 'array'
         and jsonb_typeof(r->'types') = 'array'
         and jsonb_typeof(r->'brands') = 'array' as expected_true
from (
  select public.report_period(date '2019-01-01', date '2019-01-31') as r
) empty;

select 'case 8b — and all three are empty' as case,
       jsonb_array_length(r->'categories') = 0
         and jsonb_array_length(r->'types') = 0
         and jsonb_array_length(r->'brands') = 0 as expected_true
from (
  select public.report_period(date '2019-01-01', date '2019-01-31') as r
) empty;

-- ── 9. The sums are bigint, not numeric ─────────────────────────────────
-- `sum()` over `bigint` returns `numeric`, and `numeric` inside `jsonb` can
-- arrive as `19200.00` — which `Money.fromJson` would then have to guess at.
select 'case 9 — no sum arrives with a decimal point' as case,
       bool_and(t->>'total_paid' not like '%.%') as expected_true
from check_report, jsonb_array_elements(r->'types') t;

rollback;
