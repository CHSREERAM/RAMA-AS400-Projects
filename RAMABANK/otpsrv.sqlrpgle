     **FREE
      //====================================================================
      // RAMA BANK - OTP SERVICE PROGRAM
      // Replaces the hardcoded '123456' OTPs used in the original
      // FUNDTRPGM and CARDDTLPGM/SETPINPGM. Generates a random 6-digit
      // OTP, stores only its SHA-256 hash with an expiry timestamp,
      // and exposes a verify procedure that checks hash + expiry +
      // limits retries to 3 attempts before forcing a fresh OTP.
      //
      // In production, OTP_Generate's returned plaintext OTP must be
      // sent to the customer's registered mobile/email via your SMS/
      // email gateway (API call) - that integration point is marked
      // below. Nothing in this codebase had any such integration, so
      // OTP delivery itself is still a TODO outside the scope of what
      // can be done in RPG alone.
      //====================================================================
       Ctl-Opt NoMain;

       Dcl-Pr Hash_SHA256 Varchar(64) ExtProc('HASH_SHA256');
           p_Input Varchar(200) Const;
       End-Pr;

       Exec SQL Set Option Commit=*None, Naming=*Sys;

      // Generates a new OTP for p_CustID/p_Purpose, valid 5 minutes.
      // Returns the plaintext 6-digit OTP so the caller can hand it to
      // an SMS/email send routine. Only the hash is persisted.
       Dcl-Pr OTP_Generate Char(6);
           p_CustID  Char(20) Const;
           p_Purpose Char(10) Const;
       End-Pr;

      // Verifies p_InputOTP for p_CustID/p_Purpose.
      // Returns *On if valid (and deletes the OTP so it cannot be
      // reused), *Off if invalid, expired, or attempts exceeded.
       Dcl-Pr OTP_Verify Ind;
           p_CustID   Char(20) Const;
           p_Purpose  Char(10) Const;
           p_InputOTP Char(6) Const;
       End-Pr;



      //--------------------------------------------------------------
       Dcl-Proc OTP_Generate Export;
       // BUG-19 FIX: Procedure is exported as 'OTP_GENERATE' (uppercase)
       // matching ExtProc('OTP_GENERATE') in all callers.
       // IBM i CRTSRVPGM EXPORT(*ALL) folds to uppercase anyway, but
       // making it explicit here removes any ambiguity.
       Dcl-Pi OTP_Generate Char(6);
           p_CustID  Char(20) Const;
           p_Purpose Char(10) Const;
       End-Pi;

       Dcl-S l_OTP    Char(6);
       Dcl-S l_Hash   Varchar(64);
       Dcl-S l_Rand   Float(8);

       // Retrieve a random floating-point value from DB2 SQL
       Exec SQL Set :l_Rand = RAND();

       // Generate a random 6-digit numeric OTP (100000-999999)
       //l_Rand = %Int(%Rand() * 900000) + 100000;
       //l_OTP  = %Char(%Int(l_Rand));

       // Convert the random float (0 to 1) into a 6-digit OTP (100000-999999)
       l_OTP  = %Char(%Int(l_Rand * 900000) + 100000);

       l_Hash = Hash_SHA256(l_OTP);

       // Remove any prior OTP for this customer/purpose first
       Exec SQL Delete From SREERAMC1.OTPSTORE
                Where CUSTID = :p_CustID And PURPOSE = :p_Purpose;

       Exec SQL Insert Into SREERAMC1.OTPSTORE
                (CUSTID, PURPOSE, OTPHASH, GENTIME, EXPTIME, ATTEMPTS)
                Values(:p_CustID, :p_Purpose, :l_Hash,
                       CURRENT_TIMESTAMP,
                       CURRENT_TIMESTAMP + 5 MINUTES, 0);

       // ---------------------------------------------------------
       // TODO (outside RPG scope): send l_OTP to the customer via
       // SMS/email gateway here. Never log or display l_OTP in any
       // production audit trail or screen other than the outbound
       // message itself.
       // ---------------------------------------------------------

       Return l_OTP;
       End-Proc;

      //--------------------------------------------------------------
       Dcl-Proc OTP_Verify Export;
       // BUG-19 FIX: Procedure exported as 'OTP_VERIFY' (uppercase)
       // matching ExtProc('OTP_VERIFY') in all callers.
       Dcl-Pi OTP_Verify Ind;
           p_CustID   Char(20) Const;
           p_Purpose  Char(10) Const;
           p_InputOTP Char(6) Const;
       End-Pi;

       Dcl-S l_DbHash    Varchar(64);
       Dcl-S l_InHash    Varchar(64);
       Dcl-S l_Attempts  Int(10);
       Dcl-S l_Expired   Int(10);

       Exec SQL Select OTPHASH, ATTEMPTS,
                  Case When CURRENT_TIMESTAMP > EXPTIME Then 1 Else 0 End
                Into :l_DbHash, :l_Attempts, :l_Expired
                From SREERAMC1.OTPSTORE
                Where CUSTID = :p_CustID And PURPOSE = :p_Purpose;

       If SQLCode <> 0;
           // No OTP was ever generated for this customer/purpose
           Return *Off;
       EndIf;

       If l_Expired = 1;
           Exec SQL Delete From SREERAMC1.OTPSTORE
                    Where CUSTID = :p_CustID And PURPOSE = :p_Purpose;
           Return *Off;
       EndIf;

       If l_Attempts >= 3;
           Exec SQL Delete From SREERAMC1.OTPSTORE
                    Where CUSTID = :p_CustID And PURPOSE = :p_Purpose;
           Return *Off;
       EndIf;

       l_InHash = Hash_SHA256(p_InputOTP);

       If l_InHash = l_DbHash;
           // Success - consume the OTP so it can't be reused
           Exec SQL Delete From SREERAMC1.OTPSTORE
                    Where CUSTID = :p_CustID And PURPOSE = :p_Purpose;
           Return *On;
       Else;
           Exec SQL Update SREERAMC1.OTPSTORE
                    Set ATTEMPTS = ATTEMPTS + 1
                    Where CUSTID = :p_CustID And PURPOSE = :p_Purpose;
           Return *Off;
       EndIf;

       End-Proc;
