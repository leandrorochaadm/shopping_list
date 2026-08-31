-- H17 + H18 — o consumo por tipo nas DUAS janelas, e a data da primeira compra.
--
-- Uma função para as duas histórias (`handoff §8`: "H18 = mesma consulta de
-- H17 + consumido no mês corrente"), e a H17 precisa do mês também: é dele que
-- sai a média do tipo cuja primeira compra foi no mês em curso.
--
-- Ela SOMA, AGRUPA e responde uma data. Não divide, não arredonda, não decide
-- divisor e não filtra por `active`: tudo isso é Dart (decisão 7, `R7`, e a
-- fronteira que `handoff §H17` escreve por extenso).
--
-- Os quatro intervalos chegam por parâmetro, do relógio do aparelho: nenhum
-- now(), nenhum current_date (decisão 13).
create or replace function public.type_consumption(
  p_window_from date,
  p_window_to   date,
  p_month_from  date,
  p_month_to    date
)
returns jsonb
language sql
-- `stable` como as irmãs, e pelo mesmo par de motivos: ela só lê, e sem o
-- marcador de volatilidade o linter do Supabase acusa no primeiro `dev`.
stable
security invoker
-- Sem esta linha o linter acusa `function_search_path_mutable` e a resolução
-- de nome passa a depender de quem chama.
set search_path = public
as $$
  with line as (
    select
      t.id          as product_type_id,
      t.name        as product_type_name,
      t.category_id,
      t.base_unit,
      t.active      as type_active,
      c.name        as category_name,
      c.active      as category_active,
      p.purchase_date,
      i.quantity_in_base_unit
    from public.purchase_item i
    join public.purchase p on p.id = i.purchase_id
    join public.product pr on pr.id = i.product_id
    join public.product_registration r on r.id = pr.product_registration_id
    join public.product_type t on t.id = r.product_type_id
    join public.category c on c.id = t.category_id
    -- A UNIÃO dos dois intervalos, e não um `between` só: o tipo cuja primeira
    -- compra foi no mês em curso não tem NADA dentro da janela fechada, e é
    -- justamente ele que a Tela 2 mais precisa oferecer.
    where (p.purchase_date between p_window_from and p_window_to)
       or (p.purchase_date between p_month_from  and p_month_to)
  ),
  -- A data da primeira compra de CADA tipo, sobre o histórico inteiro e sem
  -- nenhum filtro de data. É ela que diz se o produto já era comprado antes da
  -- janela (divide por 3) ou se estreou dentro dela (divide por 2 ou por 1) —
  -- e a conta em si é Dart.
  first_purchase as (
    select r.product_type_id, min(p.purchase_date) as day
      from public.purchase_item i
      join public.purchase p on p.id = i.purchase_id
      join public.product pr on pr.id = i.product_id
      join public.product_registration r on r.id = pr.product_registration_id
     group by r.product_type_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'product_type_id',    g.product_type_id,
    'product_type_name',  g.product_type_name,
    'category_id',        g.category_id,
    'category_name',      g.category_name,
    'base_unit',          g.base_unit,
    -- Os dois `active` vêm e o Dart é que descarta (decisão E-e): a regra
    -- "tipo desativado não é sugerido" é da H10, e regra não mora em SQL.
    'type_active',        g.type_active,
    'category_active',    g.category_active,
    'consumed_in_window', g.consumed_in_window,
    'consumed_in_month',  g.consumed_in_month,
    'first_purchase_on',  f.day
  )), '[]'::jsonb)
  from (
    select
      product_type_id, product_type_name, category_id, category_name,
      base_unit, type_active, category_active,
      -- `filter` em vez de `case`: é a mesma agregação lida duas vezes, e o
      -- `coalesce` existe porque `sum()` de zero linhas devolve NULL — que é
      -- exatamente o caso do tipo que só tem compra no mês em curso.
      --
      -- `::bigint` nos dois, e não é enfeite: `sum()` sobre `bigint` devolve
      -- NUMERIC no Postgres, e numeric dentro de `jsonb` chega como
      -- `18000.00`. É a lição que `20260830120000_period_report.sql` já
      -- escreveu.
      coalesce(sum(quantity_in_base_unit) filter (
        where purchase_date between p_window_from and p_window_to), 0)::bigint
        as consumed_in_window,
      coalesce(sum(quantity_in_base_unit) filter (
        where purchase_date between p_month_from and p_month_to), 0)::bigint
        as consumed_in_month
    from line
    group by product_type_id, product_type_name, category_id, category_name,
             base_unit, type_active, category_active
  ) g
  -- `join` e não `left join`: a linha só existe porque houve compra, então a
  -- primeira compra existe. Um `left` esconderia, com um null, um furo de
  -- integridade.
  join first_purchase f on f.product_type_id = g.product_type_id;
$$;

-- Nenhuma ordenação, de propósito: quem ordena é `groupAveragesByCategory`, em
-- Dart, e um `order by` aqui seria uma segunda ordenação para divergir da
-- primeira. É a mesma nota que `report_period` carrega.
comment on function public.type_consumption(date, date, date, date) is
  'Consumo por tipo na janela fechada e no mes em curso, mais a data da '
  'primeira compra de cada tipo. So soma, agrupa e devolve uma data: o '
  'divisor, a divisao, o arredondamento e o filtro de desativado sao Dart. '
  'Os quatro intervalos chegam por parametro, do relogio do aparelho.';

-- Dentro desta migration, nunca no `rls.sql` já aplicado.
grant execute on function public.type_consumption(date, date, date, date)
  to anon, authenticated;
