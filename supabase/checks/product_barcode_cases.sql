-- Not a migration: the cases of `product_barcode`, `add_packagings` and of the
-- barcode keys of `create_product_registration`, run by hand against the local
-- Postgres 17 (`uv run tool/local_dev/setup.py`):
--
--   psql -v ON_ERROR_STOP=1 -d shopping_list_dev \
--     -f supabase/checks/product_barcode_cases.sql
--
-- Everything happens inside ONE transaction that is rolled back at the end.
--
-- Every case prints `case N — ok: ...` or `case N — FAILED: ...`, so the check
-- is a `grep`. A refusal case is `ok` only when the EXPECTED constraint fires:
-- another one (`product_packaging_key`, `product_registration_identity_key`)
-- would also raise, and the case would pass for the wrong reason.

begin;

-- ── Fixtures ────────────────────────────────────────────────────────────
insert into public.category (id, name)
values ('00000000-0000-4000-8000-000000000300', 'Check Códigos');

insert into public.product_type (id, name, category_id, base_unit) values
  ('00000000-0000-4000-8000-000000000301', 'Check Refrigerante',
   '00000000-0000-4000-8000-000000000300', 'milliliter'),
  ('00000000-0000-4000-8000-000000000302', 'Check Fruta Seca',
   '00000000-0000-4000-8000-000000000300', 'gram');

insert into public.store (id, name) values
  ('00000000-0000-4000-8000-000000000310', 'Check Mercado A'),
  ('00000000-0000-4000-8000-000000000311', 'Check Mercado B');

-- The registration `add_packagings` is aimed at, with one leaf of its own.
insert into public.product_registration (
  id, product_type_id, description, selling_mode
)
values (
  '00000000-0000-4000-8000-000000000320',
  '00000000-0000-4000-8000-000000000301',
  'Check alvo', 'by_piece'
);

insert into public.product (
  id, product_registration_id, piece_count, piece_size, piece_size_unit,
  total_content
)
values (
  '00000000-0000-4000-8000-000000000321',
  '00000000-0000-4000-8000-000000000320',
  1, 1000, 'milliliter', 1000
);

-- Runs `p_sql` and reports `ok` only when it raises `p_expected`.
create function pg_temp.expect_refusal(
  p_case text, p_sql text, p_expected text
) returns void language plpgsql as $$
declare
  v_constraint text;
begin
  execute p_sql;
  raise notice '% — FAILED: no error raised', p_case;
exception
  when unique_violation or check_violation then
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = p_expected then
      raise notice '% — ok: refused by %', p_case, v_constraint;
    else
      raise notice '% — FAILED: refused by % (expected %)',
        p_case, v_constraint, p_expected;
    end if;
end;
$$;

-- ── case 1 — two codes on one card are two rows, both without a store ───
do $$
declare
  v_result jsonb;
  v_rows integer;
  v_with_store integer;
begin
  v_result := public.create_product_registration(
    '00000000-0000-4000-8000-000000000301', null, 'Check caso 1', 'by_piece',
    '[{"piece_count": 6, "piece_size": 350, "piece_size_unit": "milliliter",
       "total_content": 2100,
       "barcodes": ["07894900011517", "07891000100103"]}]'::jsonb);

  select count(*), count(store_id) into v_rows, v_with_store
  from public.product_barcode
  where code in ('07894900011517', '07891000100103');

  if v_rows = 2 and v_with_store = 0
     and jsonb_array_length(v_result -> 'products' -> 0 -> 'product_barcode') = 2
  then
    raise notice 'case 1 — ok: 2 rows without store, 2 codes in the response';
  else
    raise notice 'case 1 — FAILED: rows %, with store %, response %',
      v_rows, v_with_store, v_result -> 'products' -> 0 -> 'product_barcode';
  end if;
end;
$$;

-- ── case 2 — each code lands on the card it came with ───────────────────
do $$
declare
  v_wrong integer;
  v_total integer;
begin
  perform public.create_product_registration(
    '00000000-0000-4000-8000-000000000301', null, 'Check caso 2', 'by_piece',
    '[{"piece_count": 6, "piece_size": 350, "piece_size_unit": "milliliter",
       "total_content": 2100,
       "barcodes": ["07890000000024", "07890000000031"]},
      {"piece_count": 4, "piece_size": 500, "piece_size_unit": "milliliter",
       "total_content": 2000,
       "barcodes": ["07890000000048", "07890000000055"]}]'::jsonb);

  select count(*),
         count(*) filter (where not (
           (b.code in ('07890000000024', '07890000000031')
              and p.total_content = 2100)
           or (b.code in ('07890000000048', '07890000000055')
              and p.total_content = 2000)))
  into v_total, v_wrong
  from public.product_barcode as b
  join public.product as p on p.id = b.product_id
  where b.code in ('07890000000024', '07890000000031',
                   '07890000000048', '07890000000055');

  if v_total = 4 and v_wrong = 0 then
    raise notice 'case 2 — ok: 4 codes, each on its own card';
  else
    raise notice 'case 2 — FAILED: total %, wrong %', v_total, v_wrong;
  end if;
end;
$$;

-- ── case 3 — a packaging code already in use is refused ─────────────────
select pg_temp.expect_refusal(
  'case 3',
  $q$select public.add_packagings(
    '00000000-0000-4000-8000-000000000320',
    '[{"piece_count": 1, "piece_size": 1500, "piece_size_unit": "milliliter",
       "total_content": 1500, "barcodes": ["07894900011517"]}]'::jsonb)$q$,
  'product_barcode_code_key');

-- ── case 4 — a refused add_packagings leaves no orphan leaf ─────────────
do $$
declare
  v_orphans integer;
begin
  select count(*) into v_orphans
  from public.product
  where product_registration_id = '00000000-0000-4000-8000-000000000320'
    and total_content = 1500;
  if v_orphans = 0 then
    raise notice 'case 4 — ok: no orphan leaf after the refused code';
  else
    raise notice 'case 4 — FAILED: % orphan leaves', v_orphans;
  end if;
end;
$$;

select pg_temp.expect_refusal(
  'case 4b',
  $q$select public.add_packagings(
    '00000000-0000-4000-8000-000000000320',
    '[{"piece_count": 1, "piece_size": 1600, "piece_size_unit": "milliliter",
       "total_content": 1600, "barcodes": ["07890000000079"]},
      {"piece_count": 1, "piece_size": 1700, "piece_size_unit": "milliliter",
       "total_content": 1700, "barcodes": ["07890000000079"]}]'::jsonb)$q$,
  'product_barcode_code_key');

do $$
declare
  v_orphans integer;
begin
  select count(*) into v_orphans
  from public.product
  where product_registration_id = '00000000-0000-4000-8000-000000000320'
    and total_content in (1600, 1700);
  if v_orphans = 0 then
    raise notice 'case 4c — ok: neither leaf of the repeated payload remains';
  else
    raise notice 'case 4c — FAILED: % leaves remain', v_orphans;
  end if;
end;
$$;

-- ── case 5 — weight-sold: `{}` still works, scale code needs a store ────
do $$
declare
  v_result jsonb;
  v_leaf_packaging integer;
  v_codes integer;
  v_store uuid;
begin
  v_result := public.create_product_registration(
    '00000000-0000-4000-8000-000000000302', null, 'Check caso 5a',
    'by_weight', '[{}]'::jsonb);
  select count(*) into v_leaf_packaging
  from public.product
  where id = (v_result -> 'products' -> 0 ->> 'id')::uuid
    and total_content is null;
  select count(*) into v_codes
  from public.product_barcode
  where product_id = (v_result -> 'products' -> 0 ->> 'id')::uuid;

  if v_leaf_packaging = 1 and v_codes = 0 then
    raise notice 'case 5 — ok: {} accepted, 1 leaf, 0 codes';
  else
    raise notice 'case 5 — FAILED: leaves %, codes %', v_leaf_packaging, v_codes;
  end if;

  v_result := public.create_product_registration(
    '00000000-0000-4000-8000-000000000302', null, 'Check caso 5b',
    'by_weight',
    '[{"scale_codes": [{"store_id": "00000000-0000-4000-8000-000000000310",
                        "code": "2822521"}]}]'::jsonb);
  select store_id into v_store
  from public.product_barcode
  where product_id = (v_result -> 'products' -> 0 ->> 'id')::uuid
    and code = '2822521';

  if v_store = '00000000-0000-4000-8000-000000000310' then
    raise notice 'case 5b — ok: scale code stored with store A';
  else
    raise notice 'case 5b — FAILED: store %', v_store;
  end if;
end;
$$;

-- ── case 6 — same scale code: two stores ok, same store refused ─────────
do $$
begin
  perform public.create_product_registration(
    '00000000-0000-4000-8000-000000000302', null, 'Check caso 6a',
    'by_weight',
    '[{"scale_codes": [{"store_id": "00000000-0000-4000-8000-000000000310",
                        "code": "2822522"}]}]'::jsonb);
  perform public.create_product_registration(
    '00000000-0000-4000-8000-000000000302', null, 'Check caso 6b',
    'by_weight',
    '[{"scale_codes": [{"store_id": "00000000-0000-4000-8000-000000000311",
                        "code": "2822522"}]}]'::jsonb);
  raise notice 'case 6 — ok: same scale code accepted in stores A and B';
exception
  when others then
    raise notice 'case 6 — FAILED: %', sqlerrm;
end;
$$;

select pg_temp.expect_refusal(
  'case 6c',
  $q$select public.create_product_registration(
    '00000000-0000-4000-8000-000000000302', null, 'Check caso 6c',
    'by_weight',
    '[{"scale_codes": [{"store_id": "00000000-0000-4000-8000-000000000310",
                        "code": "2822522"}]}]'::jsonb)$q$,
  'product_barcode_code_key');

-- ── case 7 — the check constraints ──────────────────────────────────────
select pg_temp.expect_refusal('case 7a — 2… without store',
  $q$insert into public.product_barcode (product_id, code)
     values ('00000000-0000-4000-8000-000000000321', '2822521')$q$,
  'product_barcode_in_store_has_store');
select pg_temp.expect_refusal('case 7b — 02… without store',
  $q$insert into public.product_barcode (product_id, code)
     values ('00000000-0000-4000-8000-000000000321', '02822521001605')$q$,
  'product_barcode_in_store_has_store');
select pg_temp.expect_refusal('case 7c — UPC-A 2… without store',
  $q$insert into public.product_barcode (product_id, code)
     values ('00000000-0000-4000-8000-000000000321', '00212345678909')$q$,
  'product_barcode_in_store_has_store');
select pg_temp.expect_refusal('case 7d — factory code with store',
  $q$insert into public.product_barcode (product_id, store_id, code)
     values ('00000000-0000-4000-8000-000000000321',
             '00000000-0000-4000-8000-000000000310', '07894900011517')$q$,
  'product_barcode_in_store_has_store');
select pg_temp.expect_refusal('case 7e — non-digits',
  $q$insert into public.product_barcode (product_id, code)
     values ('00000000-0000-4000-8000-000000000321', '789ABC')$q$,
  'product_barcode_code_digits');

-- ── case 8 — the old payload (no `barcodes` key) is still accepted ──────
do $$
declare
  v_result jsonb;
  v_added jsonb;
  v_codes integer;
begin
  v_result := public.create_product_registration(
    '00000000-0000-4000-8000-000000000301', null, 'Check caso 8', 'by_piece',
    '[{"piece_count": 1, "piece_size": 1800, "piece_size_unit": "milliliter",
       "total_content": 1800}]'::jsonb);
  v_added := public.add_packagings(
    '00000000-0000-4000-8000-000000000320',
    '[{"piece_count": 1, "piece_size": 1850, "piece_size_unit": "milliliter",
       "total_content": 1850}]'::jsonb);

  select count(*) into v_codes
  from public.product_barcode
  where product_id in ((v_result -> 'products' -> 0 ->> 'id')::uuid,
                       (v_added -> 0 ->> 'id')::uuid);

  if jsonb_array_length(v_result -> 'products') = 1
     and jsonb_array_length(v_added) = 1 and v_codes = 0 then
    raise notice 'case 8 — ok: old payload accepted by both, 0 codes';
  else
    raise notice 'case 8 — FAILED: codes %', v_codes;
  end if;
end;
$$;

-- ── case 9 — releasing a code is a real DELETE, and frees it ────────────
do $$
begin
  delete from public.product_barcode where code = '07894900011517';
  insert into public.product_barcode (product_id, code)
  values ('00000000-0000-4000-8000-000000000321', '07894900011517');
  raise notice 'case 9 — ok: code released and registered on another leaf';
exception
  when others then
    raise notice 'case 9 — FAILED: %', sqlerrm;
end;
$$;

-- ── case 10 — the response of add_packagings, in payload order ──────────
do $$
declare
  v_added jsonb;
begin
  v_added := public.add_packagings(
    '00000000-0000-4000-8000-000000000320',
    '[{"piece_count": 1, "piece_size": 1900, "piece_size_unit": "milliliter",
       "total_content": 1900, "barcodes": ["07890000000086"]},
      {"piece_count": 1, "piece_size": 1950, "piece_size_unit": "milliliter",
       "total_content": 1950}]'::jsonb);

  if jsonb_array_length(v_added) = 2
     and (v_added -> 0 ->> 'total_content')::integer = 1900
     and (v_added -> 1 ->> 'total_content')::integer = 1950
     and v_added -> 0 ? 'id'
     and jsonb_array_length(v_added -> 0 -> 'product_barcode') = 1
     and jsonb_array_length(v_added -> 1 -> 'product_barcode') = 0
     and v_added -> 0 -> 'product_barcode' -> 0 ? 'store_id'
  then
    raise notice 'case 10 — ok: 2 entries in payload order with product_barcode';
  else
    raise notice 'case 10 — FAILED: %', v_added;
  end if;
end;
$$;

rollback;
