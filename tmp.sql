        v_active_client_cond, v_where_summary, v_current_year, v_previous_year, -- Chart
        v_active_client_cond, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, v_where_summary, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, -- KPI Curr
        v_active_client_cond, v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, v_where_summary, v_previous_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND mes = %L ', v_target_month) ELSE '' END, -- KPI Prev
        v_active_client_cond, v_where_summary, date_trunc('month', v_tri_start), date_trunc('month', v_tri_end), date_trunc('month', v_tri_start), date_trunc('month', v_tri_end), v_where_summary, date_trunc('month', v_tri_start), date_trunc('month', v_tri_end), -- KPI Tri
        v_where_raw, v_current_year, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END, -- Prod
        v_where_raw, v_previous_year, v_current_year, CASE WHEN v_target_month IS NOT NULL THEN format(' AND EXTRACT(MONTH FROM dtped) = %L ', v_target_month) ELSE '' END, -- Prod
        v_active_client_cond_slow -- Prod Agg
        )
        INTO v_chart_data, v_kpis_current, v_kpis_previous, v_kpis_tri_avg, v_products_table;

    ELSE
        -- SLOW PATH (Full Raw Data with dim_produtos join)
        EXECUTE format('
            WITH
            salty_base AS (
                SELECT s.dtped, s.codcli, s.vlvenda
