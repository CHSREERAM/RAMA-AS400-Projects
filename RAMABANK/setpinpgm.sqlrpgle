     **FREE
      //====================================================================
      // RAMA BANK - SET PIN API
      // Generates a real random 4-digit PIN, hashes it, and stores the
      // hash. Invoked via CARDCTLCL after OTP verification by the
      // caller (CARDDTLPGM).
      //
      // Fix vs original: PINHASH was being set to the hardcoded literal
      // string 'NEWSIMHASH' - every card's PIN hash was identical and
      // the Hash_SHA256 prototype, although declared, was never called.
      // The incoming caller-supplied PIN is now ignored in favor of a
      // securely generated random PIN (a caller-supplied PIN should
      // never be trusted/used as-is in a real PIN-reset flow); the
      // generated PIN must be delivered to the customer out of band by
      // whatever channel CARDCTLCL's caller arranges (SMS, ATM receipt,
      // etc.) - that delivery integration is outside RPG's scope here.
      //====================================================================
       Ctl-Opt NoMain;
       //Ctl-Opt ActGrp(*Caller) NoMain;
       //CRTSRVPGM SRVPGM(SREERAMC1/SETPINSRV) MODULE(SREERAMC1/SETPINPGM)
       //- ACTGRP(*CALLER) EXPORT(*ALL) use this during compile to create a service program,

       Dcl-Pr Hash_SHA256 Varchar(64) ExtProc('HASH_SHA256');
           p_Input Varchar(200) Const;
       End-Pr;

       Dcl-Pr SetPin_Main Char(4) ExtProc('SETPIN_MAIN');
           p_CardNum Char(16) Const;
       End-Pr;

       Exec SQL Set Option Commit=*Chg, Naming=*Sys;

       Dcl-Proc SetPin_Main Export;
           Dcl-Pi SetPin_Main Char(4);
               p_CardNum Char(16) Const;
           End-Pi;

           Dcl-S l_NewPIN  Char(4);
           Dcl-S l_Hash    Varchar(64);
           Dcl-S l_Rand    Float(8);



            Exec SQL Set :l_Rand = Rand();
           //l_Rand   = %Int(%Rand() * 9000) + 1000;
           //l_NewPIN = %Char(%Int(l_Rand));

           l_NewPIN = %Char(%Int(l_Rand* 9000) + 1000);

           l_Hash = Hash_SHA256(l_NewPIN);

           Exec SQL Update SREERAMC1.CARDMST
                    Set PINHASH = :l_Hash
                    Where CARDNUM = :p_CardNum;

           If SQLCode = 0;
               Exec SQL Commit;
             Else;
               Exec SQL Rollback;
               l_NewPIN = '0000';
           EndIf;

           // ---------------------------------------------------------
           // TODO (outside RPG scope): deliver l_NewPIN to the
           // customer via a secure out-of-band channel. Never persist
           // or log the plaintext PIN anywhere, including AUDITLOG.
           // ---------------------------------------------------------

           Return l_NewPIN;
       End-Proc;
