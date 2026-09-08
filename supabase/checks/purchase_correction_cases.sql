-- Not a migration: the cases of `update_purchase` and `delete_purchase`, run
-- by hand against a throwaway Postgres 17 (`uv run tool/local_dev/setup.py
-- --reset`) because the Supabase projects do not exist yet (pendency A1).
--
-- Everything happens inside ONE transaction that is rolled back at the end,
-- so the file can be run again over a seeded database without dirtying it.
--
-- Each block prints a line whose expected value is written next to it. A line
-- that comes back different is the failure — there is no assertion framework
-- here, and adding one would mean a second implementation of the schema.
--
-- It is the twin of `purchase_write_cases.sql`: that one is the way in, this
-- one is the way back.

begin;

-- ── Fixtures ────────────────────────────────────────────────────────────
-- Its own catalog, so the file does not depend on what the seed happens to
-- hold. The ids are the same shape as the write file's, one letter apart.
insert into public.category (id, name)
values ('00000000-0000-4000-8000-0000000000d1', 'Undo Bebidas');

insert into public.product_type (id, name, category_id, base_unit)
values (
  '00000000-0000-4000-8000-0000000000d2',
  'Undo Leite',
  '00000000-0000-4000-8000-0000000000d1',
  'milliliter'
);

insert into public.product_registration (id, product_type_id, selling_mode)
values (
  '00000000-0000-4000-8000-0000000000d3',
  '00000000-0000-4000-8000-0000000000d2',
  'by_piece'
);

insert into public.product (
  id, product_registration_id, piece_count, piece_size, piece_size_unit,
  total_content
)
values (
  '00000000-0000-4000-8000-0000000000d4',
  '00000000-0000-4000-8000-0000000000d3',
  1, 1000, 'milliliter', 1000
);

insert into public.store (id, name) values
  ('00000000-0000-4000-8000-0000000000d5', 'Undo Mercado'),
  ('00000000-0000-4000-8000-0000000000d6', 'Undo Feira');

-- Three list items of the same type:
--   e1 — asks for 6 L, and the purchase below closes it;
--   e2 — no quantity, marked "não encontrei", closed by a zero-amount row;
--   e3 — asks for 2 L, closed by the purchase and then REMOVED BY HAND.
insert into public.shopping_list_item (
  id, product_type_id, quantity, entered_on, not_found
)
values
  (
    '00000000-0000-4000-8000-0000000000e1',
    '00000000-0000-4000-8000-0000000000d2',
    6000, date '2026-08-01', false
  ),
  (
    '00000000-0000-4000-8000-0000000000e2',
    '00000000-0000-4000-8000-0000000000d2',
    null, date '2026-08-01', true
  ),
  (
    '00000000-0000-4000-8000-0000000000e3',
    '00000000-0000-4000-8000-0000000000d2',
    2000, date '2026-08-01', false
  );

-- The purchase to be corrected: 8 L, closing all three.
select 'fixture — the purchase to correct' as case,
       public.create_purchase(
         jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f1',
           'purchase_date', '2026-08-18',
           'store_id', '00000000-0000-4000-8000-0000000000d5',
           'registered_by', 'Leandro'
         ),
         jsonb_build_array(jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f2',
           'product_id', '00000000-0000-4000-8000-0000000000d4',
           'quantity', 8, 'quantity_in_base_unit', 8000, 'total_paid', 4800
         )),
         jsonb_build_array(
           jsonb_build_object(
             'purchase_item_id', '00000000-0000-4000-8000-0000000000f2',
             'shopping_list_item_id', '00000000-0000-4000-8000-0000000000e1',
             'quantity_written_off', 6000,
             'cleared_not_found', false, 'fulfills', true
           ),
           jsonb_build_object(
             'purchase_item_id', '00000000-0000-4000-8000-0000000000f2',
             'shopping_list_item_id', '00000000-0000-4000-8000-0000000000e3',
             'quantity_written_off', 2000,
             'cleared_not_found', false, 'fulfills', true
           ),
           jsonb_build_object(
             'purchase_item_id', '00000000-0000-4000-8000-0000000000f2',
             'shopping_list_item_id', '00000000-0000-4000-8000-0000000000e2',
             'quantity_written_off', 0,
             'cleared_not_found', true, 'fulfills', true
           )
         ),
         '[]'::jsonb
       ) as result;  -- expected: {"already_registered": false, ...}

-- ── 1. A purchase that does not exist raises P0002 and writes nothing ────
do $$
begin
  perform public.update_purchase(
    jsonb_build_object(
      'id', '00000000-0000-4000-8000-00000000ffff',
      'purchase_date', '2026-08-19',
      'store_id', '00000000-0000-4000-8000-0000000000d5'
    ),
    '[]'::jsonb, '[]'::jsonb, '[]'::jsonb,
    '[]'::jsonb
  );
  raise notice 'case 1 — FAILED: a missing purchase was accepted';
exception when no_data_found then
  raise notice 'case 1 — ok: missing purchase raised P0002';
end;
$$;

-- ── 2. Correcting 8 L to 2 L reopens the item with 4 L still to buy ──────
-- `p_restored` is what `undoWriteOffs` computed: e1 back to open, e3 back to
-- open, e2 back to open AND with the "não encontrei" mark on again. The new
-- write-off then takes 2 L of e1 without closing it.
--
-- Note the `fulfilled_on` key travelling PRESENT with a null value: an
-- omitted key would leave the item closed, and in silence.
select 'case 2 — correcting 8 L to 2 L' as case,
       public.update_purchase(
         jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f1',
           'purchase_date', '2026-08-18',
           'store_id', '00000000-0000-4000-8000-0000000000d5'
         ),
         jsonb_build_array(jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f3',
           'product_id', '00000000-0000-4000-8000-0000000000d4',
           'quantity', 2, 'quantity_in_base_unit', 2000, 'total_paid', 1200
         )),
         jsonb_build_array(jsonb_build_object(
           'purchase_item_id', '00000000-0000-4000-8000-0000000000f3',
           'shopping_list_item_id', '00000000-0000-4000-8000-0000000000e1',
           'quantity_written_off', 2000,
           'cleared_not_found', false, 'fulfills', false
         )),
         jsonb_build_array(
           jsonb_build_object(
             'id', '00000000-0000-4000-8000-0000000000e1',
             'fulfilled_on', null, 'not_found', false
           ),
           jsonb_build_object(
             'id', '00000000-0000-4000-8000-0000000000e2',
             'fulfilled_on', null, 'not_found', true
           ),
           jsonb_build_object(
             'id', '00000000-0000-4000-8000-0000000000e3',
             'fulfilled_on', null, 'not_found', false
           )
         ),
         '[]'::jsonb
       ) as returns_void;
-- expected: an EMPTY cell. `void` renders as '' in a target list and is not
-- NULL, so `is null` here would print f and mean nothing.

select 'case 2 — the balance and the marks' as case,
       (select fulfilled_on from public.shopping_list_item
         where id = '00000000-0000-4000-8000-0000000000e1') is null
         as e1_back_on_the_list,
       (select coalesce(sum(quantity_written_off), 0)
          from public.list_write_off
         where shopping_list_item_id = '00000000-0000-4000-8000-0000000000e1')
         = 2000 as e1_owes_2_of_6,
       (select not_found from public.shopping_list_item
         where id = '00000000-0000-4000-8000-0000000000e2') = true
         as e2_not_found_is_back,
       (select count(*) from public.purchase_item
         where purchase_id = '00000000-0000-4000-8000-0000000000f1') = 1
         as one_item_left;
-- expected: t | t | t | t

-- ── 3. The same correction twice ends in the same state ──────────────────
-- It is what proves that undoing-and-reapplying is closed: nothing
-- accumulates, because step 1 always starts from the trail on disk.
select 'case 3 — same correction again' as case,
       public.update_purchase(
         jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f1',
           'purchase_date', '2026-08-18',
           'store_id', '00000000-0000-4000-8000-0000000000d5'
         ),
         jsonb_build_array(jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f4',
           'product_id', '00000000-0000-4000-8000-0000000000d4',
           'quantity', 2, 'quantity_in_base_unit', 2000, 'total_paid', 1200
         )),
         jsonb_build_array(jsonb_build_object(
           'purchase_item_id', '00000000-0000-4000-8000-0000000000f4',
           'shopping_list_item_id', '00000000-0000-4000-8000-0000000000e1',
           'quantity_written_off', 2000,
           'cleared_not_found', false, 'fulfills', false
         )),
         jsonb_build_array(jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000e1',
           'fulfilled_on', null, 'not_found', false
         )),
         '[]'::jsonb
       ) as returns_void;  -- expected: an empty cell

select 'case 3 — nothing accumulated' as case,
       (select count(*) from public.list_write_off
         where shopping_list_item_id = '00000000-0000-4000-8000-0000000000e1')
         = 1 as one_row_only,
       (select coalesce(sum(quantity_written_off), 0)
          from public.list_write_off
         where shopping_list_item_id = '00000000-0000-4000-8000-0000000000e1')
         = 2000 as still_2000;
-- expected: t | t

-- ── 7. `removed_on` is never touched by the undo ─────────────────────────
-- e3 is removed by hand, and then a correction sends its id in `p_restored`.
-- The item must NOT come back: a purchase can only resurrect what IT took,
-- and a human gesture in between wins (D1).
update public.shopping_list_item
   set removed_on = date '2026-08-20'
 where id = '00000000-0000-4000-8000-0000000000e3';

select 'case 7 — a hand-removed item is not resurrected' as case,
       public.update_purchase(
         jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f1',
           'purchase_date', '2026-08-19',
           'store_id', '00000000-0000-4000-8000-0000000000d6'
         ),
         jsonb_build_array(jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f5',
           'product_id', '00000000-0000-4000-8000-0000000000d4',
           'quantity', 2, 'quantity_in_base_unit', 2000, 'total_paid', 1300
         )),
         '[]'::jsonb,
         jsonb_build_array(
           jsonb_build_object(
             'id', '00000000-0000-4000-8000-0000000000e1',
             'fulfilled_on', null, 'not_found', false
           ),
           jsonb_build_object(
             'id', '00000000-0000-4000-8000-0000000000e3',
             'fulfilled_on', null, 'not_found', false
           )
         ),
         '[]'::jsonb
       ) as returns_void;  -- expected: an empty cell

select 'case 7 — removed_on survived, and the header changed' as case,
       (select removed_on from public.shopping_list_item
         where id = '00000000-0000-4000-8000-0000000000e3')
         = date '2026-08-20' as still_removed,
       (select purchase_date from public.purchase
         where id = '00000000-0000-4000-8000-0000000000f1')
         = date '2026-08-19' as date_corrected,
       (select store_id from public.purchase
         where id = '00000000-0000-4000-8000-0000000000f1')
         = '00000000-0000-4000-8000-0000000000d6' as store_corrected,
       (select registered_by from public.purchase
         where id = '00000000-0000-4000-8000-0000000000f1') = 'Leandro'
         as author_untouched;
-- expected: t | t | t | t

-- ── 6. A failure in the middle undoes everything ─────────────────────────
-- A trail pointing at a list item that does not exist: neither the corrected
-- header nor the new items may survive.
do $$
begin
  perform public.update_purchase(
    jsonb_build_object(
      'id', '00000000-0000-4000-8000-0000000000f1',
      'purchase_date', '2026-07-01',
      'store_id', '00000000-0000-4000-8000-0000000000d5'
    ),
    jsonb_build_array(jsonb_build_object(
      'id', '00000000-0000-4000-8000-0000000000f6',
      'product_id', '00000000-0000-4000-8000-0000000000d4',
      'quantity', 9, 'quantity_in_base_unit', 9000, 'total_paid', 9900
    )),
    jsonb_build_array(jsonb_build_object(
      'purchase_item_id', '00000000-0000-4000-8000-0000000000f6',
      'shopping_list_item_id', '00000000-0000-4000-8000-000000000eee',
      'quantity_written_off', 1000,
      'cleared_not_found', false, 'fulfills', false
    )),
    '[]'::jsonb,
    '[]'::jsonb
  );
  raise notice 'case 6 — FAILED: a dangling write-off was accepted';
exception when foreign_key_violation then
  raise notice 'case 6 — ok: the whole correction rolled back';
end;
$$;

select 'case 6 — nothing of the failed correction survived' as case,
       (select purchase_date from public.purchase
         where id = '00000000-0000-4000-8000-0000000000f1')
         = date '2026-08-19' as date_unchanged,
       not exists (
         select 1 from public.purchase_item
          where id = '00000000-0000-4000-8000-0000000000f6'
       ) as item_not_written;
-- expected: t | t

-- ── 4 and 5. Deleting gives the list back, and takes the trail with it ───
-- First put e1 back into the state a purchase leaves it in, so the delete has
-- something to give back.
select 'case 4 — a purchase to delete' as case,
       public.create_purchase(
         jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f7',
           'purchase_date', '2026-08-21',
           'store_id', '00000000-0000-4000-8000-0000000000d5',
           'registered_by', 'esposa'
         ),
         jsonb_build_array(jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000f8',
           'product_id', '00000000-0000-4000-8000-0000000000d4',
           'quantity', 4, 'quantity_in_base_unit', 4000, 'total_paid', 2600
         )),
         jsonb_build_array(jsonb_build_object(
           'purchase_item_id', '00000000-0000-4000-8000-0000000000f8',
           'shopping_list_item_id', '00000000-0000-4000-8000-0000000000e2',
           'quantity_written_off', 0,
           'cleared_not_found', true, 'fulfills', true
         )),
         '[]'::jsonb
       ) as result;

select 'case 4 — delete_purchase gives it back' as case,
       public.delete_purchase(
         '00000000-0000-4000-8000-0000000000f7',
         jsonb_build_array(jsonb_build_object(
           'id', '00000000-0000-4000-8000-0000000000e2',
           'fulfilled_on', null, 'not_found', true
         )),
         '[]'::jsonb
       ) as returns_void;  -- expected: an empty cell

select 'case 4 — item, balance and the not-found mark are back' as case,
       (select fulfilled_on from public.shopping_list_item
         where id = '00000000-0000-4000-8000-0000000000e2') is null
         as back_on_the_list,
       (select not_found from public.shopping_list_item
         where id = '00000000-0000-4000-8000-0000000000e2') = true
         as not_found_restored;
-- expected: t | t

select 'case 5 — the cascade left no orphan' as case,
       not exists (
         select 1 from public.purchase
          where id = '00000000-0000-4000-8000-0000000000f7'
       ) as purchase_gone,
       not exists (
         select 1 from public.purchase_item
          where purchase_id = '00000000-0000-4000-8000-0000000000f7'
       ) as items_gone,
       not exists (
         select 1 from public.list_write_off
          where purchase_item_id = '00000000-0000-4000-8000-0000000000f8'
       ) as trail_gone;
-- expected: t | t | t

rollback;
