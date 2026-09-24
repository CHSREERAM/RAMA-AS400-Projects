     **FREE
         // ====================================================================
         // RAMA BANK - MINI STATEMENT (LAST 10 TRANSACTIONS)
         // No subfile, uses flattened arrays natively to bind to screen format
         // ====================================================================
         Ctl-Opt ActGrp(*NEW) Main(Mini_Main);

         Dcl-F MINISCR WORKSTN IndDS(ScnInd);

         // Added Prototype to prevent compiler warnings and fix Varchar crash
         Dcl-Pr Mini_Main ExtPgm('MINIPGM');
                p_CustID Char(20) Const;
         End-Pr;

         Dcl-Ds ScnInd;
                ExitKey   Ind Pos(3);
         End-Ds;

         // Define an array to hold SQL cursor results before binding
         Dcl-DS TxnArray Dim(10) Qualified;
         tDate Char(10);
         tTime Char(8);
         tType Char(2);
         tAmt  Char(15);
         tBal  Zoned(15:2);
         End-DS;

         Dcl-Proc Mini_Main;
           Dcl-Pi Mini_Main;
              p_CustID Char(20) Const;
           End-Pi;

         Dcl-S i Int(10);
         Dcl-S RowsFetched Int(10);
         Dcl-S l_Exit Ind Inz(*Off);
         Dcl-S l_AcctNum Varchar(20);

         // FIX 1: Temporary variables for the SQL Fetch
          Dcl-S sql_Date Char(10);
          Dcl-S sql_Time Char(8);
          Dcl-S sql_Type Char(2);
          Dcl-S sql_Amt  Char(15);
          Dcl-S sql_Bal  Zoned(15:2);

          Exec SQL Set Option Commit=*None, Naming=*Sys;

         // Initial load info
         Exec SQL Select ACCTNUM Into :l_AcctNum
                  From SREERAMC1.ACCTMST
                  Where CUSTID = :p_CustID
                  Fetch First 1 Row Only;

         If SQLCode <> 0;
            l_Exit = *On;
            ACCTNUM = 'No account found for this customer.';
            ExFmt MINIFMT;
            close MINISCR;
            Return;
         EndIf;

         ACCTNUM = 'XXXXXXXXXXXXXXXX'
                    + %Subst(l_AcctNum: %Len(%Trim(l_AcctNum)) - 3: 4);


             // Fetch 10 rows only for performance
            Exec SQL Declare MCur Cursor For
                 Select CHAR(TXNDATE), CHAR(TXNTIME), TXNTYPE,
                 CHAR(AMOUNT), BALAFTER
                 From SREERAMC1.TXNHIST
                 Where ACCTNUM = :l_AcctNum
                 Order By TXNDATE Desc, TXNTIME Desc
                 Fetch First 10 Rows Only;

             Dow Not l_Exit;

             Exec SQL Open MCur;

                     i = 1;
            Dow SQLCode = 0 And i <= 10;
                Exec SQL
                   Fetch MCur Into :sql_Date, :sql_Time, :sql_Type,
                                   :sql_Amt, :sql_Bal;

                If SQLCode <> 0;
                   Leave;
                EndIf;

              // Move fetched data into the array
                 TxnArray(i).tDate = sql_Date;
                 TxnArray(i).tTime = sql_Time;
                 TxnArray(i).tType = sql_Type;
                 TxnArray(i).tAmt  = sql_Amt;
                 TxnArray(i).tBal  = sql_Bal;

                 i += 1;
            EndDo;
               RowsFetched = i - 1;

           Exec SQL Close MCur;

         // Map arrays to DSPF variables (which are non-arrays due-
         // to fixed positioning
         If RowsFetched >= 1;
            DT1 = TxnArray(1).tDate;
            TM1 = TxnArray(1).tTime;
            TY1 = TxnArray(1).tType;
            AM1 = TxnArray(1).tAmt;
            BL1 = TxnArray(1).tBal;
         EndIf;
         If RowsFetched >= 2;
            DT2 = TxnArray(2).tDate;
            TM2 = TxnArray(2).tTime;
            TY2 = TxnArray(2).tType;
            AM2 = TxnArray(2).tAmt;
            BL2 = TxnArray(2).tBal;
         EndIf;
         If RowsFetched >= 3;
            DT3 = TxnArray(3).tDate;
            TM3 = TxnArray(3).tTime;
            TY3 = TxnArray(3).tType;
            AM3 = TxnArray(3).tAmt;
            BL3 = TxnArray(3).tBal;
         EndIf;
         If RowsFetched >= 4;
            DT4 = TxnArray(4).tDate;
            TM4 = TxnArray(4).tTime;
            TY4 = TxnArray(4).tType;
            AM4 = TxnArray(4).tAmt;
            BL4 = TxnArray(4).tBal;
         EndIf;
         If RowsFetched >= 5;
            DT5 = TxnArray(5).tDate;
            TM5 = TxnArray(5).tTime;
            TY5 = TxnArray(5).tType;
            AM5 = TxnArray(5).tAmt;
            BL5 = TxnArray(5).tBal;
         EndIf;
         If RowsFetched >= 6;
            DT6 = TxnArray(6).tDate;
            TM6 = TxnArray(6).tTime;
            TY6 = TxnArray(6).tType;
            AM6 = TxnArray(6).tAmt;
            BL6 = TxnArray(6).tBal;
         EndIf;
         If RowsFetched >= 7;
            DT7 = TxnArray(7).tDate;
            TM7 = TxnArray(7).tTime;
            TY7 = TxnArray(7).tType;
            AM7 = TxnArray(7).tAmt;
            BL7 = TxnArray(7).tBal;
         EndIf;
         If RowsFetched >= 8;
            DT8 = TxnArray(8).tDate;
            TM8 = TxnArray(8).tTime;
            TY8 = TxnArray(8).tType;
            AM8 = TxnArray(8).tAmt;
            BL8 = TxnArray(8).tBal;
         EndIf;
         If RowsFetched >= 9;
            DT9 = TxnArray(9).tDate;
            TM9 = TxnArray(9).tTime;
            TY9 = TxnArray(9).tType;
            AM9 = TxnArray(9).tAmt;
            BL9 = TxnArray(9).tBal;
         EndIf;
         If RowsFetched >= 10;
            DT10 = TxnArray(10).tDate;
            TM10 = TxnArray(10).tTime;
            TY10 = TxnArray(10).tType;
            AM10 = TxnArray(10).tAmt;
            BL10 = TxnArray(10).tBal;
         EndIf;

           ExFmt MINIFMT;

            If ExitKey; //*In03; // Exit
               l_Exit = *On;
               Iter;
            EndIf;
         EndDo;

          close MINISCR;
          Return;

         End-Proc;
