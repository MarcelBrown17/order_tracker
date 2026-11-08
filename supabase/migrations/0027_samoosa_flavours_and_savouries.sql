-- Samoosa flavours + spring rolls, subs, pizza.
-- Keep old "Samoosas (bag of 3)" inactive so historical orders stay intact.

update public.products
set active = false
where name = 'Samoosas (bag of 3)';

insert into public.products (name, cost_price, sell_price, active, category)
select v.name, v.cost_price, v.sell_price, true, 'other'
from (
  values
    ('Samoosas (Cheese and corn)'::text, 0.00::numeric, 25.00::numeric),
    ('Samoosas (Potato)', 0.00, 25.00),
    ('Samoosas (Mince)', 0.00, 25.00),
    ('Samoosas (Chicken)', 0.00, 25.00),
    ('Spring rolls', 0.00, 25.00),
    ('Subs', 0.00, 30.00),
    ('Pizza', 0.00, 30.00)
) as v(name, cost_price, sell_price)
where not exists (
  select 1 from public.products p where p.name = v.name
);

update public.products
set category = 'other', active = true
where name in (
  'Samoosas (Cheese and corn)',
  'Samoosas (Potato)',
  'Samoosas (Mince)',
  'Samoosas (Chicken)',
  'Spring rolls',
  'Subs',
  'Pizza'
);
