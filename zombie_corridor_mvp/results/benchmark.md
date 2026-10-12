# Benchmark observado

Ventana: 10 ≤ elapsed_s < 70.
Objetivo p95: < 16.7 ms. Percentiles nearest-rank.
CPU: 100 % = un núcleo. RSS en MiB. NA = dato no medido.
Los estados del resumen no certifican jugabilidad ni duración completa de la prueba.

| run_id | scenario | tick_count | sample_count | observed_span_s | tick_ms_p95 | tick_ms_p99 | cpu_core_percent_mean | rss_mb_peak | active_mobs_mean | dormant_mobs_mean | tx_bytes_s_mean | dormancy_status | tick_goal_status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| local_active20_54e6b90408 | active20 | 1800 | 60 | 59.975 | 1.325 | 1.655 | 3.753 | 99.594 | 20.000 | 0.000 | 7400.946 | NOT_EXERCISED | WITHIN_GOAL |
| local_active50_30e5063017 | active50 | 1800 | 60 | 59.988 | 10.521 | 11.687 | 6.952 | 85.016 | 50.000 | 0.000 | 66964.022 | NOT_EXERCISED | WITHIN_GOAL |
| local_combat_37448e0a3c | combat | 1800 | 60 | 59.968 | 4.042 | 5.037 | 4.654 | 100.688 | 12.067 | 1.000 | 13418.061 | PASS_DORMANCY | WITHIN_GOAL |
| local_dormant100_2f6c70e9aa | dormant100 | 1800 | 60 | 59.981 | 0.828 | 0.991 | 3.502 | 100.859 | 0.000 | 100.000 | 1516.768 | PASS_DORMANCY | WITHIN_GOAL |
| local_dormant20_ced4c806cd | dormant20 | 1800 | 60 | 59.987 | 1.196 | 1.422 | 3.512 | 100.422 | 0.000 | 20.000 | 1516.141 | PASS_DORMANCY | WITHIN_GOAL |
| local_idle_41f64b54b6 | idle | 1800 | 60 | 59.981 | 0.038 | 0.044 | 0.488 | 98.906 | 0.000 | 0.000 | 0.000 | NOT_EXERCISED | WITHIN_GOAL |
| local_player_cbd3e3ad89 | player | 1800 | 60 | 59.984 | 0.916 | 1.130 | 3.432 | 100.375 | 0.000 | 0.000 | 1508.269 | NOT_EXERCISED | WITHIN_GOAL |
| local_split_ee7f008877 | split | 1800 | 60 | 59.981 | 2.219 | 2.429 | 4.284 | 100.469 | 20.000 | 0.000 | 9605.960 | NOT_EXERCISED | WITHIN_GOAL |
