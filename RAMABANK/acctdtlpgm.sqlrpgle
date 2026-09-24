     **FREE
      //====================================================================
      // RAMA BANK - ACCOUNT DETAILS VIEW
      // Three-table SQL join to fetch full detail and nominee info.
      // F4 toggles masking, gated by real OTP verification.
      //
      // This program had multiple compile-breaking errors in the
      // original: missing semicolons on nearly every Dcl-S line,
      // a duplicate variable name (Sql_ACCTNUM declared twice), a
      // stray extra parenthesis, screen fields ($CUSTNAME, $BRANCH,
      // $IFSC, $MICR, $BALANCE, $NOMNAME, $NOMREL) that were declared
      // on the DSPF but never populated, and an invalid CallP syntax
      // calling a quoted literal program name. All fixed below.
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(AcctDtl_Main)
               BndDir('RAMABND');

       Dcl-F ACCTDTLSCR WORKSTN IndDS(ScnInd);

       Dcl-Ds ScnInd;
           ExitKey   Ind Pos(3);
           ToggleKey Ind Pos(4);
       End-Ds;

       Dcl-Pr AcctDtl_Main ExtPgm('ACCTDTLPGM');
           p_CustID  Char(20) Const;
           p_AcctNum Char(20) Const;
       End-Pr;

       Dcl-Pr Call_OtpVer ExtPgm('OTPVERPGM');
           p_CustID  Char(20) Const;
           p_Purpose Char(10) Const;
           p_Valid   Ind;
       End-Pr;

       Exec SQL Set Option Commit=*None, Naming=*Sys;

       Dcl-Proc AcctDtl_Main;
       Dcl-Pi AcctDtl_Main;
           p_CustID Char(20) Const;
           p_AcctNum Char(20) Const;
       End-Pi;

       Dcl-S l_Exit      Ind Inz(*Off);
       Dcl-S l_Masked    Ind Inz(*On);
       Dcl-S l_OTPValid  Ind Inz(*Off);

       Dcl-S Sql_ACCTNUM   Char(20);
       Dcl-S Sql_CUSTNAME  Char(50);
       Dcl-S Sql_BRANCH    Char(30);
       Dcl-S Sql_IFSC      Char(11);
       Dcl-S Sql_MICR      Char(9);
       Dcl-S Sql_BALANCE   Packed(15:2);
       Dcl-S Sql_NOMNAME   Char(100);
       Dcl-S Sql_RELATION  Char(50);
       Dcl-S l_Found       Int(10);

       Exec SQL
           Select A.ACCTNUM, A.BRANCH, A.IFSC, A.MICR, A.BALANCE,
                  C.FULLNAME,
                  Coalesce(N.NOMNAME, ''), Coalesce(N.RELATION, '')
           Into :Sql_ACCTNUM, :Sql_BRANCH, :Sql_IFSC, :Sql_MICR,
                :Sql_BALANCE, :Sql_CUSTNAME, :Sql_NOMNAME, :Sql_RELATION
           From SREERAMC1.ACCTMST A
           Join SREERAMC1.CUSTMST C ON A.CUSTID = C.CUSTID
           Left Join SREERAMC1.NOMINEEMST N ON A.ACCTNUM = N.ACCTNUM
           Where A.CUSTID = :p_CustID And A.ACCTNUM = :p_AcctNum
           Fetch First 1 Row Only;

       l_Found = 1;
       If SQLCode <> 0;
           l_Found = 0;
       EndIf;

       $CUSTID   = p_CustID;
       $CUSTNAME = Sql_CUSTNAME;
       $BRANCH   = Sql_BRANCH;
       $IFSC     = Sql_IFSC;
       $MICR     = Sql_MICR;
       $BALANCE  = Sql_BALANCE;
       $NOMNAME  = Sql_NOMNAME;
       $NOMREL   = Sql_RELATION;

       Dow Not l_Exit;

           If l_Found = 0;
               $ACCTNUM = 'NOT FOUND';
               ExFmt ACCTFMT;
               l_Exit = *On;
               Iter;
           EndIf;

           If l_Masked = *On;
               $ACCTNUM = 'XXXX-XXXX-XXXX-'
                   + %Subst(Sql_ACCTNUM: %Len(%Trim(Sql_ACCTNUM))-3: 4);
           Else;
               $ACCTNUM = Sql_ACCTNUM;
           EndIf;

           ExFmt ACCTFMT;

           Select;
               When ExitKey;
                   l_Exit = *On;

               When ToggleKey;
                   If l_Masked = *On;
                       Monitor;
                           Call_OtpVer(p_CustID: 'UNMASK': l_OTPValid);
                       On-Error;
                           l_OTPValid = *Off;
                       EndMon;

                       If l_OTPValid = *On;
                           l_Masked = *Off;
                       EndIf;
                   Else;
                       l_Masked = *On;
                   EndIf;
           EndSl;
       EndDo;

       Close ACCTDTLSCR;
       Return;
       End-Proc;
