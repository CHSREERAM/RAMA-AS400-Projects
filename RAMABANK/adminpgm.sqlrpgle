     **FREE
      //====================================================================
      // RAMA BANK - ADMIN PANEL
      // BUG-14 FIX: KYCSTS corrected (was KYC_STATUS in original PF but
      //             now CUSTMST.PF has been fixed to KYCSTS)
      //             PANNO corrected (was PAN in original PF but now
      //             CUSTMST.PF has been fixed to PANNO)
      // BUG-15 FIX: Dcl-S moved out of BegSr KycVerification to module level
      // BUG-16 FIX: Dcl-S moved out of BegSr MakerChecker to module level
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Admin_Main)
               BndDir('RAMABND');

       Dcl-F ADMINSCR WORKSTN Sfile(CUSTSFL : C_RRN)
                               Sfile(KYCSFL  : K_RRN)
                               Sfile(MCRSFL  : M_RRN)
                               IndDS(ScnInd);

       Dcl-Ds ScnInd;
           ExitKey   Ind Pos(3);
           SflClr    Ind Pos(42);
           SflDspCtl Ind Pos(41);
           SflDsp    Ind Pos(40);
       End-Ds;

       Dcl-Pr Admin_Main ExtPgm('ADMINPGM');
           p_UserID Char(20) Const;
       End-Pr;

       Exec SQL Set Option Commit=*Chg, Naming=*Sys;

       Dcl-S C_RRN Int(10);
       Dcl-S K_RRN Int(10);
       Dcl-S M_RRN Int(10);

       // BUG-15 FIX: Moved from inside BegSr KycVerification
       Dcl-S l_NewKyc  Char(1);
       Dcl-S l_NextLog Int(10);

       // BUG-16 FIX: Moved from inside BegSr MakerChecker
       Dcl-S l_ReqId    Int(10);
       Dcl-S l_SaveCust Char(20);
       Dcl-S l_SaveFld  Char(10);
       Dcl-S l_SaveNew  Char(100);
       Dcl-S l_NextLog2 Int(10);

       // Prototype for standard IBM i command execution program
       Dcl-Pr RunCmd ExtPgm('QCMDEXC');
           CmdStr  Char(3000) Const Options(*VarSize);
           CmdLen  Packed(15:5) Const;
       End-Pr;

       Dcl-Proc Admin_Main;
       Dcl-Pi Admin_Main;
           p_UserID Char(20) Const;
       End-Pi;

       Dcl-S l_Exit Ind Inz(*Off);
       Dcl-S cmd    Char(200);

       Dow Not l_Exit;
           ERRMSG  = *Blanks;
           MENUOPT = '';
           ExFmt ADMNMENU;

           If ExitKey;
               l_Exit = *On;
               Iter;
           EndIf;

           ERRMSG = *Blanks;

           Select;
               When MENUOPT = '1';
                   ExSr CustomerSearch;
               When MENUOPT = '2';
                   ExSr KycVerification;
               When MENUOPT = '3';
                   ExSr MakerChecker;
               When MENUOPT = '4';
                   ExSr ScheduleReport;
               Other;
                   ERRMSG = 'Invalid selection. Choose 1-4.';
           EndSl;
       EndDo;

       Close ADMINSCR;
       Return;

      //=================================================================
       BegSr CustomerSearch;
           SflClr = *On;
           Write CUSTCTL;
           SflClr = *Off;
           SflDspCtl = *On;
           SflDsp = *Off;
           C_RRN = 0;

           Exec SQL Declare CustSrchCur Cursor For
               Select C.CUSTID, C.FULLNAME, C.MOBILE, C.KYCSTS
               From SREERAMC1.CUSTMST C
               Where (:SRCHVAL = '' Or
                      C.CUSTID Like '%' CONCAT :SRCHVAL CONCAT '%'
                      Or UPPER(C.FULLNAME) Like
                         '%' CONCAT UPPER(:SRCHVAL) CONCAT '%')
               Order By C.CUSTID Asc
               Fetch First 50 Rows Only;

           Exec SQL Open CustSrchCur;

           Dow SQLCode = 0;
               Exec SQL Fetch CustSrchCur
                        Into :C_CUSTID, :C_NAME, :C_MOBILE, :C_KYC;
               If SQLCode <> 0;
                   Leave;
               EndIf;
               C_RRN += 1;
               Write CUSTSFL;
           EndDo;

           Exec SQL Close CustSrchCur;

           If C_RRN > 0;
               SflDsp = *On;
           Else;
               ERRMSG = 'No customers found matching the search.';
           EndIf;

           Write CUSTFTR;
           ExFmt CUSTCTL;
       EndSr;

      //=================================================================
       BegSr KycVerification;
           // BUG-14 FIX: KYCSTS and PANNO now match CUSTMST.PF
           SflClr = *On;
           Write KYCCTL;
           SflClr = *Off;
           SflDspCtl = *On;
           SflDsp = *Off;
           K_RRN = 0;

           Exec SQL Declare KycCur Cursor For
               Select CUSTID, FULLNAME, PANNO, KYCSTS
               From SREERAMC1.CUSTMST
               Where KYCSTS = 'P'
               Order By CUSTID Asc
               Fetch First 50 Rows Only;

           Exec SQL Open KycCur;

           Dow SQLCode = 0;
               Exec SQL Fetch KycCur
                        Into :K_CUSTID, :K_NAME, :K_PAN, :K_KYC;
               If SQLCode <> 0;
                   Leave;
               EndIf;
               K_RRN += 1;
               Write KYCSFL;
           EndDo;

           Exec SQL Close KycCur;

           If K_RRN > 0;
               SflDsp = *On;
           Else;
               ERRMSG = 'No pending KYC verifications.';
               ExFmt KYCCTL;
               Return;
           EndIf;

           Write KYCFTR;
           ExFmt KYCCTL;

           // BUG-15 FIX: l_NewKyc and l_NextLog declared at module level now
           ReadC KYCSFL;
           Dow Not %Eof(ADMINSCR);
               Select;
                   When K_SEL = 'A';
                       l_NewKyc = 'Y';
                   When K_SEL = 'R';
                       l_NewKyc = 'R';
                   Other;
                       ReadC KYCSFL;
                       Iter;
               EndSl;

               // BUG-14 FIX: Update KYCSTS (correct column name)
               Exec SQL Update SREERAMC1.CUSTMST
                        Set KYCSTS = :l_NewKyc
                        Where CUSTID = :K_CUSTID;

               If SQLCode = 0;
                   Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_LOGID
                            Into :l_NextLog;

                   Exec SQL Insert Into SREERAMC1.AUDITLOG
                            (LOGID, LOGTS, USERID, ACTION, DETAILS)
                            Values(:l_NextLog, CURRENT TIMESTAMP, :p_UserID,
                                   'KYC_UPDATE',
                                   'CustID ' || Trim(:K_CUSTID) ||
                                   ' KYC set to ' || :l_NewKyc);
               EndIf;

               K_SEL = '';
               Update KYCSFL;
               ReadC KYCSFL;
           EndDo;

           Exec SQL Commit;
           ERRMSG = 'KYC decisions applied.';
       EndSr;

      //=================================================================
       BegSr MakerChecker;
           // BUG-16 FIX: All Dcl-S now at module level
           SflClr = *On;
           Write MCRCTL;
           SflClr = *Off;
           SflDspCtl = *On;
           SflDsp = *Off;
           M_RRN = 0;

           Exec SQL Declare McrCur Cursor For
               Select CUSTID, FIELDNAME, OLDVAL, NEWVAL, REQID
               From SREERAMC1.UPDATEREQ
               Where STATUS = 'P'
               Order By REQDATE Asc
               Fetch First 50 Rows Only;

           Exec SQL Open McrCur;

           Dow SQLCode = 0;
               Exec SQL Fetch McrCur
                        Into :M_CUSTID, :M_FIELD, :M_OLDVAL, :M_NEWVAL,
                             :l_ReqId;
               If SQLCode <> 0;
                   Leave;
               EndIf;
               M_SEL = '';
               M_RRN += 1;
               Write MCRSFL;
           EndDo;

           Exec SQL Close McrCur;

           If M_RRN > 0;
               SflDsp = *On;
           Else;
               ERRMSG = 'No pending update requests.';
               ExFmt MCRCTL;
               Return;
           EndIf;

              Write MCRFTR;
           ExFmt MCRCTL;

           ReadC MCRSFL;
           Dow Not %Eof(ADMINSCR);
               If M_SEL = 'A' Or M_SEL = 'R';
                   l_SaveCust = M_CUSTID;
                   l_SaveFld  = M_FIELD;
                   l_SaveNew  = M_NEWVAL;

                   If M_SEL = 'A';
                       Select;
                           When M_FIELD = 'ADDRESS';
                               Exec SQL Update SREERAMC1.CUSTMST
                                        Set ADDRESS = :l_SaveNew
                                        Where CUSTID = :l_SaveCust;
                           When M_FIELD = 'EMAIL';
                               Exec SQL Update SREERAMC1.CUSTMST
                                        Set EMAIL = :l_SaveNew
                                        Where CUSTID = :l_SaveCust;
                           When M_FIELD = 'MOBILE';
                               Exec SQL Update SREERAMC1.CUSTMST
                                        Set MOBILE = :l_SaveNew
                                        Where CUSTID = :l_SaveCust;
                           Other;
                               M_SEL = 'R';
                       EndSl;

                       Exec SQL Update SREERAMC1.UPDATEREQ
                                Set STATUS = 'A'
                                Where CUSTID = :l_SaveCust
                                And FIELDNAME = :l_SaveFld
                                And STATUS = 'P';
                   Else;
                       Exec SQL Update SREERAMC1.UPDATEREQ
                                Set STATUS = 'R'
                                Where CUSTID = :l_SaveCust
                                And FIELDNAME = :l_SaveFld
                                And STATUS = 'P';
                   EndIf;

                   Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_LOGID
                            Into :l_NextLog2;

                   Exec SQL Insert Into SREERAMC1.AUDITLOG
                            (LOGID, LOGTS, USERID, ACTION, DETAILS)
                            Values(:l_NextLog2, CURRENT TIMESTAMP,
                                   :p_UserID, 'MCR_' || :M_SEL,
                                   'CustID ' || Trim(:l_SaveCust) ||
                                   ' field ' || Trim(:l_SaveFld));

                   M_SEL = '';
                   Update MCRSFL;
               EndIf;
               ReadC MCRSFL;
           EndDo;

           Exec SQL Commit;
           ERRMSG = 'Maker-Checker decisions applied.';
       EndSr;

      //=================================================================
       BegSr ScheduleReport;
           Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_LOGID
                    Into :l_NextLog;

           Exec SQL Insert Into SREERAMC1.AUDITLOG
                    (LOGID, LOGTS, USERID, ACTION, DETAILS)
                    Values(:l_NextLog, CURRENT TIMESTAMP, :p_UserID,
                           'RPTSUBMIT', 'Batch report submitted by admin');

           Exec SQL Commit;

           //Exec CL('SBMJOB CMD(CALL PGM(SREERAMC1/RPTPGM)) '
           //        'JOBQ(QBATCH) JOBNAME(RAMARPT)');

           //Exec CL is not a valid keyword or command in standard RPGLE or SQLRPGLE.
           // The correct way to submit a job is to use the QCMDEXC prototype or a SQL procedure.

            // CORRECTED WAY using SQL procedure:
           //Exec SQL CALL QSYS2.QCMDEXC(
           //    'SBMJOB CMD(CALL PGM(SREERAMC1/RPTPGM))' ||
           //    'JOBQ(QBATCH) JOBNAME(RAMARPT)');

           // Call QCMDEXC using the prototype:
           cmd = 'SBMJOB CMD(CALL PGM(SREERAMC1/RPTPGM))' +
                 'JOBQ(QBATCH) JOBNAME(RAMARPT)';

           RunCmd(cmd : %Len(%Trim(cmd)));

           ERRMSG = 'Report job submitted to QBATCH.';
       EndSr;

       End-Proc;
