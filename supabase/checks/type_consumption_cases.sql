-- Not a migration: the cases of `type_consumption`, run by hand against a
-- throwaway Postgres 17 (`uv run tool/local_dev/setup.py --reset`) because the
-- Supabase projects do not exist yet (pendency A1).
--
-- Everything happens inside ONE transaction that is rolled back at the end, so
-- the file can be run again over a seeded database without dirtying it.
--
-- Each block prints a line whose expected value is written next to it. A line
-- that comes back different is the failure — there is no assertion framework
-- here, and adding one would mean a second implementation of the schema.
--
-- The intervals under test are the ones a phone with a clock on 15/08/2026
-- would compute: the CLOSED window 01/05 → 31/07 and the month in progress
-- 01/08 → 31/08. Neither is computed here — no now(), no current_date.

begin;

-- ── Fixtures ────────────────────────────────────────────────────────────
-- Its own catalog, so the file does not depend on what the seed happens to
-- hold. Ids are hex-only on purpose: `uuid` refuses anything else — the trap
-- that broke `purchase_write_cases.sql` and `purchase_correction_cases.sql`
-- from the day they were born.
insert into public.category (id, name) values
  ('00000000-0000-4000-8000-00000000ca11', 'Check Consumo Carnes'),
  ('00000000-0000-4000-8000-00000000ca12', 'Check Consumo Mercearia');

insert into public.product_type (id, name, category_id, base_unit) values
  -- Bought in the window AND in the month: case 9, the crossed-sum one.
  (
    '00000000-0000-4000-8000-00000000bb11', 'Check Acém',
    '00000000-0000-4000-8000-00000000ca11', 'kilogram'
  ),
  -- Bought ONLY in the month in progress: case 2.
  (
    '00000000-0000-4000-8000-00000000bb12', 'Check Iogurte',
    '00000000-0000-4000-8000-00000000ca12', 'liter'
  ),
  -- Bought only OUTSIDE both intervals: case 3.
  (
    '00000000-0000-4000-8000-00000000bb13', 'Check Esquecido',
    '00000000-0000-4000-8000-00000000ca12', 'kilogram'
  ),
  -- First purchase before the window, one purchase inside it: case 4, the
  -- café of the requirement.
  (
    '00000000-0000-4000-8000-00000000bb14', 'Check Café',
    '00000000-0000-4000-8000-00000000ca12', 'kilogram'
  ),
  -- Two brands under one type: case 5.
  (
    '00000000-0000-4000-8000-00000000bb15', 'Check Sabão',
    '00000000-0000-4000-8000-00000000ca12', 'kilogram'
  ),
  -- Deactivated, for case 6: the flag travels and Dart is what discards.
  (
    '00000000-0000-4000-8000-00000000bb16', 'Check Desativado',
    '00000000-0000-4000-8000-00000000ca11', 'kilogram'
  ),
  -- Bought exactly ON the two boundaries: case 10.
  (
    '00000000-0000-4000-8000-00000000bb17', 'Check Borda',
    '00000000-0000-4000-8000-00000000ca11', 'unit'
  );
update public.product_type set active = false
where id = '00000000-0000-4000-8000-00000000bb16';

insert into public.brand (id, name) values
  ('00000000-0000-4000-8000-00000000bd11', 'Check Omo'),
  ('00000000-0000-4000-8000-00000000bd12', 'Check Tixan');

insert into public.product_registration
  (id, product_type_id, brand_id, description, selling_mode, active)
values
  ('00000000-0000-4000-8000-00000000dd11',
   '00000000-0000-4000-8000-00000000bb11', null, '', 'by_weight', true),
  ('00000000-0000-4000-8000-00000000dd12',
   '00000000-0000-4000-8000-00000000bb12', null, '', 'by_piece', true),
  ('00000000-0000-4000-8000-00000000dd13',
   '00000000-0000-4000-8000-00000000bb13', null, '', 'by_weight', true),
  ('00000000-0000-4000-8000-00000000dd14',
   '00000000-0000-4000-8000-00000000bb14', null, '', 'by_weight', true),
  -- The two brands of the same type — case 5 sums them into ONE line.
  ('00000000-0000-4000-8000-00000000dd15',
   '00000000-0000-4000-8000-00000000bb15',
   '00000000-0000-4000-8000-00000000bd11', '', 'by_piece', true),
  ('00000000-0000-4000-8000-00000000dd16',
   '00000000-0000-4000-8000-00000000bb15',
   '00000000-0000-4000-8000-00000000bd12', '', 'by_piece', true),
  ('00000000-0000-4000-8000-00000000dd17',
   '00000000-0000-4000-8000-00000000bb16', null, '', 'by_weight', true),
  ('00000000-0000-4000-8000-00000000dd18',
   '00000000-0000-4000-8000-00000000bb17', null, '', 'by_piece', true);

insert into public.product
  (id, product_registration_id, piece_count, piece_size, piece_size_unit,
   total_content)
values
  ('00000000-0000-4000-8000-00000000ee11',
   '00000000-0000-4000-8000-00000000dd11', null, null, null, null),
  ('00000000-0000-4000-8000-00000000ee12',
   '00000000-0000-4000-8000-00000000dd12', 1, 1000, 'milliliter', 1000),
  ('00000000-0000-4000-8000-00000000ee13',
   '00000000-0000-4000-8000-00000000dd13', null, null, null, null),
  ('00000000-0000-4000-8000-00000000ee14',
   '00000000-0000-4000-8000-00000000dd14', null, null, null, null),
  ('00000000-0000-4000-8000-00000000ee15',
   '00000000-0000-4000-8000-00000000dd15', 1, 4000, 'gram', 4000),
  ('00000000-0000-4000-8000-00000000ee16',
   '00000000-0000-4000-8000-00000000dd16', 1, 4000, 'gram', 4000),
  ('00000000-0000-4000-8000-00000000ee17',
   '00000000-0000-4000-8000-00000000dd17', null, null, null, null),
  ('00000000-0000-4000-8000-00000000ee18',
   '00000000-0000-4000-8000-00000000dd18', 1, 1, 'unit', 1);

insert into public.store (id, name)
values ('00000000-0000-4000-8000-00000000ff11', 'Check Mercado Consumo');

-- The days this file needs, and every one of them is a literal: no now(), no
-- current_date, and no arithmetic on a clock.
insert into public.purchase (id, purchase_date, store_id, registered_by) values
  -- Inside the closed window.
  ('00000000-0000-4000-8000-00000000ab11', date '2026-05-12',
   '00000000-0000-4000-8000-00000000ff11', 'Check'),
  ('00000000-0000-4000-8000-00000000ab12', date '2026-06-10',
   '00000000-0000-4000-8000-00000000ff11', 'Check'),
  ('00000000-0000-4000-8000-00000000ab13', date '2026-07-15',
   '00000000-0000-4000-8000-00000000ff11', 'Check'),
  -- Inside the month in progress.
  ('00000000-0000-4000-8000-00000000ab14', date '2026-08-10',
   '00000000-0000-4000-8000-00000000ff11', 'Check'),
  -- Before both intervals — the first purchase of the café, and the only
  -- purchase of the forgotten type.
  ('00000000-0000-4000-8000-00000000ab15', date '2026-03-10',
   '00000000-0000-4000-8000-00000000ff11', 'Check'),
  -- Exactly ON `p_window_to` and exactly ON `p_month_from`: both ends are
  -- closed, and case 10 is what says so.
  ('00000000-0000-4000-8000-00000000ab16', date '2026-07-31',
   '00000000-0000-4000-8000-00000000ff11', 'Check'),
  ('00000000-0000-4000-8000-00000000ab17', date '2026-08-01',
   '00000000-0000-4000-8000-00000000ff11', 'Check');

insert into public.purchase_item
  (id, purchase_id, product_id, quantity, quantity_in_base_unit, total_paid)
values
  -- Acém: 12 + 10 + 2 kg in the window, 6 kg in the month.
  ('00000000-0000-4000-8000-0000000012a1',
   '00000000-0000-4000-8000-00000000ab11',
   '00000000-0000-4000-8000-00000000ee11', 12000, 12000, 38400),
  ('00000000-0000-4000-8000-0000000012a2',
   '00000000-0000-4000-8000-00000000ab12',
   '00000000-0000-4000-8000-00000000ee11', 10000, 10000, 32000),
  ('00000000-0000-4000-8000-0000000012a3',
   '00000000-0000-4000-8000-00000000ab13',
   '00000000-0000-4000-8000-00000000ee11', 2000, 2000, 6000),
  ('00000000-0000-4000-8000-0000000012a4',
   '00000000-0000-4000-8000-00000000ab14',
   '00000000-0000-4000-8000-00000000ee11', 6000, 6000, 19200),
  -- Iogurte: only in the month in progress.
  ('00000000-0000-4000-8000-0000000012a5',
   '00000000-0000-4000-8000-00000000ab14',
   '00000000-0000-4000-8000-00000000ee12', 3, 3000, 1800),
  -- Esquecido: only in March, outside both intervals.
  ('00000000-0000-4000-8000-0000000012a6',
   '00000000-0000-4000-8000-00000000ab15',
   '00000000-0000-4000-8000-00000000ee13', 1000, 1000, 2000),
  -- Café: first bought in March, and once inside the window in June.
  ('00000000-0000-4000-8000-0000000012a7',
   '00000000-0000-4000-8000-00000000ab15',
   '00000000-0000-4000-8000-00000000ee14', 1000, 1000, 3200),
  ('00000000-0000-4000-8000-0000000012a8',
   '00000000-0000-4000-8000-00000000ab12',
   '00000000-0000-4000-8000-00000000ee14', 2000, 2000, 6600),
  -- Sabão: two brands, both inside the window, one line expected.
  ('00000000-0000-4000-8000-0000000012a9',
   '00000000-0000-4000-8000-00000000ab12',
   '00000000-0000-4000-8000-00000000ee15', 2, 8000, 16000),
  ('00000000-0000-4000-8000-0000000012b1',
   '00000000-0000-4000-8000-00000000ab13',
   '00000000-0000-4000-8000-00000000ee16', 2, 8000, 16000),
  -- Desativado: bought inside the window, and it must still come back.
  ('00000000-0000-4000-8000-0000000012b2',
   '00000000-0000-4000-8000-00000000ab11',
   '00000000-0000-4000-8000-00000000ee17', 1000, 1000, 2500),
  -- Borda: one purchase exactly on 31/07 and one exactly on 01/08.
  ('00000000-0000-4000-8000-0000000012b3',
   '00000000-0000-4000-8000-00000000ab16',
   '00000000-0000-4000-8000-00000000ee18', 7, 7, 700),
  ('00000000-0000-4000-8000-0000000012b4',
   '00000000-0000-4000-8000-00000000ab17',
   '00000000-0000-4000-8000-00000000ee18', 9, 9, 900);

-- The answer under test, computed once and read by every case below. The four
-- dates are what a phone whose clock says 15/08/2026 would send.
create temporary table check_consumption on commit drop as
select public.type_consumption(
  date '2026-05-01', date '2026-07-31',
  date '2026-08-01', date '2026-08-31'
) as r;

-- ── 1. The three closed months add up in `consumed_in_window` ───────────
select 'case 1 — the window sums the three closed months' as case,
       (t->>'consumed_in_window')::bigint = 24000 as expected_true
from check_consumption, jsonb_array_elements(r) t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb11';

-- ── 2. Bought ONLY in the month in progress ────────────────────────────
-- It has to APPEAR — it is the type the suggestion most needs to offer — with
-- nothing in the window. This is what the `or` of the `where` is for.
select 'case 2 — a type born this month appears, with window zero' as case,
       count(*) = 1
         and max((t->>'consumed_in_window')::bigint) = 0
         and max((t->>'consumed_in_month')::bigint) = 3000 as expected_true
from check_consumption, jsonb_array_elements(r) t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb12';

-- ── 3. Bought outside BOTH intervals: it does not appear ────────────────
select 'case 3 — a type bought outside both intervals is absent' as case,
       count(*) = 0 as expected_true
from check_consumption, jsonb_array_elements(r) t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb13';

-- ── 4. `first_purchase_on` ignores both intervals ───────────────────────
-- The café was first bought in March, outside the window, and it is that date
-- that makes Dart divide by three. A `min()` filtered by the interval would
-- answer June and the average would be wrong by a third, in silence.
select 'case 4 — first_purchase_on is the oldest purchase, window or not'
         as case,
       (t->>'first_purchase_on')::date = date '2026-03-10' as expected_true
from check_consumption, jsonb_array_elements(r) t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb14';

-- ── 5. Two brands of one type sum into ONE line ────────────────────────
-- The grouping is by TYPE, which is the level that sums; a second line per
-- registration would halve every average of a two-brand type.
select 'case 5 — two brands of a type come back as one summed line' as case,
       count(*) = 1
         and max((t->>'consumed_in_window')::bigint) = 16000 as expected_true
from check_consumption, jsonb_array_elements(r) t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb15';

-- ── 6. The deactivated type comes back, flagged ────────────────────────
-- Decision E-e: the flag travels and DART discards. The rule "a deactivated
-- type is not suggested" is H10's, and a rule does not live in SQL.
select 'case 6 — a deactivated type is returned with type_active false'
         as case,
       count(*) = 1 and bool_and((t->>'type_active')::boolean is false)
         as expected_true
from check_consumption, jsonb_array_elements(r) t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb16';

-- ── 7. No purchase at all is `[]`, never null ──────────────────────────
-- `jsonb_agg` of zero rows returns NULL. The empty state is a screen to draw,
-- not an error, and `coalesce` is what keeps it that way.
select 'case 7 — an interval with no purchase is an empty array' as case,
       r is not null and jsonb_typeof(r) = 'array'
         and jsonb_array_length(r) = 0 as expected_true
from (
  select public.type_consumption(
    date '2019-01-01', date '2019-03-31',
    date '2019-04-01', date '2019-04-30'
  ) as r
) empty;

-- ── 8. The sums are bigint, not numeric ────────────────────────────────
-- `sum()` over `bigint` returns `numeric`, and `numeric` inside `jsonb` can
-- arrive as `24000.00` — which the Dart cast would then have to guess at.
select 'case 8 — no sum arrives with a decimal point' as case,
       bool_and(t->>'consumed_in_window' not like '%.%'
                and t->>'consumed_in_month' not like '%.%') as expected_true
from check_consumption, jsonb_array_elements(r) t;

-- ── 9. Bought in BOTH intervals: one line, and no crossed sum ──────────
-- The most likely failure of the whole function: the `or` of the `where` lets
-- every row of both intervals in, and it is the two `filter` clauses that keep
-- them apart. A missing `filter` would answer 30000 on both numbers.
select 'case 9 — a type in both intervals is one line, sums not crossed'
         as case,
       count(*) = 1
         and max((t->>'consumed_in_window')::bigint) = 24000
         and max((t->>'consumed_in_month')::bigint) = 6000 as expected_true
from check_consumption, jsonb_array_elements(r) t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb11';

-- ── 10. Both ends of both `between` are inclusive ──────────────────────
-- 31/07 is `p_window_to` and 01/08 is `p_month_from`. An exclusive end would
-- lose the last day of the window and the first day of the month — the two
-- days a purchase is most likely to fall on, at the turn.
select 'case 10 — the boundaries 31/07 and 01/08 are both inside' as case,
       (t->>'consumed_in_window')::bigint = 7
         and (t->>'consumed_in_month')::bigint = 9 as expected_true
from check_consumption, jsonb_array_elements(r) t
where t->>'product_type_id' = '00000000-0000-4000-8000-00000000bb17';

rollback;
