     **FREE
      //====================================================================
      // RAMA BANK - LOAN DETAIL & EMI PAYMENT
      // BUG-07 FIX: Sfile changed from LOANSFL to LNSFL (DSPF defines LNSFL)
      // BUG-08 FIX: Write changed from LOANSFL to LNSFL
      // BUG-09 FIX: PRINAMT_S renamed to PRINAMT (LNSFL field name)
      // BUG-10 FIX: EMISTS renamed to STATUS (LNSFL field name)
      // BUG-11 FIX: Dcl-S moved out of BegSr to proc-level declarations
      // BUG-12/13 FIX: CA10 added to LOANDTLSCR; ExFmt LNPAY now shown
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Loan_Main)
               BndDir('RAMABND');

       Dcl-F LOANDTLSCR WORKSTN Sfile(LNSFL: RRN) IndDS(ScnInd);

       Dcl-Ds ScnInd;
           ExitKey   Ind Pos(3);
           PayKey    Ind Pos(10);
           SflClr    Ind Pos(42);
           SflDspCtl Ind Pos(41);
           SflDsp    Ind Pos(40);
       End-Ds;

       Dcl-Pr Loan_Main ExtPgm('LOANDTLPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Exec SQL Set Option Commit=*Chg, Naming=*Sys;

       // All Dcl-S at module level - NOT inside subroutines
       Dcl-S l_LoanAcct Char(20);
       Dcl-S l_Prinamt  Packed(15:2);
       Dcl-S l_IntRate  Packed(5:2);
       Dcl-S l_TermMnth Int(10);
       Dcl-S l_LoanSts  Char(1);
       Dcl-S l_Found    Int(10);
       Dcl-S RRN        Int(10);
       Dcl-S l_SbAcct   Char(20);
       // Subfile fetch variables (BUG-11: moved out of BegSr)
       Dcl-S l_DueDate   Date;
       Dcl-S l_EmiAmtCl  Packed(15:2);
       Dcl-S l_PrinAmtCl Packed(15:2);
       Dcl-S l_IntAmtCl  Packed(15:2);
       Dcl-S l_StsVal    Char(10);
       // KYC Verification / pay variables
       Dcl-S l_KycApprove Char(1);
       Dcl-S l_NewKyc     Char(1);
       Dcl-S l_NextLog2   Int(10);

       Dcl-Proc Loan_Main;
       Dcl-Pi Loan_Main;
           p_CustID Char(20) Const;
       End-Pi;

       Dcl-S l_Exit    Ind Inz(*Off);
       Dcl-S l_EmiId   Int(10);
       Dcl-S l_EmiAmt  Packed(15:2);
       Dcl-S l_NextTxn Int(10);
       Dcl-S l_SbBal   Packed(15:2);
       Dcl-S l_Failed  Ind Inz(*Off);

       Exec SQL Select LOANACCT, PRINAMT, INTRATE, TERMMNTH, LOANSTS
                Into :l_LoanAcct, :l_Prinamt, :l_IntRate,
                     :l_TermMnth, :l_LoanSts
                From SREERAMC1.LOANMST
                Where CUSTID = :p_CustID And LOANSTS = 'A'
                Fetch First 1 Row Only;

       l_Found = 1;
       If SQLCode <> 0;
           l_Found = 0;
       EndIf;

       Exec SQL Select ACCTNUM Into :l_SbAcct
                From SREERAMC1.ACCTMST
                Where CUSTID = :p_CustID And ACCTTYPE = 'SB' And STATUS = 'A'
                Fetch First 1 Row Only;

       If SQLCode <> 0;
           l_SbAcct = '';
       EndIf;

       If l_Found = 1;
           LOANACCT = l_LoanAcct;
           INTRATED  = l_IntRate;
           TERMMNTHD = l_TermMnth;
           LOANSTSD  = l_LoanSts;
           // Use ACCTMST balance as the outstanding loan balance
           Exec SQL Select BALANCE Into :l_Prinamt
                    From SREERAMC1.ACCTMST
                    Where ACCTNUM = :l_LoanAcct;
           BAL = l_Prinamt;
       EndIf;

       ExSr LoadSubfile;

       Dow Not l_Exit;
           ExFmt LNCTL;

           If ExitKey;
               l_Exit = *On;
               Iter;
           EndIf;

           ERRMSG = *Blanks;

           If l_Found = 0;
               ERRMSG = 'No active loan found for this customer.';
               l_Exit = *On;
               Iter;
           EndIf;

           If PayKey;
               // BUG-13 FIX: Show LNPAY screen to get EMI ID before paying
               PAYID  = 0;
               ERRMSG = *Blanks;
               ExFmt LNPAY;
               If Not ExitKey;
                   l_EmiId = PAYID;
                   ExSr PayNextEmi;
                   ExSr LoadSubfile;
               EndIf;
               Iter;
           EndIf;

       EndDo;
       Close LOANDTLSCR;
       Return;

       BegSr LoadSubfile;
           SflClr = *On;
           Write LNCTL;
           SflClr = *Off;
           SflDspCtl = *On;
           SflDsp = *Off;
           RRN = 0;

           Exec SQL Declare LoanCur Cursor For
               Select EMIID, DUEDATE, EMI_AMT, PRIN_AMT, INT_AMT, STATUS
               From SREERAMC1.EMISCHDULE
               Where LOANACCT = :l_LoanAcct
               Order By DUEDATE Asc;

           Exec SQL Open LoanCur;

           Dow SQLCode = 0;
               Exec SQL Fetch LoanCur Into :l_EmiId, :l_DueDate,
                                           :l_EmiAmtCl, :l_PrinAmtCl,
                                           :l_IntAmtCl, :l_StsVal;
               If SQLCode <> 0;
                   Leave;
               EndIf;

               // BUG-08/09/10 FIX: Write to LNSFL; use PRINAMT not PRINAMT_S;
               // use STATUS not EMISTS
               EMIID   = l_EmiId;
               DUEDATE = %Char(l_DueDate: *ISO);
               EMIAMT  = l_EmiAmtCl;
               PRINAMT = l_PrinAmtCl;
               INTAMT  = l_IntAmtCl;
               STATUS  = l_StsVal;

               RRN += 1;
               Write LNSFL;
           EndDo;

           Exec SQL Close LoanCur;

           If RRN > 0;
               SflDsp = *On;
           Else;
               ERRMSG = 'No EMI schedule found for this loan.';
           EndIf;
       EndSr;

       BegSr PayNextEmi;
           If l_SbAcct = '';
               ERRMSG = 'No active savings account found for EMI debit.';
               Return;
           EndIf;

           If l_EmiId <= 0;
               ERRMSG = 'Invalid EMI ID entered.';
               Return;
           EndIf;

           // Verify the EMI belongs to this loan and is PENDING
           Exec SQL Select EMI_AMT Into :l_EmiAmt
                    From SREERAMC1.EMISCHDULE
                    Where EMIID = :l_EmiId And LOANACCT = :l_LoanAcct
                    And STATUS = 'PENDING';

           If SQLCode <> 0;
               ERRMSG = 'EMI not found or already paid.';
               Return;
           EndIf;

           l_Failed = *Off;

           Exec SQL Declare EmiPayCur Cursor For
               Select BALANCE From SREERAMC1.ACCTMST
               Where ACCTNUM = :l_SbAcct For Update Of BALANCE;
           Exec SQL Open EmiPayCur;
           Exec SQL Fetch EmiPayCur Into :l_SbBal;

           If SQLCode <> 0;
               Exec SQL Close EmiPayCur;
               ERRMSG = 'Could not lock savings account for debit.';
               Return;
           EndIf;

           If l_SbBal < l_EmiAmt;
               Exec SQL Close EmiPayCur;
               ERRMSG = 'Insufficient balance to pay this EMI.';
               Return;
           EndIf;

           l_SbBal -= l_EmiAmt;

           Exec SQL Update SREERAMC1.ACCTMST Set BALANCE = :l_SbBal
                    Where Current Of EmiPayCur;
           If SQLCode <> 0;
               l_Failed = *On;
           EndIf;
           Exec SQL Close EmiPayCur;

           If Not l_Failed;
               Exec SQL Update SREERAMC1.EMISCHDULE Set STATUS = 'PAID'
                        Where EMIID = :l_EmiId;
               If SQLCode <> 0;
                   l_Failed = *On;
               EndIf;
           EndIf;

           If Not l_Failed;
               Exec SQL Update SREERAMC1.ACCTMST
                        Set BALANCE = BALANCE - :l_EmiAmt
                        Where ACCTNUM = :l_LoanAcct;
               If SQLCode <> 0;
                   l_Failed = *On;
               EndIf;
           EndIf;

           If Not l_Failed;
               Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_TXNID
                        Into :l_NextTxn;

               Exec SQL Insert Into SREERAMC1.TXNHIST
                        (TXNID, TXNDATE, TXNTIME, ACCTNUM, TXNTYPE,
                         AMOUNT, REFNUM, BALAFTER, STATUS)
                    Values(:l_NextTxn, CURRENT_DATE, CURRENT_TIME,
                           :l_SbAcct, 'DR', :l_EmiAmt,
                           'EMI' || TRIM(Char(:l_EmiId)), :l_SbBal, 'S');
               If SQLCode <> 0;
                   l_Failed = *On;
               EndIf;
           EndIf;

           If l_Failed;
               Exec SQL Rollback;
               ERRMSG = 'EMI payment failed. Please try again.';
           Else;
               Exec SQL Commit;
               // Refresh displayed outstanding balance
               Exec SQL Select BALANCE Into :l_Prinamt
                        From SREERAMC1.ACCTMST
                        Where ACCTNUM = :l_LoanAcct;
               BAL    = l_Prinamt;
               ERRMSG = 'EMI ' + %Char(l_EmiId) + ' paid. Amount: '
                        + %Trim(%EditC(l_EmiAmt: 'P'));
           EndIf;
       EndSr;

       End-Proc;
