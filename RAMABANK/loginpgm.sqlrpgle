     **FREE
      //====================================================================
      // RAMA BANK - LOGIN MODULE
      // Validates credentials, locks account after 3 failed attempts,
      // creates a session via SESSCTL, routes to dashboard.
      //
      // Note: To unlock an account, run the following SQL: in strsql
      // - or via ibm i acs run sql script
      //
      // UPDATE SREERAMC1.USERMST
      // SET LOCKFLAG = 'N',
      // FAILCNT = 0
      // WHERE USERID = 'ADMIN001';
      //
      // If you want to clear the lock on all accounts at once,
      // you can run: UPDATE SREERAMC1.USERMST SET LOCKFLAG = 'N',
      // FAILCNT = 0;
      //
      // Note: To reset a direct password, run the following SQL:
      // UPDATE SREERAMC1.USERMST
      // SET PWDHASH = HASH_SHA256('MyNewPassword123')
      // WHERE USERID = 'ADMIN001';

      // Fixes vs original:
      //  - Now calls Hash_SHA256 (HASHSRV) instead of duplicating the
      //    HASH() SQL call inline, so there is one single source of
      //    truth for the hashing algorithm.
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Login_Main)
               BndDir('RAMABND');

       Dcl-F LOGINSCR WORKSTN IndDS(ScnInd);

       Dcl-Ds ScnInd;
             ExitKey  Ind Pos(3);
             ResetKey Ind Pos(9);
       End-Ds;

       Exec SQL Set Option Commit=*None, Naming=*Sys;

       Dcl-Pr Login_Main ExtPgm('LOGINPGM');
       End-Pr;

       Dcl-Pr Hash_SHA256 Varchar(64) ExtProc('HASH_SHA256');
           p_Input Varchar(200) Const;
       End-Pr;

       Dcl-Pr Call_SessCtl ExtPgm('SESSCTL');
              p_UserID    Char(20) Const;
              p_SessionID Varchar(50) Const;
       End-Pr;

       Dcl-Pr Call_DashPgm ExtPgm('DASHPGM');
              p_UserID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_ResetPgm ExtPgm('RESETPGM');
              p_UserID Char(20) Const;
       End-Pr;

       Dcl-Proc Login_Main;

         Dcl-S sql_UserID   Char(20);
         Dcl-S sql_PwdHid   Char(20);

         Dcl-S  l_Exit       Ind Inz(*Off);
         Dcl-S  l_PwdHash    Varchar(64);
         Dcl-S  l_DbHash     Varchar(64);
         Dcl-S  l_LockFlag   Char(1);
         Dcl-S  l_FailCnt    Int(10);
         Dcl-S  l_SessionID  Varchar(50);

        Dow Not l_Exit;
         ExFmt LOGINFMT;

          If ExitKey;
             l_Exit = *On;
           Iter;
          EndIf;

          If ResetKey;
             Monitor;
                Call_ResetPgm(USERID);
             On-Error;
                ERRMSG = 'Reset program is currently unavailable.';
             EndMon;

            PWDHID = *Blanks;
             ERRMSG = 'If password was reset, please log in.';
             Iter;
          EndIf;

            ERRMSG = *Blanks;

          If USERID = *Blanks Or PWDHID = *Blanks;
           ERRMSG = 'User ID and Password are required.';
           Iter;
          EndIf;

           sql_UserID = USERID;
           sql_PwdHid = PWDHID;

          Exec SQL
            Select PWDHASH, LOCKFLAG, COALESCE(FAILCNT, 0)
            Into :l_DbHash, :l_LockFlag, :l_FailCnt
            From SREERAMC1.USERMST
            Where USERID = :sql_UserID;

          If SQLCode <> 0;
             ERRMSG = 'Invalid User ID or Password.';
             Iter;
          EndIf;

          If l_LockFlag = 'Y';
             ERRMSG = 'Account is locked. Please contact admin.';
             Iter;
          EndIf;

          l_PwdHash = Hash_SHA256(%Trim(sql_PwdHid));

          If l_PwdHash <> l_DbHash;
             l_FailCnt += 1;
            If l_FailCnt >= 3;
               Exec SQL Update SREERAMC1.USERMST Set LOCKFLAG = 'Y',
                        FAILCNT = :l_FailCnt Where USERID = :sql_UserID;
               ERRMSG = 'Account locked due to 3 failed attempts.';
             Else;
               Exec SQL Update SREERAMC1.USERMST Set FAILCNT = :l_FailCnt
                        Where USERID = :sql_UserID;
               ERRMSG = 'Invalid password. Attempts left: '
                        + %Char(3 - l_FailCnt);
            EndIf;
             Iter;

           Else;
           Exec SQL Update SREERAMC1.USERMST Set FAILCNT = 0
                    Where USERID = :sql_UserID;

           Exec SQL Values(QSYS2.GENERATE_UUID()) Into :l_SessionID;

           Exec SQL Update SREERAMC1.USERMST
                    Set SESSIONID = :l_SessionID
                    Where USERID = :sql_UserID;

           Monitor;
               Call_SessCtl(USERID: l_SessionID);
           On-Error;
           EndMon;

           Monitor;
             Call_DashPgm(USERID);
            On-Error;
           EndMon;

           USERID = *Blanks;
           PWDHID = *Blanks;
           ERRMSG = 'Successfully logged out.';
          EndIf;

        EndDo;

         Close LOGINSCR;
        Return;
       End-Proc;
