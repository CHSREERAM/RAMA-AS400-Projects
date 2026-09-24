------------------------------------------------------------------
-- 06_seed_data.sql  -  sample data for SREERAMC1 / SREERAMC1 only
------------------------------------------------------------------
SET SCHEMA SREERAMC1;

INSERT INTO SEC_ROLE (ROLE_CD, ROLE_DESC, APPROVAL_LEVEL) VALUES
 ('AUTHOR',   'Author',            10),
 ('REVIEWER', 'Reviewer',          20),
 ('QA',       'Quality Assurance', 30),
 ('QC',       'Quality Control',   30),
 ('PROD',     'Production',        30),
 ('VALID',    'Validation',        40),
 ('SITEQA',   'Site QA',           50),
 ('CORPQA',   'Corporate QA',      60);

INSERT INTO SEC_USER (USER_ID, FULL_NAME, EMAIL, PASSWORD_HASH) VALUES
 ('JSMITH',  'Jane Smith',   'jane.smith@example.com',  'PLACEHOLDER_HASH'),
 ('RKUMAR',  'Ravi Kumar',   'ravi.kumar@example.com',  'PLACEHOLDER_HASH'),
 ('MPATEL',  'Meera Patel',  'meera.patel@example.com', 'PLACEHOLDER_HASH');

INSERT INTO SEC_ROLE_PERM (USER_ID, ROLE_CD, ASSIGNED_BY) VALUES
 ('JSMITH','AUTHOR','SYSTEM'),
 ('RKUMAR','REVIEWER','SYSTEM'),
 ('MPATEL','CORPQA','SYSTEM');

INSERT INTO MD_DEPARTMENT (DEPT_CD, DEPT_NAME) VALUES
 ('PROD', 'Production'), ('QA', 'Quality Assurance'), ('QC', 'Quality Control'), ('ENG', 'Engineerin

INSERT INTO MD_PRODUCT (PRODUCT_CD, GENERIC_NAME, DOSAGE_FORM, DEFAULT_STRENGTH, SHELF_LIFE_MONTHS,
 ('PRD001', 'Paracetamol', 'Tablet', '500mg', 36, 'Store below 25C');

INSERT INTO MD_MATERIAL (MATERIAL_CD, MATERIAL_NAME, MATERIAL_TYPE, DEFAULT_UOM) VALUES
 ('MAT001', 'Paracetamol API', 'A', 'KG'),
 ('MAT002', 'Microcrystalline Cellulose', 'E', 'KG'),
 ('MAT003', 'Magnesium Stearate', 'E', 'KG');

INSERT INTO MD_EQUIPMENT (EQUIP_CD, EQUIP_NAME, EQUIP_TYPE, LOCATION_CD) VALUES
 ('EQP001', 'Rapid Mixer Granulator RMG-100', 'Granulation', 'GRAN-1'),
 ('EQP002', 'Rotary Tablet Press RTP-45', 'Compression', 'COMP-1');

INSERT INTO MD_UTILITY (UTILITY_CD, UTILITY_NAME) VALUES
 ('CAIR','Compressed Air'), ('HVAC','HVAC'), ('PWATER','Purified Water'),
 ('STEAM','Steam'), ('NITRO','Nitrogen'), ('VACUUM','Vacuum');

-- Sample protocol
INSERT INTO PPQ_HEADER (PROTOCOL_NO, REVISION_NO, VERSION_NO, PRODUCT_CD, PRODUCT_NAME, STRENGTH, DO
VALUES ('PPQ/2026/00001', 0, 1, 'PRD001', 'Paracetamol', '500mg', 'Tablet', 'Domestic', 250000, 'TAB

-- NOTE: use the identity value returned above (e.g. via IDENTITY_VAL_LOCAL()) for child inserts in
