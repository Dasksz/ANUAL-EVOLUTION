-- Recreate View to include new column
create or replace view public.all_sales as
select * from public.data_detailed
union all
select * from public.data_history;
