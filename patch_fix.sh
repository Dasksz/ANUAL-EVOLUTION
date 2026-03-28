#!/bin/bash
# Move ALTER FUNCTION to AFTER CREATE OR REPLACE FUNCTION
grep -v "ALTER FUNCTION public.get_innovations_data" sql/full_system_v1.sql > temp_sql
echo "ALTER FUNCTION public.get_innovations_data(p_filial text[], p_cidade text[], p_supervisor text[], p_vendedor text[], p_rede text[], p_tipovenda text[], p_categoria_inovacao text, p_ano text, p_mes text) SET search_path = public;" >> temp_sql
mv temp_sql sql/full_system_v1.sql
