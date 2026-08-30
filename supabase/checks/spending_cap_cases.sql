-- Not a migration: the cases of H13 and H14, run by hand against a throwaway
-- Postgres 17 (`uv run tool/local_dev/setup.py --reset`) because the Supabase
-- projects do not exist yet (pendency A1).
--
-- Everything happens inside ONE transaction that is rolled back at the end, so
-- the file can be run again over a seeded database without dirtying it.
--
-- Each block prints a line whose expected value is written next to it. A line
-- that comes back different is the failure — there is no assertion framework
-- here, and adding one would mean a second implementation of the schema.
--
-- **No threshold is exercised here, and that is the point**: the 80% and the
-- 100% live in `CapThreshold`, in Dart, with their own test. What this file
-- proves is that the database STORES what Dart decided and gives it back.

begin;

-- ── Fixtures ────────────────────────────────────────────────────────────
-- Its own catalog and its own months, so the file does not depend on what the
-- seed happens to hold. The months are 2019, far from any seeded purchase, so
-- `spent` counts only what is inserted below.
insert into public.category (id, name) values
  ('00000000-0000-4000-8000-0000000ca101', 'Check Teto');

insert into public.product_type (id, name, category_id, base_unit) values
  ('00000000-0000-4000-8000-0000000bb101', 'Check Leite',
   '00000000-0000-4000-8000-0000000ca101', 'liter'),
  ('00000000-0000-4000-8000-0000000bb102', 'Check Café',
   '00000000-0000-4000-8000-0000000ca101', 'kilogram');

insert into public.brand (id, name) values
  ('00000000-0000-4000-8000-0000000bd101', 'Check Italac'),
  ('00000000-0000-4000-8000-0000000bd102', 'Check Piracanjuba');

-- Two registrations of the SAME type under different brands: it is what case
-- 10 needs to prove the comparison happens at the TYPE level.
insert into public.product_registration
  (id, product_type_id, brand_id, description, selling_mode, active)
values
  ('00000000-0000-4000-8000-0000000dd101',
   '00000000-0000-4000-8000-0000000bb101',
   '00000000-0000-4000-8000-0000000bd101', '', 'by_piece', true),
  ('00000000-0000-4000-8000-0000000dd102',
   '00000000-0000-4000-8000-0000000bb101',
   '00000000-0000-4000-8000-0000000bd102', '', 'by_piece', true),
  ('00000000-0000-4000-8000-0000000dd103',
   '00000000-0000-4000-8000-0000000bb102', null, '', 'by_weight', true);

insert into public.product
  (id, product_registration_id, piece_count, piece_size, piece_size_unit,
   total_content)
values
  ('00000000-0000-4000-8000-0000000ee101',
   '00000000-0000-4000-8000-0000000dd101', 1, 1000, 'milliliter', 1000),
  ('00000000-0000-4000-8000-0000000ee102',
   '00000000-0000-4000-8000-0000000dd102', 1, 1000, 'milliliter', 1000),
  ('00000000-0000-4000-8000-0000000ee103',
   '00000000-0000-4000-8000-0000000dd103', null, null, null, null);

insert into public.store (id, name)
values ('00000000-0000-4000-8000-0000000ff101', 'Check Mercado Teto');

-- R$ 1.200,00 spent in August 2019, in two purchases by two different people
-- on the SAME day — which is also the fixture of H14.
insert into public.purchase (id, purchase_date, store_id, registered_by) values
  ('00000000-0000-4000-8000-0000000aa101', date '2019-08-10',
   '00000000-0000-4000-8000-0000000ff101', 'Leandro'),
  ('00000000-0000-4000-8000-0000000aa102', date '2019-08-10',
   '00000000-0000-4000-8000-0000000ff101', 'esposa'),
  -- July, so case 2 has a month BEFORE the first cap with spending in it.
  ('00000000-0000-4000-8000-0000000aa103', date '2019-07-15',
   '00000000-0000-4000-8000-0000000ff101', 'Leandro');

insert into public.purchase_item
  (id, purchase_id, product_id, quantity, quantity_in_base_unit, total_paid)
values
  ('00000000-0000-4000-8000-000000011101',
   '00000000-0000-4000-8000-0000000aa101',
   '00000000-0000-4000-8000-0000000ee101', 1, 1000, 70000),
  ('00000000-0000-4000-8000-000000011102',
   '00000000-0000-4000-8000-0000000aa102',
   '00000000-0000-4000-8000-0000000ee102', 1, 1000, 50000),
  ('00000000-0000-4000-8000-000000011103',
   '00000000-0000-4000-8000-0000000aa103',
   '00000000-0000-4000-8000-0000000ee103', 1000, 1000, 3300);

-- ── 1. A month with no cap row at all ───────────────────────────────────
select 'case 1 — no cap ever configured answers cap_amount null' as case,
       (r->0->>'cap_amount') is null
         and (r->0->>'cap_effective_from') is null as expected_true
from (
  select public.cap_states(
    '[{"month": "2019-08-01", "last_day": "2019-08-31"}]'::jsonb
  ) as r
) s;

-- The cap the rest of the file runs on: R$ 1.500,00 from August 2019 on.
insert into public.spending_cap (amount, effective_from)
values (150000, date '2019-08-01');

-- ── 2. A month BEFORE the first cap stays without one, forever ──────────
select 'case 2 — July has no cap, and its spending is still counted' as case,
       (r->0->>'cap_amount') is null
         and (r->0->>'spent')::bigint = 3300 as expected_true
from (
  select public.cap_states(
    '[{"month": "2019-07-01", "last_day": "2019-07-31"}]'::jsonb
  ) as r
) s;

-- ── 3. A closed month keeps the cap OF ITS TIME ─────────────────────────
-- October raises it to R$ 1.800; August must go on answering R$ 1.500.
insert into public.spending_cap (amount, effective_from)
values (180000, date '2019-10-01');

select 'case 3 — August answers 150000 and October 180000' as case,
       (r->0->>'cap_amount')::bigint = 150000
         and (r->1->>'cap_amount')::bigint = 180000 as expected_true
from (
  select public.cap_states(
    '[{"month": "2019-10-01", "last_day": "2019-10-31"},
      {"month": "2019-08-01", "last_day": "2019-08-31"}]'::jsonb
  ) as r
) s;

-- …and the answer above proves one more thing that a caller could get wrong
-- in silence: the months came back ORDERED, not in the order asked. August
-- was asked SECOND and is at index 0.
select 'case 3b — the answer is ordered by month, not by the order asked'
         as case,
       (r->0->>'month') = '2019-08-01' as expected_true
from (
  select public.cap_states(
    '[{"month": "2019-10-01", "last_day": "2019-10-31"},
      {"month": "2019-08-01", "last_day": "2019-08-31"}]'::jsonb
  ) as r
) s;

-- ── 3c. The month's spending is the sum of its purchases ────────────────
select 'case 3c — August spent 120000, both purchases of the day counted'
         as case,
       (r->0->>'spent')::bigint = 120000 as expected_true
from (
  select public.cap_states(
    '[{"month": "2019-08-01", "last_day": "2019-08-31"}]'::jsonb
  ) as r
) s;

-- ── 4. A mark is written ────────────────────────────────────────────────
select public.apply_cap_alerts(
  '[{"month": "2019-08-01", "warned_80": true, "warned_100": false}]'::jsonb
);

select 'case 4 — warned_80 stamped, warned_100 still null' as case,
       warned_80_at is not null and warned_100_at is null as expected_true
from public.spending_cap_alert where month = date '2019-08-01';

-- ── 5. Called again with the same `true`, the FIRST stamp survives ──────
-- This is what makes the warning happen once: the second purchase of a month
-- still above the cut sends `true` again and must not restamp.
create temporary table check_first_stamp on commit drop as
select warned_80_at as at from public.spending_cap_alert
where month = date '2019-08-01';

select pg_sleep(0.01);

select public.apply_cap_alerts(
  '[{"month": "2019-08-01", "warned_80": true, "warned_100": false}]'::jsonb
);

select 'case 5 — the original stamp is preserved' as case,
       a.warned_80_at = f.at as expected_true
from public.spending_cap_alert a, check_first_stamp f
where a.month = date '2019-08-01';

-- ── 6. `false` ERASES the stamp — the rearm ─────────────────────────────
select public.apply_cap_alerts(
  '[{"month": "2019-08-01", "warned_80": false, "warned_100": false}]'::jsonb
);

select 'case 6 — both marks back to null: the rearm' as case,
       warned_80_at is null and warned_100_at is null as expected_true
from public.spending_cap_alert where month = date '2019-08-01';

-- ── 7. Saving a cap clears the month and writes what came ───────────────
select public.apply_cap_alerts(
  '[{"month": "2019-08-01", "warned_80": true, "warned_100": true}]'::jsonb
);

select public.save_spending_cap(
  200000, date '2019-08-01',
  '[{"month": "2019-08-01", "warned_80": false, "warned_100": false}]'::jsonb
);

select 'case 7 — the new amount is in, and both marks were cleared' as case,
       (select amount from public.spending_cap
         where effective_from = date '2019-08-01') = 200000
         and (select warned_80_at is null and warned_100_at is null
                from public.spending_cap_alert
               where month = date '2019-08-01') as expected_true;

-- ── 8. …and a CLOSED month is not touched ───────────────────────────────
insert into public.spending_cap_alert (month, warned_80_at, warned_100_at)
values (date '2019-07-01', now(), now());

select public.save_spending_cap(
  210000, date '2019-08-01',
  '[{"month": "2019-08-01", "warned_80": true, "warned_100": false}]'::jsonb
);

select 'case 8 — July keeps both of its stamps' as case,
       warned_80_at is not null and warned_100_at is not null as expected_true
from public.spending_cap_alert where month = date '2019-07-01';

-- ── 9. create_purchase writes the purchase AND the mark, or neither ─────
savepoint before_purchase;

select public.create_purchase(
  jsonb_build_object(
    'id', '00000000-0000-4000-8000-0000000aa199',
    'purchase_date', '2019-08-20',
    'store_id', '00000000-0000-4000-8000-0000000ff101',
    'registered_by', 'Leandro'
  ),
  jsonb_build_array(jsonb_build_object(
    'id', '00000000-0000-4000-8000-000000011199',
    'product_id', '00000000-0000-4000-8000-0000000ee101',
    'quantity', 1, 'quantity_in_base_unit', 1000, 'total_paid', 40000
  )),
  '[]'::jsonb,
  '[{"month": "2019-08-01", "warned_80": true, "warned_100": true}]'::jsonb
);

select 'case 9a — the purchase is in and both marks with it' as case,
       (select count(*) from public.purchase
         where id = '00000000-0000-4000-8000-0000000aa199') = 1
         and (select warned_100_at is not null
                from public.spending_cap_alert
               where month = date '2019-08-01') as expected_true;

-- And the resend that arrives twice writes NOTHING: the `if not found` path
-- returns before `apply_cap_alerts`, so a month already marked is not
-- re-marked over a spending that was read before the first send.
select public.apply_cap_alerts(
  '[{"month": "2019-08-01", "warned_80": false, "warned_100": false}]'::jsonb
);

select public.create_purchase(
  jsonb_build_object(
    'id', '00000000-0000-4000-8000-0000000aa199',
    'purchase_date', '2019-08-20',
    'store_id', '00000000-0000-4000-8000-0000000ff101',
    'registered_by', 'Leandro'
  ),
  jsonb_build_array(jsonb_build_object(
    'id', '00000000-0000-4000-8000-000000011198',
    'product_id', '00000000-0000-4000-8000-0000000ee101',
    'quantity', 1, 'quantity_in_base_unit', 1000, 'total_paid', 40000
  )),
  '[]'::jsonb,
  '[{"month": "2019-08-01", "warned_80": true, "warned_100": true}]'::jsonb
);

select 'case 9b — the resend marks nothing' as case,
       warned_80_at is null and warned_100_at is null as expected_true
from public.spending_cap_alert where month = date '2019-08-01';

rollback to savepoint before_purchase;

select 'case 9c — the rollback took the purchase and the mark together'
         as case,
       (select count(*) from public.purchase
         where id = '00000000-0000-4000-8000-0000000aa199') = 0 as expected_true;

-- ── 10. same_day_types finds the OTHER person's type ────────────────────
-- Two purchases of 10/08/2019: milk Italac by Leandro and milk Piracanjuba by
-- esposa. The comparison is on the TYPE, so different brands still match.
select 'case 10 — the other person''s milk is found, by type' as case,
       jsonb_array_length(r) = 1
         and (r->0->>'name') = 'Check Leite' as expected_true
from (
  select public.same_day_types(
    date '2019-08-10', 'Leandro',
    array['00000000-0000-4000-8000-0000000bb101']::uuid[]
  ) as r
) s;

-- …and one's OWN purchase never warns: asking as 'esposa' finds Leandro's,
-- never her own, and asking with a label nobody used finds both — one row,
-- because the aggregate is `distinct` on the type.
select 'case 10b — asking as the other side finds the counterpart' as case,
       jsonb_array_length(r) = 1 as expected_true
from (
  select public.same_day_types(
    date '2019-08-10', 'esposa',
    array['00000000-0000-4000-8000-0000000bb101']::uuid[]
  ) as r
) s;

select 'case 10c — a type nobody bought that day is not returned' as case,
       jsonb_array_length(r) = 0 as expected_true
from (
  select public.same_day_types(
    date '2019-08-10', 'Leandro',
    array['00000000-0000-4000-8000-0000000bb102']::uuid[]
  ) as r
) s;

-- ── 11. A day with nothing answers `[]`, never null ─────────────────────
select 'case 11 — an empty day is an empty array, not null' as case,
       r is not null and jsonb_typeof(r) = 'array'
         and jsonb_array_length(r) = 0 as expected_true
from (
  select public.same_day_types(
    date '2019-08-11', 'Leandro',
    array['00000000-0000-4000-8000-0000000bb101']::uuid[]
  ) as r
) s;

-- …and so does `cap_states` with an empty request.
select 'case 11b — cap_states of nothing is [], never null' as case,
       public.cap_states('[]'::jsonb) = '[]'::jsonb as expected_true;

-- ── 12. The spending is bigint, not numeric ─────────────────────────────
-- `sum()` over `bigint` returns `numeric`, and `numeric` inside `jsonb` can
-- arrive as `120000.00` — which `Money.fromJson` would then have to guess at.
select 'case 12 — spent has no decimal point' as case,
       (r->0->>'spent') not like '%.%' as expected_true
from (
  select public.cap_states(
    '[{"month": "2019-08-01", "last_day": "2019-08-31"}]'::jsonb
  ) as r
) s;

rollback;
