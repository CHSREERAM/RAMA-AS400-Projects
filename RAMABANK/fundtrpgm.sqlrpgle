     **FREE
      //===============================================================
      // RAMA BANK - FUND TRANSFER WORKFLOW
      // 4 Screens: Details -> Confirmation -> OTP Verify -> Result
      // Enforces limits: NEFT max 10L, RTGS min 2L, IMPS max 5L.
      // Atomic Commit with row locking (FOR UPDATE) and real
      // Commitment Control (Commit=*Chg + explicit Rollback on error).
      //
      // CRITICAL FIXES vs original:
      //  1. The destination account was NEVER credited for intra-bank
      //     transfers - money simply vanished. This version credits
      //     the beneficiary's ACCTMST row when the beneficiary account
      //     belongs to this bank, and queues NEFT/RTGS items for the
      //     settlement batch (NEFTBATCH/NEFTPGM) when it doesn't
      //     resolve to a local account (true interbank transfer).
      //  2. OTP was hardcoded as '123456'. Now uses OTPSRV
      //     (OTP_Generate/OTP_Verify) with real expiry + hashing.
      //  3. Commit=*None meant Commit/Rollback were no-ops and a
      //     failure between the debit and the TXNHIST insert silently
      //     lost money with no audit trail. Now uses Commit=*Chg with
      //     explicit Rollback on any failure step.
      //  4. The beneficiary check tested SQLCode<>0 after SELECT
      //     COUNT(*), which never happens (COUNT always returns a
      //     row). Now correctly tests the count itself.
      //  5. TXNID/QID generation used SELECT MAX()+1, which races
      //     under concurrent use. Now uses SEQ_TXNID/SEQ_QID.
      //  6. Library corrected from BANKLIB to SREERAMC1 throughout.
      //===============================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Fund_Main)
               BndDir('RAMABND');
       Ctl-Opt Option(*SrcStmt : *NoDebugIO);

       Exec SQL Set Option Commit=*Chg, Naming=*Sys, CloSqlCsr=*EndMod;

       Dcl-F FUNDSCR WORKSTN IndDS(dspfInds);

       Dcl-Pr Fund_Main ExtPgm('FUNDTRPGM');
             p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr OTP_Generate Char(6) ExtProc('OTP_GENERATE');
           p_CustID  Char(20) Const;
           p_Purpose Char(10) Const;
       End-Pr;

       Dcl-Pr OTP_Verify Ind ExtProc('OTP_VERIFY');
           p_CustID   Char(20) Const;
           p_Purpose  Char(10) Const;
           p_InputOTP Char(6) Const;
       End-Pr;

       Dcl-Ds dspfInds;
           ExitKey    Ind Pos(3);
           BackKey    Ind Pos(5);
           ErrorColor Ind Pos(90);
       End-Ds;

       Dcl-S l_State     Int(10) Inz(1); // 1=Dtl, 2=Cnf, 3=OTP, 4=Res
       Dcl-S l_Exit      Ind Inz(*Off);

       Dcl-S l_Bal       Packed(15:2);
       Dcl-S l_BenName   Varchar(100);
       Dcl-S l_Count     Int(10);
       Dcl-S l_NextTxn   Int(10);
       Dcl-S l_NextQ     Int(10);
       Dcl-S l_LocalAcct Int(10); // count of matching local ACCTMST rows
       Dcl-S l_Failed    Ind Inz(*Off);

       Dcl-S W_$FROMACCT    Varchar(20);
       Dcl-S W_$TOACCT      Varchar(20);
       Dcl-S W_$TOIFSC      Char(11);
       Dcl-S W_$TRNAMT      Packed(15:2);
       Dcl-S W_$TRNTYPE     Char(4);
       Dcl-S w_$REFNO       Varchar(20);

       Dcl-Proc Fund_Main;
       Dcl-Pi Fund_Main;
          p_CustID Char(20) Const;
       End-Pi;

       Exec SQL Select ACCTNUM, BALANCE
             Into :W_$FROMACCT, :l_Bal
             From SREERAMC1.ACCTMST
             Where CUSTID = :p_CustID
             Fetch First 1 Row Only;

       If SQLCode <> 0;
           ERRMSG = 'No account found for this customer.';
           ExFmt TRNDTL;
           Return;
       EndIf;

       $FROMBAL = %Trim(%EditC(l_Bal: 'P'));
       $FROMACCT = W_$FROMACCT;

       Dow Not l_Exit;
         Select;
          // ==================================
          // SCREEN 1: DETAILS
          // ==================================
          When l_State = 1;
               ExFmt TRNDTL;
               If ExitKey;
                  l_Exit = *On;
                  Else;
                     ERRMSG = *Blanks;
                     W_$TOACCT  = $TOACCT;
                     W_$TOIFSC  = $TOIFSC;
                     W_$TRNTYPE = $TRNTYPE;
                     W_$TRNAMT  = $TRNAMT;

                  If W_$TRNAMT <= 0;
                     ERRMSG = 'Invalid Amount';
                     Iter;
                  EndIf;

                  If W_$TRNAMT > l_Bal;
                     ERRMSG = 'Insufficient balance for this transfer.';
                     Iter;
                  EndIf;

                  If W_$TOACCT = W_$FROMACCT;
                     ERRMSG = 'Cannot transfer to the same account.';
                     Iter;
                  EndIf;

                  If W_$TRNTYPE = 'NEFT' And W_$TRNAMT > 1000000;
                     ERRMSG = 'NEFT Maximum Limit is 10 Lakhs';
                     Iter;
                  EndIf;

                  If W_$TRNTYPE = 'RTGS' And W_$TRNAMT < 200000;
                     ERRMSG = 'RTGS Minimum Limit is 2 Lakhs';
                     Iter;
                  EndIf;

                  If W_$TRNTYPE = 'IMPS' And W_$TRNAMT > 500000;
                     ERRMSG = 'IMPS Maximum Limit is 5 Lakhs';
                     Iter;
                  EndIf;

                  If W_$TRNTYPE <> 'NEFT' And W_$TRNTYPE <> 'RTGS'
                     And W_$TRNTYPE <> 'IMPS';
                     ERRMSG = 'Transfer Type must be NEFT, RTGS or IMPS.';
                     Iter;
                  EndIf;

                  // Verify Beneficiary exists for this customer
                  Exec SQL Select COUNT(*)
                            Into :l_Count
                         From SREERAMC1.BENEFMST
                         Where CUSTID = :p_CustID
                           And BENEFACCT = :W_$TOACCT
                           And BENEIFSC = :W_$TOIFSC
                           And STATUS = 'A';

                  If l_Count = 0;
                ERRMSG = 'Beneficiary not registered/approved, or still '
                         + 'in cooling period.';
                     Iter;
                  EndIf;

                  l_State = 2;
                 EndIf;

              // ==================================
              // SCREEN 2: CONFIRMATION
              // ==================================
             When l_State = 2;
               $CFROMACC = W_$FROMACCT;
               $CTOACCT = W_$TOACCT;
               $CAMT = %Trim(%EditC(W_$TRNAMT: 'P'));

               Exec SQL Select BENEFNAME
                        Into :l_BenName
                        From SREERAMC1.BENEFMST
                      Where CUSTID = :p_CustID
                      And BENEFACCT = :W_$TOACCT
                      Fetch First 1 Row Only;
                     $CBENAME = l_BenName;

                ExFmt TRNCNF;

                 If ExitKey;
                    l_Exit = *On;
                 ElseIf BackKey;
                    l_State = 1;
                  Else;
                    l_State = 3;
                 EndIf;

                 // ==================================
                 // SCREEN 3: OTP VERIFY
                 // ==================================
             When l_State = 3;
                 // Generate OTP the first time we land on this screen
                 If $OTPINP = *Blanks;
                    OTP_Generate(p_CustID: 'FUNDTR');
                 EndIf;
                 $OTPERR = *Blanks;
                 ExFmt TRNOTP;

                 If ExitKey;
                    l_Exit = *On;
                 ElseIf BackKey;
                    l_State = 2;
                    $OTPINP = *Blanks;
                  Else;
                    If Not OTP_Verify(p_CustID: 'FUNDTR': $OTPINP);
                       $OTPERR = 'Invalid or expired OTP. Try again.';
                      Else;
                      ExSr ProcessTransfer;
                           l_State = 4;
                   EndIf;
                 EndIf;

              // ==================================
              // SCREEN 4: RESULT
              // ==================================
             When l_State = 4;
                  ExFmt TRNRES;

                 If ExitKey;
                    l_Exit = *On;
                  Else;
                    l_State = 1;
                    $TOACCT = *Blanks;
                    $TOIFSC = *Blanks;
                    $TRNAMT = 0;
                    $TRNTYPE = *Blanks;
                    $OTPINP = *Blanks;

                    // Refresh balance for the next transfer
                    Exec SQL Select BALANCE Into :l_Bal
                             From SREERAMC1.ACCTMST
                             Where ACCTNUM = :W_$FROMACCT;
                    $FROMBAL = %Trim(%EditC(l_Bal: 'P'));
                 EndIf;
         EndSl;
       EndDo;

       Close FUNDSCR;
       Return;

      // ==================================
      // DATABASE TRANSACTION PROCESSING
      // ==================================
       BegSr ProcessTransfer;
          l_Failed = *Off;

          // 1. Lock the source account row
          Exec SQL Declare BalCursor Cursor For
             Select BALANCE From SREERAMC1.ACCTMST
             Where ACCTNUM = :W_$FROMACCT For Update Of BALANCE;

          Exec SQL Open BalCursor;
          Exec SQL Fetch BalCursor Into :l_Bal;

          If SQLCode <> 0;
             Exec SQL Close BalCursor;
             $TRNSTAT = 'FAILED';
             $REFNO = 'N/A';
             ErrorColor = *On;
             Return;
          EndIf;

          // Re-check balance under lock (protects against a concurrent
          // debit that happened between screen display and this point)
          If l_Bal < W_$TRNAMT;
             Exec SQL Close BalCursor;
             $TRNSTAT = 'FAILED';
             $REFNO = 'N/A';
             ErrorColor = *On;
             Return;
          EndIf;

          l_Bal -= W_$TRNAMT;

          // 2. Debit source account
          Exec SQL Update SREERAMC1.ACCTMST
                 Set BALANCE = :l_Bal
                 Where Current of BalCursor;

          If SQLCode <> 0;
             Exec SQL Close BalCursor;
             Exec SQL Rollback;
             $TRNSTAT = 'FAILED';
             $REFNO = 'N/A';
             ErrorColor = *On;
             Return;
          EndIf;

          Exec SQL Close BalCursor;

          w_$REFNO = 'TRN' + %Char(%Timestamp(): *ISO0);
          w_$REFNO = %Subst(w_$REFNO: 1: 20);

          // 3. Debit-side transaction history row
          Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_TXNID Into :l_NextTxn;

          Exec SQL Insert Into SREERAMC1.TXNHIST(TXNID, TXNDATE,
                       TXNTIME, ACCTNUM, TXNTYPE,
                       AMOUNT, REFNUM, BALAFTER, STATUS)
                Values(:l_NextTxn, CURRENT_DATE, CURRENT_TIME, :W_$FROMACCT,
                'DR', :W_$TRNAMT, :w_$REFNO, :l_Bal, 'S');

          If SQLCode <> 0;
             l_Failed = *On;
          EndIf;

          // 4. Determine whether the beneficiary account is local
          //    (same bank) - if so, credit it directly and record a
          //    matching CR transaction history row. If not local
          //    (genuine interbank NEFT/RTGS), queue it for settlement
          //    by the NEFTBATCH job, which calls NEFTPGM.
          If Not l_Failed;
             Exec SQL Select COUNT(*) Into :l_LocalAcct
                      From SREERAMC1.ACCTMST
                      Where ACCTNUM = :W_$TOACCT And STATUS = 'A';
          EndIf;

          If Not l_Failed And l_LocalAcct > 0 And W_$TRNTYPE <> 'NEFT'
             And W_$TRNTYPE <> 'RTGS';
             // IMPS or any instant local transfer: credit immediately
             Exec SQL Update SREERAMC1.ACCTMST
                      Set BALANCE = BALANCE + :W_$TRNAMT
                      Where ACCTNUM = :W_$TOACCT;

             If SQLCode <> 0;
                l_Failed = *On;
             Else;
                Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_TXNID
                         Into :l_NextTxn;

                Exec SQL Insert Into SREERAMC1.TXNHIST(TXNID, TXNDATE,
                             TXNTIME, ACCTNUM, TXNTYPE,
                             AMOUNT, REFNUM, BALAFTER, STATUS)
                      Select :l_NextTxn, CURRENT_DATE, CURRENT_TIME,
                             :W_$TOACCT, 'CR', :W_$TRNAMT, :w_$REFNO,
                             BALANCE, 'S'
                      From SREERAMC1.ACCTMST
                      Where ACCTNUM = :W_$TOACCT;

                If SQLCode <> 0;
                   l_Failed = *On;
                EndIf;
             EndIf;

          ElseIf Not l_Failed And l_LocalAcct > 0;
             // NEFT/RTGS but happens to be a local account: still
             // credit immediately since no external network hop is
             // actually required (avoids needlessly delaying same
             // bank transfers through the batch queue).
             Exec SQL Update SREERAMC1.ACCTMST
                      Set BALANCE = BALANCE + :W_$TRNAMT
                      Where ACCTNUM = :W_$TOACCT;

             If SQLCode <> 0;
                l_Failed = *On;
             Else;
                Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_TXNID
                         Into :l_NextTxn;

                Exec SQL Insert Into SREERAMC1.TXNHIST(TXNID, TXNDATE,
                             TXNTIME, ACCTNUM, TXNTYPE,
                             AMOUNT, REFNUM, BALAFTER, STATUS)
                      Select :l_NextTxn, CURRENT_DATE, CURRENT_TIME,
                             :W_$TOACCT, 'CR', :W_$TRNAMT, :w_$REFNO,
                             BALANCE, 'S'
                      From SREERAMC1.ACCTMST
                      Where ACCTNUM = :W_$TOACCT;

                If SQLCode <> 0;
                   l_Failed = *On;
                EndIf;
             EndIf;

          ElseIf Not l_Failed;
             // Genuine interbank transfer - queue for NEFTBATCH/NEFTPGM
             Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_QID Into :l_NextQ;

             Exec SQL Insert Into SREERAMC1.TXNQUEUE
                   (QID, FROMACCT, TOACCT, TOIFSC, AMOUNT, QTIMESTAMP,
                    STATUS, NWTYPE)
                  Values(:l_NextQ, :W_$FROMACCT, :W_$TOACCT, :W_$TOIFSC,
                    :W_$TRNAMT, CURRENT_TIMESTAMP, 'P', :W_$TRNTYPE);

             If SQLCode <> 0;
                l_Failed = *On;
             EndIf;
          EndIf;

          // 5. Commit or rollback as one atomic unit
          If l_Failed;
             Exec SQL Rollback;
             $TRNSTAT = 'FAILED';
             $REFNO = 'N/A';
             ErrorColor = *On;
          Else;
             Exec SQL Commit;
             $TRNSTAT = 'SUCCESS';
             $REFNO = w_$REFNO;
             ErrorColor = *Off;
          EndIf;
        EndSr;

       End-Proc;
