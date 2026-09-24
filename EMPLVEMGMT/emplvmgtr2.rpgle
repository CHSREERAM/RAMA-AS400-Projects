     H DEBUG(*YES)
     H OPTION(*NODEBUGIO)
     FEMPMASTER IF A E           K DISK
     FADMINDASH CF   E             WORKSTN SFILE(ADMINRCD:RRN)
     DPGST            SDS
     DPGMNAME            *PROC
     DRRN              S              4S 0
     DARR              S             40A    DIM(2) CTDATA

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
           EMPID=$EMPID1;
           CHAIN EMPID EMPMASTER;
           IF NOT %FOUND(EMPMASTER);
           EMPID   = $EMPID1;
           EMPNAM  = $EMPNAM1;
           EMPADR1 = $EMPADR11;
           EMPPC   = $EMPPC1;
           EMPCITY = $EMPCITY1;
           EMPCTRY = $EMPCTRY1;
           EMPCON  = $EMPCON1;
           EMPEMG  = $EMPEMG1;
           EMPGND  = $EMPGND1;
           EMPDOB  = $EMPDOB1;
           EMPDOJ  = $EMPDOJ1;
           EMPEMLP = $EMPEMLP1;
           EMPEMLO = $EMPEMLO1;
           EMPTEAM = $EMPTEAM1;
           EMPPRJID= $EMPPRJID1;
           EMPMGRID= $EMPMGRID1;
           EMPROL  = $EMPROL1;
           EMPDES  = $EMPDES1;
           EMPSTS  = $EMPSTS1;
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
           //
           //
           //
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
