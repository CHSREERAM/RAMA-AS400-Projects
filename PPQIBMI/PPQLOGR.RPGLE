
**FREE
      //=================================================================
      // PPQLOGR - Login program (Module 1). Entry point of the job;
      // on success CALLs PPQMENR, on F3 ends the job.
      //=================================================================
      ctl-opt main(Main);
      //ctl-opt dftactgrp(*no) actgrp('PPQ'); if binddir not provided,-
      //the default activation group is used and shows errors in binding step.
      ctl-opt dftactgrp(*no) actgrp('PPQ') bnddir('SREERAMC1/PPQBNDDIR');

      dcl-f PPQLOGD workstn indds(LogInd);


      dcl-pr Log_in ind extproc('LOGIN');
        pUserId   varchar(10) const;
        pPassword varchar(128) const;
        pDeviceNm char(10) const options(*nopass);
      end-pr;

      dcl-pr PPQMENR extpgm('PPQMENR');
      end-pr;

      dcl-ds LogInd len(99);
        F03 ind pos(3);
      end-ds;

      dcl-ds pgmStatus PSDS qualified;
         SystemName char(8) pos(396);
      end-ds;


      dcl-proc Main;
        dow *on;
          clear $MSGTXT;
          write LOGIN;
          read LOGIN;
          if F03;
            leave;
          endif;




          if Log_in($USERID: $PASSWD: %char(pgmStatus.SystemName));
            PPQMENR();
          else;
            $MSGTXT = 'Invalid user ID or password, or account locked.';
          endif;
        enddo;

        // Explicitly close the workstation file to resolve warning RNF7534
        close PPQLOGD;

        *inlr = *on;
      end-proc;

