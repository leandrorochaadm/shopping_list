-- Not a migration: the cases of `create_purchase` and of the B6 columns, run
-- by hand against a throwaway Postgres 17 (`uv run tool/local_dev/setup.py
-- --reset`) because the Supabase projects do not exist yet (pendency A1).
--
-- Everything happens inside ONE transaction that is rolled back at the end,
-- so the file can be run again over a seeded database without dirtying it.
--
-- Each block prints a line whose expected value is written next to it. A line
-- that comes back different is the failure — there is no assertion framework
-- here, and adding one would mean a second implementation of the schema.

begin;

-- ── Fixtures ────────────────────────────────────────────────────────────
-- Its own catalog, so the file does not depend on what the seed happens to
-- hold.
insert into public.category (id, name)
values ('00000000-0000-4000-8000-0000000000c1', 'Check Bebidas');

insert into public.product_type (id, name, category_id, base_unit)
values (
  '00000000-0000-4000-8000-0000000000b8'::uuid,
  'Check Leite',
  '00000000-0000-4000-8000-0000000000c1',
  'liter'
);

insert into public.product_registration (id, product_type_id, selling_mode)
values (
  '00000000-0000-4000-8000-0000000000b6',
  '00000000-0000-4000-8000-0000000000b8',
  'by_piece'
);

insert into public.product (
  id, product_registration_id, piece_count, piece_size, piece_size_unit,
  total_content
)
values (
  '00000000-0000-4000-8000-0000000000b5',
  '00000000-0000-4000-8000-0000000000b6',
  1, 1000, 'liter', 1000
);

insert into public.store (id, name) values
  ('00000000-0000-4000-8000-0000000000b7', 'Check Mercado');

-- Two list items of the same type: one asking for 6 L, one with NO quantity
-- and marked "não encontrei".
insert into public.shopping_list_item (
  id, product_type_id, quantity, entered_on, not_found
)
values
  (
    '00000000-0000-4000-8000-0000000000b3',
    '00000000-0000-4000-8000-0000000000b8',
    6000, date '2026-08-01', false
  ),
  (
    '00000000-0000-4000-8000-0000000000b4',
    '00000000-0000-4000-8000-0000000000b8',
    null, date '2026-08-01', true
  );

-- ── 29. `quantity` null is accepted, `quantity = 0` is not ───────────────
-- The nullable quantity is delivery 2's correction to the base schema; it is
-- checked here because H7's write-off is what depends on it.
select 'case 29a — null quantity accepted' as case,
       count(*) = 1 as expected_true
from public.shopping_list_item
where id = '00000000-0000-4000-8000-0000000000b4' and quantity is null;

do $$
begin
  insert into public.shopping_list_item (product_type_id, quantity, entered_on)
  values (
    '00000000-0000-4000-8000-0000000000b8', 0, date '2026-08-01'
  );
  raise notice 'case 29b — FAILED: quantity = 0 was accepted';
exception when check_violation then
  raise notice 'case 29b — ok: quantity = 0 refused';
end;
$$;

-- ── 30. `list_write_off` accepts zero and refuses negative ───────────────
-- The zero row is what closes an item with no quantity; a negative one would
-- be a purchase giving quantity back to the list.
do $$
declare
  v_item uuid;
begin
  insert into public.purchase (id, purchase_date, store_id, registered_by)
  values (
    '00000000-0000-4000-8000-0000000000a0', date '2026-08-18',
    '00000000-0000-4000-8000-0000000000b7', 'check'
  );
  insert into public.purchase_item (
    purchase_id, product_id, quantity, quantity_in_base_unit, total_paid
  )
  values (
    '00000000-0000-4000-8000-0000000000a0',
    '00000000-0000-4000-8000-0000000000b5', 1, 1000, 500
  )
  returning id into v_item;

  insert into public.list_write_off (
    purchase_item_id, shopping_list_item_id, quantity_written_off
  )
  values (v_item, '00000000-0000-4000-8000-0000000000b4', 0);
  raise notice 'case 30a — ok: zero write-off accepted';

  begin
    insert into public.list_write_off (
      purchase_item_id, shopping_list_item_id, quantity_written_off
    )
    values (v_item, '00000000-0000-4000-8000-0000000000b4', -1);
    raise notice 'case 30b — FAILED: negative write-off was accepted';
  exception when check_violation then
    raise notice 'case 30b — ok: negative write-off refused';
  end;
end;
$$;

-- ── 26. The same purchase id twice writes ONE purchase ───────────────────
-- The resend of H8 that arrived twice. The second call has to be a no-op and
-- say so, or the list would be written off a second time.
select 'case 26a — first call' as case,
       public.create_purchase(
         jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000a1',
           'purchase_date', '2026-08-18',
           'store_id', '00000000-0000-4000-8000-0000000000b7',
           'registered_by', 'Leandro'
         ),
         jsonb_build_array(jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000b1',
           'product_id', '00000000-0000-4000-8000-0000000000b5',
           'quantity', 2, 'quantity_in_base_unit', 2000, 'total_paid', 1200
         )),
         jsonb_build_array(
           jsonb_build_object(
             'purchase_item_id', '00000000-0000-4000-8000-0000000000b1',
             'shopping_list_item_id', '00000000-0000-4000-8000-0000000000b3',
             'quantity_written_off', 2000,
             'cleared_not_found', false,
             'fulfills', false
           ),
           jsonb_build_object(
             'purchase_item_id', '00000000-0000-4000-8000-0000000000b1',
             'shopping_list_item_id', '00000000-0000-4000-8000-0000000000b4',
             'quantity_written_off', 0,
             'cleared_not_found', true,
             'fulfills', true
           )
         ),
         '[]'::jsonb
       ) as result;  -- expected: {"already_registered": false, ...}

select 'case 26b — second call, same id' as case,
       public.create_purchase(
         jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000a1',
           'purchase_date', '2026-08-18',
           'store_id', '00000000-0000-4000-8000-0000000000b7',
           'registered_by', 'Leandro'
         ),
         '[]'::jsonb,
         '[]'::jsonb,
         '[]'::jsonb
       ) as result;  -- expected: {"already_registered": true, ...}

select 'case 26c — one purchase, one item, two write-offs' as case,
       (select count(*) from public.purchase
         where id = '00000000-0000-4000-8000-0000000000a1') = 1 as one_purchase,
       (select count(*) from public.purchase_item
         where purchase_id = '00000000-0000-4000-8000-0000000000a1') = 1
         as one_item,
       (select count(*) from public.list_write_off
         where purchase_item_id = '00000000-0000-4000-8000-0000000000b1') = 2
         as two_write_offs;
-- expected: t | t | t

-- ── 31. `fulfills` is a flag, not a column ───────────────────────────────
select 'case 31 — fulfills closed the item and left no column' as case,
       (select fulfilled_on from public.shopping_list_item
         where id = '00000000-0000-4000-8000-0000000000b4')
         = date '2026-08-18' as closed_on_purchase_day,
       (select fulfilled_on from public.shopping_list_item
         where id = '00000000-0000-4000-8000-0000000000b3') is null
         as partial_stays_open,
       (select not_found from public.shopping_list_item
         where id = '00000000-0000-4000-8000-0000000000b4') = false
         as not_found_cleared,
       not exists (
         select 1 from information_schema.columns
         where table_name = 'list_write_off' and column_name = 'fulfills'
       ) as no_fulfills_column;
-- expected: t | t | t | t

-- ── 28. `fulfilled_on` takes the item out of the partial index ───────────
-- And so does `removed_on`: "open" is neither bought nor removed by hand.
update public.shopping_list_item
set removed_on = date '2026-08-19'
where id = '00000000-0000-4000-8000-0000000000b3';

select 'case 28 — the open index sees neither' as case,
       count(*) = 0 as none_open
from public.shopping_list_item
where product_type_id = '00000000-0000-4000-8000-0000000000b8'
  and fulfilled_on is null
  and removed_on is null;
-- expected: t

-- ── 27. A failure in the middle undoes everything ────────────────────────
-- The write-off points at a list item that does not exist. Neither the
-- purchase nor its items may survive — that is the whole reason this is one
-- function and not four PostgREST calls.
do $$
begin
  perform public.create_purchase(
    jsonb_build_object(
      'id', '00000000-0000-4000-8000-0000000000a2',
      'purchase_date', '2026-08-18',
      'store_id', '00000000-0000-4000-8000-0000000000b7',
      'registered_by', 'Leandro'
    ),
    jsonb_build_array(jsonb_build_object(
      'id', '00000000-0000-4000-8000-0000000000b2',
      'product_id', '00000000-0000-4000-8000-0000000000b5',
      'quantity', 1, 'quantity_in_base_unit', 1000, 'total_paid', 600
    )),
    jsonb_build_array(jsonb_build_object(
      'purchase_item_id', '00000000-0000-4000-8000-0000000000b2',
      'shopping_list_item_id', '00000000-0000-4000-8000-00000000dead',
      'quantity_written_off', 1000,
      'cleared_not_found', false,
      'fulfills', false
    )),
    '[]'::jsonb
  );
  raise notice 'case 27 — FAILED: the dangling write-off was accepted';
exception when foreign_key_violation then
  raise notice 'case 27 — ok: refused with foreign_key_violation';
end;
$$;

select 'case 27b — nothing survived the rollback' as case,
       (select count(*) from public.purchase
         where id = '00000000-0000-4000-8000-0000000000a2') = 0
         as no_purchase,
       (select count(*) from public.purchase_item
         where id = '00000000-0000-4000-8000-0000000000b2') = 0 as no_item;
-- expected: t | t

rollback;
