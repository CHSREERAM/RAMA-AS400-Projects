     **FREE
      //====================================================================
      // RAMA BANK - PRINT STATEMENT SPOOLER
      // Generates a spool file via QPRINT for the customer's statement.
      //
      // Fixes vs original:
      //  - Original query had NO account-number filter at all, so any
      //    customer's printed statement showed every other customer's
      //    transactions within the date range. Now filtered by
      //    p_AcctNum (new required parameter, passed by STMTPGM).
      //  - p_FltType was accepted but never applied; now applied.
      //  - Printed line only ever included date/time/reference; type,
      //    amount and balance were silently dropped despite being in
      //    the header. Now all columns are printed.
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Prt_Main) BndDir('RAMABND');

       Dcl-Pr Prt_Main ExtPgm('STMTPRT');
           p_CustID  Char(20) Const;
           p_AcctNum Char(20) Const;
           p_FrmDate Char(10) Const;
           p_ToDate  Char(10) Const;
           p_FltType Char(3) Const;
       End-Pr;

       Dcl-F QPRINT PRINTER(132) OFLIND(*In99);

       Exec SQL Set Option Commit=*None, Naming=*Sys;

       Dcl-Proc Prt_Main;
       Dcl-Pi *N;
           p_CustID  Char(20) Const;
           p_AcctNum Char(20) Const;
           p_FrmDate Char(10) Const;
           p_ToDate  Char(10) Const;
           p_FltType Char(3) Const;
       End-Pi;

       Dcl-Ds
          //OutLine Char(132)
          OutLine Len(132)
       End-Ds;

       Dcl-S l_Count Int(10) Inz(0);

       Dcl-S Sql_TXNDATE Date;
       Dcl-S Sql_TXNTIME Time;
       Dcl-S Sql_REFNUM  Char(50);
       Dcl-S Sql_AMOUNT  Packed(15:2);
       Dcl-S Sql_BALAFTER Packed(15:2);
       Dcl-S Sql_TXNTYPE Char(2);

       OutLine = 'STATEMENT FOR CUSTOMER: ' + p_CustID
                  + '   ACCOUNT: ' + p_AcctNum;
       Write QPRINT OutLine;
       OutLine = 'DATE       TIME     REFERENCE            TYPE   '+
                  'AMOUNT          BALANCE';
       Write QPRINT OutLine;
       OutLine = '--------------------------------------------------------'+
                       '-----------';
       Write QPRINT OutLine;

       Exec SQL Declare PrtCur Cursor For
           Select TXNDATE, TXNTIME, REFNUM, TXNTYPE, AMOUNT, BALAFTER
           From SREERAMC1.TXNHIST
           Where ACCTNUM = :p_AcctNum
             And (:p_FrmDate = '' OR TXNDATE >= DATE(:p_FrmDate))
             And (:p_ToDate  = '' OR TXNDATE <= DATE(:p_ToDate))
             And (:p_FltType = '' OR :p_FltType = 'ALL'
                  OR TXNTYPE = :p_FltType)
           Order By TXNDATE Desc, TXNTIME Desc;

       Exec SQL Open PrtCur;

       Dow SQLCode = 0;
           Exec SQL Fetch PrtCur Into :Sql_TXNDATE, :Sql_TXNTIME,
                                      :Sql_REFNUM, :Sql_TXNTYPE,
                                      :Sql_AMOUNT, :Sql_BALAFTER;
           If SQLCode <> 0;
               Leave;
           EndIf;

           OutLine = %Char(Sql_TXNDATE: *ISO) + ' '
                      + %Char(Sql_TXNTIME) + ' '
                      + %Subst(Sql_REFNUM: 1: 20) + ' '
                      + Sql_TXNTYPE + '     '
                      + %Trim(%EditC(Sql_AMOUNT: 'P')) + '   '
                      + %Trim(%EditC(Sql_BALAFTER: 'P'));
           Write QPRINT OutLine;

           l_Count += 1;
           If *In99;
               OutLine = '--- Page Break ---';
               Write QPRINT OutLine;
               *In99 = *Off;
           EndIf;
       EndDo;

       Exec SQL Close PrtCur;

       OutLine = 'END OF REPORT. TOTAL RECORDS: ' + %Char(l_Count);
       Write QPRINT OutLine;

       Close QPRINT;
       Return;
       End-Proc;
