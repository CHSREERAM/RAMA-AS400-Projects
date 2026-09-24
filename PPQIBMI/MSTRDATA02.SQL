------------------------------------------------------------------
-- 02_masterdata.sql  -  Module 2: Master Data
------------------------------------------------------------------
SET SCHEMA = SREERAMC1;

-- Drop tables first if they already exist
DROP TABLE IF EXISTS MD_PACKAGING_MATERIAL;
DROP TABLE IF EXISTS MD_ENV_CONDITION;
DROP TABLE IF EXISTS MD_ANALYTICAL_METHOD;
DROP TABLE IF EXISTS MD_APPROVER;
DROP TABLE IF EXISTS MD_VALIDATION_TEAM;
DROP TABLE IF EXISTS MD_INSTRUMENT;
DROP TABLE IF EXISTS MD_UTILITY;
DROP TABLE IF EXISTS MD_EQUIPMENT;
DROP TABLE IF EXISTS MD_VENDOR;
DROP TABLE IF EXISTS MD_MATERIAL;
DROP TABLE IF EXISTS MD_API;
DROP TABLE IF EXISTS MD_PRODUCT;
DROP TABLE IF EXISTS MD_MFG_AREA;
DROP TABLE IF EXISTS MD_DEPARTMENT;

------------------------------------------------------------------
-- Table: MD_DEPARTMENT
------------------------------------------------------------------
CREATE TABLE MD_DEPARTMENT (
  DEPT_CD      CHAR(10)     NOT NULL,
  DEPT_NAME    VARCHAR(60)  NOT NULL,
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_DEPT PRIMARY KEY (DEPT_CD)
);

------------------------------------------------------------------
-- Table: MD_MFG_AREA
------------------------------------------------------------------
CREATE TABLE MD_MFG_AREA (
  AREA_CD      CHAR(10)     NOT NULL,
  AREA_NAME    VARCHAR(60)  NOT NULL,
  ROOM_CLASS   VARCHAR(20),
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_AREA PRIMARY KEY (AREA_CD)
);

------------------------------------------------------------------
-- Table: MD_PRODUCT
------------------------------------------------------------------
CREATE TABLE MD_PRODUCT (
  PRODUCT_CD   CHAR(15)     NOT NULL,
  GENERIC_NAME VARCHAR(80)  NOT NULL,
  BRAND_NAME   VARCHAR(80),
  DOSAGE_FORM  VARCHAR(40),
  DEFAULT_STRENGTH VARCHAR(40),
  SHELF_LIFE_MONTHS SMALLINT,
  STORAGE_COND VARCHAR(60),
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_PRODUCT PRIMARY KEY (PRODUCT_CD)
);

------------------------------------------------------------------
-- Table: MD_API
------------------------------------------------------------------
CREATE TABLE MD_API (
  API_CD       CHAR(15)     NOT NULL,
  API_NAME     VARCHAR(80)  NOT NULL,
  CAS_NO       VARCHAR(20),
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_API PRIMARY KEY (API_CD)
);

------------------------------------------------------------------
-- Table: MD_MATERIAL
-- MATERIAL_TYPE: A=API, E=Excipient, P=Packaging
------------------------------------------------------------------
CREATE TABLE MD_MATERIAL (
  MATERIAL_CD  CHAR(15)     NOT NULL,
  MATERIAL_NAME VARCHAR(80) NOT NULL,
  MATERIAL_TYPE CHAR(1)     NOT NULL DEFAULT 'E',    -- A=API E=Excipient P=Packaging
  DEFAULT_UOM  CHAR(6),
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_MATERIAL PRIMARY KEY (MATERIAL_CD)
);

------------------------------------------------------------------
-- Table: MD_VENDOR
------------------------------------------------------------------
CREATE TABLE MD_VENDOR (
  VENDOR_CD    CHAR(15)     NOT NULL,
  VENDOR_NAME  VARCHAR(80)  NOT NULL,
  COUNTRY      VARCHAR(40),
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_VENDOR PRIMARY KEY (VENDOR_CD)
);

------------------------------------------------------------------
-- Table: MD_EQUIPMENT
------------------------------------------------------------------
CREATE TABLE MD_EQUIPMENT (
  EQUIP_CD     CHAR(15)     NOT NULL,
  EQUIP_NAME   VARCHAR(80)  NOT NULL,
  EQUIP_TYPE   VARCHAR(40),
  LOCATION_CD  CHAR(10),
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_EQUIPMENT PRIMARY KEY (EQUIP_CD)
);

------------------------------------------------------------------
-- Table: MD_UTILITY
-- UTILITY_NAME: e.g. Compressed Air / HVAC / Purified Water
------------------------------------------------------------------
CREATE TABLE MD_UTILITY (
  UTILITY_CD   CHAR(10)     NOT NULL,
  UTILITY_NAME VARCHAR(60)  NOT NULL,               -- Compressed Air / HVAC / Purified Water / Stea
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_UTILITY PRIMARY KEY (UTILITY_CD)
);

------------------------------------------------------------------
-- Table: MD_INSTRUMENT
------------------------------------------------------------------
CREATE TABLE MD_INSTRUMENT (
  INSTRUMENT_CD CHAR(15)    NOT NULL,
  INSTRUMENT_NAME VARCHAR(80) NOT NULL,
  CALIBRATION_FREQ_DAYS SMALLINT,
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_INSTRUMENT PRIMARY KEY (INSTRUMENT_CD)
);

------------------------------------------------------------------
-- Table: MD_VALIDATION_TEAM
------------------------------------------------------------------
CREATE TABLE MD_VALIDATION_TEAM (
  TEAM_MEMBER_CD CHAR(10)   NOT NULL,
  USER_ID        VARCHAR(10) NOT NULL,
  DEFAULT_DESIGNATION VARCHAR(60),
  DEFAULT_DEPT_CD CHAR(10),
  ACTIVE_IND     CHAR(1)    NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_VALTEAM PRIMARY KEY (TEAM_MEMBER_CD),
  CONSTRAINT FK_MDVT_USER FOREIGN KEY (USER_ID)
    REFERENCES SEC_USER (USER_ID)
);

------------------------------------------------------------------
-- Table: MD_APPROVER
------------------------------------------------------------------
CREATE TABLE MD_APPROVER (
  APPROVER_CD  CHAR(10)     NOT NULL,
  USER_ID      VARCHAR(10)  NOT NULL,
  ROLE_CD      CHAR(10)     NOT NULL,
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_APPROVER PRIMARY KEY (APPROVER_CD),
  CONSTRAINT FK_MDAP_USER FOREIGN KEY (USER_ID)
     REFERENCES SEC_USER (USER_ID),
  CONSTRAINT FK_MDAP_ROLE FOREIGN KEY (ROLE_CD)
     REFERENCES SEC_ROLE (ROLE_CD)
);

------------------------------------------------------------------
-- Table: MD_ANALYTICAL_METHOD
------------------------------------------------------------------
CREATE TABLE MD_ANALYTICAL_METHOD (
  METHOD_CD    CHAR(15)     NOT NULL,
  METHOD_NAME  VARCHAR(80)  NOT NULL,
  METHOD_VERSION VARCHAR(10),
  VALIDATED_IND CHAR(1)     NOT NULL DEFAULT 'N',
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_METHOD PRIMARY KEY (METHOD_CD)
);

------------------------------------------------------------------
-- Table: MD_ENV_CONDITION
------------------------------------------------------------------
CREATE TABLE MD_ENV_CONDITION (
  ENV_CD       CHAR(10)     NOT NULL,
  ENV_NAME     VARCHAR(60)  NOT NULL,
  TEMP_MIN     DECIMAL(5, 1),
  TEMP_MAX     DECIMAL(5, 1),
  HUMIDITY_MIN DECIMAL(5, 1),
  HUMIDITY_MAX DECIMAL(5, 1),
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_ENVCOND PRIMARY KEY (ENV_CD)
);

------------------------------------------------------------------
-- Table: MD_PACKAGING_MATERIAL
------------------------------------------------------------------
CREATE TABLE MD_PACKAGING_MATERIAL (
  PKG_MATERIAL_CD CHAR(15)  NOT NULL,
  PKG_MATERIAL_NAME VARCHAR(80) NOT NULL,
  PKG_TYPE     VARCHAR(40),
  ACTIVE_IND   CHAR(1)      NOT NULL DEFAULT 'Y',
  CONSTRAINT PK_MD_PKGMAT PRIMARY KEY (PKG_MATERIAL_CD)
);
