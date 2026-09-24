**FREE
      //====================================================================
      // RAMA BANK - BILL PAYMENTS
      // Fetches registered billers, supports manual payment and the
      // overnight AutoPay batch (called with p_CustID = '*AUTOPAY').
      //
      // Rewritten. Original had multiple Exec SQL statements truncated
      // mid-line (would not compile), referenced BANKLIB.ACCTMS (typo,
      // missing the final T, and wrong library), never generated a
      // TXNID for the TXNHIST insert, re-used a stale BALANCE host
      // variable instead of re-checking it at payment time, and
      // RunAutoPayBatch declared a cursor but never opened, fetched,
      // or paid anything - the entire AutoPay feature was a stub.
      //
      // To create SEQ_TXNID sequence (if not already present): IN STRSQL
      //CREATE SEQUENCE SREERAMC1.SEQ_BENEFID
      //AS INTEGER
      //START WITH 1
      //INCREMENT BY 1
      //NO MAXVALUE
      //NO CYCLE
      //CACHE 20
      //====================================================================

      //====================================================================
      // RAMA BANK - BILL PAYMENTS
      // Fetches registered billers, supports manual payment and the
      // overnight AutoPay batch (called with p_CustID = '*AUTOPAY').
      //====================================================================
      Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(BillPay_Main) BndDir('RAMABND');

      // USROPN prevents the interactive display file from opening in batch jobs
      Dcl-F BILLPAYSCR WORKSTN Sfile(BILLSFL: RRN) IndDS(ScnInd) UsrOpn;

      Dcl-Ds ScnInd;
          ExitKey   Ind Pos(3);
          SflClr    Ind Pos(42);
          SflDspCtl Ind Pos(41);
          SflDsp    Ind Pos(40);
      End-Ds;

      Dcl-Pr BillPay_Main ExtPgm('BILLPAYPGM');
          p_CustID Char(20) Const;
      End-Pr;

      Dcl-S RRN Int(10); // FIX: Declared globally so the global Dcl-F can see it

      Exec SQL Set Option Commit=*Chg, Naming=*Sys;

      Dcl-Proc BillPay_Main;
          Dcl-Pi BillPay_Main;
              p_CustID Char(20) Const; // '*AUTOPAY' triggers batch mode
          End-Pi;

       // Local variables for BillPay_Main
        Dcl-S l_Exit     Ind Inz(*Off);
        Dcl-S l_AcctNum  Char(20);
        Dcl-S l_Balance  Packed(15:2);

       // FIX: Variables moved from ProcessPayment subroutine to the top of procedure
         Dcl-S l_NextTxn  Int(10);
         Dcl-S l_CurBal   Packed(15:2);
         Dcl-S l_Failed   Ind Inz(*Off);

         // FIX: Variables moved from RunAutoPayBatch subroutine to the top of procedure
         Dcl-S l_AutoAcct Char(20);
         Dcl-S l_AutoBill Char(20);
         Dcl-S l_AutoBal  Packed(15:2);
         Dcl-S l_AutoAmt  Packed(15:2);
         Dcl-S l_AutoTxn  Int(10);
         Dcl-S l_AutoFail Ind Inz(*Off);

         // SQL Cursors declared at the top of the procedure
         Exec SQL Declare BillCur Cursor For
             Select B.BILLERNAME, B.CATEGORY, R.CONN_NUM, R.AUTOPAY
             From SREERAMC1.BILLREG R
             Join SREERAMC1.BILLERMST B ON R.BILLERID = B.BILLERID
             Where R.CUSTID = :p_CustID;

         Exec SQL Declare PayCur Cursor For
             Select BALANCE From SREERAMC1.ACCTMST
             Where ACCTNUM = :l_AcctNum For Update Of BALANCE;

         Exec SQL Declare AutoCur Cursor For
             Select ACCTNUM, BILLERID From SREERAMC1.BILLREG
             Where AUTOPAY = 'Y'
             For Read Only;

         Exec SQL Declare AutoBalCur Cursor For
             Select BALANCE From SREERAMC1.ACCTMST
             Where ACCTNUM = :l_AutoAcct For Update Of BALANCE;

         // Check for Overnight Batch Mode
         If p_CustID = '*AUTOPAY';
             ExSr RunAutoPayBatch;
             Return;
         EndIf;

         // FIX: Only open the workstation file in interactive mode
         If Not %Open(BILLPAYSCR);
             Open BILLPAYSCR;
         EndIf;

         Exec SQL Select ACCTNUM, BALANCE Into :l_AcctNum, :l_Balance
                  From SREERAMC1.ACCTMST
                  Where CUSTID = :p_CustID Fetch First 1 Row Only;

         If SQLCode <> 0;
             ERRMSG = 'No account found for this customer.';
             ExFmt BILLCTL;

             // FIX: Explicit close before early return
             If %Open(BILLPAYSCR);
                 Close BILLPAYSCR;
             EndIf;
             Return;
         EndIf;

         ACCTNUM = l_AcctNum;
         BALANCE = l_Balance;

         Dow Not l_Exit;
             ExSr LoadSubfile;
             ExFmt BILLCTL;

             If ExitKey;
                 l_Exit = *On;
                 Iter;
             EndIf;

             ExSr ProcessPayment;
         EndDo;

         // FIX: Explicitly close the workstation file before program exit
         If %Open(BILLPAYSCR);
             Close BILLPAYSCR;
         EndIf;
         Return;

         BegSr LoadSubfile;
             SflClr = *On;
             Write BILLCTL;
             SflClr = *Off;
             SflDspCtl = *On;
             SflDsp = *Off;
             RRN = 0;

             Exec SQL Open BillCur;

             Dow SQLCode = 0;
                 Exec SQL Fetch BillCur Into :S_BILLER, :S_CAT, :S_CONNUM,
                                              :S_AUTOPAY;
                 If SQLCode <> 0;
                     Leave;
                 EndIf;

                 S_SEL = '';
                 RRN += 1;
                 Write BILLSFL;
             EndDo;

             Exec SQL Close BillCur;

             If RRN > 0;
                 SflDsp = *On;
             EndIf;
         EndSr;

         BegSr ProcessPayment;
             ReadC BILLSFL;
             Dow Not %Eof(BILLPAYSCR);
                 If S_SEL = '1';
                     Exec SQL Open PayCur;
                     Exec SQL Fetch PayCur Into :l_CurBal;

                     If SQLCode <> 0;
                         Exec SQL Close PayCur;
                         ERRMSG = 'Could not retrieve current balance.';
                     ElseIf PAYAMT <= 0 Or PAYAMT > l_CurBal;
                         Exec SQL Close PayCur;
                         ERRMSG = 'Invalid amount or insufficient balance.';
                     Else;
                         l_Failed = *Off;
                         l_CurBal -= PAYAMT;

                         Exec SQL Update SREERAMC1.ACCTMST
                                  Set BALANCE = :l_CurBal
                                  Where Current Of PayCur;
                         If SQLCode <> 0;
                             l_Failed = *On;
                         EndIf;
                         Exec SQL Close PayCur;

                         If Not l_Failed;
                             Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_TXNID
                                      Into :l_NextTxn;

                             Exec SQL Insert Into SREERAMC1.TXNHIST(TXNID,
                                         TXNDATE, TXNTIME, ACCTNUM, TXNTYPE,
                                         AMOUNT, REFNUM, BALAFTER, STATUS)
                                  Values(:l_NextTxn, CURRENT_DATE,
                                         CURRENT_TIME, :l_AcctNum, 'DR',
                                         :PAYAMT,
                                         'BILL' || TRIM(Char(:l_NextTxn)),
                                         :l_CurBal, 'S');
                             If SQLCode <> 0;
                                 l_Failed = *On;
                             EndIf;
                         EndIf;

                         If l_Failed;
                             Exec SQL Rollback;
                             ERRMSG = 'Payment failed - please try again.';
                         Else;
                             Exec SQL Commit;
                             l_Balance = l_CurBal;
                             BALANCE = l_CurBal;
                             ERRMSG = 'Payment successful for '
                                      + %Trim(S_BILLER);
                         EndIf;
                     EndIf;

                     S_SEL = '';
                     Update BILLSFL;
                 EndIf;
                 ReadC BILLSFL;
             EndDo;
         EndSr;

         BegSr RunAutoPayBatch;
             l_AutoAmt = 500.00;

             Exec SQL Open AutoCur;

             Dow SQLCode = 0;
                 Exec SQL Fetch AutoCur Into :l_AutoAcct, :l_AutoBill;
                 If SQLCode <> 0;
                     Leave;
                 EndIf;

                 l_AutoFail = *Off;

                 Exec SQL Open AutoBalCur;
                 Exec SQL Fetch AutoBalCur Into :l_AutoBal;

                 If SQLCode <> 0 Or l_AutoBal < l_AutoAmt;
                     Exec SQL Close AutoBalCur;
                     Iter;
                 EndIf;

                 l_AutoBal -= l_AutoAmt;

                 Exec SQL Update SREERAMC1.ACCTMST Set BALANCE = :l_AutoBal
                          Where Current Of AutoBalCur;
                 If SQLCode <> 0;
                     l_AutoFail = *On;
                 EndIf;
                 Exec SQL Close AutoBalCur;

                 If Not l_AutoFail;
                     Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_TXNID
                              Into :l_AutoTxn;

                     Exec SQL Insert Into SREERAMC1.TXNHIST(TXNID, TXNDATE,
                                 TXNTIME, ACCTNUM, TXNTYPE, AMOUNT, REFNUM,
                                 BALAFTER, STATUS)
                          Values(:l_AutoTxn, CURRENT_DATE, CURRENT_TIME,
                                 :l_AutoAcct, 'DR', :l_AutoAmt,
                                 'AUTOPAY' || TRIM(Char(:l_AutoTxn)), :l_AutoBal,
                                 'S');
                     If SQLCode <> 0;
                         l_AutoFail = *On;
                     EndIf;
                 EndIf;

                 If l_AutoFail;
                     Exec SQL Rollback;
                 Else;
                     Exec SQL Commit;
                 EndIf;
             EndDo;

             Exec SQL Close AutoCur;
         EndSr;

        End-Proc;

