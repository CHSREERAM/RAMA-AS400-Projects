**FREE
      //=================================================================
      // PPQCPPR - Critical Process Parameters subfile (Module 13)
      // Called from PPQHDRR with the parent PROTOCOL_ID. This program's
      // shape - load/add/update/delete against one *SRVPGM - is the
      // template for every other child module's Rxxx program.
      //=================================================================
      ctl-opt main(Main);
      ctl-opt dftactgrp(*no) actgrp('PPQ') bnddir('SREERAMC1/PPQBNDDIR');

      dcl-f PPQCPPD workstn sfile(SFL1:$RRN1) indds(CppInd);

      dcl-ds CppInd len(99);
        F03  ind pos(3);
        F06  ind pos(6);
        F12  ind pos(12);
        Sfl31 ind pos(31);
      end-ds;


      dcl-ds Cpp_t qualified template;
        ProtocolId  int(20);
        CppSeq      int(5);
        StepNo      int(5);
        ParamName   varchar(60);
        LowerLimit  packed(15:4);
        Target      packed(15:4);
        UpperLimit  packed(15:4);
        Uom         char(10);
        Criticality char(1);
        MonFreq     varchar(40);
      end-ds;

      dcl-pr AddCpp int(5) extproc('ADDCPP');
        pCpp likeds(Cpp_t);
      end-pr;
      dcl-pr UpdateCpp ind extproc('UPDATECPP');
        pCpp likeds(Cpp_t);
      end-pr;
      dcl-pr DeleteCpp ind extproc('DELETECPP');
        pProtocolId int(20) const;
        pCppSeq     int(5) const;
      end-pr;

      // Define the explicit prototype for your main entry procedure
      dcl-pr Main extpgm('PPQCPPR');
        pProtocolId int(20) const;
      end-pr;


      dcl-ds wCpp likeds(Cpp_t);
      dcl-s sql_TheProtocolId int(20);


      dcl-proc Main;
        dcl-pi Main;
        pProtocolId int(20) const;
      end-pi;
        sql_TheProtocolId = pProtocolId;
        $H_PROTNO = %char(sql_TheProtocolId);

        LoadSubfile();
        dow *on;
          Sfl31 = *on;
          write SFL1CTL;
          exfmt SFL1CTL;

          if F03 or F12;
            leave;
          elseif F06;
            AddOne();
            LoadSubfile();
          else;
            ProcessOptions();
            LoadSubfile();
          endif;
        enddo;

        close PPQCPPD;
        *inlr = *on;
      end-proc;

      //-----------------------------------------------------------------
      dcl-proc LoadSubfile;
        dcl-s rrn int(10) inz(0);

        exec sql
          DECLARE C2 CURSOR FOR
            SELECT CPP_SEQ, PARAM_NAME, LOWER_LIMIT, TARGET,
                   UPPER_LIMIT, CRITICALITY
            FROM PPQ_CPP
            WHERE PROTOCOL_ID = :sql_TheProtocolId ORDER BY CPP_SEQ;
        exec sql OPEN C2;

        dow sqlcode = 0;
          exec sql
            FETCH C2 INTO :$C_CPPSEQ, :$C_PARAM, :$C_LOLIM, :$C_TARGT,
                          :$C_UPLIM, :$C_CRIT;
          if sqlcode = 0;
            rrn += 1;
            $RRN1 = rrn;
            write SFL1;
          endif;
        enddo;
        exec sql CLOSE C2;
      end-proc;

      //-----------------------------------------------------------------
      dcl-proc AddOne;
        clear wCpp;
        // In production: separate CPPDTL detail format for full field
        // entry (Step No, MonFreq, Uom); simplified here to subfile-only
        // capture via direct-add row on the list format.
        wCpp.ProtocolId  = sql_TheProtocolId;
        wCpp.ParamName   = 'NEW PARAMETER';
        wCpp.Criticality = 'C';
        AddCpp(wCpp);
      end-proc;

      //-----------------------------------------------------------------
      dcl-proc ProcessOptions;
        readc SFL1;
        dow not %eof(PPQCPPD);
          select;
            when $SFLOPT = '2';
              wCpp.ProtocolId  = sql_TheProtocolId;
              wCpp.CppSeq      = $C_CPPSEQ;
              wCpp.ParamName   = %trim($C_PARAM);
              wCpp.LowerLimit  = $C_LOLIM;
              wCpp.Target      = $C_TARGT;
              wCpp.UpperLimit  = $C_UPLIM;
              wCpp.Criticality = $C_CRIT;
              UpdateCpp(wCpp);
            when $SFLOPT = '4';
              DeleteCpp(sql_TheProtocolId: $C_CPPSEQ);
          endsl;
          readc SFL1;
        enddo;
      end-proc;

