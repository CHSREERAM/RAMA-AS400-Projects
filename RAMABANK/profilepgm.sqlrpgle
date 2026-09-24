     **FREE
      //====================================================================
      // RAMA BANK - CUSTOMER PROFILE & KYC UPDATE
      // Shows current details, allows update requests for restricted
      // fields (ADDRESS, EMAIL, MOBILE) via the maker-checker queue.
      //
      // Rewritten. Original had:
      //  - "Select ... Into :CustRec" with a 6-column SELECT into a
      //    single DS host variable (invalid embedded SQL; must list each
      //    individual host var or qualify subfields).
      //  - REQID (the UPDATEREQ primary key) never generated/inserted.
      //  - OLDVAL column never captured (admin would have no before-value
      //    to compare against on the checker screen).
      //  - User could type any arbitrary field name (e.g. BALANCE) as
      //    the field to update; now restricted to an approved list.
      //  - BANKLIB instead of SREERAMC1.
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Prof_Main)
               BndDir('RAMABND');

       Dcl-F PROFSCR WORKSTN IndDS(ScnInd);

       Dcl-Ds ScnInd;
           ExitKey   Ind Pos(3);
           UpdtKey   Ind Pos(9);
           ChgPwdKey Ind Pos(6);
       End-Ds;

       Dcl-Pr Prof_Main ExtPgm('PROFILEPGM');
           p_CustID Char(20) Const;
       End-Pr;

       Dcl-Pr Call_ChgPwd ExtPgm('CHGPWDPGM');
           p_UserID Char(20) Const;
       End-Pr;

       Exec SQL Set Option Commit=*Chg, Naming=*Sys;

       Dcl-Proc Prof_Main;
       Dcl-Pi Prof_Main;
           p_CustID Char(20) Const;
       End-Pi;

       Dcl-S l_Exit    Ind Inz(*Off);
       Dcl-S l_Found   Int(10);
       Dcl-S l_Count   Int(10);
       Dcl-S l_NextReq Int(10);

       // Current customer field values (fetched for display + OLDVAL capture)
       Dcl-S l_FullName Char(60);
       Dcl-S l_Email    Char(50);
       Dcl-S l_Mobile   Char(15);
       Dcl-S l_Address  Char(100);
       Dcl-S l_KycSts   Char(1);
       Dcl-S l_OldVal   Char(100);

       Exec SQL Select FULLNAME, EMAIL, MOBILE, ADDRESS, KYCSTS
                Into :l_FullName, :l_Email, :l_Mobile, :l_Address,
                     :l_KycSts
                From SREERAMC1.CUSTMST
                Where CUSTID = :p_CustID;

       l_Found = 1;
       If SQLCode <> 0;
           l_Found = 0;
       EndIf;

       If l_Found = 1;
           NAME     = l_FullName;
           EMAIL    = l_Email;
           MOBILE   = l_Mobile;
           ADDRESS  = l_Address;
           //KYCSTS   = l_KycSts;  // Maps to CUSTMST.KYCSTS (fixed in PF)
       EndIf;

       Dow Not l_Exit;
           ERRMSG = *Blanks;
           ExFmt PROFFMT;

           If ExitKey;
               l_Exit = *On;
               Iter;
           EndIf;

           If ChgPwdKey;
               Monitor;
                   Call_ChgPwd(p_CustID);
               On-Error;
                   ERRMSG = 'Change password program unavailable.';
               EndMon;
               Iter;
           EndIf;

           If UpdtKey;
               If l_Found = 0;
                   ERRMSG = 'Customer record not found.';
                   Iter;
               EndIf;

               If %Trim(UPDFLD) = '' Or %Trim(UPDVAL) = '';
                   ERRMSG = 'Field name and new value are required.';
                   Iter;
               EndIf;

               // Restrict to safe, editable fields only
               Select;
                   When UPDFLD = 'ADDRESS';
                       l_OldVal = l_Address;
                   When UPDFLD = 'EMAIL';
                       l_OldVal = l_Email;
                   When UPDFLD = 'MOBILE';
                       l_OldVal = l_Mobile;
                   Other;
                       ERRMSG = 'Only ADDRESS, EMAIL, or MOBILE '
                                + 'may be updated.';
                       Iter;
               EndSl;

               // Check for an already-pending request for the same field
               Exec SQL Select COUNT(*) Into :l_Count
                        From SREERAMC1.UPDATEREQ
                        Where CUSTID = :p_CustID And FIELDNAME = :UPDFLD
                        And STATUS = 'P';

               If l_Count > 0;
                   ERRMSG = 'A pending request for ' + %Trim(UPDFLD)
                            + ' already exists. Please wait for approval.';
                   Iter;
               EndIf;

               Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_REQID
                        Into :l_NextReq;

               Exec SQL Insert Into SREERAMC1.UPDATEREQ
                        (REQID, CUSTID, FIELDNAME, OLDVAL, NEWVAL,
                         REQDATE, STATUS)
                        Values(:l_NextReq, :p_CustID, :UPDFLD, :l_OldVal,
                               :UPDVAL, CURRENT DATE, 'P');
                               // BUG-18 FIX: REQDATE is Date(L) not Timestamp(Z)
                               // Using CURRENT DATE not CURRENT TIMESTAMP

               If SQLCode = 0;
                   Exec SQL Commit;
                   ERRMSG = 'Update request submitted. Pending admin '
                            + 'approval.';
                   UPDFLD = '';
                   UPDVAL = '';
               Else;
                   Exec SQL Rollback;
                   ERRMSG = 'Request failed. SQLCODE: ' + %Char(SQLCode);
               EndIf;
           EndIf;
       EndDo;

       Close PROFSCR;
       Return;
       End-Proc;
