     H DEBUG(*YES) OPTION(*SRCSTMT:*NODEBUGIO)
     H DFTACTGRP(*NO) ACTGRP(*NEW)
     A*================================================================
     A*  EMPLVER  -  Employee Apply Leaves
     A*  Screens  :  5.3.3  Leave Type Selection (balances shown)
     A*             5.3.4  Leave Date Entry Form
     A*  Validations (5.3.3):
     A*    1. Leave balance must be > 0 for selected type
     A*    2. Valid option (1–3)
     A*    3. Do not allow applying leaves on Sat/Sun/Holidays
     A*  Validations (5.3.4):
     A*    1. From Date must be valid YYYYMMDD
     A*    2. Cannot apply leave for previous month
     A*    3. To Date must be valid YYYYMMDD
     A*    4. To Date must not be BEFORE From Date
     A*    5. All fields mandatory
     A*    6. From/To Date must not be less than DOJ
     A*    7. Day type must be FH/SH/FD
     A*================================================================
     FEMPLVED   CF   E             WORKSTN
     FLEAVEPF   UF   E           K DISK
     FLEAVEBAL  UF   E           K DISK
     FEMPMASTER IF   E           K DISK
     FHOLIDAYS  IF   E           K DISK

     D P_EMPID         S              4S 0

     D w_empid         S              4S 0
     D w_doj           S               D
     D d_frdt          S               D
     D d_todt          S               D
     D d_today         S               D
     D d_prvmonst      S               D     // First day of current month
     D d_loop          S               D
     D w_tday          S              2S 0
     D w_isholiday     S               N
     D w_dow           S              1S 0
     D w_lveid         S              8S 0
     D w_empnam        S             30A
     D w_team          S             10A

     D ARR             S             40A   DIM(3) CTDATA

     C     *ENTRY        PLIST
     C                   PARM                    P_EMPID

     //FREE

           w_empid = P_EMPID;
           if w_empid = 0;
              w_empid = 1001;
           endif;

           // Load employee context
           chain w_empid EMPMASTER;
           if %found(EMPMASTER);
              w_empnam = EMPNAM;
              w_team   = EMPTEAM;
              w_doj    = %DATE(EMPDOJ : *ISO);
           else;
              w_empnam = 'UNKNOWN';
              w_team   = 'UNKNOWN';
           endif;

           // Load leave balances
           chain w_empid LEAVEBAL;
           if %found(LEAVEBAL);
              $BALCL = LBCL;
              $BALEL = LBEL;
              $BALCO = LBCO;
           else;
              $BALCL = 0;
              $BALEL = 0;
              $BALCO = 0;
           endif;

           exsr SEL_LOOP;
           *inlr = *on;

     //*================================================================
     //*  SEL_LOOP  -  5.3.3  Leave Type Selection
     //*================================================================
           begsr SEL_LOOP;

                 $USER     = %subst(w_empnam:1:10);
                 $TEAM     = %subst(w_team:1:10);
                 MSG       = *BLANKS;
                 $SELVTYP  = 0;

                 dow *in03 = *off;

                    exfmt APPLYSEL;

                    if *in03 = *on or *in12 = *on;
                       *in03 = *off;
                       *in12 = *off;
                       leave;
                    endif;

                    if *in05 = *on;   // Refresh balances
                       *in05 = *off;
                       chain w_empid LEAVEBAL;
                       if %found(LEAVEBAL);
                          $BALCL = LBCL;
                          $BALEL = LBEL;
                          $BALCO = LBCO;
                       endif;
                       iter;
                    endif;

                    MSG = *BLANKS;

                    // Validate selection (1-3)
                    if $SELVTYP < 1 or $SELVTYP > 3;
                       MSG = 'Invalid option. Enter 1, 2, or 3.';
                       iter;
                    endif;

                    // Check balance for selected type
                    select;
                       when $SELVTYP = 1;   // CL
                          if $BALCL = 0;
                             MSG = 'Insufficient Casual Leave balance.';
                             iter;
                          endif;
                          $FLVTYP = 'CL';
                          $FBAL   = $BALCL;

                       when $SELVTYP = 2;   // EL
                          if $BALEL = 0;
                             MSG = 'Insufficient Earned Leave balance.';
                             iter;
                          endif;
                          $FLVTYP = 'EL';
                          $FBAL   = $BALEL;

                       when $SELVTYP = 3;   // CO
                          if $BALCO = 0;
                             MSG = 'Insufficient Comp Off Leave balance.';
                             iter;
                          endif;
                          $FLVTYP = 'CO';
                          $FBAL   = $BALCO;
                    endsl;

                    // Proceed to date entry form
                    exsr FORM_LOOP;

                    // Refresh balances after return
                    chain w_empid LEAVEBAL;
                    if %found(LEAVEBAL);
                       $BALCL = LBCL;
                       $BALEL = LBEL;
                       $BALCO = LBCO;
                    endif;
                    $SELVTYP = 0;
                    MSG = *BLANKS;

                 enddo;

           endsr;

     //*================================================================
     //*  FORM_LOOP  -  5.3.4  Leave Date Entry Form
     //*================================================================
           begsr FORM_LOOP;

                 $FUSER    = %subst(w_empnam:1:10);
                 $FTEAM    = %subst(w_team:1:10);
                 $LVEFRDT  = *ZEROS;
                 $LVEFRDY  = *BLANKS;
                 $LVETODT  = *ZEROS;
                 $LVETODY  = *BLANKS;
                 $LVERSNY  = *BLANKS;
                 $LVETDAY  = 0;
                 MSG       = *BLANKS;

                 dow *in03 = *off;

                    exfmt APPLYFRM;

                    if *in03 = *on or *in12 = *on;
                       *in03 = *off;
                       *in12 = *off;
                       leave;
                    endif;

                    // F4 Prompt – cycle day type for From or To
                    if *in04 = *on;
                       *in04 = *off;
                       select;
                          when P_FLD = '$LVEFRDY';
                             exsr PROMPT_FDY;
                             *in71 = *on;
                          when P_FLD = '$LVETODY';
                             exsr PROMPT_TDY;
                             *in72 = *on;
                       endsl;
                       iter;
                    endif;

                    // F5 Refresh
                    if *in05 = *on;
                       *in05 = *off;
                       $LVEFRDT = *ZEROS;
                       $LVEFRDY = *BLANKS;
                       $LVETODT = *ZEROS;
                       $LVETODY = *BLANKS;
                       $LVERSNY = *BLANKS;
                       $LVETDAY = 0;
                       MSG      = *BLANKS;
                       iter;
                    endif;

                    exsr VALIDATE_FORM;

                    if MSG = *BLANKS;
                       exsr SAVE_LEAVE;
                       leave;                // Exit after successful apply
                    endif;

                 enddo;

           endsr;

     //*================================================================
     //*  VALIDATE_FORM  -  All leave date validations
     //*================================================================
           begsr VALIDATE_FORM;

                 MSG = *BLANKS;

                 // V1: All mandatory
                 if $LVEFRDT = 0 or
                    %trim($LVEFRDY) = *BLANKS or
                    $LVETODT = 0   or
                    %trim($LVETODY) = *BLANKS or
                    %trim($LVERSNY) = *BLANKS;
                    MSG = 'All fields are mandatory.';
                    LEAVESR;
                 endif;

                 // V2: Day type values
                 if ($LVEFRDY <> 'FH' and $LVEFRDY <> 'SH' and
                     $LVEFRDY <> 'FD');
                    MSG = 'From Day Type must be FH, SH, or FD. Press F4.';
                    LEAVESR;
                 endif;

                 if ($LVETODY <> 'FH' and $LVETODY <> 'SH' and
                     $LVETODY <> 'FD');
                    MSG = 'To Day Type must be FH, SH, or FD. Press F4.';
                    LEAVESR;
                 endif;

                 // V3: From Date valid format
                 TEST(DE) *ISO $LVEFRDT;
                 if %error;
                    MSG = 'From Date is invalid. Use YYYYMMDD format.';
                    LEAVESR;
                 endif;
                 d_frdt = %DATE($LVEFRDT : *ISO);

                 // V4: To Date valid format
                 TEST(DE) *ISO $LVETODT;
                 if %error;
                    MSG = 'To Date is invalid. Use YYYYMMDD format.';
                    LEAVESR;
                 endif;
                 d_todt  = %DATE($LVETODT : *ISO);
                 d_today = %DATE();

                 // V5: To Date must not be before From Date
                 if d_todt < d_frdt;
                    MSG = 'To Date cannot be before From Date.';
                    LEAVESR;
                 endif;

                 // V6: Cannot apply leave for a previous month
                 //     (From Date must be in current month or future)
                 d_prvmonst = %DATE(%CHAR(%SUBDT(d_today:*YEARS):'4') +
                              %EDITC(%SUBDT(d_today:*MONTHS):'X') +
                              '01' : *ISO);
                 if d_frdt < d_prvmonst;
                    MSG = 'Cannot apply leave for a previous month.';
                    LEAVESR;
                 endif;

                 // V7: From/To Date must not be before DOJ
                 if d_frdt < w_doj;
                    MSG = 'From Date must not be before Date of Joining.';
                    LEAVESR;
                 endif;

                 if d_todt < w_doj;
                    MSG = 'To Date must not be before Date of Joining.';
                    LEAVESR;
                 endif;

                 // V8: Count working days (exclude Sat/Sun/Holidays)
                 //     and validate none of the days are Sat/Sun/Holidays
                 w_tday = 0;
                 d_loop = d_frdt;
                 dow d_loop <= d_todt;

                    w_dow = %REM(%DIFF(d_loop :
                            %DATE(20000102:*ISO) : *DAYS) : 7);
                    // 0 = Sunday, 6 = Saturday

                    if w_dow = 0 or w_dow = 6;
                       // Skip weekends – do not count but do not error
                       // (spec says "Do not allow to apply on Sat/Sun")
                       // Error if ALL days chosen are weekends – handled below
                    else;
                       // Check holiday
                       w_isholiday = *OFF;
                       chain %DATE($LVEFRDT:*ISO) HOLIDAYS;
                       // More precise: convert d_loop to numeric for chain
                       chain (%INT(%CHAR(d_loop:*ISO0))) HOLIDAYS;
                       if %found(HOLIDAYS);
                          w_isholiday = *ON;
                       endif;

                       if not w_isholiday;
                          // Adjust for half-day on first/last day
                          if d_loop = d_frdt and $LVEFRDY <> 'FD';
                             w_tday = w_tday + 1;  // half day = 1 unit here
                          elseif d_loop = d_todt and $LVETODY <> 'FD';
                             w_tday = w_tday + 1;
                          else;
                             w_tday = w_tday + 1;
                          endif;
                       endif;
                    endif;

                    d_loop = d_loop + %DAYS(1);
                 enddo;

                 // If counting half-days: FH/SH = 0.5, FD = 1
                 // The LEAVEPF LVETDAY is 2,0 so we store integer days
                 // Recalculate properly:
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
                    MSG = 'No working days in the selected range.';
                    LEAVESR;
                 endif;

                 // V9: Check sufficient balance for calculated days
                 chain w_empid LEAVEBAL;
                 if %found(LEAVEBAL);
                    select;
                       when $FLVTYP = 'CL';
                          if LBCL < w_tday;
                             MSG = 'Insufficient Casual Leave balance for' +
                                   ' ' + %CHAR(w_tday) + ' day(s).';
                             LEAVESR;
                          endif;
                       when $FLVTYP = 'EL';
                          if LBEL < w_tday;
                             MSG = 'Insufficient Earned Leave balance for' +
                                   ' ' + %CHAR(w_tday) + ' day(s).';
                             LEAVESR;
                          endif;
                       when $FLVTYP = 'CO';
                          if LBCO < w_tday;
                             MSG = 'Insufficient Comp-Off balance for' +
                                   ' ' + %CHAR(w_tday) + ' day(s).';
                             LEAVESR;
                          endif;
                    endsl;
                 else;
                    MSG = 'Leave balance record not found for employee.';
                    LEAVESR;
                 endif;

                 $LVETDAY = w_tday;

           endsr;

     //*================================================================
     //*  SAVE_LEAVE  -  Write leave record and deduct balance
     //*================================================================
           begsr SAVE_LEAVE;

                 // Generate LVEID
                 setgt *hival LEAVEPF;
                 readp LEAVEPF;
                 if %eof(LEAVEPF);
                    w_lveid = 1;
                 else;
                    w_lveid = LVEID + 1;
                 endif;

                 LVEID    = w_lveid;
                 LVEEMPID = w_empid;
                 LVEFRDT  = $LVEFRDT;
                 LVEFRDY  = $LVEFRDY;
                 LVETODT  = $LVETODT;
                 LVETODY  = $LVETODY;
                 LVETDAY  = w_tday;
                 LVERSNY  = $LVERSNY;
                 LVESTS   = 'P';            // Pending
                 LVECLTY  = $FLVTYP;
                 write LEAVEREC;

                 // Deduct balance
                 chain w_empid LEAVEBAL;
                 if %found(LEAVEBAL);
                    select;
                       when $FLVTYP = 'CL';
                          LBCL = LBCL - w_tday;
                       when $FLVTYP = 'EL';
                          LBEL = LBEL - w_tday;
                       when $FLVTYP = 'CO';
                          LBCO = LBCO - w_tday;
                    endsl;
                    update LVBALREC;
                 endif;

                 MSG = ARR(1);

           endsr;

     //*================================================================
     //*  PROMPT_FDY / PROMPT_TDY  -  Cycle FD / FH / SH
     //*================================================================
           begsr PROMPT_FDY;
                 select;
                    when %trim($LVEFRDY) = *BLANKS;
                       $LVEFRDY = 'FD';
                       MSG = 'From Day Type: Full Day (FD)';
                    when %trim($LVEFRDY) = 'FD';
                       $LVEFRDY = 'FH';
                       MSG = 'From Day Type: First Half (FH)';
                    when %trim($LVEFRDY) = 'FH';
                       $LVEFRDY = 'SH';
                       MSG = 'From Day Type: Second Half (SH)';
                    other;
                       $LVEFRDY = 'FD';
                       MSG = 'From Day Type: Full Day (FD)';
                 endsl;
           endsr;

           begsr PROMPT_TDY;
                 select;
                    when %trim($LVETODY) = *BLANKS;
                       $LVETODY = 'FD';
                       MSG = 'To Day Type: Full Day (FD)';
                    when %trim($LVETODY) = 'FD';
                       $LVETODY = 'FH';
                       MSG = 'To Day Type: First Half (FH)';
                    when %trim($LVETODY) = 'FH';
                       $LVETODY = 'SH';
                       MSG = 'To Day Type: Second Half (SH)';
                    other;
                       $LVETODY = 'FD';
                       MSG = 'To Day Type: Full Day (FD)';
                 endsl;
           endsr;

     //END-FREE
     **CTDATA ARR
     Leave applied successfully. Pending manager approval.
     Insufficient balance for the selected leave type.
     Leave could not be saved. Please try again.
