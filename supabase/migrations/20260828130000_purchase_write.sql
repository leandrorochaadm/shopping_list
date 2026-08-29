-- H7 — the purchase write, and the write-off it leaves on the list.
--
-- Two things happen here, and they cannot be split: the columns that let an
-- item LEAVE the list without being deleted, and the single transactional
-- function that registers a purchase, its items and the trail of what it
-- cleared.
--
-- Like every migration in this folder, it DECIDES NOTHING: no now(), no
-- current_date, no threshold and no unit conversion (decisions 7 and 13).
-- Every value arrives already decided by Dart.

-- ─────────────────────────────────────────────────────────────────────────
-- B6 — an item leaves the list by DATE, never by DELETE
-- ─────────────────────────────────────────────────────────────────────────

-- The constraint that forced this: `list_write_off.shopping_list_item_id` is
-- `not null references shopping_list_item (id)` with no ON DELETE. So the
-- first purchase that cleared an item and then tried to remove it would hit
-- the foreign key. Both ways out of the list are dates now, and the trail
-- stays whole — which is exactly what H9 undoes.

-- Null = still on the list. Filled = the day a purchase closed it. It is a
-- `date` and not a timestamp because it holds the PURCHASE's day, which is
-- the day printed on the receipt (decision 13) — never the instant of the
-- write.
alter table public.shopping_list_item
  add column fulfilled_on date;

-- Removing by hand is a DIFFERENT act from being bought, and it needs its own
-- column: an item that already took a partial write-off and is then removed
-- from the item dialog would otherwise hit the same foreign key. Keeping the
-- two apart is what lets H9 tell "a compra fechou este item" from "alguém
-- tirou este item da lista" when it undoes a purchase.
alter table public.shopping_list_item
  add column removed_on date;

-- The list screen (H4) reads the OPEN items, and open means neither closed by
-- a purchase nor removed by hand. This index documents that intention as much
-- as it serves it: a query that forgets one of the two halves makes a bought
-- item reappear in the aisle.
create index shopping_list_item_open_idx
  on public.shopping_list_item (product_type_id)
  where fulfilled_on is null and removed_on is null;

-- A write-off of ZERO is not nonsense here, and refusing it is what breaks
-- the requirement "an item with no quantity leaves the list on the FIRST
-- purchase of its type".
--
-- An item with no quantity never asked for an amount, so there is no amount
-- to consume: it takes a row worth 0 and is closed by it. Letting it swallow
-- "all the amount still available" instead inflates the trail and steals from
-- the quantified items of the same type. And giving it no row at all would
-- leave `fulfilled_on` unreachable, because that is set from the write-offs
-- below and undone by deleting them (H9).
--
-- It is relaxed to `>= 0` and no further: a NEGATIVE write-off would be a
-- purchase giving quantity back to the list, and there is no such gesture.
alter table public.list_write_off
  drop constraint if exists list_write_off_quantity_written_off_check;

alter table public.list_write_off
  add constraint list_write_off_quantity_written_off_check
  check (quantity_written_off >= 0);

-- ─────────────────────────────────────────────────────────────────────────
-- The one write that cannot be four calls
-- ─────────────────────────────────────────────────────────────────────────

-- A purchase of twenty items is one `purchase` row, twenty `purchase_item`
-- rows and up to twenty `list_write_off` rows, plus two updates on the list.
-- PostgREST cannot write that in one transaction, and a partial write is the
-- worst outcome H7 has: a purchase saved with half its items, or a list
-- cleared by a purchase that was never recorded.
--
-- **It decides nothing.** Which items to write off, how much, and who loses
-- the "não encontrei" mark are all decided by `planWriteOffs`, in Dart, in
-- the domain. This only inserts and updates what arrived already decided.
--
-- p_purchase   {"id": uuid, "purchase_date": "2026-08-18",
--               "store_id": uuid, "registered_by": "Leandro"}
-- p_items      [{"id": uuid, "product_id": uuid, "quantity": 1,
--                "quantity_in_base_unit": 4200, "total_paid": 6200}]
-- p_write_offs [{"purchase_item_id": uuid, "shopping_list_item_id": uuid,
--                "quantity_written_off": 2000, "cleared_not_found": true,
--                "fulfills": false}]
create function public.create_purchase(
  p_purchase   jsonb,
  p_items      jsonb,
  p_write_offs jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_purchase_id uuid := (p_purchase ->> 'id')::uuid;
  v_purchase_date date := (p_purchase ->> 'purchase_date')::date;
  v_write_offs jsonb := coalesce(p_write_offs, '[]'::jsonb);
begin
  -- IDEMPOTENCE FIRST, and this clause is what makes H8's automatic resend
  -- safe. The key is born on the phone, so a resend that arrives twice — the
  -- response of the first one lost to a dropped connection — finds the row
  -- already there. Without this, the second attempt would create a second
  -- purchase AND write the list off a second time.
  insert into public.purchase (id, purchase_date, store_id, registered_by)
  select
    v_purchase_id,
    v_purchase_date,
    (p_purchase ->> 'store_id')::uuid,
    p_purchase ->> 'registered_by'
  on conflict (id) do nothing;

  if not found then
    return jsonb_build_object(
      'already_registered', true,
      'purchase_id', v_purchase_id
    );
  end if;

  -- The `purchase_id` does NOT travel inside each item: it is the same for
  -- all of them and comes from p_purchase. What each item does carry is its
  -- own id, born on the phone, so the write-offs below can point at it.
  insert into public.purchase_item (
    id, purchase_id, product_id, quantity, quantity_in_base_unit, total_paid
  )
  select
    (item ->> 'id')::uuid,
    v_purchase_id,
    (item ->> 'product_id')::uuid,
    (item ->> 'quantity')::bigint,
    (item ->> 'quantity_in_base_unit')::bigint,
    (item ->> 'total_paid')::bigint
  from jsonb_array_elements(p_items) as item;

  -- The columns are named one by one ON PURPOSE. `fulfills` travels in the
  -- same object but is NOT a column of `list_write_off` — it is the flag the
  -- update below reads. An insert that trusted the order, or a
  -- jsonb_populate_record, would break right here.
  insert into public.list_write_off (
    purchase_item_id, shopping_list_item_id, quantity_written_off,
    cleared_not_found
  )
  select
    (off ->> 'purchase_item_id')::uuid,
    (off ->> 'shopping_list_item_id')::uuid,
    (off ->> 'quantity_written_off')::bigint,
    coalesce((off ->> 'cleared_not_found')::boolean, false)
  from jsonb_array_elements(v_write_offs) as off;

  -- "Não encontrei" falls on the first purchase of the type, even a partial
  -- one. Which write-offs clear it was decided in Dart.
  update public.shopping_list_item
  set not_found = false
  where id in (
    select (off ->> 'shopping_list_item_id')::uuid
    from jsonb_array_elements(v_write_offs) as off
    where coalesce((off ->> 'cleared_not_found')::boolean, false)
  );

  -- The item leaves the list on the PURCHASE's day, not on today's: a
  -- purchase registered late closes the item with the date on the receipt.
  update public.shopping_list_item
  set fulfilled_on = v_purchase_date
  where id in (
    select (off ->> 'shopping_list_item_id')::uuid
    from jsonb_array_elements(v_write_offs) as off
    where coalesce((off ->> 'fulfills')::boolean, false)
  );

  return jsonb_build_object(
    'already_registered', false,
    'purchase_id', v_purchase_id
  );
end;
$$;

comment on function public.create_purchase is
  'Registra uma compra, seus itens e a baixa da lista em UMA transação. Não '
  'decide nada: o plano de baixa chega pronto do domínio em Dart. Devolve '
  'already_registered = true quando a compra já existia — o reenvio da H8 '
  'que chegou duas vezes. Chamada por PurchaseRepositoryRemote.save.';

-- Without this the anon role cannot execute it, and the app gets a 42501 that
-- AppFailure reads as AccessDenied.
grant execute on function public.create_purchase(jsonb, jsonb, jsonb)
  to anon, authenticated;
