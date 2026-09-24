     H DEBUG(*YES) OPTION(*SRCSTMT:*NODEBUGIO)
     H DFTACTGRP(*NO) ACTGRP(*NEW)
     A*================================================================
     A*  EMPCOMPR  -  Employee Apply Comp-Off
     A*  Screen    :  5.3.2 Apply Comp-Off
     A*  Validations:
     A*    1. Date must be in YYYYMMDD format
     A*    2. Worked date must NOT be in the future
     A*    3. All fields mandatory
     A*    4. Date must not be older than 3 months
     A*    5. Comp-off can only be applied on Sat/Sun or a holiday
     A*    6. Duplicate check (same employee + same worked date)
     A*================================================================
     FEMPCOMPD  CF   E             WORKSTN
     FCOMPOFF   UF   E           K DISK
     FEMPMASTER IF   E           K DISK
     FHOLIDAYS  IF   E           K DISK

     D P_EMPID         S              4S 0

     D d_wrdt          S               D
     D d_today         S               D
     D d_3mago         S               D
     D w_dow           S              1S 0    // Day-of-week (1=Sun..7=Sat)
     D w_isholiday     S               N
     D w_comid         S              8S 0
     D w_empid         S              4S 0

     D ARR             S             40A   DIM(2) CTDATA

     C     *ENTRY        PLIST
     C                   PARM                    P_EMPID

     //FREE

           w_empid = P_EMPID;
           if w_empid = 0;
              w_empid = 1001;
           endif;

           // Load employee header info
           chain w_empid EMPMASTER;
           if %found(EMPMASTER);
              $USER = %subst(EMPNAM:1:10);
              $TEAM = %subst(EMPTEAM:1:10);
           else;
              $USER = 'EMPLOYEE';
              $TEAM = 'UNKNOWN';
           endif;

           exsr MAIN_LOOP;
           *inlr = *on;

     //*================================================================
     //*  MAIN_LOOP  -  Apply Comp-Off entry loop
     //*================================================================
           begsr MAIN_LOOP;

                 MSG        = *BLANKS;
                 $COWRDT    = *ZEROS;
                 $CODYTY    = *BLANKS;
                 $CORSN     = *BLANKS;
                 $COPRJD    = *BLANKS;

                 dow *in03 = *off;

                    exfmt APPLYCO;

                    // F3 / F12 – exit
                    if *in03 = *on or *in12 = *on;
                       *in03 = *off;
                       *in12 = *off;
                       leave;
                    endif;

                    // F4 Prompt – cycle Day Type
                    if *in04 = *on;
                       *in04 = *off;
                       if P_FLD = '$CODYTY';
                          exsr PROMPT_DAYTYPE;
                          *in61 = *on;   // cursor back on day type
                       endif;
                       iter;
                    endif;

                    // F5 Refresh
                    if *in05 = *on;
                       *in05 = *off;
                       $COWRDT = *ZEROS;
                       $CODYTY = *BLANKS;
                       $CORSN  = *BLANKS;
                       $COPRJD = *BLANKS;
                       MSG     = *BLANKS;
                       iter;
                    endif;

                    exsr VALIDATE;

                    if MSG = *BLANKS;
                       exsr SAVE_CO;
                    endif;

                 enddo;

           endsr;

     //*================================================================
     //*  VALIDATE  -  All validations for comp-off
     //*================================================================
           begsr VALIDATE;

                 MSG = *BLANKS;

                 // V1: Mandatory fields
                 if $COWRDT = 0 or
                    %trim($CODYTY) = *BLANKS or
                    %trim($CORSN)  = *BLANKS or
                    %trim($COPRJD) = *BLANKS;
                    MSG = 'All fields are mandatory.';
                    LEAVESR;
                 endif;

                 // V2: Validate Day Type value
                 if $CODYTY <> 'FH' and
                    $CODYTY <> 'SH' and
                    $CODYTY <> 'FD';
                    MSG = 'Day Type must be FH, SH, or FD. Use F4 to select.';
                    LEAVESR;
                 endif;

                 // V3: Date format check
                 TEST(DE) *ISO $COWRDT;
                 if %error;
                    MSG = 'Worked Date is invalid. Use YYYYMMDD format.';
                    LEAVESR;
                 endif;

                 d_wrdt  = %DATE($COWRDT : *ISO);
                 d_today = %DATE();

                 // V4: Date must not be in the future
                 if d_wrdt > d_today;
                    MSG = 'Worked Date cannot be in the future.';
                    LEAVESR;
                 endif;

                 // V5: Date must not be older than 3 months
                 d_3mago = d_today - %MONTHS(3);
                 if d_wrdt < d_3mago;
                    MSG = 'Worked Date cannot be older than 3 months.';
                    LEAVESR;
                 endif;

                 // V6: Comp-off only on Sat/Sun or a holiday
                 //     %SUBDT(*ISO / d) day-of-week: Mon=1 .. Sun=7 (ISO)
                 //     Saturday=6, Sunday=7 in ISO weekday
                 w_dow = %SUBDT(d_wrdt : *DAYS);   // Not standard – use alternate
                 // Compute weekday: (days from known Monday) mod 7
                 // Simpler: check HLDATE in HOLIDAYS PF first
                 w_isholiday = *OFF;
                 chain $COWRDT HOLIDAYS;
                 if %found(HOLIDAYS);
                    w_isholiday = *ON;
                 endif;

                 // Check Sat/Sun via %WEEKDAY BIF (ILE RPG V7R3+)
                 // %DAYS gives a relative date number; use MOD check:
                 // Known Sunday base: 20000102 (Sunday)
                 // Diff from base in days MOD 7: 0=Sun,6=Sat
                 w_dow = %REM(%DIFF(d_wrdt : %DATE(20000102:*ISO) : *DAYS) : 7);
                 // w_dow = 0 → Sunday, 6 → Saturday

                 if not w_isholiday and w_dow <> 0 and w_dow <> 6;
                    MSG = 'Comp-off can only be applied for Saturday,' +
                          ' Sunday, or a holiday.';
                    LEAVESR;
                 endif;

                 // V7: Duplicate check – same employee + same worked date
                 chain ($COWRDT) COMPOFF;
                 dow %found(COMPOFF);
                    if COMEMPID = w_empid;
                       MSG = 'A comp-off request for this date already exists.';
                       LEAVESR;
                    endif;
                    reade ($COWRDT) COMPOFF;
                 enddo;

           endsr;

     //*================================================================
     //*  SAVE_CO  -  Write comp-off record
     //*================================================================
           begsr SAVE_CO;

                 // Generate new COMID  (last record + 1)
                 setgt *hival COMPOFF;
                 readp COMPOFF;
                 if %eof(COMPOFF);
                    w_comid = 1;
                 else;
                    w_comid = COMID + 1;
                 endif;

                 COMID    = w_comid;
                 COMEMPID = w_empid;
                 COMWRDT  = $COWRDT;
                 COMDYTY  = $CODYTY;
                 COMRSN   = $CORSN;
                 COMSTS   = 'P';          // Pending
                 COMPRJD  = $COPRJD;
                 write COMPREC;

                 MSG     = ARR(1);

                 // Clear for next entry
                 $COWRDT = *ZEROS;
                 $CODYTY = *BLANKS;
                 $CORSN  = *BLANKS;
                 $COPRJD = *BLANKS;

           endsr;

     //*================================================================
     //*  PROMPT_DAYTYPE  -  Cycle through FH / SH / FD
     //*================================================================
           begsr PROMPT_DAYTYPE;
                 select;
                    when %trim($CODYTY) = *BLANKS;
                       $CODYTY = 'FD';
                       MSG = 'Day Type: Full Day (FD)';
                    when %trim($CODYTY) = 'FD';
                       $CODYTY = 'FH';
                       MSG = 'Day Type: First Half (FH)';
                    when %trim($CODYTY) = 'FH';
                       $CODYTY = 'SH';
                       MSG = 'Day Type: Second Half (SH)';
                    other;
                       $CODYTY = 'FD';
                       MSG = 'Day Type: Full Day (FD)';
                 endsl;
           endsr;

     //END-FREE
     **CTDATA ARR
     Comp-off request submitted successfully.
     Duplicate comp-off request for this date already exists.
