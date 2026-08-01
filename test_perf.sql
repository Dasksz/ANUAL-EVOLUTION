BEGIN;
EXPLAIN ANALYZE
SELECT * FROM get_boxes_dashboard_data(
    ARRAY['1'], -- filial
    NULL, NULL, NULL, NULL,
    '2024',
    NULL,
    NULL,
    NULL,
    NULL, -- produto
    NULL -- categoria
);
ROLLBACK;
