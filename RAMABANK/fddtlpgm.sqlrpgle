     **FREE
      //====================================================================
      // RAMA BANK - FIXED DEPOSIT DETAIL & OPERATIONS
      // BUG-04 FIX: ExFmt changed from FDMFMT to FDFMT (FDSCR defines FDFMT)
      // BUG-05 FIX: TERMMNTH renamed to MONTHS (FDSCR defines MONTHS)
      // BUG-06 FIX: DAYSLEFT removed (no such field in FDSCR)
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(FdDtl_Main)
               BndDir('RAMABND');

       Dcl-F FDSCR WORKSTN IndDS(ScnInd);

       Dcl-Ds ScnInd;
           ExitKey  Ind Pos(3);
           CloseKey Ind Pos(10);
       End-Ds;

       Dcl-Pr FdDtl_Main ExtPgm('FDDTLPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Exec SQL Set Option Commit=*Chg, Naming=*Sys;

       Dcl-S l_FdAcct    Char(20);
       Dcl-S l_LinkedSB  Char(20);
       Dcl-S l_Prinamt   Packed(15:2);
       Dcl-S l_IntRate   Packed(5:2);
       Dcl-S l_TermMnth  Int(10);
       Dcl-S l_StartDate Date;
       Dcl-S l_MatDate   Date;
       Dcl-S l_MatAmt    Packed(15:2);
       Dcl-S l_FdSts     Char(1);
       Dcl-S l_Found     Int(10);

       Dcl-Proc FdDtl_Main;
       Dcl-Pi FdDtl_Main;
           p_CustID Char(20) Const;
       End-Pi;

       Dcl-S l_Exit    Ind Inz(*Off);
       Dcl-S l_Penalty  Packed(15:2);
       Dcl-S l_Final    Packed(15:2);
       Dcl-S l_NextTxn  Int(10);
       Dcl-S l_Failed   Ind Inz(*Off);

       Exec SQL
           Select FDACCT, LINKEDSB, PRINAMT, INTRATE, TERMMNTH,
                  STARTDATE, MATDATE, MATAMT, FDSTS
           Into :l_FdAcct, :l_LinkedSB, :l_Prinamt, :l_IntRate,
                :l_TermMnth, :l_StartDate, :l_MatDate, :l_MatAmt,
                :l_FdSts
           From SREERAMC1.FDMST
           Where CUSTID = :p_CustID And FDSTS = 'A'
           Fetch First 1 Row Only;

       l_Found = 1;
       If SQLCode <> 0;
           l_Found = 0;
       EndIf;

       If l_Found = 1;
           FDACCT  = l_FdAcct;
           PRINAMT = l_Prinamt;
           INTRATE = l_IntRate;
           MONTHS  = l_TermMnth;          // BUG-05 FIX: was TERMMNTH
           MATDATE = %Char(l_MatDate: *ISO);
           MATAMT  = l_MatAmt;
           STATUS  = l_FdSts;
           // BUG-06 FIX: DAYSLEFT removed - no such field in FDSCR
       EndIf;

       Dow Not l_Exit;
           If l_Found = 0;
               ERRMSG = 'No active Fixed Deposit found for this customer.';
               ExFmt FDFMT;                // BUG-04 FIX: was FDMFMT
               l_Exit = *On;
               Iter;
           EndIf;

           ExFmt FDFMT;                   // BUG-04 FIX: was FDMFMT

           If ExitKey;
               l_Exit = *On;
               Iter;
           EndIf;

           ERRMSG = *Blanks;

           If CloseKey;
               If l_FdSts <> 'A';
                   ERRMSG = 'FD is not Active. Cannot close.';
                   Iter;
               EndIf;

               l_Penalty = l_Prinamt * 0.01;
               l_Final   = l_Prinamt - l_Penalty;
               l_Failed  = *Off;

               Exec SQL Update SREERAMC1.ACCTMST
                        Set BALANCE = BALANCE + :l_Final
                        Where ACCTNUM = :l_LinkedSB;
               If SQLCode <> 0;
                   l_Failed = *On;
               EndIf;

               If Not l_Failed;
                   Exec SQL Update SREERAMC1.ACCTMST
                            Set STATUS = 'C'
                            Where ACCTNUM = :l_FdAcct;
                   If SQLCode <> 0;
                       l_Failed = *On;
                   EndIf;
               EndIf;

               If Not l_Failed;
                   Exec SQL Update SREERAMC1.FDMST Set FDSTS = 'C'
                            Where FDACCT = :l_FdAcct;
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
                       Select :l_NextTxn, CURRENT_DATE, CURRENT_TIME,
                              :l_LinkedSB, 'CR', :l_Final,
                             // 'FDCLOSE' + %Char(l_NextTxn), BALANCE, 'S'
                              'FDCLOSE' || TRIM(CHAR(:l_NextTxn)), BALANCE, 'S'
                       From SREERAMC1.ACCTMST
                       Where ACCTNUM = :l_LinkedSB;

                   If SQLCode <> 0;
                       l_Failed = *On;
                   EndIf;
               EndIf;

               If l_Failed;
                   Exec SQL Rollback;
                   ERRMSG = 'FD closure failed. Please try again.';
               Else;
                   Exec SQL Commit;
                   l_FdSts = 'C';
                   STATUS  = 'C';
                   ERRMSG  = 'FD closed. Penalty: '
                              + %Trim(%EditC(l_Penalty: 'P'))
                              + '  Credited: '
                              + %Trim(%EditC(l_Final: 'P'));
                   l_Exit  = *On;
               EndIf;
           EndIf;
       EndDo;

       Close FDSCR;
       Return;
       End-Proc;
