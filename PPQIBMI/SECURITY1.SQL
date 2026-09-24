------------------------------------------------------------------
-- 01_security.sql  -  Module 1: Security
------------------------------------------------------------------
SET SCHEMA SREERAMC1;

-- Drop tables in reverse dependency order to avoid constraint errors
DROP TABLE IF EXISTS SEC_LOGIN_AUDIT;
DROP TABLE IF EXISTS SEC_ESIGNATURE;
DROP TABLE IF EXISTS SEC_ROLE_PERM;
DROP TABLE IF EXISTS SEC_USER;
DROP TABLE IF EXISTS SEC_ROLE;

