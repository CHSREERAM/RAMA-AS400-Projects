**FREE
      //=================================================================
      // PPQHDRR - Protocol Header: Search subfile + Detail maintenance
      // Presentation layer only - all data access via HDRSRV.
      //=================================================================
      ctl-opt main(Main);
      ctl-opt dftactgrp(*no) actgrp('PPQ') bnddir('SREERAMC1/PPQBNDDIR');

      dcl-f PPQHDRD workstn sfile(SFL1:$RRN1) indds(HdrInd);

      dcl-ds HdrInd len(99);
        F03  ind pos(3);
        F06  ind pos(6);
        F09  ind pos(9);
        F12  ind pos(12);
        F15  ind pos(15);
        Sfl31 ind pos(31);
      end-ds;

      /copy SREERAMC1/PPQIBMI,CPYHDR
      /copy SREERAMC1/PPQIBMI,CPYSEC

      dcl-pr CreateHeader int(20) extproc('CREATEHEADER');
        pHeader likeds(PpqHeader_t);
      end-pr;

      dcl-pr GetHeader ind extproc('GETHEADER');
        pProtocolId int(20) const;
        pHeader     likeds(PpqHeader_t);
      end-pr;

      dcl-pr UpdateHeader ind extproc('UPDATEHEADER');
        pHeader likeds(PpqHeader_t);
      end-pr;

      dcl-pr PPQCPPR extpgm('PPQCPPR');
        pProtocolId int(20) const;
      end-pr;



      dcl-ds wHdr likeds(PpqHeader_t);


      dcl-s sql_SelectedId int(20);

      dcl-proc Main;
        LoadSubfile();
        dow *on;
          Sfl31 = *on;   // display subfile control
          write SFL1CTL;
          exfmt SFL1CTL;

          if F03 or F12;
            leave;
          elseif F06;
            AddProtocol();
            LoadSubfile();
          elseif F09;
        // print preview - CALL RPTHDRR passing the current filter (omitted)
          elseif F15;
            // search window - prompt for status/product filter (omitted)
          else;
            ProcessSubfileOptions();
            LoadSubfile();
          endif;
        enddo;

        close PPQHDRD;
        *inlr = *on;
      end-proc;

      //-----------------------------------------------------------------
      dcl-proc LoadSubfile;
        dcl-s rrn int(10) inz(0);

        exec sql
          DECLARE C1 CURSOR FOR
            SELECT PROTOCOL_ID, PROTOCOL_NO, REVISION_NO,
                   PRODUCT_NAME, STATUS
            FROM PPQ_HEADER ORDER BY CREATED_TS DESC;
        exec sql OPEN C1;

        dow sqlcode = 0;
          exec sql FETCH C1 INTO :sql_SelectedId, :$PROTNOS, :$REVN,
                                 :$PRODN, :$STATS;
          if sqlcode = 0;
            rrn += 1;
            $RRN1 = rrn;
            write SFL1;
          endif;
        enddo;
        exec sql CLOSE C1;
      end-proc;

      //-----------------------------------------------------------------
      dcl-proc AddProtocol;
        clear wHdr;
        $D_STATUS = STAT_DRAFT;
        exfmt HDRDTL;
        if not *in12;
          wHdr.ProductCd     = $D_PRODCD;
          wHdr.ProductName   = $D_PRODNM;
          wHdr.Strength      = $D_STRNG;
          wHdr.DosageForm    = $D_DOSFRM;
          wHdr.Market        = $D_MARKET;
          wHdr.BatchSize     = $D_BATSZ;
          wHdr.BatchSizeUom  = $D_BATUOM;
          wHdr.ValidationTyp = $D_VTYPE;
          wHdr.CreatedBy     = %trim(sql_gSession.UserId);
          sql_SelectedId = CreateHeader(wHdr);
        endif;
      end-proc;

      //-----------------------------------------------------------------
      dcl-proc ProcessSubfileOptions;
        dcl-s rrn int(10) inz(0);

        readc SFL1;
        dow not %eof(PPQHDRD);
          select;
            when $SFLOPT = '2';   // select -> open detail, then CPP/child modules
              if GetHeader(sql_SelectedId: wHdr);
                $D_PROTNO = wHdr.ProtocolNo;
                $D_STATUS = wHdr.Status;
                $D_PRODCD = wHdr.ProductCd;
                $D_PRODNM = wHdr.ProductName;
                $D_STRNG  = wHdr.Strength;
                $D_DOSFRM = wHdr.DosageForm;
                $D_MARKET = wHdr.Market;
                $D_BATSZ  = wHdr.BatchSize;
                $D_BATUOM = wHdr.BatchSizeUom;
                $D_VTYPE = wHdr.ValidationTyp;
                exfmt HDRDTL;
                if not *in12;
                  wHdr.ProductName = $D_PRODNM;
                  wHdr.Strength = $D_STRNG;
                  wHdr.DosageForm  = $D_DOSFRM;
                  wHdr.Market   = $D_MARKET;
                  wHdr.BatchSize   = $D_BATSZ;
                  wHdr.BatchSizeUom = $D_BATUOM;
                  wHdr.ValidationTyp = $D_VTYPE;
                  wHdr.UpdatedBy = %trim(sql_gSession.UserId);
                  UpdateHeader(wHdr);
                endif;
                PPQCPPR(sql_SelectedId);   // drill into Critical Process Parameters
              endif;
            when $SFLOPT = '5';   // inquire (read-only) - same screen, protected
              // omitted for brevity - identical to '2' with DSPATR(PR) fields
          endsl;
          readc SFL1;
        enddo;
      end-proc;

