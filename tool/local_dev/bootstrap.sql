-- Makes a plain Postgres look enough like a Supabase project for the migrations
-- in supabase/migrations/ to apply unchanged. Hosted Supabase ships all of this
-- already; a database created by createdb does not.
--
-- Idempotent on purpose: setup.py runs it on every start.

-- 1. The schema `unaccent` is installed into. normalize_function.sql says
--    `with schema extensions`, which fails if the schema is absent.
create schema if not exists extensions;

--    And the privilege to reach into it. normalize_name is SECURITY INVOKER
--    with `set search_path = extensions`, so a direct RPC call runs as anon and
--    needs USAGE here. Hosted Supabase grants this out of the box; createdb
--    does not, and without it supabase/checks/normalize_cases.sql fails with
--    42501 while the app's generated columns keep working -- they run as the
--    table owner. A gap that only shows up on the check, never on the screen.
grant usage on schema extensions to anon, authenticated, service_role;

-- 2. The two roles the RLS migration grants to, plus the one PostgREST
--    authenticates as before switching. The RLS migration only GRANTS to these
--    roles, it never creates them.
--
--    NOLOGIN on anon/authenticated: PostgREST reaches them through SET ROLE
--    from the authenticator, never by connecting as them.
do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
  -- The role PostgREST logs in as. It holds no privileges of its own: every
  -- request switches to anon or authenticated based on the JWT `role` claim.
  if not exists (select from pg_roles where rolname = 'authenticator') then
    create role authenticator login noinherit password 'postgrest_local';
  end if;
end
$$;

grant anon, authenticated, service_role to authenticator;

-- 3. The publication base_schema.sql adds shopping_list_item to. Realtime is
--    not running locally, but the ALTER PUBLICATION still has to resolve.
do $$
begin
  if not exists (select from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end
$$;
