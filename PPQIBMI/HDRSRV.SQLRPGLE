**FREE
      //=================================================================
      // HDRSRV - Module 3: PPQ Protocol Header business logic
      //=================================================================
      ctl-opt nomain;
      ctl-opt datfmt(*iso);
      exec sql SET OPTION commit = *cs, closqlcsr = *endmod;

      /copy SREERAMC1/PPQIBMI,CPYERR
      /copy SREERAMC1/PPQIBMI,CPYHDR

      dcl-pr NextProtocolNumber varchar(20) extproc('NEXTPROTOCOLNUMBER');
      end-pr;

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

      dcl-pr ChangeStatus ind extproc('CHANGESTATUS');
        pProtocolId int(20) const;
        pNewStatus  varchar(10) const;
        pUserId     varchar(10) const;
      end-pr;

      //-----------------------------------------------------------------
      // CreateHeader - inserts a new Draft protocol header, auto-numbered
      //-----------------------------------------------------------------

      dcl-proc CreateHeader export;
      //You must use dcl-parm if the name of your parameter is identical to-
      // an RPG operation code (op-code) or a reserved free-form keyword-
      // (such as SELECT, MONITOR, LEAVE, UPDATE, READ, DELETE, or EVAL).
        dcl-pi *n int(20);
          //dcl-parm sql_pHeader likeds(PpqHeader_t);
           sql_pHeader likeds(PpqHeader_t);
        end-pi;
        dcl-s sql_NewProtocolNo varchar(20);
        dcl-s sql_NewId int(20);

        sql_NewProtocolNo = NextProtocolNumber();


        exec sql SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

        monitor;
          exec sql
            INSERT INTO PPQ_HEADER
              (PROTOCOL_NO, REVISION_NO, VERSION_NO, PRODUCT_CD,
               PRODUCT_NAME, STRENGTH, DOSAGE_FORM, MARKET, BATCH_SIZE,
               BATCH_SIZE_UOM, VALIDATION_TYPE, STATUS, CREATED_BY)
            VALUES
               (:sql_NewProtocolNo, 0, 1, :sql_pHeader.ProductCd,
                :sql_pHeader.ProductName, :sql_pHeader.Strength,
                :sql_pHeader.DosageForm, :sql_pHeader.Market,
                :sql_pHeader.BatchSize, :sql_pHeader.BatchSizeUom,
                :sql_pHeader.ValidationTyp, :STAT_DRAFT,
                :sql_pHeader.CreatedBy);


          exec sql VALUES IDENTITY_VAL_LOCAL() INTO :sql_NewId;

          // Seed the mandatory PPQ_APPROVAL rows for the standard role chain
          exec sql
            INSERT INTO PPQAPRVL (PROTOCOL_ID, APPR_SEQ, ROLE_CD)
            SELECT :sql_NewId, ROW_NUMBER() OVER (ORDER BY APPROVAL_LEVEL), ROLE_CD
            FROM SEC_ROLE WHERE ACTIVE_IND = 'Y';

          exec sql COMMIT;
          return sql_NewId;
        on-error;
          exec sql ROLLBACK;
          LogError('CreateHeader': sqlcode: sqlstt:
                 'Failed to create protocol header': sql_pHeader.CreatedBy);
          return -1;
        endmon;
      end-proc;

      //-----------------------------------------------------------------
      // GetHeader - retrieves one header by PROTOCOL_ID
      //-----------------------------------------------------------------

      dcl-proc GetHeader export;
        dcl-pi *n ind;
          //dcl-parm sql_pProtocolId int(20) const;
          //dcl-parm sql_pHeader     likeds(PpqHeader_t);
          sql_pProtocolId int(20) const;
          sql_pHeader     likeds(PpqHeader_t);
        end-pi;

        exec sql
          SELECT PROTOCOL_ID, PROTOCOL_NO, REVISION_NO, VERSION_NO,
                 PRODUCT_CD, PRODUCT_NAME, STRENGTH, DOSAGE_FORM, MARKET,
                 BATCH_SIZE, BATCH_SIZE_UOM, VALIDATION_TYPE,
                 STATUS, CREATED_BY, CREATED_TS, UPDATED_BY, UPDATED_TS
          INTO :sql_pHeader
          FROM PPQ_HEADER WHERE PROTOCOL_ID = :sql_pProtocolId;

        return (sqlcode = 0);
      end-proc;

      //-----------------------------------------------------------------
      // UpdateHeader - updates editable header fields (Draft/Review only)
      //-----------------------------------------------------------------

      dcl-proc UpdateHeader export;
        dcl-pi *n ind;
           //dcl-parm sql_pHeader likeds(PpqHeader_t);
           sql_pHeader likeds(PpqHeader_t);
        end-pi;
        dcl-s sql_CurStatus varchar(10);


        exec sql SELECT STATUS INTO :sql_CurStatus
                 FROM PPQ_HEADER
                 WHERE PROTOCOL_ID = :sql_pHeader.ProtocolId;

        if sql_CurStatus <> STAT_DRAFT and sql_CurStatus <> STAT_REVIEW;
          return *off;  // locked once past Review
        endif;

        monitor;
          exec sql
            UPDATE PPQ_HEADER SET
              PRODUCT_NAME = :sql_pHeader.ProductName,
              STRENGTH = :sql_pHeader.Strength,
              DOSAGE_FORM = :sql_pHeader.DosageForm,
              MARKET = :sql_pHeader.Market,
              BATCH_SIZE = :sql_pHeader.BatchSize,
              BATCH_SIZE_UOM = :sql_pHeader.BatchSizeUom,
              VALIDATION_TYPE = :sql_pHeader.ValidationTyp,
              UPDATED_BY = :sql_pHeader.UpdatedBy,
              UPDATED_TS = CURRENT TIMESTAMP
            WHERE PROTOCOL_ID = :sql_pHeader.ProtocolId;
          exec sql COMMIT;
          return *on;
        on-error;
          exec sql ROLLBACK;
          LogError('UpdateHeader': sqlcode: sqlstt:
                  'Failed to update header': sql_pHeader.UpdatedBy);
          return *off;
        endmon;
      end-proc;

      //-----------------------------------------------------------------
      // ChangeStatus - drives the Draft->Review->Approved->Executed->Closed
      // workflow. Approved transition is additionally gated by the DB
      // trigger TRG_PPQ_HEADER_WORKFLOW (pending approvals / equipment).
      //-----------------------------------------------------------------

      dcl-proc ChangeStatus export;
        dcl-pi *n ind;
          //dcl-parm sql_pProtocolId int(20) const;
          //dcl-parm sql_pNewStatus  varchar(10) const;
          //dcl-parm sql_pUserId     varchar(10) const;
          sql_pProtocolId int(20) const;
          sql_pNewStatus  varchar(10) const;
          sql_pUserId     varchar(10) const;
        end-pi;

        monitor;
          exec sql
            UPDATE PPQ_HEADER
            SET STATUS = :sql_pNewStatus,
            UPDATED_BY = :sql_pUserId,
            UPDATED_TS = CURRENT TIMESTAMP
            WHERE PROTOCOL_ID = :sql_pProtocolId;
          exec sql COMMIT;
          return (sqlcode = 0);
        on-error;
          exec sql ROLLBACK;
          // trigger SIGNALs (75001/75002) surface here with the workflow reason
          LogError('ChangeStatus': sqlcode: sqlstt:
              'Status transition rejected by workflow rule': sql_pUserId);
          return *off;
        endmon;
      end-proc;

