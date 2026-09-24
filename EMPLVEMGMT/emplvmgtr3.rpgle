     H DEBUG(*YES)
     H OPTION(*NODEBUGIO)
     FEMPMASTER IF A E           K DISK
     FEMPMTERL  UF   E           K DISK     RENAME(EMPREC:EMPRECL)
     F                                      PREFIX(W_)
     FADMINDASH CF   E             WORKSTN SFILE(ADMINRCD:RRN)
     DPGST            SDS
     DPGMNAME            *PROC
     DRRN              S              4S 0
     DARR              S             40A    DIM(2) CTDATA
     DUPPER            S             26A   INZ('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
     DLOWER            S             26A   INZ('abcdefghijklmnopqrstuvwxyz')

     //FREE
         //PGMNAME=PGMNAM;
           EXSR CLEAR;
           EXSR LOAD;
           EXSR PROCESS;
           *INLR=*ON;

      //CLEAR SR
           BEGSR CLEAR;
           RRN=0;
           *IN27=*ON;         //SFLCLR ON
           WRITE ADMINCTL;
           *IN27=*OFF;        //SFLCLR OFF
           ENDSR;

       //LOAD SR
           BEGSR LOAD;
           SETLL *LOVAL EMPMASTER;
           READ EMPMASTER;
           DOW NOT %EOF(EMPMASTER);
           $EMPID = EMPID;
           $EMPNAM = EMPNAM;
           $EMPCITY = EMPCITY;
           $EMPROL  = EMPROL;
           RRN= RRN+1;
           WRITE ADMINRCD;
           READ EMPMASTER;
           ENDDO;

           //END OF FILE
           IF %EOF(EMPMASTER);
           *IN28 = *ON;   // SFLEND ON
           ELSE;
           *IN28 = *OFF;  // SFLEND OFF
           ENDIF;
           ENDSR;

       //PROCESS SR
           BEGSR PROCESS;
           DOW *IN03= *OFF;
           IF *IN07=*ON;
           EXSR CLEAR;
           EXSR LOAD;
           *IN07 = *OFF;
           ENDIF;
           EXSR DISPLY;
           IF *IN06= *ON;
           EXSR ADDEP;
           *IN07=*ON;
           ENDIF;


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
           DOW *IN03=*OFF;
           MSG=*BLANKS;    //FOR MSG ERROR
           EXFMT ADDEMP;
           // TO FIX EMPTY RECORDS
           IF *IN03=*ON OR *IN12=*ON;
           *IN03=*OFF;
           *IN12=*OFF;
           LEAVE;
           ENDIF;

           IF $EMPEMLP1 <> *BLANKS;
           $EMPEMLP1 = %XLATE(UPPER: LOWER: $EMPEMLP1);
           ENDIF;

           IF $EMPEMLO1 <> *BLANKS;
           $EMPEMLO1 = %XLATE(UPPER: LOWER: $EMPEMLO1);
           ENDIF;

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
           EMPEMLP   = $EMPEMLP1;
           EMPEMLO   = $EMPEMLO1;
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

         //F12 CANCEL
           IF *IN12=*ON;
           *IN12=*OFF;
           LEAVE;
           ENDIF;

         //F5 REFRESH
           IF *IN05 = *ON;
           $EMPID1   = *ZEROS;
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
      //END-FREE
**CTDATA ARR
Record Updated Successfully.
Record Already Exists.
