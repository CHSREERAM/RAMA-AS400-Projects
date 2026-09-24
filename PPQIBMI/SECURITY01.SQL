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

------------------------------------------------------------------
-- Table: SEC_ROLE
------------------------------------------------------------------
CREATE TABLE SEC_ROLE (
  ROLE_CD        CHAR(10)      NOT NULL,
  ROLE_DESC      VARCHAR(60)   NOT NULL,
  APPROVAL_LEVEL SMALLINT      NOT NULL DEFAULT 0,   -- ordering in the approval workflow
  ACTIVE_IND     CHAR(1)       NOT NULL DEFAULT 'Y'
  CONSTRAINT CK_SECROLE_ACT CHECK (ACTIVE_IND IN ('Y','N')),
  CONSTRAINT PK_SEC_ROLE PRIMARY KEY (ROLE_CD)
);
LABEL ON TABLE SEC_ROLE IS 'Security - Role Master';

------------------------------------------------------------------
-- Table: SEC_USER
------------------------------------------------------------------
CREATE TABLE SEC_USER (
  USER_ID        VARCHAR(10)   NOT NULL,          -- matches IBM i user profile name
  FULL_NAME      VARCHAR(60)   NOT NULL,
  EMAIL          VARCHAR(80),
  DEPT_CD        CHAR(10),
  PASSWORD_HASH  VARCHAR(128)  NOT NULL,           -- SHA-256 hex, app-level 2nd factor for e-sign (
  PASSWORD_CHG_DT DATE,
  FAILED_LOGIN_CNT SMALLINT    NOT NULL DEFAULT 0,
  LOCKED_IND     CHAR(1)       NOT NULL DEFAULT 'N'
  CONSTRAINT CK_SECUSER_LOCK CHECK (LOCKED_IND IN ('Y','N')),
  ACTIVE_IND     CHAR(1)       NOT NULL DEFAULT 'Y'
  CONSTRAINT CK_SECUSER_ACT  CHECK (ACTIVE_IND IN ('Y','N')),
  CREATE_TS      TIMESTAMP     NOT NULL DEFAULT CURRENT TIMESTAMP,
  LAST_LOGIN_TS  TIMESTAMP,
  CONSTRAINT PK_SEC_USER PRIMARY KEY (USER_ID)
);
LABEL ON TABLE SEC_USER IS 'Security - User Profile';

------------------------------------------------------------------
-- Table: SEC_ROLE_PERM
------------------------------------------------------------------
CREATE TABLE SEC_ROLE_PERM (
  USER_ID        VARCHAR(10)   NOT NULL,
  ROLE_CD        CHAR(10)      NOT NULL,
  ASSIGNED_TS    TIMESTAMP     NOT NULL DEFAULT CURRENT TIMESTAMP,
  ASSIGNED_BY    VARCHAR(10)   NOT NULL,
  CONSTRAINT PK_SEC_ROLE_PERM PRIMARY KEY (USER_ID, ROLE_CD),
  CONSTRAINT FK_SRP_USER FOREIGN KEY (USER_ID)
     REFERENCES SEC_USER (USER_ID) ON DELETE CASCADE,
  CONSTRAINT FK_SRP_ROLE FOREIGN KEY (ROLE_CD)
     REFERENCES SEC_ROLE (ROLE_CD) ON DELETE CASCADE
);
LABEL ON TABLE SEC_ROLE_PERM IS
   'Security - User to Role assignment (many-to-many)';

------------------------------------------------------------------
-- Table: SEC_ESIGNATURE
------------------------------------------------------------------
CREATE TABLE SEC_ESIGNATURE (
  ESIG_ID        BIGINT        NOT NULL GENERATED ALWAYS AS IDENTITY
  (START WITH 1 INCREMENT BY 1),
  USER_ID        VARCHAR(10)   NOT NULL,
  MEANING_TXT    VARCHAR(100)  NOT NULL,           -- e.g. 'Reviewed and Approved'
  SIGNED_TS      TIMESTAMP     NOT NULL DEFAULT CURRENT TIMESTAMP,
  REAUTH_IND     CHAR(1)       NOT NULL DEFAULT 'Y'
  CONSTRAINT CK_ESIG_REAUTH CHECK (REAUTH_IND IN ('Y','N')),
  SOURCE_IP      VARCHAR(45),
  CONSTRAINT PK_SEC_ESIGNATURE PRIMARY KEY (ESIG_ID),
  CONSTRAINT FK_ESIG_USER FOREIGN KEY (USER_ID) REFERENCES SEC_USER (USER_ID)
);
LABEL ON TABLE SEC_ESIGNATURE IS
  'Security - Captured Electronic Signature';
COMMENT ON TABLE SEC_ESIGNATURE IS
  'Security - Captured Electronic Signature (21 CFR Part 11 style)';

------------------------------------------------------------------
-- Table: SEC_LOGIN_AUDIT
------------------------------------------------------------------
CREATE TABLE SEC_LOGIN_AUDIT (
  LOGIN_AUDIT_ID BIGINT        NOT NULL GENERATED ALWAYS AS IDENTITY,
  USER_ID        VARCHAR(10)   NOT NULL,
  EVENT_TYPE     CHAR(10)      NOT NULL,            -- LOGIN / LOGOFF / FAILED / LOCKED
  EVENT_TS       TIMESTAMP     NOT NULL DEFAULT CURRENT TIMESTAMP,
  DEVICE_NAME    VARCHAR(10),
  CONSTRAINT PK_SEC_LOGIN_AUDIT PRIMARY KEY (LOGIN_AUDIT_ID)
);
LABEL ON TABLE SEC_LOGIN_AUDIT IS 'Security - Login/Logoff Audit Trail';

CREATE INDEX IX_SLA_USER ON SEC_LOGIN_AUDIT (USER_ID, EVENT_TS);
