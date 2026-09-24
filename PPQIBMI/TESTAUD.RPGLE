**FREE
      //=================================================================
      // TESTAUD - Test Harness to simulate DB2 trigger on PPQ_HEADER
      //=================================================================
      ctl-opt dftactgrp(*no) actgrp(*new);

      // 1. Define the System Trigger Buffer structure matching TrigBuf_t
      dcl-ds TrigBuf_t qualified template;
        PgmName        char(10) pos(1);
        PgmLib         char(10) pos(11);
        TblName        char(10) pos(21);
        TblLib         char(10) pos(31);
        Timestamp      char(26) pos(41);
        TrigEvent      char(1)  pos(67);
        TrigTime       char(1)  pos(68);
        CCSID          int(10)  pos(69);
        OldRecLen      int(10)  pos(73);
        NewRecLen      int(10)  pos(77);
        NullOldOffset  int(10)  pos(81);
        NullNewOffset  int(10)  pos(85);
        OldRecOffset   int(10)  pos(89);
        NewRecOffset   int(10)  pos(93);
      end-ds;

      // 2. Define the PpqHeader record structure
      dcl-ds PpqHeaderRec_t qualified template;
        ProtocolId  packed(18:0);
        ProtocolNo  varchar(20);
        RevisionNo  int(5);
        VersionNo   int(5);
        ProductCd   char(15);
        ProductName varchar(80);
        Strength    varchar(40);
        DosageForm  varchar(40);
        Market      varchar(60);
        BatchSize   packed(15:3);
        BatchSzUom  char(6);
        ValdtnTyp   char(2);
        Status      varchar(10);
        CreatedBy   varchar(10);
        CreatedTs   char(26);
        UpdatedBy   varchar(10);
        UpdatedTs   char(26);
      end-ds;

      // 3. Define the combined buffer (Trigger Header + New Record Data)
      dcl-ds TestBuffer qualified;
        Header     likeds(TrigBuf_t)       inz;
        NewRecord  likeds(PpqHeaderRec_t)  inz;
      end-ds;

      dcl-s BufferLen int(10);

      // Define prototype matching the new PPQHDRAUD parameter definition
      dcl-pr PPQHDRAUD extpgm('PPQHDRAUD');
        pTriggerBuffer likeds(TrigBuf_t);
        pTriggerBufLen int(10) const options(*nopass);
      end-pr;

      // Populate Mock Trigger Header Data
      TestBuffer.Header.PgmName = 'PPQHDRAUD';
      TestBuffer.Header.PgmLib = 'SREERAMC1';
      TestBuffer.Header.TblName = 'PPQ_HEADER';
      TestBuffer.Header.TblLib = 'SREERAMC1';
      TestBuffer.Header.TrigEvent = 'I'; // 'I' = Insert
      TestBuffer.Header.TrigTime = '2';  // '2' = After Event
      TestBuffer.Header.CCSID = 37;
      TestBuffer.Header.NewRecLen = %size(PpqHeaderRec_t);
      TestBuffer.Header.NewRecOffset = %size(TrigBuf_t); // Offset to NewRecord (96 bytes)
      TestBuffer.Header.OldRecLen = 0;
      TestBuffer.Header.OldRecOffset = 0; // No old record for insert

      // Populate Mock New Record Data
      TestBuffer.NewRecord.ProtocolId = 123456;
      TestBuffer.NewRecord.ProtocolNo = 'PRT-2026-001';
      TestBuffer.NewRecord.RevisionNo = 0;
      TestBuffer.NewRecord.VersionNo = 1;
      TestBuffer.NewRecord.ProductCd = 'PROD-ABC';
      TestBuffer.NewRecord.ProductName = 'Test Product';
      TestBuffer.NewRecord.Status = 'DRAFT';

      BufferLen = %size(TestBuffer);

      // Call the trigger program with the aligned buffer
      PPQHDRAUD(TestBuffer.Header : BufferLen);

      *inlr = *on;
