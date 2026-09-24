     H DEBUG(*YES) OPTION(*SRCSTMT:*NODEBUGIO)
     FMGRTRANS  CF   E             WORKSTN SFILE(ARVLVE:RRN)
     F                                     SFILE(ARVCOMP:RRN1)
     F                                     SFILE(TEAMHIST:RRN2)
     FLEAVEPF   UF   E           K DISK    RENAME(LEAVEREC:LVEREC_U)
     FLEAVELF   UF   E           K DISK
     FLEAVEBAL  UF   E           K DISK
     FCOMPOFF   UF   E           K DISK    RENAME(COMPREC:COMPREC_U)
     FEMPMASTER IF   E           K DISK

     D RRN             S              4S 0
     D RRN1            S              4S 0
     D RRN2            S              4S 0
     D CURRENTMODE     S              1A    INZ('L')

     D P_MGRID         S              4S 0
     D P_MODE          S              1A

     C     *ENTRY        PLIST
     C                   PARM                    P_MGRID
     C                   PARM                    P_MODE


     //FREE

         if P_MODE <> *BLANKS;
            CURRENTMODE = P_MODE;
         endif;

         exsr LOAD_DATA;


         dow *in03 = *off;
           // MSG= *BLANKS;

            //Display Leave / Comp off Control
                   //if CURRENTMODE = 'L';
                   //   write ARLVFOOTER;
                   //   exfmt ARVLVECTL;
                   //   MSG= *BLANKS;
                   //else;
                   //   write ARLVFOOTER;
                   //   exfmt ARVCOMPCTL;
                   //   MSG= *BLANKS;
                   //endif;

            select;
              when CURRENTMODE = 'L';
                 write ARLVFOOTER;
                 exfmt ARVLVECTL;
              when CURRENTMODE = 'C';
                 write ARLVFOOTER;
                 exfmt ARVCOMPCTL;
              when CURRENTMODE = 'H';
                 write ARLVFOOTER;
                 exfmt TEAMHISTC;
            endsl;

              MSG= *BLANKS;


           // Key handling for F3, F12, F5, F10
            select;
              when *in03 = *on; // F3 EXIT
                 leave;

              when *in12 = *on; // F12 CANCEL
                 leave;

              when *in05 = *on; // F3 REFRESH
                 exsr LOAD_DATA;
                 iter;

              when *in10 = *on; // F4 TOGGLE MODE
                 if CURRENTMODE = 'L';
                    CURRENTMODE = 'C';
                 elseif CURRENTMODE = 'C';
                    CURRENTMODE = 'H';
                 else;
                    CURRENTMODE = 'L';
                 endif;
                 *in10 = *off;
                 exsr LOAD_DATA;
                 iter;
            endsl;

            // Process Leave / Comp off Control
            if CURRENTMODE = 'L';
               exsr LEAVE_CONTROL;
            elseif CURRENTMODE = 'C';
               exsr COMPOFF_CONTROL;
            elseif CURRENTMODE = 'H';
               exsr HISTORY_CONTROL;
            else;
                CURRENTMODE = 'L';

            endif;

         enddo;
         *inlr = *on;




         //********* LOAD_DATA ***********************
         begsr LOAD_DATA;

            if CURRENTMODE = 'L';
               exsr LOAD_PENDING_LEV;
            elseif CURRENTMODE = 'C';
               exsr LOAD_PENDING_COMP;
            elseif CURRENTMODE = 'H';
               exsr LOAD_TEAM_HISTORY;
            else;
               CURRENTMODE = 'L';
            endif;
         endsr;
         //********* END OF LOAD_DATA ***********************

         //*********** LOAD_PENDING_LEV ***********************
         begsr LOAD_PENDING_LEV;

               // Clear subfile
                  *in27 = *on; // Clear subfile
                  write ARVLVECTL;
                  *in27 = *off;
                  RRN = 0;

               setll *loval LEAVEPF;
               read LEAVEPF;
               dow not %eof;
                 // if LVESTS = 'P' ;
                     $EMPID   = LVEEMPID;
                     $LVEFRDT = LVEFRDT;
                     $LVETODT = LVETODT;
                     $LVETDAY = LVETDAY;
                     $LVESTS  = LVESTS;
                     $LVECLTY = LVECLTY;

                     chain $EMPID EMPMASTER;
                        $EMPNAM = EMPNAM;

                     RRN = RRN + 1;
                     write ARVLVE;
                 // endif;
                  read LEAVEPF;

               enddo;

           //END OF FILE

               if %eof(LEAVEPF);
                  *in28 = *on;   // SFLEND ON
               else;
                  *in28 = *off;  // SFLEND OFF
               endif;


               *in25 = (RRN > 0); // Set subfile no empty indicator
               *in26 = *on; // SFLDSPCTL Set subfile full indicator off
               write ARLVFOOTER;


         endsr;
         //*********** END OF LOAD_PENDING_LEV ***********************

         //********* LEAVE_CONTROL ***********************

         begsr LEAVE_CONTROL;

            // Process Leave subfile options
            readc ARVLVE;
            dow not %eof;
                select;
                  when OPT = 1; // Approve Leave
                     exsr APPROVE_LVE_PROC;
                     //exsr LOAD_DATA;

                  when OPT = 2; // Deny Leave
                     exsr REJECT_LVE_PROC;
                     //exsr LOAD_DATA;

                  when OPT = 5; // View Details
                     exsr VIEW_LVE_DTL;
                     if W_OPT = 1 OR W_OPT = 2;
                       // exsr LOAD_DATA;
                     endif;
                 endsl;

                 clear OPT;
                 update ARVLVE;
                 readc ARVLVE;
            enddo;
            exsr LOAD_DATA;
         endsr;
         //********* END OF LEAVE_CONTROL ***************

        //*********  APPROVE_LVE_PROC ***********************
         begsr APPROVE_LVE_PROC;
               chain $EMPID LEAVEBAL;
               if %found;
                  select;
                    when $LVECLTY = 'CL';
                        if LBCL >= $LVETDAY;
                           LBCL = LBCL - $LVETDAY;

                        else;
                           MSG= 'Error: Insufficient CL Balance';
                           LEAVESR;
                        endif;

                    when $LVECLTY = 'EL';
                        if LBEL >= $LVETDAY;
                           LBEL = LBEL - $LVETDAY;

                        else;
                           MSG= 'Error: Insufficient EL Balance';
                           LEAVESR;
                        endif;

                    when $LVECLTY = 'CO';
                        if LBCO >= $LVETDAY;
                           LBCO = LBCO - $LVETDAY;

                        else;
                           MSG= 'Error: Insufficient CO Balance';
                           LEAVESR;
                        endif;

                  endsl;

                  //SUBTRACT leave days from balance
                  update LVBALREC;

                  //UPDATE LEAVE STATUS TO APPROVED
                  //$EMPID = LVEEMPID;
                  setll $EMPID LEAVEPF;
                  chain $EMPID LEAVEPF;
                  dow %found;
                     if LVEFRDT = $LVEFRDT and LVETODT = $LVETODT;
                        if LVESTS <> 'P';
                           MSG = 'Error: Leave already processed';
                           LEAVESR;
                        else;
                        LVESTS = 'A'; // Approved
                        update LVEREC_U;
                        MSG = 'Leave Approved Successfully';

                        EMPID = $EMPID;
                        chain $EMPID LEAVEPF;
                        $LVESTS = LVESTS;
                        endif;
                        leave;
                     endif;
                     reade ($EMPID) LEAVEPF;
                  enddo;
               endif;
         endsr;

        //********* END OF APPROVE_LVE_PROC ***********************

         //*********  REJECT_LVE_PROC ***********************
          begsr REJECT_LVE_PROC;
                //UPDATE LEAVE STATUS TO REJECTED
                //$EMPID = LVEEMPID;
                setll $EMPID LEAVEPF;
                chain $EMPID LEAVEPF;
                dow %found;
                     if LVEFRDT = $LVEFRDT and LVETODT = $LVETODT;
                        if LVESTS <> 'D';
                           MSG = 'Error: Leave already processed';
                           LEAVESR;
                        endif;
                      LVESTS = 'D'; // Rejected
                      update LVEREC_U;
                      MSG = 'Leave Rejected Successfully';

                        EMPID = $EMPID;
                        chain $EMPID LEAVEPF;
                        $LVESTS = LVESTS;
                      leave;
                     endif;
                     reade ($EMPID) LEAVEPF;
                enddo;
          endsr;
         //********* END OF REJECT_LVE_PROC ***********************

         //*********  VIEW_DETAILS ***********************
          begsr VIEW_LVE_DTL;
                chain $EMPID LEAVEPF; //fETCH FULL DETAILS FROM pf
                dow not %eof;
                   if LVEFRDT = $LVEFRDT;
                       W_EMPID = LVEEMPID;
                       W_FRDT = LVEFRDT;
                       W_TODT = LVETODT;
                       W_TOTDAY = LVETDAY;
                       W_STATUS  = LVESTS;
                       W_LVETYP = LVECLTY;
                       W_REASON = LVERSNY;

                    //FETCH EMP NAME
                   chain W_EMPID EMPMASTER;
                        if %found(EMPMASTER);
                           W_EMPNAM = EMPNAM;
                        endif;

                     //FETCH LEAVE BALANCE
                    chain W_EMPID LEAVEBAL;
                        if %found(LEAVEBAL);
                           if W_LVETYP = 'CL';
                              W_LVEBAL = LBCL;
                           elseif W_LVETYP = 'EL';
                              W_LVEBAL = LBEL;
                           elseif W_LVETYP = 'CO';
                              W_LVEBAL = LBCO;
                           else;
                              W_LVEBAL = 0;
                           endif;
                        endif;

                     //DISPLAY DETAILS
                     clear W_OPT;
                     exfmt LVEDETAIL;

                     // Handling window options
                     if *in12 = *on or *in03 = *on;
                       // W_OPT = 0;
                       // *in12 = *off;
                       // *in03 = *off;
                        leave;
                     else;
                        select;
                           when W_OPT = 1; // Approve from details
                              exsr APPROVE_LVE_PROC;
                              leave;

                           when W_OPT = 2; // Reject from details
                              exsr REJECT_LVE_PROC;
                              leave;
                        endsl;
                     endif;

                     LEAVE;
                   endif;
                 reade ($EMPID) LEAVEPF;
                enddo;


             //F12 CANCEL
             //  if *in12 = *on;
             //     *in12 = *off;
             //     leave;
             //  endif;

          endsr;
         //********* END OF VIEW_LVE_DETAILS ***********************


         //*********** LOAD_PENDING_COMP ***********************
         begsr LOAD_PENDING_COMP;

               // Clear subfile
                  *in32 = *on; // Clear subfile
                  write ARVCOMPCTL;
                  *in32 = *off;
                  *IN33 = *off; // SFLEND OFF
                  RRN1 = 0;

               setll *loval COMPOFF;
               read COMPOFF;
               dow not %eof;
                 // if LVESTS = 'P' ;
                     $EMPID   = COMEMPID;
                     $COMWRDT = COMWRDT;
                     $COMDYTY = COMDYTY;
                     $COMSTS  = COMSTS;


                     chain $EMPID EMPMASTER;
                     if %found;
                        $EMPNAM = EMPNAM;
                     endif;

                     RRN1 = RRN1 + 1;
                     write ARVCOMP;
                 // endif;
                  read COMPOFF;

               enddo;

           //END OF FILE
            //   if %eof(COMPOFF);
            //      *in33 = *on;   // SFLEND ON
            //   else;
            //      *in33 = *off;  // SFLEND OFF
            //   endif;


               *in30 = (RRN1 > 0); // SFLDSP Set subfile no empty indicator
               *in31 = *on; // SFLDSPCTL Set subfile full indicator off
             //  *in32 = *off; // Clear SF data remains visible
               *in33 = *on; // SFLEND ON
               write ARLVFOOTER;


         endsr;
         //*********** END OF LOAD_PENDING_COMP *******************

         //********* COMPOFF_CONTROL ***********************

         begsr COMPOFF_CONTROL;

            // Process Leave subfile options
            readc ARVCOMP;
            dow not %eof;
                select;
                  when OPT = 1; // Approve Leave
                     exsr APPROVE_COMP_PROC;
                     //exsr LOAD_DATA;

                  when OPT = 2; // Deny Leave
                     exsr REJECT_COMP_PROC;
                     //exsr LOAD_DATA;

                  when OPT = 5; // View Details
                     exsr VIEW_CO_DTL;
                   //  exsr LOAD_DATA;

                endsl;

                 clear OPT;
                 update ARVCOMP;
                 readc ARVCOMP;
            enddo;
            exsr LOAD_DATA;
         endsr;
         //********* END OF COMPOFF_CONTROL ***************


        //*********  APPROVE_COMP_PROC ***********************
         begsr APPROVE_COMP_PROC;
               chain $EMPID LEAVEBAL;
               if %found;
                //  select;
                //    when $LVECLTY = 'CL';
                        if $COMDYTY = 'FD';
                           LBCO = LBCO + 1;
                         else;
                           LBCO = LBCO + 0.5;
                        endif;

                  update LVBALREC;

                  //UPDATE LEAVE STATUS TO APPROVED
                  //$EMPID = LVEEMPID;
                  setll $EMPID COMPOFF;
                  chain $EMPID COMPOFF;
                  if %found;
                           if COMSTS <> 'P';
                              MSG = 'Error: Compoff already processed';
                           else;
                              COMSTS = 'A'; // Approved
                              update COMPREC_U;
                              MSG = 'Compoff Approved Successfully';

                            //  EMPID = $EMPID;
                            //  chain $EMPID COMPOFF;
                              $COMSTS = COMSTS;
                           endif;
                  endif;
               endif;
         endsr;

        //********* END OF APPROVE_COMP_PROC ***********************

         //*********  REJECT_COMP_PROC ***********************
          begsr REJECT_COMP_PROC;
                //($EMPID:$COMWRDT) for exact match if multiple records
                //$EMPID = LVEEMPID;
                //setll ($EMPID:$COMWRDT) COMPOFF;
                //chain ($EMPID:$COMWRDT) COMPOFF;

                setll $EMPID COMPOFF;
                chain $EMPID COMPOFF;
                  if %found;
                        if COMSTS <> 'P';
                           MSG = 'Error: Compoff already processed';
                          else;
                           COMSTS = 'D'; // Rejected
                           update COMPREC_U;
                           MSG = 'Compoff Rejected Successfully';

                         //  EMPID = $EMPID;
                         //  chain $EMPID COMPOFF;
                           $COMSTS = COMSTS;
                        endif;
                  endif;

          endsr;
         //********* END OF REJECT_COMP_PROC ***********************

         //*********  VIEW_CO_DTL ***********************
          begsr VIEW_CO_DTL;
                chain $EMPID COMPOFF; //fETCH FULL DETAILS FROM pf
                dow not %eof;
                   if COMWRDT = $COMWRDT;
                       C_EMPID = COMEMPID;
                       C_WRDT  = COMWRDT;
                       C_DYTY  = COMDYTY;
                       C_STS  = COMSTS;
                       C_RSN = COMRSN;
                       C_PRJD = COMPRJD;


                    //FETCH EMP NAME
                   chain C_EMPID EMPMASTER;
                        if %found(EMPMASTER);
                           C_EMPNAM = EMPNAM;
                        endif;

                     //FETCH COMP OFF BALANCE
                  //  chain C_EMPID LEAVEBAL;
                  //      if %found(LEAVEBAL);
                  //         C_COBAL = LBCO;
                  //        else;
                  //         C_COBAL = 0;
                  //      endif;

                     //DISPLAY DETAILS
                     clear C_OPT;
                     exfmt CODETAIL;

                     // Handling window options
                     if *in12 = *on or *in03 = *on;
                       // W_OPT = 0;
                       // *in12 = *off;
                       // *in03 = *off;
                        leave;
                     else;
                        select;
                           when C_OPT = 1; // Approve from details
                              exsr APPROVE_COMP_PROC;
                              leave;

                           when C_OPT = 2; // Reject from details
                              exsr REJECT_COMP_PROC;
                              leave;
                        endsl;
                     endif;

                     LEAVE;
                   endif;
                 reade ($EMPID) COMPOFF;
                enddo;
          endsr;
         //********* END OF VIEW_CO_DTL ***********************

        //*********** LOAD_TEAM_HISTORY ***********************
         begsr LOAD_TEAM_HISTORY;
             *in42 = *on; // Clear subfile
             write TEAMHISTC;
             *in42 = *off;
               RRN2 = 0;

              setll *loval LEAVEPF;
              read LEAVEPF;
              dow not %eof;
                H_EMPID   = LVEEMPID;
                H_FRDT    = LVEFRDT;
                H_TODT    = LVETODT;
                H_TOTDAY  = LVETDAY;
                H_STS     = LVESTS;
                H_TYPE    = LVECLTY;
                H_REASON  = LVERSNY;

                chain H_EMPID EMPMASTER;
                   if %found;
                     H_EMPNAM = EMPNAM;
                   endif;

                  RRN2 = RRN2 + 1;
                  write TEAMHIST;
                  read LEAVEPF;
               enddo;

             //END OF FILE
                 if %eof(LEAVEPF);
                    *in43 = *on;   // SFLEND ON
                 else;
                    *in43 = *off;  // SFLEND OFF
                 endif;

                 *in40 = (RRN2 > 0); // Set subfile no empty indicator
                 *in41 = *on; // SFLDSPCTL Set subfile full indicator off
                 write ARLVFOOTER;
         endsr;
        //*********** END OF LOAD_TEAM_HISTORY ***********************

        //********* HISTORY_CONTROL ***********************

         begsr HISTORY_CONTROL;

            // Process History subfile options
            readc TEAMHIST;
            dow not %eof;
               if H_OPT = 5; // View Details
               // --- FIX: Map Subfile fields to Global Key variables ---
                  $EMPID   = H_EMPID;   // Set the ID from the selected row
                  $LVEFRDT = H_FRDT;    // Set the Date from the selected row
                  exsr VIEW_LVE_DTL;
               endif;

                 clear H_OPT;
                 update TEAMHIST;
                 readc TEAMHIST;
            enddo;
            exsr LOAD_DATA;
         endsr;
         //********* END OF HISTORY_CONTROL ***************



