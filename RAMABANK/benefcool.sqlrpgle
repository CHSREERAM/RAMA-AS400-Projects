     **FREE
      //====================================================================
      // RAMA BANK - BENEFICIARY COOLING PERIOD PROMOTER
      // New program. BENEFPGM set new beneficiaries to STATUS='P' with
      // a comment promising a "batch later" would promote them to 'A'
      // after 30 minutes, but no such batch job existed anywhere in
      // the original codebase, so beneficiaries could never actually
      // be paid (FUNDTRPGM requires STATUS='A' to allow a transfer).
      //
      // Intended to run every 5-10 minutes via job scheduler/SBMJOB
      // (see BENEFCOOLCL.CLLE).
      //====================================================================
       Ctl-Opt DftActGrp(*No) ActGrp(*NEW) Main(Cool_Main) BndDir('RAMABND');

       Dcl-Pr Cool_Main ExtPgm('BENEFCOOL');
       End-Pr;

       Exec SQL Set Option Commit=*Chg, Naming=*Sys;

       Dcl-Proc Cool_Main;

       Dcl-S l_Count Int(10);

       Exec SQL
           Update SREERAMC1.BENEFMST
           Set STATUS = 'A'
           Where STATUS = 'P'
             And ADDTIME <= (CURRENT_TIMESTAMP - 30 MINUTES);

       l_Count = SQLerrd(3);

       Exec SQL Commit;

       Return;
       End-Proc;
