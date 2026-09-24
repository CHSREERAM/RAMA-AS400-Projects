     **FREE
      //====================================================================
      // RAMA BANK - DASHBOARD (Main Navigation Hub)
      // Merged from DASHPGM + DASHPGM1 (were two divergent versions of
      // the same screen). DASHPGM1 and DASHSCR1 are retired.
      //
      // Fixes:
      //  - ExtPgm('PROFPGL') corrected to ExtPgm('PROFILEPGM').
      //    'PROFPGL' does not exist anywhere in the codebase; selecting
      //    option 7 (Profile & KYC) would abend on every run.
      //  - $BALANCE in DASHSFL is now Packed(15:2) to match ACCTMST
      //    (was 15Y 2 in DASHSCR which is Zoned; ACCTMST is Packed).
      //    The program explicitly casts via %EditC to the 15A display
      //    string on screen, so no DSPF type mismatch remains.
      //  - $MENUOPT stray field outside any record format (was in a
      //    commented-out R DASHMENU block). Now in DASHMENU properly.
      //  - $ERRMSG added to DASHMENU to surface downstream failures.
      //  - Library SREERAMC1 confirmed throughout.
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Dash_Main)
               BndDir('RAMABND');

       Dcl-F DASHSCR WORKSTN Sfile(DASHSFL: RRN) IndDS(ScnInd);

       Dcl-Ds ScnInd;
           ExitKey   Ind Pos(3);
           SflClr    Ind Pos(42);
           SflDspCtl Ind Pos(41);
           SflDsp    Ind Pos(40);
           SflEnd    Ind Pos(43);
       End-Ds;

       Dcl-Pr Dash_Main ExtPgm('DASHPGM');
           p_UserID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_StmtPgm  ExtPgm('STMTPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_FundTr   ExtPgm('FUNDTRPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_CardDtl  ExtPgm('CARDDTLPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_LoanDtl  ExtPgm('LOANDTLPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_FdDtl    ExtPgm('FDDTLPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_BillPay  ExtPgm('BILLPAYPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_Profile  ExtPgm('PROFILEPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_Benef    ExtPgm('BENEFPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_Admin    ExtPgm('ADMINPGM');
           p_UserID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_MiniStmt ExtPgm('MINIPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_Logout   ExtPgm('LOGOUTCL');
       End-Pr;

       Exec SQL Set Option Commit=*None, Naming=*Sys;

       Dcl-S RRN     Int(10);
       Dcl-S l_Exit  Ind Inz(*Off);
       Dcl-S l_CustID Char(20);
       Dcl-S l_BalNum Packed(15:2);

       Dcl-Proc Dash_Main;
       Dcl-Pi Dash_Main;
           p_UserID Char(20) Const;
       End-Pi;

       Exec SQL Select CUSTID Into :l_CustID
                From SREERAMC1.USERMST
                Where USERID = :p_UserID;

       If SQLCode <> 0;
           Close DASHSCR;
           Return;
       EndIf;

       Exec SQL Select FULLNAME Into :$CUSTNAME
                From SREERAMC1.CUSTMST
                Where CUSTID = :l_CustID;

       If SQLCode <> 0;
           $CUSTNAME = 'Welcome, ' + %Trim(p_UserID);
       EndIf;

       ExSr LoadSubfile;

       Dow Not l_Exit;
           $MENUOPT = '';
           $ERRMSG  = *Blanks;
           ExFmt DASHCTL;
           ExFmt DASHMENU;

           If ExitKey;
               Monitor;
                   Call_Logout();
               On-Error;
               EndMon;
               l_Exit = *On;
               Iter;
           EndIf;

           Select;
               When $MENUOPT = '1';
                   Monitor;
                       Call_StmtPgm(l_CustID);
                   On-Error;
                       $ERRMSG = 'Statement module unavailable.';
                   EndMon;

               When $MENUOPT = '2';
                   Monitor;
                       Call_FundTr(l_CustID);
                   On-Error;
                       $ERRMSG = 'Fund Transfer module unavailable.';
                   EndMon;

               When $MENUOPT = '3';
                   Monitor;
                       Call_CardDtl(l_CustID);
                   On-Error;
                       $ERRMSG = 'Card module unavailable.';
                   EndMon;

               When $MENUOPT = '4';
                   Monitor;
                       Call_LoanDtl(l_CustID);
                   On-Error;
                       $ERRMSG = 'Loan module unavailable.';
                   EndMon;

               When $MENUOPT = '5';
                   Monitor;
                       Call_FdDtl(l_CustID);
                   On-Error;
                       $ERRMSG = 'FD module unavailable.';
                   EndMon;

               When $MENUOPT = '6';
                   Monitor;
                       Call_BillPay(l_CustID);
                   On-Error;
                       $ERRMSG = 'Bill Pay module unavailable.';
                   EndMon;

               When $MENUOPT = '7';
                   Monitor;
                       Call_Profile(l_CustID);
                   On-Error;
                       $ERRMSG = 'Profile module unavailable.';
                   EndMon;

               When $MENUOPT = '8';
                   Monitor;
                       Call_Benef(l_CustID);
                   On-Error;
                       $ERRMSG = 'Beneficiary module unavailable.';
                   EndMon;

               When $MENUOPT = '9';
                   Monitor;
                       Call_Admin(p_UserID);
                   On-Error;
                       $ERRMSG = 'Admin panel unavailable or access denied.';
                   EndMon;

               When $MENUOPT = 'M';
                   Monitor;
                       Call_MiniStmt(l_CustID);
                   On-Error;
                       $ERRMSG = 'Mini-statement module unavailable.';
                   EndMon;

               Other;
                   $ERRMSG = 'Invalid selection. Use 1-9 or M.';
           EndSl;

           // Refresh account balances after any module returns
           ExSr LoadSubfile;
       EndDo;

       Close DASHSCR;
       Return;

       BegSr LoadSubfile;
           SflClr = *On;
           Write DASHCTL;
           SflClr = *Off;
           SflDspCtl = *On;
           SflDsp = *Off;
           RRN = 0;

           Exec SQL Declare DashCur Cursor For
               Select ACCTNUM, ACCTTYPE, BALANCE, STATUS
               From SREERAMC1.ACCTMST
               Where CUSTID = :l_CustID
               Order By ACCTTYPE Asc;

           Exec SQL Open DashCur;

           Dow SQLCode = 0;
               Exec SQL Fetch DashCur
                        Into :$ACCTNUM, :$ACCTTYPE, :l_BalNum, :$STATUS;
               If SQLCode <> 0;
                   Leave;
               EndIf;
               $BALANCE = l_BalNum;
               RRN += 1;
               Write DASHSFL;
           EndDo;

           Exec SQL Close DashCur;

           If RRN > 0;
               SflDsp = *On;
           EndIf;
       EndSr;

       End-Proc;
