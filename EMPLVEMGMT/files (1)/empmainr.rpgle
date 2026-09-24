     H DEBUG(*YES) OPTION(*SRCSTMT:*NODEBUGIO)
     H DFTACTGRP(*NO) ACTGRP(*NEW)
     A*================================================================
     A*  EMPMAINR  -  Employee Main Dashboard
     A*  Screens covered : 5.3.1 Dashboard Menu
     A*                    5.3.7 View Holidays
     A*                    5.3.8 Change Password
     A*                    N/A   Sign Out
     A*  Called programs : EMPCOMPR  (Apply Comp-off  5.3.2)
     A*                    EMPLVER   (Apply Leaves    5.3.3/5.3.4)
     A*                    EMPSTSR   (Status screens  5.3.5/5.3.6)
     A*================================================================
     FEMPDASH   CF   E             WORKSTN SFILE(MVHLDY:RRN)
     FEMPMASTER IF   E           K DISK
     FLOGIN     UF   E           K DISK
     FHOLIDAYS  IF   E           K DISK

     D RRN             S              4S 0

     D P_EMPID         S              4S 0
     D W_EMPID         S              4S 0
     D W_ACTION        S              1A

     D*  PR for sub-programs
     D EMPCOMPR        PR                  EXTPGM('EMPCOMPR')
     D  xEMPID                        4S 0

     D EMPLVER         PR                  EXTPGM('EMPLVER')
     D  xEMPID                        4S 0

     D EMPSTSR         PR                  EXTPGM('EMPSTSR')
     D  xEMPID                        4S 0
     D  xMODE                         1A

     C     *ENTRY        PLIST
     C                   PARM                    P_EMPID

     //FREE

      //**** Load employee context *****************************
           W_EMPID = P_EMPID;

           if W_EMPID = 0;
              W_EMPID = 1001;          // Default for testing
           endif;

           chain W_EMPID EMPMASTER;
           if %found(EMPMASTER);
              $USER  = %subst(EMPNAM:1:10);
              $TEAM  = %subst(EMPTEAM:1:10);
           else;
              $USER  = 'EMPLOYEE';
              $TEAM  = 'UNKNOWN';
           endif;

      //**** Main Dashboard Loop ****************************
           dow *in03 = *off;

              MSG = *BLANKS;
              exfmt EMPMAIN;

              if *in03 = *on or *in12 = *on;
                 *in03 = *off;
                 *in12 = *off;
                 leave;
              endif;

              MSG = *BLANKS;

              // Validate selection range
              if $SELECT < 1 or $SELECT > 7;
                 MSG = 'Invalid selection. Enter a value between 1 and 7.';
                 iter;
              endif;

              select;

                 when $SELECT = 1;          // Apply Comp-Off
                       EMPCOMPR(W_EMPID);
                       $SELECT = 0;

                 when $SELECT = 2;          // Apply Leaves
                       EMPLVER(W_EMPID);
                       $SELECT = 0;

                 when $SELECT = 3;          // Leave Status
                       W_ACTION = 'L';
                       EMPSTSR(W_EMPID : W_ACTION);
                       $SELECT = 0;

                 when $SELECT = 4;          // Comp-Off Status
                       W_ACTION = 'C';
                       EMPSTSR(W_EMPID : W_ACTION);
                       $SELECT = 0;

                 when $SELECT = 5;          // View Holidays
                       exsr VHLDYSR;
                       $SELECT = 0;

                 when $SELECT = 6;          // Change Password
                       exsr CHGPWDSR;
                       $SELECT = 0;

                 when $SELECT = 7;          // Sign Off
                       exsr SIGNOUTSR;
                       $SELECT = 0;

              endsl;

           enddo;

           *inlr = *on;

     //*================================================================
     //*  VHLDYSR  -  5.3.7  View Holidays (Read-only subfile)
     //*================================================================
           begsr VHLDYSR;

              exsr CLEARVH;
              exsr LOADVH;
              exsr PROCVH;

           endsr;

           //CLEARVH SR
           begsr CLEARVH;
                 RRN = 0;
                 *in22 = *on;          // SFLCLR ON
                 write MVHLDYCTL;
                 *in22 = *off;         // SFLCLR OFF
           endsr;

           //LOADVH SR
           begsr LOADVH;
                 $HUSER = $USER;
                 setll *loval HOLIDAYS;
                 read HOLIDAYS;
                 dow not %eof(HOLIDAYS);
                    $HDATE = HLDATE;
                    $HDAY  = HLDAY;
                    $HRMRK = HLRMRK;
                    RRN = RRN + 1;
                    write MVHLDY;
                    read HOLIDAYS;
                 enddo;

                 if %eof(HOLIDAYS);
                    *in23 = *on;        // SFLEND ON
                 else;
                    *in23 = *off;
                 endif;
           endsr;

           //PROCVH SR
           begsr PROCVH;
                 dow *in03 = *off;

                    if *in05 = *on;     // F5 Refresh
                       exsr CLEARVH;
                       exsr LOADVH;
                       *in05 = *off;
                    endif;

                    // Display subfile
                    *in21 = *on;        // SFLDSPCTL ON
                    if RRN > 0;
                       *in20 = *on;     // SFLDSP ON
                    else;
                       *in20 = *off;
                    endif;

                    write MVHFOOTER;
                    exfmt MVHLDYCTL;

                    if *in12 = *on;
                       *in12 = *off;
                       leave;
                    endif;

                 enddo;
           endsr;

     //*================================================================
     //*  CHGPWDSR  -  5.3.8  Change Password
     //*================================================================
           begsr CHGPWDSR;
                 MSG        = *BLANKS;
                 $LOGEMPID  = *ZEROS;
                 $CURPWD    = *BLANKS;
                 $NEWPWD    = *BLANKS;
                 $NEWPWDV   = *BLANKS;
                 $CPUSER    = $USER;

                 dow *in03 = *off;
                    exfmt CHGPWD;

                    if *in12 = *on or *in03 = *on;
                       *in12 = *off;
                       *in03 = *off;
                       leave;
                    endif;

                    MSG = *BLANKS;

                    // Validation 1: New and verify must match
                    if $NEWPWD <> $NEWPWDV;
                       MSG = 'New password and confirm password do not match.';
                       iter;
                    endif;

                    // Validation 2: New must differ from current
                    if %trim($CURPWD) = %trim($NEWPWD);
                       MSG = 'New password must not match current password.';
                       iter;
                    endif;

                    // Validation 3: Verify current password in PF
                    chain(N) $LOGEMPID LOGIN;
                    if not %found(LOGIN);
                       MSG = 'User ID not found in system.';
                       iter;
                    endif;

                    if %trim(LOGPWD) <> %trim($CURPWD);
                       MSG = 'Current password is incorrect.';
                       iter;
                    endif;

                    // All passed – update password
                    if MSG = *BLANKS;
                       LOGEMPID = $LOGEMPID;
                       chain LOGEMPID LOGIN;
                       if %found(LOGIN);
                          LOGPWD = $NEWPWD;
                          update LOGINREC;
                          MSG = 'Password changed successfully.';
                       endif;
                    endif;

                 enddo;
           endsr;

     //*================================================================
     //*  SIGNOUTSR  -  Sign Out Confirmation
     //*================================================================
           begsr SIGNOUTSR;
                 exfmt SIGNOUT;
                 if *in10 = *on;
                    *in03 = *on;      // Trigger exit from main loop
                 endif;
                 *in10 = *off;
           endsr;

     //END-FREE
