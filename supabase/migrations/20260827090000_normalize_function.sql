-- The one function the duplicate guard of the six catalogs is built on.
--
-- Every catalog (category, product_type, brand, product_registration, store)
-- compares names NORMALIZED: no case, no surrounding blanks, no accents. The
-- app answers the user in Dart — `lib/domain/models/name_normalization.dart`
-- is the mirror of this function — and the unique index over the generated
-- column is the net underneath.
--
-- ── Why a function of our own, and not `unaccent()` directly ───────────────
-- `unaccent(text)` is STABLE, not IMMUTABLE: it looks up whichever dictionary
-- the session has loaded. Postgres REFUSES a STABLE function inside an index
-- or a generated column, so the one-argument form cannot be used where we
-- need it. The two-argument form — with the dictionary named explicitly — is
-- IMMUTABLE, and wrapping it here is what makes the whole thing indexable.
--
-- ── The trap that only shows up months later ──────────────────────────────
-- The moment the FIRST generated column uses normalize_name, this function is
-- frozen in practice. Replacing it is worse than it looks:
--
--   * `CREATE OR REPLACE FUNCTION` SUCCEEDS (it is `DROP` that the dependency
--     blocks), so nothing warns you;
--   * the values already stored in the generated columns are NOT recomputed;
--   * the unique indexes keep their old entries.
--
-- The result is a screen that lets through exactly what the database was
-- supposed to refuse, with no error anywhere. Changing the normalization
-- later = a new migration PLUS a forced UPDATE on every table that uses it.
-- Decide it here, once.

create extension if not exists unaccent with schema extensions;

create or replace function public.normalize_name(value text)
returns text
language sql
immutable
parallel safe
-- Pinned so the function keeps meaning the same thing regardless of the
-- caller's search_path — required of anything an index depends on.
set search_path = extensions, pg_catalog
as $$
  -- Two arguments on purpose: `unaccent(value)` alone is STABLE and Postgres
  -- would refuse this function inside an index.
  select lower(trim(extensions.unaccent('extensions.unaccent'::regdictionary, value)))
$$;

comment on function public.normalize_name(text) is
  'Normalized name used by the catalog duplicate guard: lower(trim(unaccent)). '
  'Mirrored in Dart by lib/domain/models/name_normalization.dart. '
  'Frozen once the first generated column uses it — see the migration header.';

-- ── Dart vs SQL: the comparison this file has to carry ─────────────────────
-- A pure Dart test cannot reach Postgres, so `test/domain/name_normalization_test.dart`
-- only guards the Dart half. The other half is run by hand, once, against the
-- `dev` project, and its output is PASTED BELOW as a comment:
--
--   psql "$DEV_DATABASE_URL" -f supabase/checks/normalize_cases.sql
--
-- Dart removes accents from a table written by hand (the Portuguese ones);
-- Postgres removes them from the much larger unaccent dictionary. Any letter
-- outside our table — a `ř`, an `ø` in an imported brand name — is stripped by
-- the database and kept by the app, and then the screen lets through what the
-- index refuses. That divergence is what the pasted output is here to expose.
--
-- OUTPUT OF THE RUN — PostgreSQL 17.10 (Homebrew), 28/08/2026, on a scratch
-- database with this same migration applied. **Run it again against `dev`
-- once A1 exists**: unaccent's dictionary is a data file, and a managed
-- Postgres may not ship exactly the one used here.
--
--      input       |  normalize_name
--   ---------------+---------------
--    Coca-Cola     | coca-cola
--      COCA cola   | coca cola
--    Açaí          | acai
--    ÁÇAÍ          | acai
--    São João      | sao joao
--    Limpeza       | limpeza
--      limpeza     | limpeza
--    Pão de Açúcar | pao de acucar
--    Müller        | muller
--    Dvořák        | dvorak        <-- Dart returns 'dvořak'
--    Smørrebrød    | smorrebrod    <-- Dart returns 'smørrebrød'
--
-- The last two rows are the divergence, measured instead of guessed: Postgres
-- strips `ř` and `ø`, the hand-written Dart table does not. The consequence is
-- contained — the app offers to create the name, the unique index refuses the
-- insert, and the user reads "já existe um cadastro com esses dados" — but the
-- app will not have explained it first. Widening the table in
-- `lib/domain/models/name_normalization.dart` is the fix, and
-- `test/domain/name_normalization_test.dart` holds the current behaviour.
