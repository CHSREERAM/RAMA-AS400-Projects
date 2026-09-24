     H DEBUG(*YES) OPTION(*SRCSTMT:*NODEBUGIO)
     H DFTACTGRP(*NO) ACTGRP(*NEW)
     A*================================================================
     A*  EMPSTSR  -  Employee Leave Status & Comp-Off Status
     A*  Screens  :  5.3.5  Leave Status
     A*             5.3.6  Comp-Off Status
     A*  Called with MODE='L' for Leave Status
     A*             MODE='C' for Comp-Off Status
     A*  Validations:
     A*    1. Only Pending (P) records can be cancelled
     A*    2. Cancel changes status to 'C'
     A*    3. If leave cancelled, restore the balance
     A*    4. Valid option check (only option 1 allowed)
     A*================================================================
     FEMPSTSD   CF   E             WORKSTN SFILE(LVESTS_SFL:RRN)
     F                                     SFILE(COSTS_SFL:RRN1)
     FLEAVEPF   UF   E           K DISK    RENAME(LEAVEREC:LVEREC_S)
     FLEAVEBAL  UF   E           K DISK
     FCOMPOFF   UF   E           K DISK    RENAME(COMPREC:COMPREC_S)
     FEMPMASTER IF   E           K DISK

     D P_EMPID         S              4S 0
     D P_MODE          S              1A

     D w_empid         S              4S 0
     D w_empnam        S             30A
     D w_team          S             10A
     D RRN             S              4S 0
     D RRN1            S              4S 0

     C     *ENTRY        PLIST
     C                   PARM                    P_EMPID
     C                   PARM                    P_MODE

     //FREE

           w_empid = P_EMPID;
           if w_empid = 0;
              w_empid = 1001;
           endif;

           chain w_empid EMPMASTER;
           if %found(EMPMASTER);
              w_empnam = EMPNAM;
              w_team   = EMPTEAM;
           else;
              w_empnam = 'EMPLOYEE';
              w_team   = 'UNKNOWN';
           endif;

           select;
              when P_MODE = 'L';
                 exsr LEAVE_STATUS;
              when P_MODE = 'C';
                 exsr COMP_STATUS;
              other;
                 exsr LEAVE_STATUS;
           endsl;

           *inlr = *on;

     //*================================================================
     //*  LEAVE_STATUS  -  5.3.5  Leave Status Subfile
     //*================================================================
           begsr LEAVE_STATUS;

                 $LSUSER = %subst(w_empnam:1:10);
                 $LSTEAM = %subst(w_team:1:10);

                 exsr LS_CLEAR;
                 exsr LS_LOAD;
                 exsr LS_PROC;

           endsr;

           //LS_CLEAR
           begsr LS_CLEAR;
                 RRN = 0;
                 *in27 = *on;          // SFLCLR ON
                 write LVESTS_CTL;
                 *in27 = *off;
           endsr;

           //LS_LOAD
           begsr LS_LOAD;
                 MSG = *BLANKS;
                 setll w_empid LEAVEPF;
                 reade w_empid LEAVEPF;
                 dow not %eof(LEAVEPF);
                    SL_OPT  = 0;
                    SL_FRDT = LVEFRDT;
                    SL_TODT = LVETODT;
                    SL_TDAY = LVETDAY;
                    SL_STS  = LVESTS;
                    SL_TYPE = LVECLTY;
                    RRN = RRN + 1;
                    write LVESTS_SFL;
                    reade w_empid LEAVEPF;
                 enddo;

                 if %eof(LEAVEPF);
                    *in28 = *on;       // SFLEND
                 else;
                    *in28 = *off;
                 endif;

                 if RRN = 0;
                    MSG = 'No leave records found.';
                 endif;
           endsr;

           //LS_PROC
           begsr LS_PROC;
                 dow *in03 = *off;

                    if *in05 = *on;
                       *in05 = *off;
                       exsr LS_CLEAR;
                       exsr LS_LOAD;
                    endif;

                    // Display subfile
                    *in26 = *on;       // SFLDSPCTL
                    if RRN > 0;
                       *in25 = *on;    // SFLDSP
                    else;
                       *in25 = *off;
                    endif;

                    write LS_FOOTER;
                    exfmt LVESTS_CTL;

                    if *in03 = *on or *in12 = *on;
                       *in03 = *off;
                       *in12 = *off;
                       leave;
                    endif;

                    // Process options
                    if RRN > 0;
                       readc LVESTS_SFL;
                       dow not %eof(EMPSTSD);

                          if SL_OPT = 1;   // Cancel
                             exsr LS_CANCEL;
                          elseif SL_OPT <> 0;
                             MSG = 'Invalid option. Only option 1 (Cancel) +
                                   is allowed.';
                          endif;

                          clear SL_OPT;
                          update LVESTS_SFL;
                          readc LVESTS_SFL;
                       enddo;
                    endif;

                    // Reload after any updates
                    exsr LS_CLEAR;
                    exsr LS_LOAD;

                 enddo;
           endsr;

           //LS_CANCEL  -  Cancel a pending leave and restore balance
           begsr LS_CANCEL;
                 MSG = *BLANKS;

                 // Only Pending can be cancelled
                 if SL_STS <> 'P';
                    MSG = 'Only Pending leaves can be cancelled.';
                    LEAVESR;
                 endif;

                 // Find exact record in LEAVEPF by EmpID + FromDate
                 setll w_empid LEAVEPF;
                 reade w_empid LEAVEPF;
                 dow not %eof(LEAVEPF);
                    if LVEFRDT = SL_FRDT and LVETODT = SL_TODT;
                       if LVESTS <> 'P';
                          MSG = 'Leave already processed. Cannot cancel.';
                          LEAVESR;
                       endif;
                       LVESTS = 'C';      // Cancelled
                       update LVEREC_S;

                       // Restore balance
                       chain w_empid LEAVEBAL;
                       if %found(LEAVEBAL);
                          select;
                             when LVECLTY = 'CL';
                                LBCL = LBCL + LVETDAY;
                             when LVECLTY = 'EL';
                                LBEL = LBEL + LVETDAY;
                             when LVECLTY = 'CO';
                                LBCO = LBCO + LVETDAY;
                          endsl;
                          update LVBALREC;
                       endif;

                       MSG = 'Leave cancelled and balance restored.';
                       LEAVESR;
                    endif;
                    reade w_empid LEAVEPF;
                 enddo;

                 if MSG = *BLANKS;
                    MSG = 'Leave record not found to cancel.';
                 endif;
           endsr;

     //*================================================================
     //*  COMP_STATUS  -  5.3.6  Comp-Off Status Subfile
     //*================================================================
           begsr COMP_STATUS;

                 $CSUSER = %subst(w_empnam:1:10);
                 $CSTEAM = %subst(w_team:1:10);

                 exsr CS_CLEAR;
                 exsr CS_LOAD;
                 exsr CS_PROC;

           endsr;

           //CS_CLEAR
           begsr CS_CLEAR;
                 RRN1 = 0;
                 *in37 = *on;          // SFLCLR ON
                 write COSTS_CTL;
                 *in37 = *off;
           endsr;

           //CS_LOAD
           begsr CS_LOAD;
                 MSG2 = *BLANKS;
                 setll w_empid COMPOFF;
                 reade w_empid COMPOFF;
                 dow not %eof(COMPOFF);
                    SC_OPT  = 0;
                    SC_WRDT = COMWRDT;
                    SC_RSN  = %subst(COMRSN:1:20);
                    SC_DYTY = COMDYTY;
                    SC_STS  = COMSTS;
                    RRN1 = RRN1 + 1;
                    write COSTS_SFL;
                    reade w_empid COMPOFF;
                 enddo;

                 if %eof(COMPOFF);
                    *in38 = *on;       // SFLEND
                 else;
                    *in38 = *off;
                 endif;

                 if RRN1 = 0;
                    MSG2 = 'No comp-off records found.';
                 endif;
           endsr;

           //CS_PROC
           begsr CS_PROC;
                 dow *in03 = *off;

                    if *in05 = *on;
                       *in05 = *off;
                       exsr CS_CLEAR;
                       exsr CS_LOAD;
                    endif;

                    // Display subfile
                    *in36 = *on;       // SFLDSPCTL
                    if RRN1 > 0;
                       *in35 = *on;    // SFLDSP
                    else;
                       *in35 = *off;
                    endif;

                    write CS_FOOTER;
                    exfmt COSTS_CTL;

                    if *in03 = *on or *in12 = *on;
                       *in03 = *off;
                       *in12 = *off;
                       leave;
                    endif;

                    // Process options
                    if RRN1 > 0;
                       readc COSTS_SFL;
                       dow not %eof(EMPSTSD);

                          if SC_OPT = 1;   // Cancel
                             exsr CS_CANCEL;
                          elseif SC_OPT <> 0;
                             MSG2 = 'Invalid option. Only option 1 (Cancel) +
                                    is allowed.';
                          endif;

                          clear SC_OPT;
                          update COSTS_SFL;
                          readc COSTS_SFL;
                       enddo;
                    endif;

                    exsr CS_CLEAR;
                    exsr CS_LOAD;

                 enddo;
           endsr;

           //CS_CANCEL  -  Cancel a pending comp-off request
           begsr CS_CANCEL;
                 MSG2 = *BLANKS;

                 if SC_STS <> 'P';
                    MSG2 = 'Only Pending comp-off requests can be cancelled.';
                    LEAVESR;
                 endif;

                 setll w_empid COMPOFF;
                 reade w_empid COMPOFF;
                 dow not %eof(COMPOFF);
                    if COMWRDT = SC_WRDT;
                       if COMSTS <> 'P';
                          MSG2 = 'Comp-off already processed. Cannot cancel.';
                          LEAVESR;
                       endif;
                       COMSTS = 'C';      // Cancelled
                       update COMPREC_S;
                       MSG2 = 'Comp-off request cancelled successfully.';
                       LEAVESR;
                    endif;
                    reade w_empid COMPOFF;
                 enddo;

                 if MSG2 = *BLANKS;
                    MSG2 = 'Comp-off record not found to cancel.';
                 endif;
           endsr;

     //END-FREE
