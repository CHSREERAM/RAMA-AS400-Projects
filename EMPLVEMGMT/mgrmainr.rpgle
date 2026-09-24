     H DEBUG(*YES) OPTION(*SRCSTMT:*NODEBUGIO)
     H DFTACTGRP(*NO) ACTGRP(*NEW)

     FMGRDASH   CF   E             WORKSTN SFILE(MVHLDY:RRN)
     FEMPMASTER IF   E           K DISK
     FHOLIDAYS  IF   E           K DISK
     FLOGIN     UF   E           K DISK

     D RRN             S              4S 0

     D W_MGRID         S              4S 0
     D W_ACTION        S              1A

     D MGRAPPROV       PR                  EXTPGM('MGRAPPROV')
     D PMGRID                         4S 0
     D pACTION                        1A

     D MGREMPDTR       PR                  EXTPGM('MGREMPDTR')
     D PMGRID                         4S 0

     //FREE

      //**** Main Dashboard Loop ***************************
           dow *in03 = *off;

           //MSG=*BLANKS;

           exfmt MGRMAIN;

           if *in03 = *on or *in12 = *on;
                *in03 = *off;
                *in12 = *off;
                leave;
           endif;

             // Validate Menu selection (1-10)
             MSG=*BLANKS;
           if $SELECT < 1 or $SELECT > 10;
                MSG = 'Invalid selection. Please enter a value ' +
                      'between 1 and 10.';
                iter; // Redisplay the screen
           endif;

            monitor;
                W_MGRID = %dec($USER : 4: 0);
            on-error;
                W_MGRID = 0;
            endmon;


           // Check Menu selection
               select;

                 when $SELECT = 1;
                       MGREMPDTR(W_MGRID);
                       $SELECT = 0;

                 when $SELECT = 2;
                       W_ACTION = 'L';
                       MGRAPPROV(W_MGRID : W_ACTION);
                       $SELECT = 0;

                 when $SELECT = 3;
                       W_ACTION = 'C';
                       MGRAPPROV(W_MGRID : W_ACTION);
                       $SELECT = 0;

                 when $SELECT = 8;
                       exsr Vhldymgr;
                       $SELECT = 0;

                 when $SELECT = 9;
                      exsr CHGPWDMGR;
                      $SELECT = 0;

                 when $SELECT = 10;
                      exsr SIGNOUTSR;
                      $SELECT = 0;

               endsl;
           enddo;

               *inlr = *on;

          //VHLDYMGR SR
           begsr Vhldymgr;
               exsr CLEARMD;
               exsr LOADMD;
               exsr PROCESSMD;
           endsr;



          //CLEARMD SR
               begsr CLEARMD;
                     RRN =0;
                    *in22=*on;         //SFLCLR ON
                    write MVHLDYCTL;
                    *in22=*off;        //SFLCLR OFF
               endsr;

           //LOADMD SR
                begsr LOADMD;
                      setll *loval HOLIDAYS;
                      read HOLIDAYS;
                      dow not %eof(HOLIDAYS);
                          $HDATE = HLDATE;
                          $HDAY = HLDAY;
                          $HRMRK = HLRMRK;
                          RRN = RRN + 1;
                          write MVHLDY;
                          read HOLIDAYS;
                      enddo;

                   //END OF FILE
                     if %eof(HOLIDAYS);
                        *in23 = *on;   // SFLEND ON
                      else;
                       *in23 = *off;  // SFLEND OFF
                     endif;
                endsr;


           //PROCESSMD SR
                 begsr PROCESSMD;
                     dow *in03= *off;
                     if *in08=*on;
                       exsr CLEARMD;
                       exsr LOADMD;
                       *in08 = *off;
                     endif;

                     exsr DISPLYMVH;


                         // F12 CANCEL
                           if *in12= *on;
                              *in12=*off;
                               leave;
                           endif;
                    enddo;
                  endsr;

                  //DISPLYMVH SR
               begsr DISPLYMVH;
                     *IN21=*ON;   //SFLDSPCTL ON
                  if RRN>0 ;
                     *IN20 = *ON; //SFLDSP ON
                   else;
                     *IN20 = *OFF; //SFLDSP OFF
                  endif;

                  write MVHFOOTER;
                  exfmt MVHLDYCTL;
               endsr;

         //*************** CHGPWDMGR SR ********************************
                begsr CHGPWDMGR;
                           MSG = *BLANKS;
                           $CURPWD = *BLANKS;
                           $NEWPWD = *BLANKS;
                           $NEWPWDV = *BLANKS;
                           $LOGEMPID = *ZEROS;

                     dow *in03 = *off;
                         exfmt CHGPWD;

                      // Always check function keys first
                         if *in12 = *on;
                            *in12 = *off;
                            leave;
                         endif;


                         // Validations
                         MSG = *BLANKS;

                  if $NEWPWD <> $NEWPWDV;
                     MSG = 'New Password and Confirm Password do not match';
                     iter;
                  endif;

                  if $CURPWD = $NEWPWD;
                     MSG = 'New Password should not match with old password';
                     iter;
                  endif;

                     //LOGEMPID = $LOGEMPID;
                     chain(N) $LOGEMPID LOGIN;
                     if not %found(LOGIN);
                        MSG = 'User ID not found';
                        iter;
                     endif;

                     if %trim(LOGPWD) <> %trim($CURPWD);
                          MSG = 'Current Password is incorrect';
                          iter;
                     endif;

                     if MSG = *BLANKS;
                           LOGEMPID = $LOGEMPID;
                           chain LOGEMPID LOGIN;
                           if %found(LOGIN);
                               LOGPWD = $NEWPWD;
                               update LOGINREC;
                               MSG = 'Password Changed Successfully';
                           endif;
                     endif;


                     enddo;

             endsr;
            //****************END OF CHGPWDMGR SR *********************

            //*******************  SIGNOUT SR  ************************
            begsr SIGNOUTSR;
                  exfmt SIGNOUT;
                  if *in10 = *on;
                     *in03 = *on;
                  endif;

                  *in10 = *off;
            endsr;

            //****************END OF SIGNOUT SR *********************
      //END-FREE
