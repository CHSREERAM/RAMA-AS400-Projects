**FREE
      //=================================================================
      // CPPSRV - Module 13: Critical Process Parameters
      // Reference implementation of the "child/detail module" pattern:
      // every other 1-to-many module off PPQ_HEADER (Formula, Equipment,
      // Utilities, Vendor, Method, Process, CQA, Risk, Plan, Environment,
      // Sampling, Yield, Deviation, Attachment) follows this exact shape
      // - swap the table/columns and keep AddX / UpdateX / DeleteX / ListX.
      //=================================================================
      ctl-opt nomain;
      exec sql SET OPTION commit = *cs, closqlcsr = *endmod;

      /copy SREERAMC1/PPQIBMI,CPYERR

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

      //-----------------------------------------------------------------

      dcl-proc AddCpp export;
        dcl-pi *n int(5);
            sql_pCpp likeds(Cpp_t);
        end-pi;

        dcl-s sql_NextSeq int(5);

        monitor;
          exec sql
            SELECT COALESCE(MAX(CPP_SEQ), 0) + 1 INTO :sql_NextSeq
            FROM PPQ_CPP WHERE PROTOCOL_ID = :sql_pCpp.ProtocolId;

          exec sql
            INSERT INTO PPQ_CPP
              (PROTOCOL_ID, CPP_SEQ, STEP_NO, PARAM_NAME, LOWER_LIMIT,
               TARGET, UPPER_LIMIT, UOM, CRITICALITY, MON_FREQ)
            VALUES
              (:sql_pCpp.ProtocolId, :sql_NextSeq, :sql_pCpp.StepNo,
               :sql_pCpp.ParamName, :sql_pCpp.LowerLimit,
               :sql_pCpp.Target, :sql_pCpp.UpperLimit, :sql_pCpp.Uom,
               :sql_pCpp.Criticality, :sql_pCpp.MonFreq);
          exec sql COMMIT;
          return sql_NextSeq;
        on-error;
          exec sql ROLLBACK;
          LogError('AddCpp': sqlcode: sqlstt: 'Failed to add CPP': 'SYSTEM');
          return -1;
        endmon;
      end-proc;

      //-----------------------------------------------------------------

      dcl-proc UpdateCpp export;
        dcl-pi *n ind;
          sql_pCpp likeds(Cpp_t);
        end-pi;

        monitor;
          exec sql
            UPDATE PPQ_CPP SET
              STEP_NO = :sql_pCpp.StepNo,
              PARAM_NAME = :sql_pCpp.ParamName,
              LOWER_LIMIT = :sql_pCpp.LowerLimit,
              TARGET = :sql_pCpp.Target,
              UPPER_LIMIT = :sql_pCpp.UpperLimit,
              UOM = :sql_pCpp.Uom,
              CRITICALITY = :sql_pCpp.Criticality,
              MON_FREQ = :sql_pCpp.MonFreq
              WHERE PROTOCOL_ID = :sql_pCpp.ProtocolId
                    AND CPP_SEQ = :sql_pCpp.CppSeq;
          exec sql COMMIT;
          return (sqlcode = 0);
        on-error;
          exec sql ROLLBACK;
          LogError('UpdateCpp': sqlcode: sqlstt:
                   'Failed to update CPP': 'SYSTEM');
          return *off;
        endmon;
      end-proc;

      //-----------------------------------------------------------------

      dcl-proc DeleteCpp export;
        dcl-pi *n ind;
          sql_pProtocolId int(20) const;
          sql_pCppSeq     int(5) const;
        end-pi;

        monitor;
          exec sql
            DELETE FROM PPQ_CPP
            WHERE PROTOCOL_ID = :sql_pProtocolId
                  AND CPP_SEQ = :sql_pCppSeq;
          exec sql COMMIT;
          return (sqlcode = 0);
        on-error;
          exec sql ROLLBACK;
          LogError('DeleteCpp': sqlcode: sqlstt:
                   'Failed to delete CPP': 'SYSTEM');
          return *off;
        endmon;
      end-proc;

