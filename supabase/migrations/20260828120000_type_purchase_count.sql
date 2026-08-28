-- How many times each product type has already been bought — what orders the
-- `#1a` panel when the search box is empty ("os tipos mais comprados por
-- eles").
--
-- It SUMS and GROUPS, and nothing else: no `now()`, no `current_date`, no
-- window and no numeric threshold (decisions 7 and 13). What to do with the
-- count is Dart's decision.
--
-- `left join` from the type: a type never bought shows up with 0 instead of
-- disappearing — in the first weeks EVERY type is in that situation, and an
-- empty panel would be the worst possible first contact with the most used
-- path of the app.
create view public.product_type_purchase_count
with (security_invoker = on) as
select
  t.id as product_type_id,
  count(i.id) as purchase_count
from public.product_type t
left join public.product_registration r on r.product_type_id = t.id
left join public.product p on p.product_registration_id = r.id
left join public.purchase_item i on i.product_id = p.id
group by t.id;

comment on view public.product_type_purchase_count is
  'Contagem de itens de compra por tipo de produto. Ordena o painel #1a com a '
  'busca vazia. Não decide nada: sem now(), sem janela e sem limiar.';

-- `security_invoker` above makes the view run with the permissions of whoever
-- calls it, not of its owner — so the permissive policies of the tables
-- underneath stay the ones that hold, instead of the view becoming a hole
-- over the RLS.
grant select on public.product_type_purchase_count to anon, authenticated;
