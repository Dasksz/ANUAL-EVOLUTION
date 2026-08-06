INSERT INTO data_summary_frequency (ano, mes, codcli, filial, cidade, codsupervisor, codusur, codfor, tipovenda, pedido, vlvenda, peso, rede, created_at)
SELECT
    2024,
    (random() * 11 + 1)::int,
    (random() * 1000)::int::text,
    (random() * 10 + 1)::int::text,
    md5(random()::text),
    (random() * 20 + 1)::int::text,
    (random() * 50 + 1)::int::text,
    (random() * 5 + 1)::int::text,
    (random() * 5 + 1)::int::text,
    md5(random()::text),
    random() * 1000,
    random() * 100,
    md5(random()::text),
    now() - (random() * 365)::int * interval '1 day'
FROM generate_series(1, 100000);
