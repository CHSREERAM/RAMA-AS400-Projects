     H DEBUG(*YES) OPTION(*SRCSTMT:*NODEBUGIO)
     H DFTACTGRP(*NO) ACTGRP(*NEW)
     A*================================================================
     A*  LOGINPGM  -  Employee Leave Management System Login
     A*  Screen  : Login Screen (Section 5 - Login Screen)
     A*  Validations:
     A*    1. Employee ID and Password must not be blank
     A*    2. Employee ID must exist in LOGIN PF
     A*    3. Password must match stored password
     A*    4. Route to correct dashboard based on EMPROL in EMPMASTER:
     A*         Role 'A' (Admin)    -> CALL ADMINDASHR
     A*         Role 'M' (Manager)  -> CALL MGRMAINR
     A*         Role 'E' (Employee) -> CALL EMPMAINR
     A*    5. If EMPMASTER record not found -> show error
     A*================================================================
     FLOGINDSPF CF   E             WORKSTN
     FLOGIN     IF   E           K DISK
     FEMPMASTER IF   E           K DISK

     D P_EMPID         S              4S 0
     D W_ROLE          S              1A
     D W_EMPID         S              4S 0

     D*  Prototype for Admin dashboard
     D ADMINDASHR      PR                  EXTPGM('ADMINDASHR')

     D*  Prototype for Manager dashboard
     D MGRMAINR        PR                  EXTPGM('MGRMAINR')

     D*  Prototype for Employee dashboard
     D EMPMAINR        PR                  EXTPGM('EMPMAINR')
     D  xEMPID                        4S 0

     //FREE

           exsr MAIN_LOOP;
           *inlr = *on;

     //*================================================================
     //*  MAIN_LOOP  -  Login display and validation loop
     //*================================================================
           begsr MAIN_LOOP;

                 MSG    = *BLANKS;
                 $EMPID = 0;
                 $PWD   = *BLANKS;

                 dow *in03 = *off;

                    exfmt LOGINSCR;

                    // F3 / F12 - Exit system
                    if *in03 = *on or *in12 = *on;
                       *in03 = *off;
                       *in12 = *off;
                       leave;
                    endif;

                    MSG = *BLANKS;

                    // V1: Mandatory fields
                    if $EMPID = 0 or %trim($PWD) = *BLANKS;
                       MSG = 'User ID and Password are required.';
                       $PWD = *BLANKS;
                       iter;
                    endif;

                    // V2: Check Employee ID in LOGIN PF
                    W_EMPID = $EMPID;
                    chain W_EMPID LOGIN;
                    if not %found(LOGIN);
                       MSG = 'User ID not found. Please check and try again.';
                       $PWD = *BLANKS;
                       iter;
                    endif;

                    // V3: Validate password
                    if %trim(LOGPWD) <> %trim($PWD);
                       MSG = 'Incorrect password. Please try again.';
                       $PWD = *BLANKS;
                       iter;
                    endif;

                    // V4: Get role from EMPMASTER
                    chain W_EMPID EMPMASTER;
                    if not %found(EMPMASTER);
                       MSG = 'Employee record not found. Contact Admin.';
                       $PWD = *BLANKS;
                       iter;
                    endif;

                    W_ROLE = EMPROL;

                    // V5: Check employee is active
                    if EMPSTS = 'I';
                       MSG = 'Your account is inactive. Contact Admin.';
                       $PWD = *BLANKS;
                       iter;
                    endif;

                    // Route to correct dashboard based on role
                    $PWD = *BLANKS;
                    MSG  = *BLANKS;

                    select;
                       when W_ROLE = 'A';    // Admin
                            ADMINDASHR();

                       when W_ROLE = 'M';    // Manager
                            MGRMAINR();

                       when W_ROLE = 'E';    // Employee
                            EMPMAINR(W_EMPID);

                       other;
                          MSG = 'Unknown role assigned. Contact Admin.';
                          iter;
                    endsl;

                    // After return from dashboard, reset for re-login
                    $EMPID = 0;
                    $PWD   = *BLANKS;
                    MSG    = *BLANKS;

                 enddo;

           endsr;

     //END-FREE
