-- The four magnitudes, each in its own WHOLE and small unit: gram,
-- millilitre, unit and centimetre.
--
-- No stored number changes: `piece_size`, `total_content` and
-- `quantity_in_base_unit` have been in grams and millilitres since B5. What
-- changes is the LABEL of the magnitude, which gave the impression the integer
-- was in kilos.
--
-- 'centimeter' is the new one: aluminium foil, cling film, string and hose are
-- sold by the metre, and there was no magnitude for them.

alter table public.product_type
  drop constraint product_type_base_unit_check;

update public.product_type
   set base_unit = case base_unit
                     when 'kilogram' then 'gram'
                     when 'liter'    then 'milliliter'
                     else base_unit
                   end;

alter table public.product_type
  add constraint product_type_base_unit_check
  check (base_unit in ('gram', 'milliliter', 'unit', 'centimeter'));

-- `piece_size_unit` stopped being "what the person typed" and became the
-- magnitude of the leaf — always the same as the type above it. The column
-- keeps the name it has: renaming it would cost the write function and the
-- Dart payload, and the old name does not lie about the content.
alter table public.product
  drop constraint product_piece_size_unit_check;

update public.product
   set piece_size_unit = case piece_size_unit
                           when 'kilogram' then 'gram'
                           when 'liter'    then 'milliliter'
                           else piece_size_unit
                         end
 where piece_size_unit is not null;

alter table public.product
  add constraint product_piece_size_unit_check
  check (
    piece_size_unit is null
    or piece_size_unit in ('gram', 'milliliter', 'unit', 'centimeter')
  );
