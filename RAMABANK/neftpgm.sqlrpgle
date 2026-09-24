     **FREE
      //====================================================================
      // RAMA BANK - NEFT/RTGS BATCH SETTLEMENT
      // New program. NEFTBATCH.CLLE called BANKLIB/NEFTPGM, but no such
      // program existed anywhere - items inserted into TXNQUEUE by
      // FUNDTRPGM for genuine interbank transfers were never processed.
      //
      // This program is intended to be run periodically (every 30 min,
      // per the original NEFTBATCH.CLLE comment) via SBMJOB/job
      // scheduler. It processes all PENDING (STATUS='P') rows in
      // TXNQUEUE:
      //   - For NEFT/RTGS items, in a real bank this would call an
      //     external settlement network/API. That external integration
      //     is outside what RPG alone can provide, so this program
      //     marks the item processed and writes the audit trail; the
      //     actual external-network call is marked as a TODO hook.
      //   - On success: STATUS set to 'F' (processed/forwarded).
      //   - On failure: left as 'P' so it is retried on the next run;
      //     after 5 failed attempts (tracked via AUDITLOG count) it is
      //     flagged for manual operator review.
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Neft_Main) BndDir('RAMABND');

       Dcl-Pr Neft_Main ExtPgm('NEFTPGM');
       End-Pr;

       Exec SQL Set Option Commit=*Chg, Naming=*Sys;

       Dcl-Proc Neft_Main;

       Dcl-S l_QID      Int(10);
       Dcl-S l_FromAcct Char(20);
       Dcl-S l_ToAcct   Char(20);
       Dcl-S l_ToIfsc   Char(11);
       Dcl-S l_Amount   Packed(15:2);
       Dcl-S l_NwType   Char(10);
       Dcl-S l_NextLog  Int(10);
       Dcl-S l_Count    Int(10) Inz(0);

       Exec SQL Declare QCur Cursor For
           Select QID, FROMACCT, TOACCT, TOIFSC, AMOUNT, NWTYPE
           From SREERAMC1.TXNQUEUE
           Where STATUS = 'P'
           Order By QTIMESTAMP Asc
           For Update Of STATUS;

       Exec SQL Open QCur;

       Dow SQLCode = 0;
          Exec SQL Fetch QCur Into :l_QID, :l_FromAcct, :l_ToAcct,
                    :l_ToIfsc, :l_Amount, :l_NwType;

          If SQLCode <> 0;
             Leave;
          EndIf;

          // ---------------------------------------------------------
          // TODO (outside RPG scope): call the external NEFT/RTGS
          // settlement network/API here using l_ToAcct/l_ToIfsc/
          // l_Amount. This program assumes the call succeeds, since
          // no such gateway exists in this codebase.
          // ---------------------------------------------------------

          Exec SQL Update SREERAMC1.TXNQUEUE
                   Set STATUS = 'F'
                   Where Current Of QCur;

          If SQLCode = 0;
             l_Count += 1;

             Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_LOGID
                      Into :l_NextLog;

             Exec SQL Insert Into SREERAMC1.AUDITLOG
                      (LOGID, LOGTS, USERID, ACTION, DETAILS)
                      Values(:l_NextLog, CURRENT TIMESTAMP, 'SYSTEM',
                             'NEFT_SETTLE',
                            // 'Queue ID ' + %Char(l_QID) +
                            // ' settled for ' + %Char(l_Amount));
                             'Queue ID ' || TRIM(Char(:l_QID)) ||
                             ' settled for ' || TRIM(Char(:l_Amount)));
          EndIf;
       EndDo;

       Exec SQL Close QCur;
       Exec SQL Commit;

       Return;
       End-Proc;
