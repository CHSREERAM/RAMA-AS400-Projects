     H DEBUG(*YES) OPTION(*SRCSTMT:*NODEBUGIO)
     FMGREMPDT  CF   E             WORKSTN SFILE(EMPDET:RRN)
     FEMPMASTER IF   E           K DISK

     D wLoginmgrid     S              4s 0
     D RRN             S              4S 0



       /FREE
          if wLoginmgrid = 0;
             wLoginmgrid = 1001;
          endif;

          chain wLoginmgrid EMPMASTER;
          if %found(EMPMASTER);
             $MGRNAM = %subst(EMPNAM:1:15);
             $MGRTEAM = EMPTEAM;
            else;
             $MGRNAM = 'UNKNOWN';
          endif;

           exsr CLEAR;
           exsr LOAD;
           exsr PROCESS;

            *inlr = *on;

        // CLEAR SUBFILE
         begsr CLEAR;
           RRN = 0;
           *in27 = *on; //SFLCLR ON
           write EMPDETCTL;
           *in27 = *off; //SFLCLR off
         endsr;

        // LOAD SR
         begsr LOAD;
           setll *loval EMPMASTER;
           read EMPMASTER;

           dow not %eof(EMPMASTER);
               if EMPMGRID = wLoginmgrid;
                  $EMPIDED = EMPID;
                  $EMPNAMED = %subst(EMPNAM:1:20);
                  $EMPTEAMED = EMPTEAM;
                  $EMPDESED = EMPDES;

                  RRN = RRN + 1;

                  write EMPDET;
               endif;

              read EMPMASTER;

           enddo;

           //END OF FILE
               if %eof(EMPMASTER);
                  *in28 = *on;   // SFLEND ON
               else;
                  *in28 = *off;  // SFLEND OFF
               endif;
         endsr;

           // PROCESS SR

            begsr PROCESS;
                  dow *in03 = *off;

                   exsr DISPLAY;

                     // F12 CANCEL
                     if *in12= *on;
                        *in12=*off;
                        leave;
                     endif;
                  enddo;
            endsr;

            //DISPLAY SR
            begsr DISPLAY;
                  *in26 = *on; //SFLDSPCTL ON
                  if RRN > 0;
                     *in25 = *on;
                  else;
                     *in25 = *off;
                  endif;
                  write FOOTER;
                  exfmt EMPDETCTL;
            endsr;


       /END-FREE








