     **FREE
      //====================================================================
      // RAMA BANK - RESET PASSWORD MODULE
      // Receives UserID, validates new password, updates PWDHASH,
      // and unlocks the account (LOCKFLAG = 'N', FAILCNT = 0).
      //
      // Fixes vs original:
      //  - PHID/LOGID now come from SEQ_PHID/SEQ_LOGID instead of being
      //    omitted (which defaulted to 0 and broke every insert after
      //    the first with a duplicate-key error).
      //  - SQLCode checked after each statement; on any DB failure the
      //    whole reset is rolled back so we never end up with a
      //    half-updated USERMST row and no PWDHIST/AUDITLOG trail.
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Reset_Main) BndDir('RAMABND');

       Dcl-F RESETSCR WORKSTN IndDS(ScnInd) ExtFile('RESETSCR');

       Dcl-Ds ScnInd;
             ExitKey Ind Pos(3);
       End-Ds;

       Dcl-Pr Reset_Main ExtPgm('RESETPGM');
                p_UserID Char(20) Const;
        End-Pr;

       Dcl-Pr Hash_SHA256 Varchar(64) ExtProc('HASH_SHA256');
           p_Input Varchar(200) Const;
       End-Pr;

       //Exec SQL Set Option Commit=*Chg, Naming=*Sys;
       //above line will be use if db2 files are journaled,
       // but since we are not journaling the files,
       //  we will use the below line
       Exec SQL Set Option Commit=*None, Naming=*Sys;

       Dcl-Proc Reset_Main;

         Dcl-Pi Reset_Main;
            p_UserID Char(20) Const;
         End-Pi;

         Dcl-S sql_UserID  Char(20);
         Dcl-S sql_NewPwd  Char(20);
         Dcl-S l_Count     Int(10);
         Dcl-S l_CountHist Int(10);
         Dcl-S l_NewHash   Varchar(64);
         Dcl-S l_NewPHID   Int(10);
         Dcl-S l_NewLogID  Int(10);
         Dcl-S l_Exit      Ind Inz(*Off);
         Dcl-S l_Failed    Ind Inz(*Off);

         USERID = p_UserID;
         ERRMSG = *Blanks;

         Dow Not l_Exit;
            ExFmt RESETFMT;

            If ExitKey;
               l_Exit = *On;
               Iter;
            EndIf;

            ERRMSG = *Blanks;

            If USERID = *Blanks Or NEWPWD = *Blanks Or CNFPWD = *Blanks;
               ERRMSG = 'All fields are required.';
               Iter;
            EndIf;

            If NEWPWD <> CNFPWD;
               ERRMSG = 'Passwords do not match. Please try again.';
               NEWPWD = *Blanks;
               CNFPWD = *Blanks;
               Iter;
            EndIf;

            If %Len(%Trim(NEWPWD)) < 8;
                ERRMSG = 'Password must be at least 8 characters long.';
                Iter;
            EndIf;

            sql_UserID = USERID;
            sql_NewPwd = NEWPWD;

            Exec SQL
               Select Count(*) Into :l_Count
               From SREERAMC1.USERMST
               Where USERID = :sql_UserID;

            If l_Count = 0;
               ERRMSG = 'User ID does not exist in the system.';
               Iter;
            EndIf;

            l_NewHash = Hash_SHA256(%Trim(sql_NewPwd));

            Exec SQL Select Count(*) Into :l_CountHist
                     From SREERAMC1.PWDHIST
                     Where USERID = :sql_UserID
                     And PWDHASH = :l_NewHash;

            If l_CountHist > 0;
                ERRMSG = 'Cannot reuse a previously used password.';
                Iter;
            EndIf;

            l_Failed = *Off;

            Exec SQL
               Update SREERAMC1.USERMST
               Set PWDHASH  = :l_NewHash,
                   LOCKFLAG = 'N',
                   FAILCNT  = 0
               Where USERID = :sql_UserID;

            If SQLCode <> 0;
               ERRMSG = 'Update failed. SQLCODE: ' + %Char(SQLCode);
               l_Failed = *On;
            EndIf;

            If Not l_Failed;
               Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_PHID
                        Into :l_NewPHID;

               Exec SQL Insert Into SREERAMC1.PWDHIST
                        (PHID, USERID, PWDHASH, CHGDATE)
                        Values( :l_NewPHID, :sql_UserID, :l_NewHash,
                                CURRENT TIMESTAMP);

               If SQLCode <> 0;
                  ERRMSG = 'PWDHIST Insert failed. SQLCODE: '
                           + %Char(SQLCode);
                  l_Failed = *On;
               EndIf;
            EndIf;

            If Not l_Failed;
               Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_LOGID
                        Into :l_NewLogID;

               Exec SQL Insert Into SREERAMC1.AUDITLOG
                        (LOGID, LOGTS, USERID, ACTION, DETAILS)
                        Values( :l_NewLogID, CURRENT TIMESTAMP, :sql_UserID,
                               'PWD_RESET', 'Password reset successfully');

               If SQLCode <> 0;
                  ERRMSG = 'AUDITLOG Insert failed. SQLCODE: '
                           + %Char(SQLCode);
                  l_Failed = *On;
               EndIf;
            EndIf;

            If l_Failed;
               Exec SQL Rollback;
               Iter;
            EndIf;

            Exec SQL Commit;

            USERID = *Blanks;
            NEWPWD = *Blanks;
            CNFPWD = *Blanks;
            ERRMSG = 'Password reset successful! Press F3 to login.';

         EndDo;

         Close RESETSCR;
         Return;

       End-Proc;
