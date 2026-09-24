**FREE
      //=================================================================
      // STATSRV - Module 21: Statistical Analysis
      // Computes Mean, StdDev, Cp/Cpk/Pp/Ppk for a CPP across all
      // recorded process-performance readings, and stores the result
      // in PPQ_STATISTICS. Readings themselves are expected in a
      // caller-supplied array (e.g. loaded from a subfile or a batch
      // upload landing table) - this keeps STATSRV independent of any
      // single data-entry path.
      //=================================================================
      ctl-opt nomain;
      ctl-opt datfmt(*iso);
      exec sql SET OPTION commit = *none, closqlcsr = *endmod;

      /copy SREERAMC1/PPQIBMI,CPYERR

      dcl-c MAX_READINGS 1000;

      dcl-pr CalcCapability extproc('CALCCAPABILITY');
        pReadings   packed(15:5) dim(MAX_READINGS) const;
        pCount      int(10) const;
        pLowerLimit packed(15:4) const;
        pUpperLimit packed(15:4) const;
        pMean       packed(15:5);
        pStdDev     packed(15:5);
        pCp         packed(9:4);
        pCpk        packed(9:4);
      end-pr;

      dcl-pr SaveStatistics ind extproc('SAVESTATISTICS');
        pProtocolId int(20) const;
        pCppSeq     int(5) const;
        pSampleSize int(10) const;
        pMean       packed(15:5) const;
        pStdDev     packed(15:5) const;
        pCp         packed(9:4) const;
        pCpk        packed(9:4) const;
        PP          packed(9:4) const;
        PPK         packed(9:4) const;
      end-pr;

      //-----------------------------------------------------------------
      // CalcCapability - given an array of readings and spec limits,
      // returns Mean/StdDev/Cp/Cpk (Pp/Ppk use the same formula against
      // the full population; Cp/Cpk use subgroup-based sigma supplied
      // by the caller when subgrouping is used - simplified here to
      // overall standard deviation for a single, ungrouped PPQ batch set).
      //-----------------------------------------------------------------

      dcl-proc CalcCapability export;
        dcl-pi *n;
          pReadings   packed(15:5) dim(MAX_READINGS) const;
          pCount      int(10) const;
          pLowerLimit packed(15:4) const;
          pUpperLimit packed(15:4) const;
          pMean       packed(15:5);
          pStdDev     packed(15:5);
          pCp         packed(9:4);
          pCpk        packed(9:4);
        end-pi;

        dcl-s i          int(10);
        dcl-s sum        packed(20:5);
        dcl-s sumSqDiff  packed(20:5);
        dcl-s mean       packed(15:5);
        dcl-s stdDev     packed(15:5);
        dcl-s uslMinusMean packed(15:5);
        dcl-s meanMinusLsl packed(15:5);

        if pCount <= 1;
          pMean = 0;
          pStdDev = 0;
          pCp = 0;
          pCpk = 0;
          return;
        endif;

        sum = 0;
        for i = 1 to pCount;
          sum += pReadings(i);
        endfor;
        mean = sum / pCount;

        sumSqDiff = 0;
        for i = 1 to pCount;
          sumSqDiff += ((pReadings(i) - mean) * (pReadings(i) - mean));
        endfor;
        stdDev = %sqrt(sumSqDiff / (pCount - 1));

        pMean   = mean;
        pStdDev = stdDev;

        if stdDev = 0;
          pCp = 0;
          pCpk = 0;
          return;
        endif;

        pCp = %dec((pUpperLimit - pLowerLimit) / (6 * stdDev) : 9 : 4);

        uslMinusMean = pUpperLimit - mean;
        meanMinusLsl = mean - pLowerLimit;
        if uslMinusMean < meanMinusLsl;
          pCpk = %dec(uslMinusMean / (3 * stdDev) : 9 : 4);
        else;
          pCpk = %dec(meanMinusLsl / (3 * stdDev) : 9 : 4);
        endif;
      end-proc;

      //-----------------------------------------------------------------
      // SaveStatistics - persists a computed result row to PPQ_STATISTICS
      // Pp/Ppk are stored equal to Cp/Cpk in this simplified single-phase
      // model; extend with long-term subgroup capture to differentiate.
      //-----------------------------------------------------------------

      dcl-proc SaveStatistics export;
        dcl-pi *n ind;

        dcl-parm sql_pProtocolId int(20) const;
        dcl-parm sql_pCppSeq     int(5) const;
        dcl-parm sql_pSampleSize int(10) const;
        dcl-parm sql_pMean       packed(15:5) const;
        dcl-parm sql_pStdDev     packed(15:5) const;
        dcl-parm sql_pCp         packed(9:4) const;
        dcl-parm sql_pCpk        packed(9:4) const;
        dcl-parm sql_PP          packed(9:4) const;
        dcl-parm sql_PPK         packed(9:4) const;

        end-pi;

        dcl-s sql_NextSeq int(5);

        monitor;
          exec sql
            SELECT COALESCE(MAX(STAT_SEQ), 0) + 1 INTO :sql_NextSeq
            FROM SREERAMC1.PPQSTTSTCS
            WHERE PROTOCOL_ID = :sql_pProtocolId;

          exec sql
            INSERT INTO SREERAMC1.PPQSTTSTCS
              (PROTOCOL_ID, STAT_SEQ, CPP_SEQ, SAMPLE_SIZE, MEAN_VAL,
                STD_DEV, CP, CPK, PP, PPK)
            VALUES
              (:sql_pProtocolId, :sql_NextSeq, :sql_pCppSeq,
               :sql_pSampleSize, :sql_pMean, :sql_pStdDev, :sql_pCp,
               :sql_pCpk, :sql_PP, :sql_PPK);

          return *on;
        on-error;
          LogError('SaveStatistics': sqlcode: sqlstt:
                   'Failed to save statistics': 'SYSTEM');
          return *off;
        endmon;
      end-proc;

