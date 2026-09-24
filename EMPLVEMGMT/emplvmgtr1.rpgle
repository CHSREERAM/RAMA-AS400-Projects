     H DEBUG(*YES)
     H OPTION(*NODEBUGIO)
     FEMPMASTER IF A E           K DISK
     FEMPMTERL  UF   E           K DISK     RENAME(EMPREC:EMPRECL)
     F                                      PREFIX(W_)
     FADMINDASH CF   E             WORKSTN SFILE(ADMINRCD:RRN)
     DPGST            SDS
     DPGMNAME            *PROC
     DRRN              S              4S 0
     DLEMPID           S              4S 0
     DARR              S             40A    DIM(2) CTDATA
     DUPPER            S             26A   INZ('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
     DLOWER            S             26A   INZ('abcdefghijklmnopqrstuvwxyz')


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
           IF RRN>0;
           READC ADMINRCD;
           DOW NOT %EOF(ADMINDASH);
           SELECT;
           WHEN OPT=2;
           CLEAR OPT;
           UPDATE ADMINRCD;
           EXSR UPDTEMP;
           *IN07=*ON;
           WHEN OPT=4;
           CLEAR OPT;
           UPDATE ADMINRCD;
           EXSR DELTEEMP;
           *IN07=*ON;
           WHEN OPT=5;
           CLEAR OPT;
           UPDATE ADMINRCD;
           EXSR DISPLAYEMP;
           ENDSL;
           READC ADMINRCD;
           ENDDO;
           ENDIF;

         // F12 CANCEL
           IF *IN12= *ON;
           *IN12=*OFF;
           LEAVE;
           ENDIF;
           ENDDO;
           ENDSR;

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

           // To validate $EMPID1 is auto increment
           SETGT *HIVAL EMPMASTER;
           READP EMPMASTER;
           IF %EOF(EMPMASTER);
               EMPID  = 1;
           ELSE;
              $EMPID1=  EMPID+ 1;
           ENDIF;

           DOW *IN03=*OFF;
         //MSG=*BLANKS;    //FOR MSG ERROR

           EXFMT ADDEMP;

           // F4 PROMPT LOGIC for Gender
           IF *IN04 = *ON;
              IF P_FLD = '$EMPGND1';
                 EXSR PROMPT_GENDER;
              ENDIF;
              *IN04 = *OFF;
               ITER; // Go back to display the screen with the new value
           ENDIF;


           // TO FIX EMPTY RECORDS
           IF *IN03=*ON OR *IN12=*ON;
           *IN03=*OFF;
           *IN12=*OFF;
           LEAVE;
           ENDIF;

              MSG = *BLANKS;

         //To validate EMPNAM as characters only and no blanks
             IF %TRIM($EMPNAM1) = *BLANKS;
              MSG ='Name is required.';
              ITER;
             ENDIF;

             IF MSG = *BLANKS AND
                %CHECK(UPPER + LOWER + '-' : %TRIM($EMPNAM1)) <>0;
              MSG= 'Name must contain letter.';
              ITER;
             ENDIF;

           IF MSG = *BLANKS;
           EMPID=$EMPID1;
           CHAIN EMPID EMPMASTER;
           IF NOT %FOUND(EMPMASTER);
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
           WRITE EMPREC;
           MSG     =  ARR(1);
           ELSE;
           MSG     =  ARR(2);
           ENDIF;
           ENDIF;

         //F12 CANCEL
           IF *IN12=*ON;
           *IN12=*OFF;
           LEAVE;
           ENDIF;

         //F5 REFRESH
           IF *IN05 = *ON;
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
           ENDIF;

           ENDDO;
           *IN06=*OFF;
           ENDSR;

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





      //UPDTEMP
           BEGSR UPDTEMP;
           DOW *IN03=*OFF;
           MSG=*BLANKS;

           IF $EMPEMLP2 <> *BLANKS;
           $EMPEMLP2 = %XLATE(UPPER: LOWER: $EMPEMLP2);
           ENDIF;

           IF $EMPEMLO2 <> *BLANKS;
           $EMPEMLO2 = %XLATE(UPPER: LOWER: $EMPEMLO2);
           ENDIF;

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
           EXFMT UPDATEEMP;

           // RECORDS ADDITION
           W_EMPID    =  $EMPID2;
           CHAIN W_EMPID EMPMTERL;
           IF %FOUND(EMPMTERL);
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
           //
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













           //
           //
           //
           //
           //
           //
     **END-FREE
**CTDATA ARR
Record Updated Successfully.
Record Already Exists.
