-- H11 + H12 — spending and consumption over a free period.
--
-- The THREE aggregations of the SAME interval (`handoff §H11`): the total
-- spent per category, the total spent and consumed per product type and,
-- inside the type, per brand.
--
-- `jsonb` and not `setof`: PostgREST exposes one function per call, and three
-- calls for the same period are three different instants of the database.
-- What the screen shows has to add up with itself.
--
-- It SUMS and GROUPS, and nothing else: no now(), no current_date, no window
-- and no threshold (decisions 7 and 13). The interval arrives as a parameter,
-- computed off the phone's clock.
--
-- H12 has no query of its own (`handoff §8`): the percentage is a division in
-- Dart over the per-category aggregation this function already returns. A
-- second query would be the same sum written in two places.
create or replace function public.report_period(p_from date, p_to date)
returns jsonb
language sql
stable
security invoker
-- The other five functions of this repository carry this line, and it is not
-- style: without it the Supabase linter reports `function_search_path_mutable`
-- on the first `dev`, and name resolution starts depending on who calls.
set search_path = public
as $$
  with line as (
    select
      c.id    as category_id,
      c.name  as category_name,
      t.id    as product_type_id,
      t.name  as product_type_name,
      t.base_unit,
      b.id    as brand_id,
      b.name  as brand_name,
      i.quantity_in_base_unit,
      i.total_paid
    from public.purchase_item i
    join public.purchase p on p.id = i.purchase_id
    join public.product pr on pr.id = i.product_id
    join public.product_registration r on r.id = pr.product_registration_id
    join public.product_type t on t.id = r.product_type_id
    join public.category c on c.id = t.category_id
    -- LEFT: a null brand is a VALUE (decision B2), and an inner join would
    -- make the ground beef disappear from the whole report, not only from the
    -- brand breakdown.
    left join public.brand b on b.id = r.brand_id
    -- No `active` filter anywhere, on purpose: deactivating a registration
    -- takes it out of the purchase screen and out of the suggestions, and
    -- requirement 16 promises it "continua aparecendo nos relatórios". A
    -- `where active` here would rewrite the past every time someone tidied up
    -- the catalog.
    where p.purchase_date >= p_from
      and p.purchase_date <= p_to
  )
  select jsonb_build_object(
    -- Money only: adding kilos to litres gives no number at all, so the
    -- category has NO quantity — which is why the wireframe draws
    -- "Carnes  R$ 480" with nothing beside it.
    'categories', coalesce((
      select jsonb_agg(g)
      from (
        select
          category_id,
          category_name,
          sum(total_paid)::bigint as total_paid
        from line
        group by category_id, category_name
      ) g
    ), '[]'::jsonb),
    -- The level that SUMS: quantity in the base unit and money.
    'types', coalesce((
      select jsonb_agg(g)
      from (
        select
          product_type_id,
          product_type_name,
          category_id,
          base_unit,
          sum(quantity_in_base_unit)::bigint as quantity_in_base_unit,
          sum(total_paid)::bigint            as total_paid
        from line
        group by product_type_id, product_type_name, category_id, base_unit
      ) g
    ), '[]'::jsonb),
    -- Inside the type, per brand. The NULL `brand_id` group comes along: who
    -- decides what to do with it is the domain, not the database (C2).
    'brands', coalesce((
      select jsonb_agg(g)
      from (
        select
          product_type_id,
          brand_id,
          brand_name,
          sum(quantity_in_base_unit)::bigint as quantity_in_base_unit,
          sum(total_paid)::bigint            as total_paid
        from line
        group by product_type_id, brand_id, brand_name
      ) g
    ), '[]'::jsonb)
  );
$$;

-- Three traps this function closes on purpose:
--
--   1. NO ordering. Whoever orders is `buildReportSections`, in Dart, and an
--      `order by` here would be a second ordering to diverge from the first.
--   2. `::bigint` on every sum. `sum()` over `bigint` returns `numeric` in
--      Postgres, and `numeric` inside `jsonb` can arrive as `19200.00` — the
--      cast closes that at the source, before `Money.fromJson` has to guess.
--   3. `coalesce(..., '[]'::jsonb)`. `jsonb_agg` of zero rows returns NULL,
--      not `[]`. Without it the empty period — which is a STATE to draw, not
--      an error — would arrive as three nulls.
comment on function public.report_period(date, date) is
  'Gasto e consumo do período, agrupados por categoria, por tipo e por marca. '
  'Só soma e agrupa: sem now(), sem janela e sem limiar. O intervalo chega por '
  'parâmetro, do relógio do aparelho.';

-- Inside this migration, never in the already-applied `rls.sql`.
grant execute on function public.report_period(date, date) to anon, authenticated;
