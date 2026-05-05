-- =============================================
-- LAB3_SEM6 TASK 5 (NETWORK PERF):
-- Compare data transfer time:
--  - local unix socket (no SSL)
--  - TCP + SSL
-- This script is meant to be executed via psql.
-- =============================================

\echo '--- COPY payload stream (output redirected to /dev/null, timing is printed) ---'
\timing on
\o /dev/null
COPY (SELECT payload FROM app.lab3_sem6_perf_plain) TO STDOUT;
\o
\timing off

