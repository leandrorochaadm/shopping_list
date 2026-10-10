-- Barcodes per packaging (decisions M-c / M-d, 10/10/2026).
--
-- Each leaf (`product`) can carry zero or more packaging codes (GTIN-14,
-- unique in the whole app, `store_id` null) and, for the weight-sold leaf,
-- scale codes tied to a store (`store_id` filled, the 7-digit item code).
--
-- This table is NOT one of the six catalogs, so it has no `active` column:
-- releasing a code is a real DELETE, otherwise the code could never be
-- registered on another leaf.
create table public.product_barcode (
  id uuid primary key default gen_random_uuid(),
  -- No `on delete cascade`: a leaf is never deleted (soft delete, decision 19).
  product_id uuid not null references public.product (id),
  -- Null = packaging code (valid in the whole app). Filled = scale code.
  store_id uuid references public.store (id),
  code text not null,
  created_at timestamptz not null default now(),
  constraint product_barcode_code_digits check (code ~ '^[0-9]{7,14}$'),
  -- The EAN-13 form (the last 13 digits) starting with `2`, or `02` (UPC-A of
  -- variable weight), is a store code, never a factory one. Same rule as
  -- `Barcode.typed` in Dart; here it is only the net underneath.
  constraint product_barcode_in_store_has_store
    check ((store_id is null) = (right(code, 13) !~ '^0?2'))
);

-- Dart answers first; the index is the net (B2/B3 of the base schema). The
-- same scale code in two stores is allowed.
create unique index product_barcode_code_key
  on public.product_barcode (code, store_id) nulls not distinct;

-- The PostgREST embed `product(..., product_barcode(...))` looks up by it.
create index product_barcode_product_idx
  on public.product_barcode (product_id);

alter table public.product_barcode enable row level security;

grant select, insert, update, delete on public.product_barcode
  to anon, authenticated;

create policy product_barcode_open_access on public.product_barcode
  for all to anon, authenticated
  using (true) with check (true);

-- Inserts the leaves and the codes of an existing registration in ONE
-- transaction. The loop is what ties each code to ITS card: the codes of an
-- element go to the id the `returning` just gave.
--
-- It DECIDES NOTHING (decision 7): no check digit, no rule about which element
-- may carry scale codes. A repeated code (in the database or inside the
-- payload) raises 23505 and the transaction undoes the leaves already inserted.
--
-- Each element is {} (weight-sold) or
-- {"piece_count": 6, "piece_size": 350, "piece_size_unit": "milliliter",
--  "total_content": 2100}, and may carry
--   "barcodes":    ["07894900011517", ...]                  (GTIN-14)
--   "scale_codes": [{"store_id": "<uuid>", "code": "2822521"}, ...]
create function public.add_packagings(
  p_registration_id uuid,
  p_packagings jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_packaging jsonb;
  v_product public.product;
  v_products jsonb := '[]'::jsonb;
begin
  for v_packaging in select value from jsonb_array_elements(p_packagings) loop
    insert into public.product (
      product_registration_id, piece_count, piece_size, piece_size_unit,
      total_content
    )
    values (
      p_registration_id,
      (v_packaging ->> 'piece_count')::integer,
      (v_packaging ->> 'piece_size')::bigint,
      v_packaging ->> 'piece_size_unit',
      (v_packaging ->> 'total_content')::bigint
    )
    returning * into v_product;

    insert into public.product_barcode (product_id, code)
    select v_product.id, c.code
    from jsonb_array_elements_text(
      coalesce(v_packaging -> 'barcodes', '[]'::jsonb)) as c(code);

    insert into public.product_barcode (product_id, store_id, code)
    select v_product.id, (s ->> 'store_id')::uuid, s ->> 'code'
    from jsonb_array_elements(
      coalesce(v_packaging -> 'scale_codes', '[]'::jsonb)) as s;

    v_products := v_products || jsonb_build_array(
      to_jsonb(v_product) || jsonb_build_object('product_barcode', (
        select coalesce(jsonb_agg(
                 jsonb_build_object('code', b.code, 'store_id', b.store_id)
                 order by b.code), '[]'::jsonb)
        from public.product_barcode as b
        where b.product_id = v_product.id)));
  end loop;

  return v_products;
end;
$$;

grant execute on function public.add_packagings(uuid, jsonb)
  to anon, authenticated;

comment on function public.add_packagings is
  'Inserts the leaves and barcodes of an existing registration in ONE '
  'transaction. Decides nothing: every value arrives converted from Dart. '
  'Called by CatalogRepositoryRemote.addPackagings.';

-- Same signature as before; the leaves now come from `add_packagings`, so the
-- two paths share one body. Each element of `p_packagings` also accepts the
-- optional keys "barcodes" and "scale_codes" (see `add_packagings`).
create or replace function public.create_product_registration(
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

  v_products := public.add_packagings(v_registration.id, p_packagings);

  return jsonb_build_object(
    'registration', to_jsonb(v_registration),
    'products', v_products
  );
end;
$$;

comment on function public.create_product_registration is
  'Inserts a registration, its packagings and their barcodes in ONE '
  'transaction (via add_packagings). Decides nothing: every value arrives '
  'converted from Dart. Called by '
  'CatalogRepositoryRemote.saveRegistrationWithProducts.';
