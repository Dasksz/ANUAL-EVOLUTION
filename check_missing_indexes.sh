#!/bin/bash
# Check if idx_cache_filters_filial_only exists
grep -i "idx_cache_filters_filial_only" sql/full_system_v1.sql || echo "idx_cache_filters_filial_only not found"
# Check if idx_cache_filters_rede_only exists
grep -i "idx_cache_filters_rede_only" sql/full_system_v1.sql || echo "idx_cache_filters_rede_only not found"
# Check if idx_cache_filters_fornecedor_only exists
grep -i "idx_cache_filters_fornecedor_only" sql/full_system_v1.sql || echo "idx_cache_filters_fornecedor_only not found"
