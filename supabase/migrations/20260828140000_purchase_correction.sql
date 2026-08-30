-- H9 — correcting and deleting a purchase, and undoing what it did to the list.
--
-- A migration of its own, never an edit of the ones before it: the base was
-- verified on a throwaway Postgres 17 and `seed.sql` was generated over it,
-- which is the same reason delivery 3's migration exists.
--
-- Like every migration in this folder, it DECIDES NOTHING: no now(), no
-- current_date, no threshold and no unit conversion (decisions 7 and 13).
-- What to give back to the list arrives already computed by
-- `write_off_undo.dart`, and what the corrected purchase takes from it by
-- `write_off_plan.dart` — both pure Dart, both tested without a database.
--
-- `removed_on` and the partial index are NOT here: delivery 3 created both in
-- `20260828130000_purchase_write.sql` (lines 27–43), in the same migration
-- that created `fulfilled_on`. The two ways out of the list were born
-- together, so the index never had to be rebuilt.

-- ─────────────────────────────────────────────────────────────────────────
-- The history's order
-- ─────────────────────────────────────────────────────────────────────────

-- The app's only paginated screen (`tecnico §1.9`). `purchase_date` has had
-- an index since the base schema; what is missing is the TIEBREAKER, because
-- two purchases of the same day with no stable order swap places between one
-- page and the next — and the one on the boundary shows up twice, or
-- vanishes.
create index purchase_history_idx
  on public.purchase (purchase_date desc, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────
-- Correcting a purchase
-- ─────────────────────────────────────────────────────────────────────────

-- It is NOT `create_purchase` with an upsert: that function opens with
-- `on conflict (id) do nothing` precisely so H8's resend cannot duplicate a
-- purchase, and turning it into an upsert would trade a shipped acceptance
-- criterion for one shared code path.
--
-- p_purchase   {id, purchase_date, store_id} — `registered_by` is NOT here:
--              who registered a purchase is a historical fact, and a
--              correction never changes the authorship of anything.
-- p_items      [{id, product_id, quantity, quantity_in_base_unit, total_paid}]
-- p_write_offs [{purchase_item_id, shopping_list_item_id,
--                quantity_written_off, cleared_not_found, fulfills}]
--              — the same shape `create_purchase` takes, `fulfills` included,
--              and `fulfills` is still not a column (delivery 3).
-- p_restored   [{id, fulfilled_on, not_found}] — every list item the UNDO
--              puts back, with the state it had before this purchase.
create function public.update_purchase(
  p_purchase   jsonb,
  p_items      jsonb,
  p_write_offs jsonb,
  p_restored   jsonb
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_purchase_id uuid := (p_purchase ->> 'id')::uuid;
  v_date        date := (p_purchase ->> 'purchase_date')::date;
  v_write_offs  jsonb := coalesce(p_write_offs, '[]'::jsonb);
  v_restored    jsonb := coalesce(p_restored, '[]'::jsonb);
begin
  update public.purchase
     set purchase_date = v_date,
         store_id      = (p_purchase ->> 'store_id')::uuid
   where id = v_purchase_id;

  if not found then
    raise exception 'purchase % not found', v_purchase_id
      using errcode = 'P0002';   -- no_data_found; the app reads it as NotFound
  end if;

  -- 1. The old items go, and the cascade takes their trail with them. This is
  --    why undoing does not add anything back: the written-off amount IS the
  --    sum of the trail (D5), so deleting the trail restores the balance.
  delete from public.purchase_item where purchase_id = v_purchase_id;

  -- 2. The list goes back to what it was BEFORE this purchase — computed in
  --    Dart by `undoWriteOffs` from the trail step 1 just deleted. It runs
  --    BEFORE the new write-offs, so a correction that closes the same item
  --    again ends with it closed, not reopened.
  --
  --    `removed_on` is deliberately absent: an item this purchase cleared and
  --    that someone then removed BY HAND stays removed, and that is the whole
  --    reason the two columns are separate (D1).
  update public.shopping_list_item as s
     set fulfilled_on = nullif(r ->> 'fulfilled_on', '')::date,
         not_found    = coalesce((r ->> 'not_found')::boolean, false)
    from jsonb_array_elements(v_restored) as r
   where s.id = (r ->> 'id')::uuid;

  -- 3. The corrected items, with the ids Dart generated: the trail points at
  --    them.
  insert into public.purchase_item (
    id, purchase_id, product_id, quantity, quantity_in_base_unit, total_paid
  )
  select (item ->> 'id')::uuid,
         v_purchase_id,
         (item ->> 'product_id')::uuid,
         (item ->> 'quantity')::bigint,
         (item ->> 'quantity_in_base_unit')::bigint,
         (item ->> 'total_paid')::bigint
    from jsonb_array_elements(p_items) as item;

  -- 4. The new trail. Columns named one by one, on purpose: `fulfills` travels
  --    in the same object and is NOT a column of `list_write_off` — it is the
  --    flag step 6 reads.
  insert into public.list_write_off (
    purchase_item_id, shopping_list_item_id, quantity_written_off,
    cleared_not_found
  )
  select (w ->> 'purchase_item_id')::uuid,
         (w ->> 'shopping_list_item_id')::uuid,
         (w ->> 'quantity_written_off')::bigint,
         coalesce((w ->> 'cleared_not_found')::boolean, false)
    from jsonb_array_elements(v_write_offs) as w;

  -- 5. The "não encontrei" marks this purchase knocks down.
  update public.shopping_list_item
     set not_found = false
   where id in (
     select (w ->> 'shopping_list_item_id')::uuid
       from jsonb_array_elements(v_write_offs) as w
      where coalesce((w ->> 'cleared_not_found')::boolean, false)
   );

  -- 6. The items this purchase closes.
  update public.shopping_list_item
     set fulfilled_on = v_date
   where id in (
     select (w ->> 'shopping_list_item_id')::uuid
       from jsonb_array_elements(v_write_offs) as w
      where coalesce((w ->> 'fulfills')::boolean, false)
   );

  -- 7. H13'S EXTENSION POINT, and this is all H9 delivers of it: once the cap
  --    tables have an owner, re-evaluating the month's two thresholds goes
  --    HERE, inside this transaction — never as a second write after it (H9's
  --    acceptance criterion). With no cap, there is no threshold to re-check.
end;
$$;

comment on function public.update_purchase is
  'Corrige uma compra inteira em UMA transacao: desfaz o efeito antigo sobre a '
  'lista e aplica o novo. Decide nada — o que devolver chega calculado de '
  'write_off_undo.dart e o que abater, de write_off_plan.dart.';

-- Deleting is the same thing without the re-applying.
create function public.delete_purchase(
  p_purchase_id uuid,
  p_restored    jsonb
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_restored jsonb := coalesce(p_restored, '[]'::jsonb);
begin
  update public.shopping_list_item as s
     set fulfilled_on = nullif(r ->> 'fulfilled_on', '')::date,
         not_found    = coalesce((r ->> 'not_found')::boolean, false)
    from jsonb_array_elements(v_restored) as r
   where s.id = (r ->> 'id')::uuid;

  -- Cascade: purchase_item goes with it, and list_write_off behind that.
  delete from public.purchase where id = p_purchase_id;
end;
$$;

comment on function public.delete_purchase is
  'Apaga a compra e devolve a lista o que ela tinha tirado. O estado a '
  'devolver chega calculado de undoWriteOffs, em Dart.';

-- The grants live HERE and not in `rls.sql`, which has already been applied:
-- both `tool/local_dev/setup.py` and `supabase db push` skip a version already
-- registered in `supabase_migrations.schema_migrations`, so editing that file
-- would work on a `--reset` and fail silently on `dev` and `prod` — the
-- function existing and PostgREST answering 401. It is the same place
-- delivery 3 put `create_purchase`'s own grant.
grant execute on function public.update_purchase(jsonb, jsonb, jsonb, jsonb)
  to anon, authenticated;

grant execute on function public.delete_purchase(uuid, jsonb)
  to anon, authenticated;
