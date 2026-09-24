     **FREE
      // ====================================================================
      // RAMA BANK - HASHING SERVICE PROGRAM
      // ====================================================================
         Ctl-Opt NoMain;

      // --------------------------------------------------------------------
      // PROTOTYPES (Required for Exported Procedures)
      // In a real application, this Dcl-Pr block would be in a separate
      // source member (e.g., QRPGLESRC,HASH_PR) and included via /COPY.
      // --------------------------------------------------------------------
         Dcl-Pr Hash_SHA256 Varchar(64);
                p_Input Varchar(200) Const;
         End-Pr;

         // SET OPTION must be the first SQL statement
          Exec SQL Set Option Commit=*None, Naming=*Sys;

      // --------------------------------------------------------------------
      // PROCEDURE IMPLEMENTATION
      // --------------------------------------------------------------------
         Dcl-Proc Hash_SHA256 Export;
         Dcl-Pi Hash_SHA256 Varchar(64);
               p_Input Varchar(200) Const;
         End-Pi;

         Dcl-S l_Hash Varchar(64) Inz('');

         // 2 is the algorithm code for SHA-256 in the DB2 HASH function.
         // Using VALUES is faster than SELECT ... FROM a dummy table.
          Exec SQL
               Values( Hex(Hash(TRIM(:p_Input), 2)) )
             Into :l_Hash;

          // Optional: Check for SQL errors
         If SQLCode <> 0;
           Return ''; // Return blank if hashing fails
         EndIf;

           Return l_Hash;
         End-Proc;
