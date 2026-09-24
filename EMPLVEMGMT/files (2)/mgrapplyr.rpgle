     H DEBUG(*YES) OPTION(*SRCSTMT:*NODEBUGIO)
     H DFTACTGRP(*NO) ACTGRP(*NEW)
     A*================================================================
     A*  MGRAPPLYR  -  Manager Personal Application Program
     A*  Screens  :  5.2.8   Apply Comp-Off
     A*             5.2.9   Apply Leaves (type selection)
     A*             5.2.10  Apply Leave  (date entry)
     A*             5.2.11  Leave Status (cancel pending)
     A*             5.2.12  Comp-Off Status (cancel pending)
     A*  Called by MGRMAINR with P_MODE:
     A*    'C' = Apply Comp-Off      (5.2.8)
     A*    'L' = Apply Leaves        (5.2.9/5.2.10)
     A*    'S' = Leave Status        (5.2.11)
     A*    'X' = Comp-Off Status     (5.2.12)
     A*================================================================
     FMGRAPPLY  CF   E             WORKSTN SFILE(MGRLVSTS_SFL:RRN)
     F                                     SFILE(MGRCOSTS_SFL:RRN1)
     FCOMPOFF   UF   E           K DISK
     FLEAVEPF   UF   E           K DISK
     FLEAVEBAL  UF   E           K DISK
     FEMPMASTER IF   E           K DISK
     FHOLIDAYS  IF   E           K DISK

     D P_EMPID         S              4S 0
     D P_MODE          S              1A

     D w_empid         S              4S 0
     D w_team          S             10A
     D w_doj           S               D
     D w_lveid         S              8S 0
     D w_comid         S              8S 0
     D w_tday          S              2S 0
     D w_dow           S              1S 0
     D w_isholiday     S               N
     D d_wrdt          S               D
     D d_frdt          S               D
     D d_todt          S               D
     D d_today         S               D
     D d_3mago         S               D
     D d_prvmonst      S               D
     D d_loop          S               D
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
              w_team = EMPTEAM;
              w_doj  = %DATE(EMPDOJ : *ISO);
           else;
              w_team = 'UNKNOWN';
           endif;

           select;
              when P_MODE = 'C';   exsr APPLY_CO;
              when P_MODE = 'L';   exsr APPLY_LV;
              when P_MODE = 'S';   exsr LV_STATUS;
              when P_MODE = 'X';   exsr CO_STATUS;
           endsl;

           *inlr = *on;

     //*================================================================
     //*  APPLY_CO  -  5.2.8  Apply Comp-Off
     //*================================================================
           begsr APPLY_CO;

                 MSG        = *BLANKS;
                 $MCOWRDT   = *ZEROS;
                 $MCODYTY   = *BLANKS;
                 $MCORSN    = *BLANKS;
                 $MCOPRJD   = *BLANKS;
                 $MTEAM     = %subst(w_team:1:10);

                 dow *in03 = *off;

                    exfmt MGRAPPLYCO;

                    if *in03 = *on or *in12 = *on;
                       *in03 = *off; *in12 = *off;
                       leave;
                    endif;

                    if *in04 = *on;
                       *in04 = *off;
                       if P_FLD = '$MCODYTY';
                          exsr PROMPT_CODY;
                          *in61 = *on;
                       endif;
                       iter;
                    endif;

                    if *in05 = *on;
                       *in05 = *off;
                       $MCOWRDT = *ZEROS; $MCODYTY = *BLANKS;
                       $MCORSN  = *BLANKS; $MCOPRJD = *BLANKS;
                       MSG = *BLANKS;
                       iter;
                    endif;

                    exsr VALIDATE_CO;

                    if MSG = *BLANKS;
                       exsr SAVE_CO;
                    endif;

                 enddo;

           endsr;

           //VALIDATE_CO
           begsr VALIDATE_CO;

                 MSG = *BLANKS;

                 // V1: All mandatory
                 if $MCOWRDT = 0 or %trim($MCODYTY) = *BLANKS or
                    %trim($MCORSN) = *BLANKS or %trim($MCOPRJD) = *BLANKS;
                    MSG = 'All fields are mandatory.';
                    LEAVESR;
                 endif;

                 // V2: Day type
                 if $MCODYTY <> 'FH' and $MCODYTY <> 'SH' and
                    $MCODYTY <> 'FD';
                    MSG = 'Day Type must be FH, SH, or FD. Press F4.';
                    LEAVESR;
                 endif;

                 // V3: Date format
                 TEST(DE) *ISO $MCOWRDT;
                 if %error;
                    MSG = 'Worked Date invalid. Use YYYYMMDD format.';
                    LEAVESR;
                 endif;

                 d_wrdt  = %DATE($MCOWRDT : *ISO);
                 d_today = %DATE();

                 // V4: Not future
                 if d_wrdt > d_today;
                    MSG = 'Worked Date cannot be in the future.';
                    LEAVESR;
                 endif;

                 // V5: Not older than 3 months
                 d_3mago = d_today - %MONTHS(3);
                 if d_wrdt < d_3mago;
                    MSG = 'Worked Date cannot be older than 3 months.';
                    LEAVESR;
                 endif;

                 // V6: Must be Sat/Sun or Holiday
                 w_isholiday = *OFF;
                 chain $MCOWRDT HOLIDAYS;
                 if %found(HOLIDAYS);
                    w_isholiday = *ON;
                 endif;

                 w_dow = %REM(%DIFF(d_wrdt :
                         %DATE(20000102:*ISO) : *DAYS) : 7);

                 if not w_isholiday and w_dow <> 0 and w_dow <> 6;
                    MSG = 'Comp-off only valid on Saturday, Sunday, or' +
                          ' a holiday.';
                    LEAVESR;
                 endif;

                 // V7: Duplicate check
                 chain ($MCOWRDT) COMPOFF;
                 dow %found(COMPOFF);
                    if COMEMPID = w_empid;
                       MSG = 'A comp-off request for this date already exists.';
                       LEAVESR;
                    endif;
                    reade ($MCOWRDT) COMPOFF;
                 enddo;

           endsr;

           //SAVE_CO
           begsr SAVE_CO;

                 setgt *hival COMPOFF;
                 readp COMPOFF;
                 if %eof(COMPOFF);
                    w_comid = 1;
                 else;
                    w_comid = COMID + 1;
                 endif;

                 COMID    = w_comid;
                 COMEMPID = w_empid;
                 COMWRDT  = $MCOWRDT;
                 COMDYTY  = $MCODYTY;
                 COMRSN   = $MCORSN;
                 COMSTS   = 'P';
                 COMPRJD  = $MCOPRJD;
                 write COMPREC;

                 MSG      = 'Comp-off request submitted successfully.';
                 $MCOWRDT = *ZEROS; $MCODYTY = *BLANKS;
                 $MCORSN  = *BLANKS; $MCOPRJD = *BLANKS;

           endsr;

           //PROMPT_CODY
           begsr PROMPT_CODY;
                 select;
                    when %trim($MCODYTY) = *BLANKS; $MCODYTY = 'FD';
                       MSG = 'Day Type: Full Day (FD)';
                    when %trim($MCODYTY) = 'FD';    $MCODYTY = 'FH';
                       MSG = 'Day Type: First Half (FH)';
                    when %trim($MCODYTY) = 'FH';    $MCODYTY = 'SH';
                       MSG = 'Day Type: Second Half (SH)';
                    other;                           $MCODYTY = 'FD';
                       MSG = 'Day Type: Full Day (FD)';
                 endsl;
           endsr;

     //*================================================================
     //*  APPLY_LV  -  5.2.9 / 5.2.10  Apply Leaves
     //*================================================================
           begsr APPLY_LV;

                 $MLTEAM   = %subst(w_team:1:10);
                 MSG       = *BLANKS;
                 $MSELVTYP = 0;

                 // Load balances
                 chain w_empid LEAVEBAL;
                 if %found(LEAVEBAL);
                    $MBALCL = LBCL;
                    $MBALEL = LBEL;
                    $MBALCO = LBCO;
                 else;
                    $MBALCL = 0; $MBALEL = 0; $MBALCO = 0;
                 endif;

                 dow *in03 = *off;

                    exfmt MGRAPPLYSEL;

                    if *in03 = *on or *in12 = *on;
                       *in03 = *off; *in12 = *off;
                       leave;
                    endif;

                    if *in05 = *on;
                       *in05 = *off;
                       chain w_empid LEAVEBAL;
                       if %found(LEAVEBAL);
                          $MBALCL = LBCL; $MBALEL = LBEL; $MBALCO = LBCO;
                       endif;
                       iter;
                    endif;

                    MSG = *BLANKS;

                    if $MSELVTYP < 1 or $MSELVTYP > 3;
                       MSG = 'Invalid option. Enter 1, 2, or 3.';
                       iter;
                    endif;

                    select;
                       when $MSELVTYP = 1;
                          if $MBALCL = 0;
                             MSG = 'Insufficient Casual Leave balance.';
                             iter;
                          endif;
                          $MFLVTYP = 'CL'; $MFBAL = $MBALCL;

                       when $MSELVTYP = 2;
                          if $MBALEL = 0;
                             MSG = 'Insufficient Earned Leave balance.';
                             iter;
                          endif;
                          $MFLVTYP = 'EL'; $MFBAL = $MBALEL;

                       when $MSELVTYP = 3;
                          if $MBALCO = 0;
                             MSG = 'Insufficient Comp Off balance.';
                             iter;
                          endif;
                          $MFLVTYP = 'CO'; $MFBAL = $MBALCO;
                    endsl;

                    exsr FORM_LV;

                    chain w_empid LEAVEBAL;
                    if %found(LEAVEBAL);
                       $MBALCL = LBCL; $MBALEL = LBEL; $MBALCO = LBCO;
                    endif;
                    $MSELVTYP = 0;
                    MSG = *BLANKS;

                 enddo;

           endsr;

           //FORM_LV  – 5.2.10
           begsr FORM_LV;

                 $MFTEAM   = %subst(w_team:1:10);
                 $MLVEFRDT = *ZEROS; $MLVEFRDY = *BLANKS;
                 $MLVETODT = *ZEROS; $MLVETODY = *BLANKS;
                 $MLVERSNY = *BLANKS; $MLVETDAY = 0;
                 MSG = *BLANKS;

                 dow *in03 = *off;

                    exfmt MGRAPPLYFRM;

                    if *in03 = *on or *in12 = *on;
                       *in03 = *off; *in12 = *off;
                       leave;
                    endif;

                    if *in04 = *on;
                       *in04 = *off;
                       select;
                          when P_FLD = '$MLVEFRDY'; exsr PROMPT_FDY;
                             *in71 = *on;
                          when P_FLD = '$MLVETODY'; exsr PROMPT_TDY;
                             *in72 = *on;
                       endsl;
                       iter;
                    endif;

                    if *in05 = *on;
                       *in05 = *off;
                       $MLVEFRDT = *ZEROS; $MLVEFRDY = *BLANKS;
                       $MLVETODT = *ZEROS; $MLVETODY = *BLANKS;
                       $MLVERSNY = *BLANKS; $MLVETDAY = 0;
                       MSG = *BLANKS;
                       iter;
                    endif;

                    exsr VALIDATE_LV;

                    if MSG = *BLANKS;
                       exsr SAVE_LV;
                       leave;
                    endif;

                 enddo;

           endsr;

           //VALIDATE_LV
           begsr VALIDATE_LV;

                 MSG = *BLANKS;

                 // V1: Mandatory
                 if $MLVEFRDT = 0 or %trim($MLVEFRDY) = *BLANKS or
                    $MLVETODT = 0  or %trim($MLVETODY) = *BLANKS or
                    %trim($MLVERSNY) = *BLANKS;
                    MSG = 'All fields are mandatory.';
                    LEAVESR;
                 endif;

                 // V2: Day type values
                 if $MLVEFRDY <> 'FH' and $MLVEFRDY <> 'SH' and
                    $MLVEFRDY <> 'FD';
                    MSG = 'From Day Type must be FH, SH, or FD. Press F4.';
                    LEAVESR;
                 endif;

                 if $MLVETODY <> 'FH' and $MLVETODY <> 'SH' and
                    $MLVETODY <> 'FD';
                    MSG = 'To Day Type must be FH, SH, or FD. Press F4.';
                    LEAVESR;
                 endif;

                 // V3: From date format
                 TEST(DE) *ISO $MLVEFRDT;
                 if %error;
                    MSG = 'From Date invalid. Use YYYYMMDD format.';
                    LEAVESR;
                 endif;
                 d_frdt = %DATE($MLVEFRDT : *ISO);

                 // V4: To date format
                 TEST(DE) *ISO $MLVETODT;
                 if %error;
                    MSG = 'To Date invalid. Use YYYYMMDD format.';
                    LEAVESR;
                 endif;
                 d_todt  = %DATE($MLVETODT : *ISO);
                 d_today = %DATE();

                 // V5: To date not before From date
                 if d_todt < d_frdt;
                    MSG = 'To Date cannot be before From Date.';
                    LEAVESR;
                 endif;

                 // V6: Cannot apply for previous month
                 d_prvmonst = %DATE(%CHAR(%SUBDT(d_today:*YEARS):'4') +
                              %EDITC(%SUBDT(d_today:*MONTHS):'X') +
                              '01' : *ISO);
                 if d_frdt < d_prvmonst;
                    MSG = 'Cannot apply leave for a previous month.';
                    LEAVESR;
                 endif;

                 // V7: From/To not before DOJ
                 if d_frdt < w_doj;
                    MSG = 'From Date must not be before Date of Joining.';
                    LEAVESR;
                 endif;
                 if d_todt < w_doj;
                    MSG = 'To Date must not be before Date of Joining.';
                    LEAVESR;
                 endif;

                 // V8: Count working days
                 w_tday = 0;
                 d_loop = d_frdt;
                 dow d_loop <= d_todt;
                    w_dow = %REM(%DIFF(d_loop :
                            %DATE(20000102:*ISO) : *DAYS) : 7);
                    if w_dow <> 0 and w_dow <> 6;
                       chain (%INT(%CHAR(d_loop:*ISO0))) HOLIDAYS;
                       if not %found(HOLIDAYS);
                          w_tday = w_tday + 1;
                       endif;
                    endif;
                    d_loop = d_loop + %DAYS(1);
                 enddo;

                 if w_tday = 0;
                    MSG = 'No working days in selected date range.';
                    LEAVESR;
                 endif;

                 // V9: Check balance
                 chain w_empid LEAVEBAL;
                 if %found(LEAVEBAL);
                    select;
                       when $MFLVTYP = 'CL';
                          if LBCL < w_tday;
                             MSG = 'Insufficient CL balance for ' +
                                   %CHAR(w_tday) + ' day(s).';
                             LEAVESR;
                          endif;
                       when $MFLVTYP = 'EL';
                          if LBEL < w_tday;
                             MSG = 'Insufficient EL balance for ' +
                                   %CHAR(w_tday) + ' day(s).';
                             LEAVESR;
                          endif;
                       when $MFLVTYP = 'CO';
                          if LBCO < w_tday;
                             MSG = 'Insufficient CO balance for ' +
                                   %CHAR(w_tday) + ' day(s).';
                             LEAVESR;
                          endif;
                    endsl;
                 else;
                    MSG = 'Leave balance record not found.';
                    LEAVESR;
                 endif;

                 $MLVETDAY = w_tday;

           endsr;

           //SAVE_LV
           begsr SAVE_LV;

                 setgt *hival LEAVEPF;
                 readp LEAVEPF;
                 if %eof(LEAVEPF);
                    w_lveid = 1;
                 else;
                    w_lveid = LVEID + 1;
                 endif;

                 LVEID    = w_lveid;
                 LVEEMPID = w_empid;
                 LVEFRDT  = $MLVEFRDT;
                 LVEFRDY  = $MLVEFRDY;
                 LVETODT  = $MLVETODT;
                 LVETODY  = $MLVETODY;
                 LVETDAY  = w_tday;
                 LVERSNY  = $MLVERSNY;
                 LVESTS   = 'P';
                 LVECLTY  = $MFLVTYP;
                 write LEAVEREC;

                 chain w_empid LEAVEBAL;
                 if %found(LEAVEBAL);
                    select;
                       when $MFLVTYP = 'CL'; LBCL = LBCL - w_tday;
                       when $MFLVTYP = 'EL'; LBEL = LBEL - w_tday;
                       when $MFLVTYP = 'CO'; LBCO = LBCO - w_tday;
                    endsl;
                    update LVBALREC;
                 endif;

                 MSG = 'Leave applied successfully. Pending manager approval.';

           endsr;

           //PROMPT_FDY
           begsr PROMPT_FDY;
                 select;
                    when %trim($MLVEFRDY) = *BLANKS; $MLVEFRDY = 'FD';
                       MSG = 'From Day Type: Full Day (FD)';
                    when %trim($MLVEFRDY) = 'FD';    $MLVEFRDY = 'FH';
                       MSG = 'From Day Type: First Half (FH)';
                    when %trim($MLVEFRDY) = 'FH';    $MLVEFRDY = 'SH';
                       MSG = 'From Day Type: Second Half (SH)';
                    other;                            $MLVEFRDY = 'FD';
                       MSG = 'From Day Type: Full Day (FD)';
                 endsl;
           endsr;

           //PROMPT_TDY
           begsr PROMPT_TDY;
                 select;
                    when %trim($MLVETODY) = *BLANKS; $MLVETODY = 'FD';
                       MSG = 'To Day Type: Full Day (FD)';
                    when %trim($MLVETODY) = 'FD';    $MLVETODY = 'FH';
                       MSG = 'To Day Type: First Half (FH)';
                    when %trim($MLVETODY) = 'FH';    $MLVETODY = 'SH';
                       MSG = 'To Day Type: Second Half (SH)';
                    other;                            $MLVETODY = 'FD';
                       MSG = 'To Day Type: Full Day (FD)';
                 endsl;
           endsr;

     //*================================================================
     //*  LV_STATUS  -  5.2.11  Leave Status Subfile
     //*================================================================
           begsr LV_STATUS;

                 $MLSTEAM = %subst(w_team:1:10);
                 exsr LVS_CLEAR;
                 exsr LVS_LOAD;
                 exsr LVS_PROC;

           endsr;

           //LVS_CLEAR
           begsr LVS_CLEAR;
                 RRN = 0;
                 *in77 = *on;
                 write MGRLVSTS_CTL;
                 *in77 = *off;
           endsr;

           //LVS_LOAD
           begsr LVS_LOAD;
                 MSG = *BLANKS;
                 setll w_empid LEAVEPF;
                 reade w_empid LEAVEPF;
                 dow not %eof(LEAVEPF);
                    MSL_OPT  = 0;
                    MSL_FRDT = LVEFRDT;
                    MSL_TODT = LVETODT;
                    MSL_TDAY = LVETDAY;
                    MSL_STS  = LVESTS;
                    MSL_TYPE = LVECLTY;
                    RRN = RRN + 1;
                    write MGRLVSTS_SFL;
                    reade w_empid LEAVEPF;
                 enddo;
                 if %eof(LEAVEPF);
                    *in78 = *on;
                 else;
                    *in78 = *off;
                 endif;
                 if RRN = 0;
                    MSG = 'No leave records found.';
                 endif;
           endsr;

           //LVS_PROC
           begsr LVS_PROC;
                 dow *in03 = *off;

                    if *in05 = *on;
                       *in05 = *off;
                       exsr LVS_CLEAR;
                       exsr LVS_LOAD;
                    endif;

                    *in76 = *on;
                    if RRN > 0;
                       *in75 = *on;
                    else;
                       *in75 = *off;
                    endif;

                    write MGRLVFOOTER;
                    exfmt MGRLVSTS_CTL;

                    if *in03 = *on or *in12 = *on;
                       *in03 = *off; *in12 = *off;
                       leave;
                    endif;

                    if RRN > 0;
                       readc MGRLVSTS_SFL;
                       dow not %eof(MGRAPPLY);
                          if MSL_OPT = 1;
                             exsr LVS_CANCEL;
                          elseif MSL_OPT <> 0;
                             MSG = 'Invalid option. Only 1 (Cancel) allowed.';
                          endif;
                          clear MSL_OPT;
                          update MGRLVSTS_SFL;
                          readc MGRLVSTS_SFL;
                       enddo;
                    endif;

                    exsr LVS_CLEAR;
                    exsr LVS_LOAD;

                 enddo;
           endsr;

           //LVS_CANCEL
           begsr LVS_CANCEL;
                 MSG = *BLANKS;

                 if MSL_STS <> 'P';
                    MSG = 'Only Pending leaves can be cancelled.';
                    LEAVESR;
                 endif;

                 setll w_empid LEAVEPF;
                 reade w_empid LEAVEPF;
                 dow not %eof(LEAVEPF);
                    if LVEFRDT = MSL_FRDT and LVETODT = MSL_TODT;
                       if LVESTS <> 'P';
                          MSG = 'Leave already processed. Cannot cancel.';
                          LEAVESR;
                       endif;
                       LVESTS = 'C';
                       update LEAVEREC;
                       chain w_empid LEAVEBAL;
                       if %found(LEAVEBAL);
                          select;
                             when LVECLTY = 'CL'; LBCL = LBCL + LVETDAY;
                             when LVECLTY = 'EL'; LBEL = LBEL + LVETDAY;
                             when LVECLTY = 'CO'; LBCO = LBCO + LVETDAY;
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
     //*  CO_STATUS  -  5.2.12  Comp-Off Status Subfile
     //*================================================================
           begsr CO_STATUS;

                 $MCSTEAM = %subst(w_team:1:10);
                 exsr COS_CLEAR;
                 exsr COS_LOAD;
                 exsr COS_PROC;

           endsr;

           //COS_CLEAR
           begsr COS_CLEAR;
                 RRN1 = 0;
                 *in82 = *on;
                 write MGRCOSTS_CTL;
                 *in82 = *off;
           endsr;

           //COS_LOAD
           begsr COS_LOAD;
                 MSG2 = *BLANKS;
                 setll w_empid COMPOFF;
                 reade w_empid COMPOFF;
                 dow not %eof(COMPOFF);
                    MSC_OPT  = 0;
                    MSC_WRDT = COMWRDT;
                    MSC_RSN  = %subst(COMRSN:1:20);
                    MSC_DYTY = COMDYTY;
                    MSC_STS  = COMSTS;
                    RRN1 = RRN1 + 1;
                    write MGRCOSTS_SFL;
                    reade w_empid COMPOFF;
                 enddo;
                 if %eof(COMPOFF);
                    *in83 = *on;
                 else;
                    *in83 = *off;
                 endif;
                 if RRN1 = 0;
                    MSG2 = 'No comp-off records found.';
                 endif;
           endsr;

           //COS_PROC
           begsr COS_PROC;
                 dow *in03 = *off;

                    if *in05 = *on;
                       *in05 = *off;
                       exsr COS_CLEAR;
                       exsr COS_LOAD;
                    endif;

                    *in81 = *on;
                    if RRN1 > 0;
                       *in80 = *on;
                    else;
                       *in80 = *off;
                    endif;

                    write MGRCOFOOTER;
                    exfmt MGRCOSTS_CTL;

                    if *in03 = *on or *in12 = *on;
                       *in03 = *off; *in12 = *off;
                       leave;
                    endif;

                    if RRN1 > 0;
                       readc MGRCOSTS_SFL;
                       dow not %eof(MGRAPPLY);
                          if MSC_OPT = 1;
                             exsr COS_CANCEL;
                          elseif MSC_OPT <> 0;
                             MSG2 = 'Invalid option. Only 1 (Cancel) allowed.';
                          endif;
                          clear MSC_OPT;
                          update MGRCOSTS_SFL;
                          readc MGRCOSTS_SFL;
                       enddo;
                    endif;

                    exsr COS_CLEAR;
                    exsr COS_LOAD;

                 enddo;
           endsr;

           //COS_CANCEL
           begsr COS_CANCEL;
                 MSG2 = *BLANKS;

                 if MSC_STS <> 'P';
                    MSG2 = 'Only Pending comp-off requests can be cancelled.';
                    LEAVESR;
                 endif;

                 setll w_empid COMPOFF;
                 reade w_empid COMPOFF;
                 dow not %eof(COMPOFF);
                    if COMWRDT = MSC_WRDT;
                       if COMSTS <> 'P';
                          MSG2 = 'Comp-off already processed. Cannot cancel.';
                          LEAVESR;
                       endif;
                       COMSTS = 'C';
                       update COMPREC;
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
