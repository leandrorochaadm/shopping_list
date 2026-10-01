-- The list line can now ask for a REGISTRATION (type + brand + description),
-- and when it does, only a purchase of that registration writes it off
-- (decision M-a, 01/10/2026). The packaging stays out of the rule.
alter table public.shopping_list_item
  add column preferred_registration_id uuid
    references public.product_registration (id);

-- 1. Lines that preferred a packaging: its registration is unambiguous.
update public.shopping_list_item as s
   set preferred_registration_id = p.product_registration_id
  from public.product as p
 where s.preferred_product_id = p.id
   and s.preferred_registration_id is null;

-- 2. Lines that preferred only a brand: carried over ONLY when the type has
--    exactly one registration of that brand. With two ("integral" and
--    "desnatado") there is no honest choice, and the line stays type-level —
--    the same outcome as a preference that fell (requirement 16).
update public.shopping_list_item as s
   set preferred_registration_id = r.id
  from public.product_registration as r
 where s.preferred_registration_id is null
   and s.preferred_brand_id is not null
   and r.product_type_id = s.product_type_id
   and r.brand_id = s.preferred_brand_id
   and (select count(*) from public.product_registration as r2
         where r2.product_type_id = s.product_type_id
           and r2.brand_id = s.preferred_brand_id) = 1;

-- preferred_brand_id and preferred_product_id stay for now: an installed PWA
-- only updates on the next launch, and an old build embedding a dropped
-- column would break the list. They go in a later migration.
