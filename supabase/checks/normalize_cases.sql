-- Not a migration: the shared case table, run by hand against `dev` so its
-- output can be pasted into 20260827090000_normalize_function.sql.
--
-- The SAME cases live in test/domain/name_normalization_test.dart. Keeping two
-- lists in sync by hand is the price of the app and the database agreeing on
-- what "the same name" means without a round trip.
select
  input,
  public.normalize_name(input) as normalized
from (values
  ('Coca-Cola'),
  ('  COCA cola '),
  ('Açaí'),
  ('ÁÇAÍ'),
  ('São João'),
  ('Limpeza'),
  ('  limpeza'),
  ('Pão de Açúcar'),
  ('Müller'),
  -- Deliberately outside Portuguese: the Dart table is written by hand and
  -- cannot cover the whole unaccent dictionary. If this row differs between
  -- the two, the app and the index disagree — which is the point of the file.
  ('Dvořák'),
  ('Smørrebrød')
) as cases(input);
