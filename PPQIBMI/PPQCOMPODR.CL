/*====================================================================*/
/* PPQ PROTOCOL MANAGEMENT SYSTEM - COMPLETE COMPILE ORDER FOR       */
/* SREERAMC1 / PPQIBMI                                                */
/* Run each step in sequence. A failure in any step will cascade     */
/* compile errors to dependent objects if skipped.                   */
/*                                                                    */
/* Unlike a DDS-PF based build, this system stores every table as    */
/* SQL DDL (Db2 for i), so there is no separate "physical file" /    */
/* "logical file" compile step - Step 0 (SQL) creates the tables,    */
/* views, and triggers together. All source below - SQL, DDS, RPG,   */
/* CL, and binder language - lives in ONE source file, PPQIBMI,      */
/* differentiated per-member by source type.                         */
/*====================================================================*/


/* ============================================================       */
/* STEP 0: SQL - SCHEMA, SEQUENCES, TABLES, VIEWS, TRIGGERS           */
/* (Run via STRSQL, ACS/VS Code Run SQL Scripts, or RUNSQLSTM)       */
/* Replaces Steps 1 & 2 (Physical/Logical Files) in a DDS-based build */
/* ============================================================       */
RUNSQLSTM SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(00SCHEMA) COMMIT(*NONE)
/*  -> creates SCHEMA SREERAMC1, SEQ_PROTOCOL_NO, SEQ_AUDIT_ID, SEQ_DEVIATION_NO */

RUNSQLSTM SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(01SECUR) COMMIT(*NONE)
/*  -> SEC_ROLE, SEC_USER, SEC_ROLE_PERM, SEC_ESIGNATURE, SEC_LOGIN_AUDIT */

RUNSQLSTM SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(02MSTDTA) COMMIT(*NONE)
/*  -> 13 MD_* master data tables */

RUNSQLSTM SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(03PPQCOR) COMMIT(*NONE)
/*  -> PPQ_HEADER + 22 child tables + PPQ_AUDIT (23 tables, 3NF) */

RUNSQLSTM SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(04VIEWS) COMMIT(*NONE)
/*  -> V_PPQ_HEADER_LIST, V_PPQ_TEAM_LIST, V_PPQ_CPP_STATS, */
/*     V_PPQ_SUMMARY, V_PPQ_CONCLUSION */

RUNSQLSTM SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(05TRIG) COMMIT(*NONE)
/*  -> TRG_PPQ_HEADER_AUD, TRG_PPQ_HEADER_WORKFLOW, TRG_PPQ_DEVIATION_NO */

/* Optional - sample/seed data, skip once real protocols exist:       */
/* RUNSQLSTM SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(06SEED) COMMIT(*NONE) */


/* ============================================================       */
/* STEP 1: DISPLAY FILES                                              */
/* ============================================================       */
CRTDSPF FILE(SREERAMC1/PPQLOGD)  SRCFILE(SREERAMC1/PPQIBMI)
CRTDSPF FILE(SREERAMC1/PPQMENU)  SRCFILE(SREERAMC1/PPQIBMI)
CRTDSPF FILE(SREERAMC1/PPQHDRD)  SRCFILE(SREERAMC1/PPQIBMI)
CRTDSPF FILE(SREERAMC1/PPQCPPD)  SRCFILE(SREERAMC1/PPQIBMI)
CRTDSPF FILE(SREERAMC1/PPQAPRD)  SRCFILE(SREERAMC1/PPQIBMI)


/* ============================================================       */
/* STEP 2: PRINTER FILES                                              */
/* ============================================================       */
CRTPRTF FILE(SREERAMC1/PPQHDRP)  SRCFILE(SREERAMC1/PPQIBMI)


/* ============================================================       */
/* STEP 3: SERVICE PROGRAM MODULES (compile as *MODULE)               */
/* ============================================================       */
/* 3a. UTLSRV - no dependencies; every other *SRVPGM binds to this   */
CRTSQLRPGI OBJ(SREERAMC1/UTLSRV) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*MODULE) COMMIT(*NONE) DBGVIEW(*SOURCE)

/* 3b. STATSRV - Cp/Cpk/Pp/Ppk calculation */
CRTSQLRPGI OBJ(SREERAMC1/STATSRV) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*MODULE) COMMIT(*NONE) DBGVIEW(*SOURCE)

/* 3c. ESIGSRV - password hash / verify / e-signature capture */
CRTSQLRPGI OBJ(SREERAMC1/ESIGSRV) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*MODULE) COMMIT(*NONE) DBGVIEW(*SOURCE)

/* 3d. SECSRV - login / role check / logoff (needs ESIGSRV at bind)  */
CRTSQLRPGI OBJ(SREERAMC1/SECSRV) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*MODULE) COMMIT(*CS) DBGVIEW(*SOURCE)

/* 3e. HDRSRV - PPQ_HEADER CRUD + workflow status transition */
CRTSQLRPGI OBJ(SREERAMC1/HDRSRV) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*MODULE) COMMIT(*CS) DBGVIEW(*SOURCE)

/* 3f. CPPSRV - Critical Process Parameters (detail-module template) */
CRTSQLRPGI OBJ(SREERAMC1/CPPSRV) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*MODULE) COMMIT(*CS) DBGVIEW(*SOURCE)

/* 3g. APRSRV - approval workflow (needs ESIGSRV + HDRSRV at bind)   */
CRTSQLRPGI OBJ(SREERAMC1/APRSRV) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*MODULE) COMMIT(*CS) DBGVIEW(*SOURCE)


/* ============================================================       */
/* STEP 4: BINDING DIRECTORY                                          */
/* ============================================================       */
CRTBNDDIR  BNDDIR(SREERAMC1/PPQBNDDIR) TEXT('PPQ Service Program Binding Directory')


/* ============================================================       */
/* STEP 5: SERVICE PROGRAMS                                           */
/* Binder source: one member per program (UTLSRV, STATSRV, ESIGSRV,  */
/* SECSRV, HDRSRV, CPPSRV, APRSRV in PPQIBMI - each a single          */
/* STRPGMEXP/ENDPGMEXP block, IBM i convention of one block/member)  */
/* ============================================================       */
CRTSRVPGM  SRVPGM(SREERAMC1/UTLSRV) MODULE(SREERAMC1/UTLSRV) +
           EXPORT(*SRCFILE) SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(UTLSRV)

CRTSRVPGM  SRVPGM(SREERAMC1/STATSRV) MODULE(SREERAMC1/STATSRV) +
           BNDSRVPGM(SREERAMC1/UTLSRV) EXPORT(*SRCFILE) +
           SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(STATSRV)

CRTSRVPGM  SRVPGM(SREERAMC1/ESIGSRV) MODULE(SREERAMC1/ESIGSRV) +
           BNDSRVPGM(SREERAMC1/UTLSRV) EXPORT(*SRCFILE) +
           SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(ESIGSRV)

CRTSRVPGM  SRVPGM(SREERAMC1/SECSRV) MODULE(SREERAMC1/SECSRV) +
           BNDSRVPGM((SREERAMC1/UTLSRV) (SREERAMC1/ESIGSRV)) +
           EXPORT(*SRCFILE) SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(SECSRV)

CRTSRVPGM  SRVPGM(SREERAMC1/HDRSRV) MODULE(SREERAMC1/HDRSRV) +
           BNDSRVPGM(SREERAMC1/UTLSRV) EXPORT(*SRCFILE) +
           SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(HDRSRV)

CRTSRVPGM  SRVPGM(SREERAMC1/CPPSRV) MODULE(SREERAMC1/CPPSRV) +
           BNDSRVPGM(SREERAMC1/UTLSRV) EXPORT(*SRCFILE) +
           SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(CPPSRV)

CRTSRVPGM  SRVPGM(SREERAMC1/APRSRV) MODULE(SREERAMC1/APRSRV) +
           BNDSRVPGM((SREERAMC1/UTLSRV) (SREERAMC1/ESIGSRV) (SREERAMC1/HDRSRV)) +
           EXPORT(*SRCFILE) SRCFILE(SREERAMC1/PPQIBMI) SRCMBR(APRSRV)

/* Add all 7 service programs to the binding directory so *PGM       */
/* compiles in Step 6 can resolve every call with one BNDDIR() ref   */
ADDBNDDIRE BNDDIR(SREERAMC1/PPQBNDDIR) OBJ((SREERAMC1/UTLSRV *SRVPGM) +
              (SREERAMC1/STATSRV *SRVPGM) (SREERAMC1/ESIGSRV *SRVPGM) +
              (SREERAMC1/SECSRV *SRVPGM) (SREERAMC1/HDRSRV *SRVPGM) +
              (SREERAMC1/CPPSRV *SRVPGM) (SREERAMC1/APRSRV *SRVPGM))


/* ============================================================       */
/* STEP 6: MAIN RPGLE/SQLRPGLE PROGRAMS                               */
/* (Each bound to PPQBNDDIR so they can resolve every *SRVPGM call)  */
/* ============================================================       */
CRTSQLRPGI OBJ(SREERAMC1/PPQLOGR) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*PGM) BNDDIR(SREERAMC1/PPQBNDDIR) COMMIT(*NONE) DBGVIEW(*SOURCE)

CRTSQLRPGI OBJ(SREERAMC1/PPQMENR) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*PGM) BNDDIR(SREERAMC1/PPQBNDDIR) COMMIT(*NONE) DBGVIEW(*SOURCE)

CRTSQLRPGI OBJ(SREERAMC1/PPQHDRR) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*PGM) BNDDIR(SREERAMC1/PPQBNDDIR) COMMIT(*CS) DBGVIEW(*SOURCE)

CRTSQLRPGI OBJ(SREERAMC1/PPQCPPR) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*PGM) BNDDIR(SREERAMC1/PPQBNDDIR) COMMIT(*CS) DBGVIEW(*SOURCE)

CRTSQLRPGI OBJ(SREERAMC1/PPQAPRR) SRCFILE(SREERAMC1/PPQIBMI) +
           OBJTYPE(*PGM) BNDDIR(SREERAMC1/PPQBNDDIR) COMMIT(*CS) DBGVIEW(*SOURCE)


/* ============================================================       */
/* STEP 7: CL PROGRAMS (build/deploy/ops tooling, not called by the  */
/* interactive flow above - compile any time after Step 0)           */
/* ============================================================       */
CRTCLPGM   PGM(SREERAMC1/PPQCRTLIB)  SRCFILE(SREERAMC1/PPQIBMI)
CRTCLPGM   PGM(SREERAMC1/PPQCOMPALL) SRCFILE(SREERAMC1/PPQIBMI)
CRTCLPGM   PGM(SREERAMC1/PPQMAIN)    SRCFILE(SREERAMC1/PPQIBMI)
CRTCLPGM   PGM(SREERAMC1/PPQDEPLOY)  SRCFILE(SREERAMC1/PPQIBMI)
CRTCLPGM   PGM(SREERAMC1/PPQBKUP)    SRCFILE(SREERAMC1/PPQIBMI)
CRTCLPGM   PGM(SREERAMC1/PPQRPTSUB)  SRCFILE(SREERAMC1/PPQIBMI)


/* ============================================================       */
/* STEP 8: SCHEDULED / BATCH JOBS                                     */
/* ============================================================       */
/* No recurring ADDJOBSCDE entries are defined for this build.       */
/* PPQRPTSUB is submitted ad hoc, per protocol, via:                  */
/*   CALL SREERAMC1/PPQRPTSUB PARM('RPTHDRR' '000123')                */
/* (RPTHDRR itself is not yet built - see README.md Extending section)*/


/* ============================================================       */
/* FIRST RUN                                                           */
/* ============================================================       */
/* CALL SREERAMC1/PPQMAIN PARM('SREERAMC1')                           */
/* -> starts at PPQLOGR (login screen)                                 */
