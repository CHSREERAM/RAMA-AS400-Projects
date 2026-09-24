     H DEBUG(*YES)
     H OPTION(*NODEBUGIO)
     FEMPMASTER IF A E           K DISK
     FEMPMTERL  UF   E           K DISK     RENAME(EMPREC:EMPRECL)
     F                                      PREFIX(W_)
     FADMINDASH CF   E             WORKSTN SFILE(ADMINRCD:RRN)
     D*PGST           SDS
     D*PGMNAME           *PROC
     D RRN             S              4S 0
     D*LEMPID          S              4S 0
     D posAt           S              5I 0
     D posDot          S              5I 0
     D d_dob           S               D
     D d_today         S               D
     D d_doj           S               D
     D AGE             S             10I 0
     D ARR             S             40A    DIM(2) CTDATA
     D UPPER           S             26A   INZ('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
     D LOWER           S             26A   INZ('abcdefghijklmnopqrstuvwxyz')
     D*
     D ALWD_CHAR       C                   CONST('ABCDEFGHIJKLMNOPQRSTUVXYZ+
     D                                     abcdefghijklmnopqrstuvwxyz_./')

     //FREE
        //ctl-opt dftactgrp(*no) option(*nodebugio) debug(*yes);

        //f EMPMASTER if  e      k disk;
        //f EMPMTREL  uf  e      k disk  rename(EMPREC:EMPRECL) prefix(W_);
        //f ADMINDASH cf  e        workstn sfile(ADMINRCD:RRN);

        //dcl-s RRN        int(4);
        //dcl-s ARR        char(40) dim(2) ctdata;
        //dcl-s UPPER      char(26) inz('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
        //dcl-s LOWER      char(26) inz('abcdefghijklmnopqrstuvwxyz');
        //dcl-c ALPHA  'ABCDEFGHIJKLMNOPQRSTUVWXYZ  abcdefghijklmnopqrstuvwxyz'

         //PGMNAME=PGMNAM;
           exsr CLEAR;
           exsr LOAD;
           exsr PROCESS;
           *inlr=*on;

      //CLEAR SR
           begsr CLEAR;
               RRN=0;
               *in27=*on;         //SFLCLR ON
               write ADMINCTL;
               *in27=*off;        //SFLCLR OFF
           endsr;

       //LOAD SR
           begsr LOAD;
               setll *loval EMPMASTER;
               read EMPMASTER;
               dow not %eof(EMPMASTER);
               $EMPID = EMPID;
               $EMPNAM = EMPNAM;
               $EMPCITY = EMPCITY;
               $EMPROL  = EMPROL;
               RRN= RRN+1;
               write ADMINRCD;
               read EMPMASTER;
               enddo;

           //END OF FILE
               if %eof(EMPMASTER);
                  *in28 = *on;   // SFLEND ON
               else;
                  *in28 = *off;  // SFLEND OFF
               endif;
           endsr;

       //PROCESS SR
        begsr PROCESS;
              dow *in03= *off;
                  if *in07=*on;
                     exsr CLEAR;
                     exsr LOAD;
                     *in07 = *off;
                  endif;

                  exsr DISPLY;

                  if *in06= *on;
                     exsr ADDEP;
                     *in07=*on;
                  endif;


      //Options
           if RRN>0;
              readc ADMINRCD;
              dow not %eof(ADMINDASH);
              select;
                   when OPT=2;
                   clear OPT;
                   update ADMINRCD;
                   exsr UPDTEMP;
                   *in07=*on;

                   when OPT=4;
                   clear OPT;
                   update ADMINRCD;
                   exsr DELTEEMP;
                   *in07=*on;

                   when OPT=5;
                   clear OPT;
                   update ADMINRCD;
                   exsr DISPLAYEMP;

              endsl;
              readc ADMINRCD;
              enddo;
           endif;

         // F12 CANCEL
           if *in12= *on;
           *in12=*off;
           leave;
           endif;
           enddo;
           endsr;

        //DISPLY SR
           BEGSR DISPLY;
           *IN26=*ON;   //SFLDSPCTL ON
           IF RRN>0 ;
           *IN25 = *ON; //SFLDSP ON
           ELSE;
           *IN25 = *OFF; //SFLDSP OFF
           ENDIF;

           WRITE FOOTERA;
           EXFMT ADMINCTL;
           ENDSR;

       //ADDEP SR
           BEGSR ADDEP;
           MSG=*BLANKS;    //FOR MSG ERROR

                exsr NEXTID;

           dow *in03=*off;

           exfmt ADDEMP;

           // F4 PROMPT LOGIC for Gender

           if *in04 = *on;
              *in41 = *off;
              *in42 = *off;
              *in43 = *off;
              *in44 = *off;
              *in45 = *off;

              select;
                   when P_FLD = '$EMPGND1';
                        exsr PROMPT_GENDER;
                        *in41 = *on;         //Keep cursor on at Gender

                   when P_FLD = '$EMPTEAM1';
                        exsr PROMPT_TEAM;
                        *in42 = *on;         //Keep cursor on at Team

                   when P_FLD = '$EMPSTS1';
                        exsr PROMPT_STATUS;
                        *in43 = *on;         //Keep cursor on at Status

                   when P_FLD = '$EMPROL1';
                        exsr PROMPT_ROLL;
                        *in44 = *on;         //Keep cursor on at Roll

                   when P_FLD = '$EMPPRJID1';
                        exsr PROMPT_PROJECT;
                        *in45 = *on;         //Keep cursor on at Project id
              endsl;

              *in04 = *off;
               iter; // Go back to display the screen with the new value
           endif;


           // TO FIX EMPTY RECORDS
           if *in03=*on or *in12=*on;
           *in03=*off;
           *in12=*off;
           leave;
           endif;

              MSG = *BLANKS;

         //To validate no blanks
             if %trim($EMPNAM1) = *BLANKS;
              MSG ='Name is required.';
              iter;
             endif;

         //Character Validations (Name, City,Country, Designation)
             if MSG = *BLANKS and
                %check(ALWD_CHAR : %trim($EMPNAM1)) <>0;
                // %CHECK(UPPER + LOWER + '-' : %TRIM($EMPNAM1)) <>0;
              MSG= 'Name must contain letter.';
              iter;
             endif;

             if MSG = *BLANKS and
                %check(ALWD_CHAR : %trim($EMPCITY1)) <>0;
              MSG= 'City must contain letter.';
              iter;
             endif;

             if MSG = *BLANKS and
                %check(ALWD_CHAR : %trim($EMPCTRY1)) <>0;
              MSG= 'Country must contain letter.';
              iter;
             endif;

             if MSG = *BLANKS AND
                %check(ALWD_CHAR : %trim($EMPDES1)) <>0;
              MSG= 'Designation must contain letter.';
              iter;
             endif;

             // Numeric Validation
             if MSG = *BLANKS and $EMPPC1 = 0;
                MSG = 'Pin code is required and must be numeric';
             endif;


             if MSG = *BLANKS and $EMPPC1 < 100000;
                MSG = 'Pin code must be 6 digits';
             endif;

             // Mobile no. validation

             if MSG = *BLANKS and $EMPCON1 < 1000000000;
                MSG = 'Contact no. must be 10 digit and cannot start with 0.';
             endif;

             if MSG = *BLANKS and $EMPEMG1 < 1000000000;
                MSG = 'Emg Contact must be 10 digit and cannot start with 0.';
             endif;

             // Official email vlaidation

             if MSG = *BLANKS and $EMPEMLO1 <> *BLANKS;
                posAt = %scan('§' : $EMPEMLO1);
                posDot = %scan('.' : $EMPEMLO1 : posAt + 1); // Look dot after §

                if posAt < 2 ; //Must have § and atleast 1 char before it
                   MSG = 'Office email is invalid(missing §).';

                elseif posDot = 0; // No dot found after §
                   MSG = 'Office email is invalid(missing . after §).';

                elseif %scan(' ' : %trim($EMPEMLO1)) >0;
                   MSG ='Office Email cannot contain spaces.';
                 endif;
              endif;


             // Personal email vlaidation

             if MSG = *BLANKS and $EMPEMLP1 <> *BLANKS;
                posAt = %scan('§' : $EMPEMLP1);
                posDot = %scan('.' : $EMPEMLP1 : posAt + 1); // Look dot after §

                if posAt < 2 ; //Must have § and atleast 1 char before it
                   MSG = 'Personal mail is invalid(missing §).';

                elseif posDot = 0; // No dot found after §
                   MSG = 'Personal email is invalid(missing . after §).';

                elseif %scan(' ' : %trim($EMPEMLO1)) >0;
                   MSG ='Personal Email cannot contain spaces.';
                 endif;
              endif;


            //Date of Birth Validation
            if MSG = *BLANKS;
               TEST(DE) *ISO $EMPDOB1;   // Check valid date format
               if %error;
                   MSG = 'Invalid DOB. Use YYYYMMDD format.';
               else;
                   d_dob = %DATE($EMPDOB1 : *ISO); // numeric to date format
                   d_today = %DATE();  // Get Current Date

                   if d_dob > d_today;
                      MSG = 'DOB Cannot be in the future.';
                   else;
                      AGE = %DIFF(d_today : d_dob : *YEARS);
                      if AGE <18;
                         MSG =  'Employee must be at least 18 years.';
                      endif;
                    endif;
                endif;
              endif;


          // Vlidate DOJ
          if MSG = *BLANKS;

             TEST(DE) *ISO $EMPDOJ1;
             if %error;
                MSG = 'Invalid DOJ. Use YYYYMMDD format.';
             else;
                d_doj = %DATE($EMPDOJ1 : *ISO);

                if d_doj < d_dob;
                   MSG = 'Joining Date must be after Date of Birth.';
                endif;
             endif;
           endif;


           if MSG = *BLANKS;   //PROCEED ONLY IF ALL PASSED
           EMPID=$EMPID1;
           chain EMPID EMPMASTER;
           if not %found(EMPMASTER);
           EMPID     = $EMPID1;
           EMPNAM    = $EMPNAM1;
           EMPADR1   = $EMPADR11;
           EMPPC     = $EMPPC1;
           EMPCITY   = $EMPCITY1;
           EMPCTRY   = $EMPCTRY1;
           EMPCON    = $EMPCON1;
           EMPEMG    = $EMPEMG1;
           EMPGND    = $EMPGND1;
           EMPDOB    = $EMPDOB1;
           EMPDOJ    = $EMPDOJ1;
           EMPEMLP   = $EMPEMLP1;    //%XLATE(UPPER: LOWER: $EMPEMLP1);
           EMPEMLO   = $EMPEMLO1;    //%XLATE(UPPER: LOWER: $EMPEMLO1);
           EMPTEAM   = $EMPTEAM1;
           EMPPRJID  = $EMPPRJID1;
           EMPMGRID  = $EMPMGRID1;
           EMPROL    = $EMPROL1;
           EMPDES    = $EMPDES1;
           EMPSTS    = $EMPSTS1;
           write EMPREC;
           MSG     =  ARR(1);
           else;
           MSG     =  ARR(2);
           endif;
           endif;

         //F12 CANCEL
           if *IN12=*ON;
           *IN12=*OFF;
           leave;
           endif;

         //F5 REFRESH
           if *IN05 = *ON;
         //$EMPID1   = *ZEROS;
           $EMPNAM1  = *BLANKS;
           $EMPADR11 = *BLANKS;
           $EMPPC1   = *ZEROS;
           $EMPCITY1 = *BLANKS;
           $EMPCTRY1 = *BLANKS;
           $EMPCON1  = *ZEROS;
           $EMPEMG1  = *ZEROS;
           $EMPGND1  = *BLANKS;
           $EMPDOB1  = *ZEROS;
           $EMPDOJ1  = *ZEROS;
           $EMPEMLP1 = *BLANKS;
           $EMPEMLO1 = *BLANKS;
           $EMPTEAM1 = *BLANKS;
           $EMPPRJID1= *BLANKS;
           $EMPMGRID1= *ZEROS;
           $EMPROL1  = *BLANKS;
           $EMPDES1  = *BLANKS;
           $EMPSTS1  = *BLANKS;
           MSG       = *BLANKS;
           exsr NEXTID;
           endif;

           enddo;
           *IN06=*OFF;
           endsr;

           // NEXTID      // To validate $EMPID1 is auto increment
           begsr NEXTID;
                 setgt *hival EMPMASTER;
                 readp EMPMASTER;
                 if %eof(EMPMASTER);
                     EMPID  = 1;
                 else;
                    $EMPID1=  EMPID+ 1;
                 endif;
           endsr;

          // Subroutine for Prompting
                 BEGSR PROMPT_GENDER;
                    // You could call a window here, but for simplicity:
                    // Toggle logic or a simple selection:
                    SELECT;
                    WHEN $EMPGND1 = *BLANKS;
                       $EMPGND1 = 'M';
                       MSG = 'Selected: Male (Press F4 to change)';
                    WHEN $EMPGND1 = 'M';
                       $EMPGND1 = 'F';
                       MSG = 'Selected: Female (Press F4 to change)';
                    OTHER;
                       $EMPGND1 = 'M';
                    ENDSL;
                 ENDSR;


          // Subroutine for Prompting TEAM
                 begsr PROMPT_TEAM;
                    select;
                         when $EMPTEAM1= *BLANKS;
                            $EMPTEAM1= 'Development';
                            $EMPMGRID1 = 1000;
                            $EMPPRJID1 = 'DEV01';

                         when $EMPTEAM1= 'Development';
                            $EMPTEAM1= 'Marketing';
                            $EMPMGRID1 = 1002;
                            $EMPPRJID1 = 'MKTG01';

                         when $EMPTEAM1= 'Marketing';
                            $EMPTEAM1= 'Sales';
                            $EMPMGRID1 = 1001;
                            $EMPPRJID1 = 'PROJ01';

                         when $EMPTEAM1= 'Sales';
                            $EMPTEAM1= 'Support';
                            $EMPMGRID1 = 1000;
                            $EMPPRJID1 = 'SUPP01';

                         when $EMPTEAM1= 'Support';
                            $EMPTEAM1= 'HR';
                            $EMPMGRID1 = 1000;
                            $EMPPRJID1 = 'HR00';

                         when $EMPTEAM1= 'HR';
                            $EMPTEAM1= 'IT_Admin';
                            $EMPMGRID1 = 1000;
                            $EMPPRJID1 = 'ITADM1';

                         other;
                            $EMPTEAM1= 'Development';
                            $EMPMGRID1 = 1000;

                     endsl;
                            MSG = 'Team Selected:' + $EMPTEAM1;
                 endsr;

          // PROMPT_PROJECT
              begsr PROMPT_PROJECT;
                    if $EMPTEAM1 = *BLANKS;
                       MSG = 'Please select Team first.';
                       LEAVESR;
                    endif;

                       //For Development Team

                 select;
                     when $EMPTEAM1 = 'Development';

                       select;
                            when $EMPPRJID1 = 'DEV01';
                                 $EMPPRJID1 = 'DEV02';
                            other;
                               $EMPPRJID1 = 'DEV01';
                        endsl;

                       //For Marketing Team

                     when $EMPTEAM1 = 'Marketing';
                       select;
                            when $EMPPRJID1 = 'MKTG01';
                                 $EMPPRJID1 = 'MKTG02';
                            when $EMPPRJID1 = 'MKTG02';
                                 $EMPPRJID1 = 'MKTG0';
                            other;
                               $EMPPRJID1 = 'MKTG01';
                        endsl;

                       //For Sales Team

                     when $EMPTEAM1 = 'Sales';
                       select;
                            when $EMPPRJID1 = 'PROJ01';
                                 $EMPPRJID1 = 'PROJ02';
                            when $EMPPRJID1 = 'PROJ02';
                                 $EMPPRJID1 = 'SALES0';
                            other;
                               $EMPPRJID1 = 'PROJ01';
                        endsl;
                 endsl;
              endsr;

          // Subroutine for Prompting STATUS
                 begsr PROMPT_STATUS;
                    select;
                         when $EMPSTS1= *BLANKS;
                            $EMPSTS1 = 'A';   //Active
                         when $EMPSTS1 = 'A';
                            $EMPSTS1 = 'I';   //Inactive
                         when $EMPSTS1 = 'I';
                            $EMPSTS1 = 'L';  //On Leave
                         other;
                            $EMPSTS1 = 'A';
                     endsl;
                            MSG = 'Status Selected:'+ $EMPSTS1;
                 endsr;


          // Subroutine for Prompting ROLL
                 begsr PROMPT_ROLL;
                    select;
                         when $EMPROL1= *BLANKS;
                            $EMPROL1 = 'E';   //Executive
                         when $EMPROL1 = 'E';
                            $EMPROL1 = 'M';   //Manager
                         when $EMPROL1 = 'M';
                            $EMPROL1 = 'A';   //Admin
                         other;
                            $EMPROL1 = 'E';
                     endsl;
                            MSG = 'Roll Selected:' + $EMPROL1;
                 endsr;

      //UPDTEMP
           BEGSR UPDTEMP;

           MSG = *BLANKS;

           EMPID  = $EMPID;
           CHAIN EMPID EMPMASTER;
           IF %FOUND(EMPMASTER);
           $EMPID2    =  EMPID ;
           $EMPNAM2   =  EMPNAM ;
           $EMPADR12  =  EMPADR1 ;
           $EMPPC2    =  EMPPC ;
           $EMPCITY2  =  EMPCITY ;
           $EMPCTRY2  =  EMPCTRY ;
           $EMPCON2   =  EMPCON ;
           $EMPEMG2   =  EMPEMG ;
           $EMPGND2   =  EMPGND ;
           $EMPDOB2   =  EMPDOB ;
           $EMPDOJ2   =  EMPDOJ ;
           $EMPEMLP2  =  EMPEMLP ;
           $EMPEMLO2  =  EMPEMLO ;
           $EMPTEAM2  =  EMPTEAM ;
           $EMPPRJID2 =  EMPPRJID ;
           $EMPMGRID2 =  EMPMGRID ;
           $EMPROL2   =  EMPROL ;
           $EMPDES2   =  EMPDES ;
           $EMPSTS2   =  EMPSTS ;
           ENDIF;

           DOW *IN03=*OFF;
           EXFMT UPDATEEMP;
           MSG=*BLANKS;

        // RECORDS ADDITION

          //************* VALIDATIONS ********************

         //Character Validations (Name, City,Country, Designation)

             if MSG = *BLANKS and
                %check(ALWD_CHAR : %trim($EMPCITY2)) <>0;
                MSG= 'City must contain letter.';
                iter;
             endif;

             if MSG = *BLANKS and
                %check(ALWD_CHAR : %trim($EMPCTRY2)) <>0;
                MSG= 'Country must contain letter.';
                iter;
             endif;

             if MSG = *BLANKS AND
                %check(ALWD_CHAR : %trim($EMPDES2)) <>0;
                MSG= 'Designation must contain letter.';
                iter;
             endif;

             // Numeric Validation
             if MSG = *BLANKS and $EMPPC2 = 0;
                MSG = 'Pin code is required and must be numeric';
             endif;


             if MSG = *BLANKS and $EMPPC2 < 100000;
                MSG = 'Pin code must be 6 digits';
             endif;

             // Mobile no. validation

             if MSG = *BLANKS and $EMPCON2 < 1000000000;
                MSG = 'Contact no. must be 10 digit and cannot start with 0.';
             endif;

             if MSG = *BLANKS and $EMPEMG2 < 1000000000;
                MSG = 'Emg Contact must be 10 digit and cannot start with 0.';
             endif;


             // Official email vlaidation

             if MSG = *BLANKS and $EMPEMLO1 <> *BLANKS;
                posAt = %scan('§' : $EMPEMLO2);
                posDot = %scan('.' : $EMPEMLO2 : posAt + 1); // Look dot after §

                if posAt < 2 ; //Must have § and atleast 1 char before it
                   MSG = 'Office email is invalid(missing §).';

                elseif posDot = 0; // No dot found after §
                   MSG = 'Office email is invalid(missing . after §).';

                elseif %scan(' ' : %trim($EMPEMLO2)) >0;
                   MSG ='Office Email cannot contain spaces.';
                 endif;
              endif;


             // Personal email vlaidation

             if MSG = *BLANKS and $EMPEMLP2 <> *BLANKS;
                posAt = %scan('§' : $EMPEMLP2);
                posDot = %scan('.' : $EMPEMLP2 : posAt + 1); // Look dot after §

                if posAt < 2 ; //Must have § and atleast 1 char before it
                   MSG = 'Personal mail is invalid(missing §).';

                elseif posDot = 0; // No dot found after §
                   MSG = 'Personal email is invalid(missing . after §).';

                elseif %scan(' ' : %trim($EMPEMLO2)) >0;
                   MSG ='Personal Email cannot contain spaces.';
                 endif;
              endif;


            //Date of Birth Validation

            if MSG = *BLANKS;
                   d_dob = %DATE($EMPDOB2 : *ISO); // numeric to date format
                   d_today = %DATE();  // Get Current Date

                 //if d_dob > d_today;
                 //   MSG = 'DOB Cannot be in the future.';
                 //else;
                      AGE = %DIFF(d_today : d_dob : *YEARS);
                      if AGE <18;
                         MSG =  'Employee must be at least 18 years.';
                      endif;
                  //endif;
              endif;


          // Vlidate DOJ
          if MSG = *BLANKS;

             TEST(DE) *ISO $EMPDOJ2;
             if %error;
                MSG = 'Invalid DOJ. Use YYYYMMDD format.';
             else;
                d_doj = %DATE($EMPDOJ2 : *ISO);

                if d_doj < d_dob;
                   MSG = 'Joining Date must be after Date of Birth.';
                endif;
             endif;
           endif;


           //******* F4 PROMPT LOGIC ***********************

           if *in04 = *on;
              *in46 = *off;
              *in47 = *off;
              *in48 = *off;
              *in49 = *off;

              select;

                   when P_FLD = '$EMPTEAM2';
                        exsr PROMPT_TEAMU;
                        *in46 = *on;         //Keep cursor on at Team

                   when P_FLD = '$EMPSTS2';
                        exsr PROMPT_STATUSU;
                        *in47 = *on;         //Keep cursor on at Status

                   when P_FLD = '$EMPROL2';
                        exsr PROMPT_ROLLU;
                        *in48 = *on;         //Keep cursor on at Roll

                   when P_FLD = '$EMPPRJID2';
                        exsr PROMPT_PROJECTU;
                        *in49 = *on;         //Keep cursor on at Project id
              endsl;

              *in04 = *off;
               iter; // Go back to display the screen with the new value
           endif;


           if MSG = *BLANKS;   //PROCEED ONLY IF ALL PASSED
              W_EMPID    =  $EMPID2;
              CHAIN W_EMPID EMPMTERL;
              if %FOUND(EMPMTERL);
                  W_EMPID     = $EMPID2;
                  W_EMPNAM    = $EMPNAM2;
                  W_EMPADR1   = $EMPADR12;
                  W_EMPPC     = $EMPPC2;
                  W_EMPCITY   = $EMPCITY2;
                  W_EMPCTRY   = $EMPCTRY2;
                  W_EMPCON    = $EMPCON2;
                  W_EMPEMG    = $EMPEMG2;
                  W_EMPGND    = $EMPGND2;
                  W_EMPDOB    = $EMPDOB2;
                  W_EMPDOJ    = $EMPDOJ2;
                  W_EMPEMLP   = $EMPEMLP2;
                  W_EMPEMLO   = $EMPEMLO2;
                  W_EMPTEAM   = $EMPTEAM2;
                  W_EMPPRJID  = $EMPPRJID2;
                  W_EMPMGRID  = $EMPMGRID2;
                  W_EMPROL    = $EMPROL2;
                  W_EMPDES    = $EMPDES2;
                  W_EMPSTS    = $EMPSTS2;
                  UPDATE EMPRECL;
                  MSG = ARR(1);

                  // Refresh the main buffer (physical file)
                  EMPID = $EMPID2;
                  CHAIN EMPID EMPMASTER;

              ENDIF;
            ENDIF;

         //F12 CANCEL
           IF *IN12=*ON;
           *IN12=*OFF;
           LEAVE;
           ENDIF;

         //F5 REFRESH
           IF *IN05 = *ON;
           $EMPID2   = EMPID;
           $EMPNAM2  = EMPNAM;
           $EMPADR12 = EMPADR1;
           $EMPPC2   = EMPPC;
           $EMPCITY2 = EMPCITY;
           $EMPCTRY2 = EMPCTRY;
           $EMPCON2  = EMPCON;
           $EMPEMG2  = EMPEMG;
           $EMPGND2  = EMPGND;
           $EMPDOB2  = EMPDOB;
           $EMPDOJ2  = EMPDOJ;
           $EMPEMLP2 = EMPEMLP;
           $EMPEMLO2 = EMPEMLO;
           $EMPTEAM2 = EMPTEAM;
           $EMPPRJID2= EMPPRJID;
           $EMPMGRID2= EMPMGRID;
           $EMPROL2  = EMPROL;
           $EMPDES2  = EMPDES;
           $EMPSTS2  = EMPSTS;
           MSG       = *BLANKS;
           ENDIF;

           ENDDO;
           ENDSR;


          // Subroutine for Prompting TEAM
                 begsr PROMPT_TEAMU;
                    select;
                         when %TRIM($EMPTEAM2)= 'IT_Admin';
                            $EMPTEAM2= 'Development';
                            $EMPMGRID2 = 1000;
                            $EMPPRJID2 = 'DEV01';

                         when %TRIM($EMPTEAM2) =  'Development';
                            $EMPTEAM2= 'Marketing';
                            $EMPMGRID2 = 1002;
                            $EMPPRJID2 = 'MKTG01';

                         when %TRIM($EMPTEAM2) = 'Marketing';
                            $EMPTEAM2= 'Sales';
                            $EMPMGRID2 = 1001;
                            $EMPPRJID2 = 'PROJ01';

                         when %TRIM($EMPTEAM2) = 'Sales';
                            $EMPTEAM2= 'Support';
                            $EMPMGRID2 = 1000;
                            $EMPPRJID2 = 'SUPP01';

                         when %TRIM($EMPTEAM2) = 'Support';
                            $EMPTEAM2= 'HR';
                            $EMPMGRID2 = 1000;
                            $EMPPRJID2 = 'HR00';

                         when %TRIM($EMPTEAM2) = 'HR';
                            $EMPTEAM2= 'IT_Admin';
                            $EMPMGRID2 = 1000;
                            $EMPPRJID2 = 'ITADM1';

                         other;
                            $EMPTEAM2= 'Development';
                            $EMPMGRID2 = 1000;

                     endsl;
                            MSG = 'Team Selected:' + %TRIM($EMPTEAM2);
                 endsr;

          // PROMPT_PROJECT
              begsr PROMPT_PROJECTU;

                       //For Development Team

                 select;
                     when %TRIM($EMPTEAM2)= 'Development';

                       select;
                            when %TRIM($EMPPRJID2)= 'DEV01';
                                       $EMPPRJID2 = 'DEV02';
                            other;
                                 $EMPPRJID2 = 'DEV01';
                        endsl;

                       //For Marketing Team

                     when %TRIM($EMPTEAM2)= 'Marketing';
                       select;
                            when %TRIM($EMPPRJID2)= 'MKTG01';
                                 $EMPPRJID2 = 'MKTG02';
                            when %TRIM($EMPPRJID2)= 'MKTG02';
                                 $EMPPRJID2 = 'MKTG0';
                            other;
                               $EMPPRJID2 = 'MKTG01';
                        endsl;

                       //For Sales Team

                     when %TRIM($EMPTEAM2)= 'Sales';
                       select;
                            when %TRIM($EMPPRJID2)= 'PROJ01';
                                 $EMPPRJID2 = 'PROJ02';
                            when %TRIM($EMPPRJID2)= 'PROJ02';
                                 $EMPPRJID2 = 'SALES0';
                            other;
                               $EMPPRJID2 = 'PROJ01';
                        endsl;
                 endsl;
              endsr;

          // Subroutine for Prompting STATUS
                 begsr PROMPT_STATUSU;
                    select;
                         when %TRIM($EMPSTS2)='L';
                            $EMPSTS2 = 'A';   //Active
                         when %TRIM($EMPSTS2)= 'A';
                            $EMPSTS2 = 'I';   //Inactive
                         when %TRIM($EMPSTS2)= 'I';
                            $EMPSTS2 = 'L';  //On Leave
                         other;
                            $EMPSTS2 = 'A';
                     endsl;
                            MSG = 'Status Selected:'+ $EMPSTS2;
                 endsr;


          // Subroutine for Prompting ROLL
                 begsr PROMPT_ROLLU;
                    select;
                         when %TRIM($EMPROL2)='A';
                            $EMPROL2 = 'E';   //Executive
                         when %TRIM($EMPROL2)= 'E';
                            $EMPROL2 = 'M';   //Manager
                         when %TRIM($EMPROL2)= 'M';
                            $EMPROL2 = 'A';   //Admin
                         other;
                            $EMPROL2 = 'E';
                     endsl;
                            MSG = 'Roll Selected:' + $EMPROL2;
                 endsr;



       //DELTEEMP SR
             BEGSR DELTEEMP;
             W_EMPID = $EMPID;
             CHAIN W_EMPID EMPMTERL;
             IF %FOUND(EMPMTERL);
             DELETE EMPRECL;
             ENDIF;
             ENDSR;

       //DISPLAYEMP SR
             BEGSR DISPLAYEMP;
             DOW *IN03=*OFF;
             EMPID = $EMPID;
             CHAIN EMPID EMPMASTER;
             IF %FOUND(EMPMASTER);
             $EMPID3   = EMPID;
             $EMPNAM3  = EMPNAM;
             $EMPADR13 = EMPADR1;
             $EMPPC3   = EMPPC;
             $EMPCITY3 = EMPCITY;
             $EMPCTRY3 = EMPCTRY;
             $EMPCON3  = EMPCON;
             $EMPEMG3  = EMPEMG;
             $EMPGND3  = EMPGND;
             $EMPDOB3  = EMPDOB;
             $EMPDOJ3  = EMPDOJ;
             $EMPEMLP3 = EMPEMLP;
             $EMPEMLO3 = EMPEMLO;
             $EMPTEAM3 = EMPTEAM;
             $EMPPRJID3= EMPPRJID;
             $EMPMGRID3= EMPMGRID;
             $EMPROL3  = EMPROL;
             $EMPDES3  = EMPDES;
             $EMPSTS3  = EMPSTS;
             EXFMT VIEWEMP;
             ENDIF;

         //F12 CANCEL
           IF *IN12=*ON;
           *IN12=*OFF;
           LEAVE;
           ENDIF;

             ENDDO;
             ENDSR;



















     //END-FREE
**CTDATA ARR
Record Updated Successfully.
Record Already Exists.
