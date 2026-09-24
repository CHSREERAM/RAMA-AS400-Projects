**FREE
// ====================================================================
// RAMA BANK - BENEFICIARY MANAGEMENT
// Enforces 30-min cooling (STATUS='P' pending verification via batch
// later -> promoted to 'A' by BENEFCOOL, a new batch job). Verifies
// IFSC against lookup table. Soft-deletes existing records.
//
// Fix vs original: BENEFID (the unique key) was never assigned on
// insert, defaulting to 0 and causing a duplicate-key failure on
// every beneficiary added system-wide after the very first one.
// Now uses SEQ_BENEFID.
// ====================================================================
Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Benef_Main) BndDir('RAMABND');

Dcl-F BENEFSCR WORKSTN Sfile(BENSFL: RRN) IndDS(ScnInd);

Dcl-Ds ScnInd;
    ExitKey Ind Pos(3);
    AddKey  Ind Pos(6);
    SflClr    Ind Pos(42);
    SflDspCtl Ind Pos(41);
    SflDsp    Ind Pos(40);
    PendColor Ind Pos(80);
End-Ds;

Dcl-Pr Benef_Main ExtPgm('BENEFPGM');
    p_CustID Char(20) Const;
End-Pr;

Dcl-S RRN Int(10);

// SET OPTION must be the first SQL statement in the source member
Exec SQL Set Option Commit=*None, Naming=*Sys;

Dcl-Proc Benef_Main;
    Dcl-Pi Benef_Main;
        p_CustID Char(20) Const;
    End-Pi;

    Dcl-S l_Exit Ind Inz(*Off);
    Dcl-S l_Found Int(10);
    Dcl-S l_NextID Int(10);
    Dcl-S sql_CustID Char(20);

    sql_CustID = p_CustID;

    Exec SQL Declare BCur Cursor For
            Select BENEFNAME, BENEFACCT, BENEIFSC, STATUS
            From SREERAMC1.BENEFMST
            Where CUSTID = :sql_CustID And STATUS <> 'D'; //-- Hide soft deleted
     // in place of declare cursor in LoadSubfile to avoid SQL0104 error on fetch

    Dow Not l_Exit;
        ExSr LoadSubfile;
        CUSTID = p_CustID;
        ExFmt BENCTL;

        If ExitKey;
            l_Exit = *On;
            Iter;
        EndIf;

        If AddKey;
            ExFmt BENADD;
            If ExitKey;
              Iter;
            EndIf;

            ExSr AddBeneficiary;
        EndIf;

        ExSr DeleteBeneficiary; // Using Option '4' mapping

    EndDo;

    // ADD THIS LINE TO FIX RNF7534:closed explicitly in a non-cycle module.
    Close BENEFSCR;
    Return;

    BegSr LoadSubfile;
        SflClr = *On;
        Write BENCTL;
        SflClr = *Off;

        SflDspCtl = *On;
        SflDsp = *Off;
        RRN = 0;

        //Exec SQL Declare BCur Cursor For
        //    Select BENEFNAME, BENEFACCT, BENEIFSC, STATUS
        //    From SREERAMC1.BENEFMST
        //    Where CUSTID = :sql_CustID And STATUS <> 'D'; //-- Hide soft deleted
        // in place of declare cursor in LoadSubfile to avoid SQL0104 error on fetch

        Exec SQL Open BCur;

        Dow SQLCode = 0;
            Exec SQL Fetch BCur Into :BENNAME, :BENACCT, :BENIFSC, :STATUS;
            If SQLCode <> 0;
                Leave;
            EndIf;

            // Color pending differently
            If STATUS = 'P';
                PendColor = *On; // Red
            Else;
                PendColor = *Off; // Normal
            EndIf;

            OPT = '';
            RRN += 1;
            Write BENSFL;
        EndDo;

        Exec SQL Close BCur;

        If RRN > 0;
            SflDsp = *On;
        EndIf;
    EndSr;

    BegSr AddBeneficiary;
        ERRMSG = *Blanks;
        If NEWNAME = '' Or NEWACCT = '' Or NEWIFSC = '';
            ERRMSG = 'All fields are mandatory.';
            //Return;
            Leavesr;  // FIX: Exits only the subroutine so the user can see the error
        EndIf;

        // Verify IFSC
        Exec SQL Select COUNT(*) Into :l_Found
                 From SREERAMC1.IFSCLOOKUP
                 Where IFSC = :NEWIFSC;

        If l_Found = 0;
            ERRMSG = 'Invalid IFSC Code mapped. Not found in dictionary.';
            //Return;
            Leavesr;  // FIX: Exits only the subroutine so the user can see the error
        EndIf;

        // Set status 'P' and insert
        Exec SQL Values NEXT VALUE FOR SREERAMC1.SEQ_BENEFID Into :l_NextID;

        Exec SQL Insert Into SREERAMC1.BENEFMST(BENEFID, CUSTID, BENEFNAME,
                             BENEFACCT, BENEIFSC, STATUS, ADDTIME)
                 Values(:l_NextID, :sql_CustID, :NEWNAME, :NEWACCT, :NEWIFSC,
                        'P', CURRENT_TIMESTAMP);

        If SQLCode <> 0;
            ERRMSG = 'Add failed. SQLCODE: ' + %Char(SQLCode);
            //Return;
            Leavesr;  // FIX: Exits only the subroutine so the user can see the error
        EndIf;

        ERRMSG = 'Beneficiary added. Subject to 30 mins cooling period.';
        NEWNAME = '';
        NEWACCT = '';
        NEWIFSC = '';
    EndSr;

    BegSr DeleteBeneficiary;
        ReadC BENSFL;
        Dow Not %Eof(BENEFSCR);
            If OPT = '4'; // Delete
                Exec SQL Update SREERAMC1.BENEFMST Set STATUS = 'D'
                         Where CUSTID = :sql_CustID
                         And BENEFACCT = :BENACCT And BENEIFSC = :BENIFSC;
                OPT = '';
                Update BENSFL;
            EndIf;
            ReadC BENSFL;
        EndDo;
    EndSr;

End-Proc;
