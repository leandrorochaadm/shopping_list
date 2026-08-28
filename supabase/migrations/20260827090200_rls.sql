-- Row Level Security ON everywhere, with a permissive policy per table.
--
-- This looks like a contradiction and is not. Decision 6: there is no login,
-- the anon key is public, and the barrier is an undisclosed URL. Whoever has
-- the address has the database — that risk is accepted in writing (E2 in
-- docs/pendencias).
--
-- RLS is still enabled because leaving it OFF on a Supabase project makes
-- PostgREST refuse everything by another route, and the app would read
-- `AccessDenied` — "o servidor recusou o acesso a este dado" — with nothing
-- on screen or in the schema explaining why. Enabled plus permissive is the
-- honest way to say "everyone with the key may read and write".
--
-- The day this project grows a login, every policy below is one place to
-- change, and the table list is already here.

-- Explicit grants: current Supabase projects do NOT auto-expose new tables to
-- the Data API roles. Without these, RLS is irrelevant — the role cannot even
-- reach the table.
grant usage on schema public to anon, authenticated;

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'category',
    'product_type',
    'brand',
    'product_registration',
    'product',
    'store',
    'shopping_list_item',
    'purchase',
    'purchase_item',
    'list_write_off',
    'spending_cap',
    'spending_cap_alert'
  ]
  loop
    execute format('alter table public.%I enable row level security', v_table);

    execute format(
      'grant select, insert, update, delete on public.%I to anon, authenticated',
      v_table
    );

    -- One policy covering every command. Split policies would suggest a
    -- distinction this project does not have.
    execute format(
      'create policy %I on public.%I for all to anon, authenticated '
      'using (true) with check (true)',
      v_table || '_open_access',
      v_table
    );
  end loop;
end;
$$;

grant execute on function public.create_product_registration(
  uuid, uuid, text, text, jsonb
) to anon, authenticated;

-- normalize_name is called by the generated columns, which run as the table
-- owner, so no grant is needed for the app. It is granted anyway so the
-- shared case table of supabase/checks/ can be run with the same key the app
-- uses, instead of needing the service role.
grant execute on function public.normalize_name(text) to anon, authenticated;
