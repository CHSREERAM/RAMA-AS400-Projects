     **FREE
      //====================================================================
      // RAMA BANK - OTP VERIFICATION SCREEN PROGRAM
      // Replaces the old stub that always returned p_Valid = *On
      // regardless of any input. Now actually generates an OTP via
      // OTPSRV, displays OTPSCR, and verifies the entered code.
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(OtpVer_Main)
               BndDir('RAMABND');

       Dcl-F OTPSCR WORKSTN IndDS(ScnInd);

       Dcl-Ds ScnInd;
           CancelKey Ind Pos(3);
       End-Ds;

       Dcl-Pr OtpVer_Main ExtPgm('OTPVERPGM');
           p_CustID  Char(20) Const;
           p_Purpose Char(10) Const;
           p_Valid   Ind;
       End-Pr;

       Dcl-Pr OTP_Generate Char(6) ExtProc('OTP_GENERATE');
           p_CustID  Char(20) Const;
           p_Purpose Char(10) Const;
       End-Pr;

       Dcl-Pr OTP_Verify Ind ExtProc('OTP_VERIFY');
           p_CustID   Char(20) Const;
           p_Purpose  Char(10) Const;
           p_InputOTP Char(6) Const;
       End-Pr;

       Dcl-Proc OtpVer_Main;
       Dcl-Pi OtpVer_Main;
           p_CustID  Char(20) Const;
           p_Purpose Char(10) Const;
           p_Valid   Ind;
       End-Pi;

       Dcl-S l_Generated Char(6);
       Dcl-S l_Exit      Ind Inz(*Off);
       Dcl-S l_Tries     Int(10) Inz(0);

       p_Valid = *Off;

       l_Generated = OTP_Generate(p_CustID: p_Purpose);

       Dow Not l_Exit And l_Tries < 3;
           OTPERR = *Blanks;
           OTPINP = *Blanks;
           ExFmt OTPFMT;

           If CancelKey;
               p_Valid = *Off;
               l_Exit  = *On;
               Iter;
           EndIf;

           l_Tries += 1;

           If OTP_Verify(p_CustID: p_Purpose: OTPINP);
               p_Valid = *On;
               l_Exit  = *On;
           Else;
               OTPERR = 'Invalid or expired OTP. Try again.';
           EndIf;
       EndDo;

       Close OTPSCR;
       Return;
       End-Proc;
