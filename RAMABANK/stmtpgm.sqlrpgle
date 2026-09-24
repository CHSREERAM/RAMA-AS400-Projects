     **FREE
        //====================================================================
        // RAMA BANK - TRANSACTION STATEMENT
        // Uses DSPF subfile pagination (PageUp/Down) with 15 records/page.
        // Color codes DR/CR based on indicators from Display File (50/51).
        //
        // Fix vs original: $ACCTNUM (the screen field) was never set from
        // the looked-up account number, so the cursor's WHERE ACCTNUM =
        // :$ACCTNUM always filtered on blanks and returned zero rows.
        // Now $ACCTNUM is populated immediately after lookup.
        // STMTFTR TO BE ADDED
        //====================================================================
            Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Stmt_Main)
                    BndDir('RAMABND');

            Dcl-Pr Stmt_Main ExtPgm('STMTPGM');
                   p_CustID Char(20) Const;
            End-Pr;

            Dcl-F STMTSCR WORKSTN Sfile(STMTSFL: RRN) IndDS(ScnInd);

            Dcl-Ds ScnInd;
                  ExitKey   Ind Pos(3);
                  SflDsp    Ind Pos(40);
                  SflDspCtl Ind Pos(41);
                  SflClr    Ind Pos(42);
                  ClrRED    Ind Pos(50);
                  ClrGRN    Ind Pos(51);
                  PrtStmt   Ind Pos(6);
                  PagSrtU   Ind Pos(7);
                  PagSrtD   Ind Pos(8);
            End-Ds;

           Dcl-Pr
                Call_Stmtprnt   ExtPgm('STMTPRT');
                p_CustID  Char(20) Const;
                p_AcctNum Char(20) Const;
                p_FrmDate Char(10) Const;
                p_ToDate  Char(10) Const;
                p_FltType Char(3) Const;
           End-Pr;

            Dcl-S RRN Int(10);
            Dcl-S PageStart Int(10);
            Dcl-S l_AcctNum Char(20);
            Dcl-S l_TxnDate Date;
            Dcl-S l_TxnTime Time;
            Dcl-S l_Amount  Packed(15:2);

            Exec SQL Set Option Commit=*None, Naming=*Sys;

         Dcl-Proc Stmt_Main;
            Dcl-Pi *N;
                  p_CustID Char(20) Const;
            End-Pi;

            Dcl-S l_Exit Ind Inz(*Off);

           Exec SQL
               Select ACCTNUM
               Into :l_AcctNum
               From SREERAMC1.ACCTMST
               Where CUSTID = :p_CustID
               Fetch First 1 Row Only;

            If SQLCode <> 0;
                $ERRMSG = 'No account found for this customer.';
                ExFmt STMTCTL;
                Close STMTSCR;
                Return;
            EndIf;

            $ACCTNUM = l_AcctNum;

               PageStart = 0;
               ExSr LoadSubfile;

            Dow Not l_Exit;
                ExFmt STMTCTL;

               If ExitKey;
                   l_Exit = *On;
                   Iter;
               EndIf;

               If PrtStmt;
                   Call_Stmtprnt(p_CustID : l_AcctNum : $FRMDATE :
                                 $TODATE : $FLTTYPE);
                   Iter;
               EndIf;

               If PagSrtU;
                  PageStart -= 15;
                 If PageStart < 0;
                    PageStart = 0;
                 EndIf;
                ExSr LoadSubfile;
                Iter;
               EndIf;

               If PagSrtD;
                  PageStart += 15;
                  ExSr LoadSubfile;
                  Iter;
               EndIf;

             PageStart = 0;
             ExSr LoadSubfile;
            EndDo;

            close STMTSCR;
             Return;

           BegSr LoadSubfile;
                SflClr = *On;
                Write STMTCTL;
                SflClr = *Off;
                SflDspCtl = *On;
                SflDsp = *Off;

                RRN = 0;

             Exec SQL
                  Declare StmtCur Cursor For
                  Select TXNDATE, TXNTIME, REFNUM, TXNTYPE,
                         AMOUNT, BALAFTER
                  From SREERAMC1.TXNHIST
                  Where ACCTNUM = :l_AcctNum
                  And (:$FRMDATE = '' OR TXNDATE >= DATE(:$FRMDATE))
                  And (:$TODATE = ''  OR TXNDATE <= DATE(:$TODATE))
                  And (:$FLTTYPE = '' OR :$FLTTYPE = 'ALL'
                       OR TXNTYPE = :$FLTTYPE)
                  Order By TXNDATE Desc, TXNTIME Desc
                  Offset :PageStart Rows
                  Fetch Next 15 Rows Only;

             Exec SQL Open StmtCur;

               Dow SQLCode = 0;
                  Exec SQL Fetch StmtCur
                   Into :l_TxnDate, :l_TxnTime, :$REFNUM, :$TYPE,
                        :l_Amount, :$BALAFTER;

                   If SQLCode <> 0;
                      Leave;
                   EndIf;

                   $TXNDATE = %Char(l_TxnDate: *ISO);
                   $TXNTIME = %Char(l_TxnTime);
                   $AMOUNT  = %Trim(%EditC(l_Amount: 'P'));

                 If $TYPE = 'DR';
                    ClrRED = *On;
                    ClrGRN = *Off;
                    Else;
                    ClrRED = *Off;
                    ClrGRN = *On;
                 EndIf;

                    RRN += 1;
                    Write STMTSFL;
               EndDo;

             Exec SQL Close StmtCur;

             If RRN > 0;
                SflDsp = *On;
               Else;
                $ERRMSG = 'No transactions found.';
             EndIf;
           EndSr;

         End-Proc;
