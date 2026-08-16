-- Pies and Samoosas: sold as bags of 3 at R24 (R8 each)
insert into public.products (name, cost_price, sell_price, active)
select v.name, v.cost_price, v.sell_price, true
from (
  values
    ('Pies (bag of 3)'::text, 0.00::numeric, 24.00::numeric),
    ('Samoosas (bag of 3)', 0.00, 24.00)
) as v(name, cost_price, sell_price)
where not exists (
  select 1 from public.products p where p.name = v.name
);
