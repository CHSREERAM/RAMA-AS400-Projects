**FREE
      //=================================================================
      // PPQHDRAUD - Database TRIGGER on PPQ_HEADER (AFTER INSERT/UPDATE/
      // DELETE). DDS-native replacement for TRG_PPQ_HEADER_AUD.
      // Attach with:
      //   ADDPFTRG FILE(SREERAMC1/PPQ_HEADER) TRGTIME(*AFTER) +
      //          TRGEVENT(*INSERT *UPDATE *DELETE) PGM(SREERAMC1/PPQHDRAUD) +
      //            TRGUPDCND(*ALWAYS) RPLTRG(*YES)
      //
      // IBM i passes ONE parameter to a database trigger program: a
      // pointer to the "trigger buffer". The buffer layout below is the
      // System Format ("format 2") trigger buffer - a fixed, documented
      // layout that has been stable for many releases. Confirm it
      // against "Database trigger support" in the current IBM i SQL
      // Programming topic before relying on it in PPQPRD; if your
      // shop already has a standard trigger-buffer copy book (many do),
      // /copy that instead of the inline template below.
      //=================================================================
      //ctl-opt nomain;
      ctl-opt datfmt(*iso);

      //dcl-pr PPQHDRAUD extpgm('PPQHDRAUD');
        //pTriggerBuffer pointer value;
        //pTriggerBuffer pointer;
      //end-pr;

      //dcl-pi PPQHDRAUD;
        //pTriggerBuffer pointer value;
      //  pTriggerBuffer pointer;
      //end-pi;

      // ---- Trigger buffer template (System Format) ------------------
      //dcl-ds TrigBuf_t based(pTriggerBuffer) qualified;
      dcl-ds TrigBuf_t qualified template;
        PgmName        char(10) pos(1);
        PgmLib         char(10) pos(11);
        TblName        char(10) pos(21);
        TblLib         char(10) pos(31);
        Timestamp      char(26) pos(41);
        TrigEvent      char(1)  pos(67);   // I / U / D
        TrigTime       char(1)  pos(68);   // B / A
        CCSID          int(10)  pos(69);
        OldRecLen      int(10)  pos(73);
        NewRecLen      int(10)  pos(77);
        NullOldOffset  int(10)  pos(81);
        NullNewOffset  int(10)  pos(85);
        OldRecOffset   int(10)  pos(89);
        NewRecOffset   int(10)  pos(93);
      end-ds;

      // Define the prototype with the structure passed by reference
      dcl-pr PPQHDRAUD extpgm('PPQHDRAUD');
        pTriggerBuffer likeds(TrigBuf_t);
        pTriggerBufLen int(10) const options(*nopass);
      end-pr;

      dcl-pi PPQHDRAUD;
        pTriggerBuffer likeds(TrigBuf_t);
        pTriggerBufLen int(10) const options(*nopass);
      end-pi;

      // Old/new record images, mapped over the same PF record format
      // used by PPQ_HEADER.pf - keep this DS in sync if the PF changes.
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

      dcl-s pOldRec pointer;
      dcl-s pNewRec pointer;
      dcl-ds oldRec likeds(PpqHeaderRec_t) based(pOldRec);
      dcl-ds newRec likeds(PpqHeaderRec_t) based(pNewRec);

      dcl-s action    char(1);
      dcl-s nextAudId packed(18:0);
      dcl-s userProf  char(10);

      // ---- Sequence access - the one remaining SQL touchpoint. Kept -
      // deliberately: SEQ_AUDIT_ID is a lightweight, single-purpose
      // object, not a table/view/trigger, and isn't part of the
      // "multi-statement script" class of problem this conversion
      // fixes. Swap for a native next-number PF (see manifest notes)
      // if you'd rather remove every last SQL reference.
      exec sql SET OPTION commit = *none;

      //pOldRec = %addr(TrigBuf_t) + TrigBuf_t.OldRecOffset;
      //pNewRec = %addr(TrigBuf_t) + TrigBuf_t.NewRecOffset;
      //userProf = %subst(TrigBuf_t.PgmLib:1:10);
     // fallback; prefer USER special register below

     // Safely calculate record offsets using %addr of the parameter
      pOldRec = %addr(pTriggerBuffer) + pTriggerBuffer.OldRecOffset;
      pNewRec = %addr(pTriggerBuffer) + pTriggerBuffer.NewRecOffset;
      userProf = %subst(pTriggerBuffer.PgmLib:1:10);

      exec sql VALUES CURRENT USER INTO :userProf;

      select;
        //when TrigBuf_t.TrigEvent = 'I';
        when pTriggerBuffer.TrigEvent = 'I';
          action = 'I';
          exec sql
            INSERT INTO PPQ_AUDIT (AUDIT_ID, PROTOCOL_ID, TABLE_NAME,
                           ACTION, KEY_VALUE, COLUMN_NAME, OLD_VALUE,
                           NEW_VALUE, CHANGED_BY)
            VALUES (NEXT VALUE FOR SEQ_AUDIT_ID, :newRec.ProtocolId,
                    'PPQ_HEADER', :action, CHAR(:newRec.ProtocolId),
                    'STATUS', NULL, :newRec.Status, :userProf);

        //when TrigBuf_t.TrigEvent = 'U';
        when pTriggerBuffer.TrigEvent = 'U';
          action = 'U';
          if newRec.Status <> oldRec.Status;
            exec sql
              INSERT INTO PPQ_AUDIT (AUDIT_ID, PROTOCOL_ID, TABLE_NAME,
                             ACTION, KEY_VALUE, COLUMN_NAME, OLD_VALUE,
                             NEW_VALUE, CHANGED_BY)
              VALUES (NEXT VALUE FOR SEQ_AUDIT_ID, :newRec.ProtocolId,
                      'PPQ_HEADER', :action, CHAR(:newRec.ProtocolId),
                      'STATUS', :oldRec.Status, :newRec.Status, :userProf);
          endif;

        //when TrigBuf_t.TrigEvent = 'D';
        when pTriggerBuffer.TrigEvent = 'D';
          action = 'D';
          exec sql
            INSERT INTO PPQ_AUDIT (AUDIT_ID, PROTOCOL_ID, TABLE_NAME,
                           ACTION, KEY_VALUE, COLUMN_NAME, OLD_VALUE,
                           NEW_VALUE, CHANGED_BY)
            VALUES (NEXT VALUE FOR SEQ_AUDIT_ID, :oldRec.ProtocolId,
                    'PPQ_HEADER', :action, CHAR(:oldRec.ProtocolId),
                    'STATUS', :oldRec.Status, NULL, :userProf);
      endsl;

      *inlr = *on;

