     **FREE
      //====================================================================
      // RAMA BANK - CHANGE PASSWORD
      // Checks history (PWDHIST) to prevent reuse, validates strength,
      // forces re-login after update.
      //
      // This program was rewritten from scratch. The original source
      // had multiple Exec SQL statements truncated mid-line with no
      // terminating semicolon (would not compile), used BANKLIB instead
      // of SREERAMC1, never qualified the WHERE clause on the password
      // lookup, used an invalid table name (QSys2.qsqptab) to fetch a
      // hash value, never generated a PWDHIST key, and called LOGOUTCL
      // with invalid CALLP syntax on a string literal.
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(ChgPwd_Main)
               BndDir('RAMABND');

       Dcl-F CHGPWDSCR WORKSTN IndDS(ScnInd);

       Dcl-Ds ScnInd;
           ExitKey Ind Pos(3);
       End-Ds;

       Dcl-Pr ChgPwd_Main ExtPgm('CHGPWDPGM');
           p_UserID Char(20) Const;
       End-Pr;

       Dcl-Pr Hash_SHA256 Varchar(64) ExtProc('HASH_SHA256');
           p_Input Varchar(200) Const;
       End-Pr;

       Dcl-Pr Call_Logout ExtPgm('LOGOUTCL');
       End-Pr;

       Exec SQL Set Option Commit=*Chg, Naming=*Sys;

       Dcl-Proc ChgPwd_Main;
       Dcl-Pi ChgPwd_Main;
           p_UserID Char(20) Const;
       End-Pi;

       Dcl-S l_Exit      Ind Inz(*Off);
       Dcl-S l_Failed    Ind Inz(*Off);
       Dcl-S l_Count     Int(10);
       Dcl-S l_CurHash   Varchar(64);
       Dcl-S l_DbHash    Varchar(64);
       Dcl-S l_NewHash   Varchar(64);
       Dcl-S l_CountHist Int(10);
       Dcl-S l_NewPHID   Int(10);
       Dcl-S l_NewLogID  Int(10);
       Dcl-S sql_UserID  Char(20);

       sql_UserID = p_UserID;

       Dow Not l_Exit;
           CURPWD = *Blanks;
           NEWPWD = *Blanks;
           CNFPWD = *Blanks;
           PWDERR = *Blanks;
           ExFmt CHGPWD;

           If ExitKey;
               l_Exit = *On;
               Iter;
           EndIf;

           PWDERR = *Blanks;

           If CURPWD = *Blanks Or NEWPWD = *Blanks Or CNFPWD = *Blanks;
               PWDERR = 'All fields are required.';
               Iter;
           EndIf;

           If NEWPWD <> CNFPWD;
               PWDERR = 'New and Confirm passwords do not match.';
               Iter;
           EndIf;

           If %Len(%Trim(NEWPWD)) < 8;
               PWDERR = 'Password must be at least 8 characters long.';
               Iter;
           EndIf;

           If NEWPWD = CURPWD;
               PWDERR = 'New password must differ from current password.';
               Iter;
           EndIf;

           Exec SQL Select Count(*), Max(PWDHASH)
                    Into :l_Count, :l_DbHash
                    From SREERAMC1.USERMST
                    Where USERID = :sql_UserID;

           If l_Count = 0;
               PWDERR = 'User record not found.';
               Iter;
           EndIf;

           l_CurHash = Hash_SHA256(%Trim(CURPWD));

           If l_CurHash <> l_DbHash;
               PWDERR = 'Current password is incorrect.';
               Iter;
           EndIf;

           l_NewHash = Hash_SHA256(%Trim(NEWPWD));

           Exec SQL Select Count(*) Into :l_CountHist
                    From SREERAMC1.PWDHIST
                    Where USERID = :sql_UserID And PWDHASH = :l_NewHash;

           If l_CountHist > 0;
               PWDERR = 'Cannot reuse a previously used password.';
               Iter;
           EndIf;

           l_Failed = *Off;

           Exec SQL Update SREERAMC1.USERMST
                    Set PWDHASH = :l_NewHash, FAILCNT = 0, LOCKFLAG = 'N'
                    Where USERID = :sql_UserID;

           If SQLCode <> 0;
               PWDERR = 'Update failed. SQLCODE: ' + %Char(SQLCode);
               l_Failed = *On;
           EndIf;

           If Not l_Failed;
               Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_PHID
                        Into :l_NewPHID;

               Exec SQL Insert Into SREERAMC1.PWDHIST
                        (PHID, USERID, PWDHASH, CHGDATE)
                        Values(:l_NewPHID, :sql_UserID, :l_NewHash,
                               CURRENT TIMESTAMP);

               If SQLCode <> 0;
                   PWDERR = 'PWDHIST insert failed. SQLCODE: '
                            + %Char(SQLCode);
                   l_Failed = *On;
               EndIf;
           EndIf;

           If Not l_Failed;
               Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_LOGID
                        Into :l_NewLogID;

               Exec SQL Insert Into SREERAMC1.AUDITLOG
                        (LOGID, LOGTS, USERID, ACTION, DETAILS)
                        Values(:l_NewLogID, CURRENT TIMESTAMP, :sql_UserID,
                               'PWD_CHANGE', 'Password changed by user');

               If SQLCode <> 0;
                   PWDERR = 'AUDITLOG insert failed. SQLCODE: '
                            + %Char(SQLCode);
                   l_Failed = *On;
               EndIf;
           EndIf;

           If l_Failed;
               Exec SQL Rollback;
               Iter;
           EndIf;

           Exec SQL Commit;

           // Force re-login: clear the session and end this program;
           // the caller (PROFILEPGM/DASHPGM) will see control return
           // and the next screen action will require re-authentication
           // because SESSIONID has been cleared.
           Monitor;
               Call_Logout();
           On-Error;
           EndMon;

           l_Exit = *On;
       EndDo;

       Close CHGPWDSCR;
       Return;

       End-Proc;
