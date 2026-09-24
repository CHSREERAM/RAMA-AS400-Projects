**FREE
      //====================================================================
      // RAMA BANK - CARD MANAGEMENT
      // Fetches Card limits, toggles usage flags (Intl, Online, Cntls).
      // Integrates with SETPINPGM/CARDCTLCL for PIN reset, now gated
      // behind real OTP verification.
      //
      // Rewritten. Original had a SELECT truncated mid-column-list with
      // a duplicate INTO host variable (:DLYLMT used twice, silently
      // dropping USEDLIMIT), multiple truncated UPDATE/INSERT
      // statements, AUDITLOG inserts missing the LOGID key, BANKLIB
      // instead of SREERAMC1, and a fake PIN reset that always sent a
      // hardcoded '0000'/'MOCKHASH' with no OTP check at all.
      //====================================================================
      Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Card_Main) BndDir('RAMABND');

      // Global File Declarations
      Dcl-F CARDDTLSCR WORKSTN IndDS(ScnInd);

      // Global Indicator Data Structure
      Dcl-Ds ScnInd;
          ExitKey   Ind Pos(3);
          UpdateKey Ind Pos(9);
      End-Ds;

      // Global Prototypes
      Dcl-Pr Card_Main ExtPgm('CARDDTLPGM');
          p_CustID Char(20) Const;
      End-Pr;

      Dcl-Pr Call_OtpVer ExtPgm('OTPVERPGM');
          p_CustID  Char(20) Const;
          p_Purpose Char(10) Const;
          p_Valid   Ind;
      End-Pr;

      Dcl-Pr Call_CardCtl ExtPgm('CARDCTLCL');
          p_CardNum Char(16) Const;
          p_Action  Char(10) Const;
      End-Pr;

      // Prototype for internal subprocedure (replaces the broken subroutine)
      Dcl-Pr ChangeCardStatus;
          p_NewStatus Char(1)  Const;
          p_Action    Char(20) Const;
          p_Details   Char(60) Const;
          p_CardNum   Char(16) Const;
          p_CustID    Char(20) Const;
      End-Pr;

      Exec SQL Set Option Commit=*None, Naming=*Sys;

      //====================================================================
      // MAIN PROCEDURE
      //====================================================================
      Dcl-Proc Card_Main;
          Dcl-Pi Card_Main;
              p_CustID Char(20) Const;
          End-Pi;

          Dcl-S l_Exit     Ind Inz(*Off);
          Dcl-S l_Card     Char(16);
          Dcl-S l_OTPValid Ind Inz(*Off);
          Dcl-S l_Found    Int(10);

          Dcl-S Sql_AcctNum    Char(20);
          Dcl-S Sql_Status     Char(1);
          Dcl-S Sql_IntlFlag   Char(1);
          Dcl-S Sql_OnlnFlag   Char(1);
          Dcl-S Sql_CntlFlag   Char(1);
          Dcl-S Sql_DlyLimit   Packed(15:2);
          Dcl-S Sql_UsdLimit   Packed(15:2);

          // SQL Query to fetch database values
          Exec SQL Select C.CARDNUM, C.ACCTNUM, C.STATUS, C.INTL_FLAG,
                          C.ONLN_FLAG, C.CNTL_FLAG, L.DAILYLIMIT, L.USEDLIMIT
                   Into :l_Card, :Sql_AcctNum, :Sql_Status, :Sql_IntlFlag,
                        :Sql_OnlnFlag, :Sql_CntlFlag, :Sql_DlyLimit,
                        :Sql_UsdLimit
                   From SREERAMC1.CARDMST C
                   Join SREERAMC1.CRDLIMIT L On C.CARDNUM = L.CARDNUM
                   Where C.CUSTID = :p_CustID Fetch First 1 Row Only;

          l_Found = 1;
          If SQLCode <> 0;
              l_Found = 0;
          EndIf;

          // Map DB fields to Display Screen Formats
          If l_Found = 1;
              CARDNUM  = 'XXXX-XXXX-XXXX-' + %Subst(l_Card: 13: 4);
              ACCTNUM  = Sql_AcctNum;
              STATUS   = Sql_Status;
              INTLFLG  = Sql_IntlFlag;
              ONLNFLG  = Sql_OnlnFlag;
              CNTLFLG  = Sql_CntlFlag;
              DLYLMT   = Sql_DlyLimit;
          EndIf;

          Dow Not l_Exit;
              If l_Found = 0;
                  ERRMSG = 'No card found for this customer.';
                  ExFmt CARDFMT;
                  l_Exit = *On;
                  Iter;
              EndIf;

              ExFmt CARDFMT;

              If ExitKey;
                  l_Exit = *On;
                  Iter;
              EndIf;

              ERRMSG = *Blanks;

              // Process Updates
              If UpdateKey;
                  If STATUS = 'A';
                      Exec SQL Update SREERAMC1.CARDMST
                               Set INTL_FLAG = :INTLFLG, ONLN_FLAG = :ONLNFLG,
                                   CNTL_FLAG = :CNTLFLG
                               Where CARDNUM = :l_Card;

                      Exec SQL Update SREERAMC1.CRDLIMIT
                               Set DAILYLIMIT = :DLYLMT
                               Where CARDNUM = :l_Card;

                      If SQLCode = 0;
                          ERRMSG = 'Card settings updated successfully.';
                      Else;
                          ERRMSG = 'Update failed. SQLCODE: ' + %Char(SQLCode);
                      EndIf;
                  Else;
                      ERRMSG = 'Card is not Active. Settings cannot be updated.';
                  EndIf;
                  Iter;
              EndIf;

              // Process Custom Actions
              If ACTION <> '';
                  If ACTION = 'B';
                      ChangeCardStatus('B': 'CARD_BLOCK':
                       'Card blocked by customer': l_Card: p_CustID);
                      STATUS = 'B';
                      ERRMSG = 'Card blocked successfully.';

                  ElseIf ACTION = 'U';
                      ChangeCardStatus('A': 'CARD_UNBLOCK':
                       'Card unblocked by customer': l_Card: p_CustID);
                      STATUS = 'A';
                      ERRMSG = 'Card unblocked successfully.';

                  ElseIf ACTION = 'H';
                      ChangeCardStatus('H': 'CARD_HOTLIST':
                       'Card hotlisted permanently': l_Card: p_CustID);
                      STATUS = 'H';
                      ERRMSG = 'Card Hotlisted permanently. Order replacement.';

                  ElseIf ACTION = 'P';
                      Monitor;
                          Call_OtpVer(p_CustID: 'PINRESET': l_OTPValid);
                      On-Error;
                          l_OTPValid = *Off;
                      EndMon;

                      If l_OTPValid = *On;
                          Monitor;
                              Call_CardCtl(l_Card: '*UPDATEPIN');
                              ERRMSG = 'PIN reset successful. New PIN sent via secure channel.';
                          On-Error;
                              ERRMSG = 'PIN reset service unavailable.';
                          EndMon;
                      Else;
                          ERRMSG = 'OTP verification failed. PIN not reset.';
                      EndIf;
                  Else;
                      ERRMSG = 'Invalid action.';
                  EndIf;
                  ACTION = '';
              EndIf;

          EndDo;

          Close CARDDTLSCR;
          Return;
      End-Proc;

      //====================================================================
      // SUBPROCEDURE: ChangeCardStatus
      //====================================================================
      Dcl-Proc ChangeCardStatus;
          Dcl-Pi *N;
              p_NewStatus Char(1)  Const;
              p_Action    Char(20) Const;
              p_Details   Char(60) Const;
              p_CardNum   Char(16) Const;
              p_CustID    Char(20) Const;
          End-Pi;

          Dcl-S l_NextLog Int(10);

          Exec SQL Update SREERAMC1.CARDMST Set STATUS = :p_NewStatus
                   Where CARDNUM = :p_CardNum;

          Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_LOGID
                   Into :l_NextLog;

          Exec SQL Insert Into SREERAMC1.AUDITLOG
                   (LOGID, LOGTS, USERID, ACTION, DETAILS)
                   Values(:l_NextLog, CURRENT TIMESTAMP, :p_CustID,
                          :p_Action, :p_Details);
      End-Proc;
