**FREE
      //=================================================================
      // PPQMENR - Main Menu driver (Module 3 entry point + navigation)
      //=================================================================
      ctl-opt main(Main);
      ctl-opt dftactgrp(*no) actgrp('PPQ') bnddir('SREERAMC1/PPQBNDDIR');

      dcl-f PPQMENU workstn indds(MenInd);

      dcl-pr PPQHDRR extpgm('PPQHDRR');
      end-pr;
      dcl-pr PPQAPRR extpgm('PPQAPRR');
      end-pr;

      dcl-ds MenInd len(99);
        F03 ind pos(3);
        F12 ind pos(12);
      end-ds;

      dcl-proc Main;
        dow *on;
          write MENU;
          read MENU;
          if F03 or F12;
            leave;
          endif;

          select;
            when $OPTION = '1' or $OPTION = '2';
              PPQHDRR();   // Protocol Search / New Protocol - both enter the
                    // header subfile; F6=Add inside PPQHDRR creates new
            when $OPTION = '4';
              PPQAPRR();   // Approval Worklist
            other;
              // 3 Master Data, 5 Reports, 6 Audit, 7 Security Admin
              // follow the same CALL pattern to MDxxxR / RPTxxxR / AUDINQR /
              // SECADMR - omitted here, see module map in the System Design
              // Specification for object names.
          endsl;
        enddo;

        close PPQMENU;

        *inlr = *on;
      end-proc;

