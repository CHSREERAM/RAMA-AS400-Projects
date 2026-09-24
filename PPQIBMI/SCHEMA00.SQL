------------------------------------------------------------------
-- SCHEMA0.sql
-- Creates the PPQ application library as a single SQL schema
-- (SQL schema = IBM i library). Run once via:
--   RUNSQLSTM SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(SCHEMA0) COMMIT(*NONE)
-- or interactively from STRSQL / ACS or VS Code "Run SQL Scripts".
--
-- This package targets a single library and single source file:
-- SREERAMC1/PPQIBMI. All source - SQL, DSPF, PRTF, RPGLE, CLLE, and
-- binder language - lives there as members, differentiated by each
-- member's source type, not by which source file it's in.
-- to create a brand-new Physical Library (*LIB) object -
--Your current user profile does not have this level of authorization.
------------------------------------------------------------------

-- CREATE SCHEMA SREERAMC1;
-- COMMENT ON SCHEMA SREERAMC1 IS 'PPQ Protocol Management System';

--SET SCHEMA SREERAMC1;

SET SCHEMA = SREERAMC1;
------------------------------------------------------------------
-- Shared sequence objects
------------------------------------------------------------------
CREATE SEQUENCE SEQ_PROTOCOL_NO
  AS INTEGER
  START WITH 1
  INCREMENT BY 1
  NO CYCLE
  CACHE 20;

CREATE SEQUENCE SEQ_AUDIT_ID
  AS BIGINT
  START WITH 1
  INCREMENT BY 1
  NO CYCLE
  CACHE 50;

CREATE SEQUENCE SEQ_DEVIATION_NO
  AS INTEGER
  START WITH 1
  INCREMENT BY 1
  NO CYCLE
  CACHE 20;
