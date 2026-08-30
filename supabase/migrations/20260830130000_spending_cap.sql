-- H13 + H14 — the month's spending cap and the same-day repeat warning.
--
-- A migration of its own, never an edit of the ones before it: the previous
-- seven were applied and verified, and `seed.sql` was generated over them.
--
-- Like every migration in this folder, it DECIDES NOTHING. **No `80`, no
-- `100`, no `0.8` and no threshold comparison appears anywhere below**: the
-- two cuts live in `CapThreshold`, in Dart, and what arrives here is the
-- DESIRED STATE of the month's two marks, already decided (D-e). Postgres
-- sums, groups and stores the validity; every instant that decides something
-- comes from the phone's clock (decisions 7 and 13).

-- ─────────────────────────────────────────────────────────────────────────
-- The only write of a mark in the system
-- ─────────────────────────────────────────────────────────────────────────

-- The state of the month's two marks, as Dart decided it. It is called from
-- INSIDE the four functions that can move a month across a cut, never by the
-- app directly: the mark and the write that moved the month have to commit
-- together (H9's acceptance criterion).
--
-- p_alerts [{"month": "2026-08-01", "warned_80": true, "warned_100": false}]
--
-- It DECIDES NOTHING: `true` means "this cut is crossed", `false` means "it is
-- not any more" — and the second one is the REARM. An empty array is a month
-- with no cap, and then there is nothing to write.
--
-- A month must not come twice in the same array: `insert ... select ... on
-- conflict do update` raises "ON CONFLICT DO UPDATE cannot affect row a second
-- time" when two elements match the same key, and the message does not say
-- where it came from. Today it cannot happen — the correction sends two
-- DISTINCT months and the other three doors send one — but nothing in the type
-- guarantees it: whoever writes a new caller groups by month first.
create function public.apply_cap_alerts(p_alerts jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  insert into public.spending_cap_alert (month, warned_80_at, warned_100_at)
  select (a ->> 'month')::date,
         -- now() is a STAMP, not a decision: the same use `created_at default
         -- now()` already makes throughout the base schema. Nothing reads it
         -- back to compare with anything (decision 13).
         case when (a ->> 'warned_80')::boolean then now() end,
         case when (a ->> 'warned_100')::boolean then now() end
    from jsonb_array_elements(coalesce(p_alerts, '[]'::jsonb)) as a
  on conflict (month) do update
     -- The coalesce on the ON side is what makes the warning happen ONCE: the
     -- second purchase of a month still above 80% sends `true` again, and the
     -- original stamp survives. The null on the OFF side is the REARM, and it
     -- is the very same line.
     set warned_80_at = case
           when excluded.warned_80_at is null then null
           else coalesce(public.spending_cap_alert.warned_80_at,
                         excluded.warned_80_at)
         end,
         warned_100_at = case
           when excluded.warned_100_at is null then null
           else coalesce(public.spending_cap_alert.warned_100_at,
                         excluded.warned_100_at)
         end;
end;
$$;

comment on function public.apply_cap_alerts is
  'Grava o estado desejado das duas marcas de um mes, como o dominio em Dart '
  'decidiu. true preserva o carimbo existente; false o apaga, e esse e o '
  'rearme. Chamada de DENTRO das quatro funcoes de escrita, nunca pelo app.';

-- ─────────────────────────────────────────────────────────────────────────
-- The read
-- ─────────────────────────────────────────────────────────────────────────

-- The cap in force, the month's spending and the marks, for one or MORE
-- months — the correction that moves a purchase from August to September has
-- to re-evaluate both.
--
-- p_months [{"month": "2026-08-01", "last_day": "2026-08-31"}]
--
-- No now(), no current_date: both dates arrive from the phone's clock
-- (decision 13). The `effective_from <= month` is what gives the requirement
-- its two halves at once — the current cap and the one in force in a closed
-- month — and a month before the first row comes back with cap_amount null,
-- which is "month with no cap, forever".
create function public.cap_states(p_months jsonb)
returns jsonb
language sql
-- `stable` like `report_period`, and for the same two reasons: it reads and
-- decides nothing, and without a volatility marker the Supabase linter reports
-- on the first `dev`.
stable
security invoker
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'month',       m.month,
    'cap_amount',  (select c.amount
                      from public.spending_cap c
                     where c.effective_from <= m.month
                     order by c.effective_from desc
                     limit 1),
    -- The month the cap STARTED in, which is not the month being asked about:
    -- a cap in force since March answers August too. Without it
    -- `MonthCapStatus` would have to invent an `effectiveFrom`, and the entity
    -- would carry a date that is not true.
    'cap_effective_from', (select c.effective_from
                             from public.spending_cap c
                            where c.effective_from <= m.month
                            order by c.effective_from desc
                            limit 1),
    -- `::bigint` on the sum, and it is not decoration: `sum()` over `bigint`
    -- returns NUMERIC in Postgres. That is the lesson
    -- `20260830120000_period_report.sql` already wrote down, and it casts
    -- every one of its own sums for it.
    'spent',       coalesce((select sum(pi.total_paid)::bigint
                               from public.purchase p
                               join public.purchase_item pi
                                 on pi.purchase_id = p.id
                              where p.purchase_date between m.month
                                                        and m.last_day), 0),
    'warned_80',   coalesce((select a.warned_80_at is not null
                               from public.spending_cap_alert a
                              where a.month = m.month), false),
    'warned_100',  coalesce((select a.warned_100_at is not null
                               from public.spending_cap_alert a
                              where a.month = m.month), false)
  ) order by m.month), '[]'::jsonb)
  from (
    select (e ->> 'month')::date as month,
           (e ->> 'last_day')::date as last_day
      from jsonb_array_elements(coalesce(p_months, '[]'::jsonb)) as e
  ) as m;
$$;

comment on function public.cap_states is
  'Teto vigente, gasto e marcas de cada mes perguntado, num jsonb so. Devolve '
  'ORDENADO POR MES, nao na ordem perguntada — quem chama casa por month, '
  'nunca por indice. Chamada por SpendingCapRepositoryRemote.fetchStatuses.';

-- ─────────────────────────────────────────────────────────────────────────
-- The cap screen's write
-- ─────────────────────────────────────────────────────────────────────────

-- p_amount         cents (B5)
-- p_effective_from always day 1 of the CURRENT month — the cap is valid "from
--                  the current month on", and the clock that says which month
--                  that is lives in Dart.
-- p_alerts         what evaluateSpendingCap decided over the ALREADY ZEROED
--                  marks — which is why the delete below and this call are one
--                  transaction and not two.
create function public.save_spending_cap(
  p_amount         bigint,
  p_effective_from date,
  p_alerts         jsonb
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  insert into public.spending_cap (amount, effective_from)
  values (p_amount, p_effective_from)
  on conflict (effective_from) do update set amount = excluded.amount;

  -- "Alterar o teto zera os dois avisos do mês corrente e reavalia na hora."
  -- The closed months are NOT touched: the delete is by month, and the month
  -- is the one the cap starts in.
  delete from public.spending_cap_alert where month = p_effective_from;

  perform public.apply_cap_alerts(p_alerts);
end;
$$;

comment on function public.save_spending_cap is
  'Grava o teto do mes, zera as duas marcas dele e regrava o que o dominio '
  'decidiu — tudo numa transacao. Meses fechados nao sao tocados.';

-- ─────────────────────────────────────────────────────────────────────────
-- H14 — the types someone ELSE bought on the same day
-- ─────────────────────────────────────────────────────────────────────────

-- p_date          the purchase's day, decided in Dart — never current_date,
--                 which at 21:00 UTC-4 on the 30th answers the 31st (R9)
-- p_registered_by the label of whoever is registering; the filter is `<>`
-- p_type_ids      the types of the purchase being saved
--
-- A function and not a PostgREST embed on purpose: the filter falls on
-- `product_registration.product_type_id`, THREE levels down the embed chain
-- (purchase_item → product → product_registration), and a third-level filter
-- is exactly where PostgREST's syntax stops being obvious. It decides nothing
-- — every date and every id arrives ready.
create function public.same_day_types(
  p_date          date,
  p_registered_by text,
  p_type_ids      uuid[]
)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(jsonb_agg(distinct jsonb_build_object(
    'product_type_id', t.id,
    'name',            t.name
  )), '[]'::jsonb)
    from public.purchase p
    join public.purchase_item pi on pi.purchase_id = p.id
    join public.product pr on pr.id = pi.product_id
    join public.product_registration reg on reg.id = pr.product_registration_id
    join public.product_type t on t.id = reg.product_type_id
   where p.purchase_date = p_date
     and p.registered_by <> p_registered_by
     and t.id = any (p_type_ids);
$$;

comment on function public.same_day_types is
  'Os tipos desta compra que OUTRA pessoa tambem comprou no mesmo dia (H14). '
  'A janela "hoje ou ontem" e o texto do aviso sao decididos em Dart; aqui so '
  'ha a juncao e o filtro <> na etiqueta.';

-- ─────────────────────────────────────────────────────────────────────────
-- The three write functions gain `p_cap_alerts`
-- ─────────────────────────────────────────────────────────────────────────

-- A new parameter is a NEW SIGNATURE in Postgres: `create or replace` does not
-- reach it, and creating without dropping would leave two overloads of the
-- same name — with PostgREST choosing by parameter name, which is the worst
-- possible failure here because it is silent.
--
-- Each one is recreated with the body it was born with, plus one call. The
-- `comment on function` and the `grant execute` go with the drop, so both are
-- rewritten below.
drop function public.create_purchase(jsonb, jsonb, jsonb);
drop function public.update_purchase(jsonb, jsonb, jsonb, jsonb);
drop function public.delete_purchase(uuid, jsonb);

-- p_purchase   {"id": uuid, "purchase_date": "2026-08-18",
--               "store_id": uuid, "registered_by": "Leandro"}
-- p_items      [{"id": uuid, "product_id": uuid, "quantity": 1,
--                "quantity_in_base_unit": 4200, "total_paid": 6200}]
-- p_write_offs [{"purchase_item_id": uuid, "shopping_list_item_id": uuid,
--                "quantity_written_off": 2000, "cleared_not_found": true,
--                "fulfills": false}]
-- p_cap_alerts [{"month": "2026-08-01", "warned_80": true,
--                "warned_100": false}] — empty when the month has no cap
create function public.create_purchase(
  p_purchase    jsonb,
  p_items       jsonb,
  p_write_offs  jsonb,
  p_cap_alerts  jsonb
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
    -- And the cap marks are NOT applied on this path, on purpose: the first
    -- send already re-evaluated the month, and the resend's `spent` was read
    -- BEFORE it and would count this purchase twice.
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

  -- H13: the month's two marks, in the SAME transaction as the purchase that
  -- moved the month across a cut.
  perform public.apply_cap_alerts(p_cap_alerts);

  return jsonb_build_object(
    'already_registered', false,
    'purchase_id', v_purchase_id
  );
end;
$$;

comment on function public.create_purchase is
  'Registra uma compra, seus itens, a baixa da lista e as marcas do teto em '
  'UMA transação. Não decide nada: o plano de baixa chega pronto do domínio '
  'em Dart, e as marcas, de evaluateSpendingCap. Devolve already_registered = '
  'true quando a compra já existia — o reenvio da H8 que chegou duas vezes, e '
  'nesse caminho nenhuma marca é gravada. Chamada por '
  'PurchaseRepositoryRemote.save.';

-- p_purchase   {id, purchase_date, store_id} — `registered_by` is NOT here:
--              who registered a purchase is a historical fact, and a
--              correction never changes the authorship of anything.
-- p_items      [{id, product_id, quantity, quantity_in_base_unit, total_paid}]
-- p_write_offs [{purchase_item_id, shopping_list_item_id,
--                quantity_written_off, cleared_not_found, fulfills}]
-- p_restored   [{id, fulfilled_on, not_found}] — every list item the UNDO
--              puts back, with the state it had before this purchase.
-- p_cap_alerts one entry per month affected — TWO when the correction moved
--              the purchase across the turn of a month, and they are always
--              distinct months (see `apply_cap_alerts`).
create function public.update_purchase(
  p_purchase    jsonb,
  p_items       jsonb,
  p_write_offs  jsonb,
  p_restored    jsonb,
  p_cap_alerts  jsonb
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

  -- 7. The month's two thresholds, re-evaluated INSIDE this transaction and
  --    never as a second write after it (H9's acceptance criterion). This is
  --    the extension point H9 left commented here, now filled: the comparison
  --    happened in Dart, over the spending this correction produces, and what
  --    arrives is the desired state of the marks — of BOTH months, when the
  --    correction moved the purchase across the turn of one.
  perform public.apply_cap_alerts(p_cap_alerts);
end;
$$;

comment on function public.update_purchase is
  'Corrige uma compra inteira em UMA transacao: desfaz o efeito antigo sobre a '
  'lista, aplica o novo e regrava as marcas do teto dos meses afetados. Decide '
  'nada — o que devolver chega calculado de write_off_undo.dart, o que abater '
  'de write_off_plan.dart e as marcas de evaluateSpendingCap.';

-- Deleting is the same thing without the re-applying. `p_cap_alerts` here is
-- almost always a REARM: a deletion only ever drops the month.
create function public.delete_purchase(
  p_purchase_id uuid,
  p_restored    jsonb,
  p_cap_alerts  jsonb
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

  perform public.apply_cap_alerts(p_cap_alerts);
end;
$$;

comment on function public.delete_purchase is
  'Apaga a compra, devolve a lista o que ela tinha tirado e regrava as marcas '
  'do teto do mes. O estado a devolver chega calculado de undoWriteOffs e as '
  'marcas de evaluateSpendingCap, ambos em Dart.';

-- ─────────────────────────────────────────────────────────────────────────
-- Grants
-- ─────────────────────────────────────────────────────────────────────────

-- The grants live HERE and not in `rls.sql`, which has already been applied.
-- And the last three are not optional housekeeping: `drop function` takes the
-- old grant with it, so without them the anon role starts getting 42501 —
-- which AppFailure reads as AccessDenied — on a screen that worked yesterday.
grant execute on function public.apply_cap_alerts(jsonb) to anon, authenticated;

grant execute on function public.cap_states(jsonb) to anon, authenticated;

grant execute on function public.save_spending_cap(bigint, date, jsonb)
  to anon, authenticated;

grant execute on function public.same_day_types(date, text, uuid[])
  to anon, authenticated;

grant execute on function public.create_purchase(jsonb, jsonb, jsonb, jsonb)
  to anon, authenticated;

grant execute on function public.update_purchase(jsonb, jsonb, jsonb, jsonb, jsonb)
  to anon, authenticated;

grant execute on function public.delete_purchase(uuid, jsonb, jsonb)
  to anon, authenticated;
