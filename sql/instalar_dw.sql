-- =====================================================================
-- Instala o DW do zero (APAGA dw, dw_floco, stg e etl) e roda a carga inicial.
-- O OLTP (esquema public) precisa ja estar populado pela classe CargaDados.
--
--   psql -U bd2 -d supermercado -f sql/instalar_dw.sql
-- =====================================================================
\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
SET client_min_messages = warning;

\echo '>> 1/5 Modelo estrela (dw)'
\ir dw/01_ddl_estrela.sql
\echo '>> 2/5 Modelo floco de neve (dw_floco)'
\ir dw/02_ddl_floco.sql
\echo '>> 3/5 Staging (stg) e controle (etl)'
\ir etl/01_staging_e_controle.sql
\echo '>> 4/5 Procedures do ETL e carga do floco'
\ir etl/02_procedures_etl.sql
\ir dw/03_carga_floco.sql
\echo '>> 5/5 Carga inicial'
\ir etl/rodar_etl.sql
